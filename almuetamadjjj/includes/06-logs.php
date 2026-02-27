<?php
/**
 * نظام المعتمد – جدول السجلات ودوال التسجيل
 */
if (!defined('ABSPATH')) { return; }

function libya_create_logs_table_v14()
{
    global $wpdb;
    $table_name = $wpdb->prefix . 'libya_system_logs';
    $charset_collate = $wpdb->get_charset_collate();

    $sql = "CREATE TABLE $table_name (
        id mediumint(9) NOT NULL AUTO_INCREMENT,
        time datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
        action varchar(50) NOT NULL,
        email varchar(100) NOT NULL,
        details text NOT NULL,
        note text DEFAULT NULL,
        ip varchar(45) NOT NULL,
        PRIMARY KEY  (id)
    ) $charset_collate;";

    require_once(ABSPATH . 'wp-admin/includes/upgrade.php');
    dbDelta($sql);
}

function libya_check_logs_table_v14()
{
    if (!get_option('libya_logs_table_created_v14')) {
        libya_create_logs_table_v14();
        update_option('libya_logs_table_created_v14', 1);
    }
    global $wpdb;
    $table = $wpdb->prefix . 'libya_system_logs';
    if ($wpdb->get_var($wpdb->prepare("SHOW TABLES LIKE %s", $table)) === $table && !$wpdb->get_results("SHOW COLUMNS FROM {$table} LIKE 'note'")) {
        $wpdb->query("ALTER TABLE {$table} ADD COLUMN note text DEFAULT NULL AFTER details");
    }
    libya_logs_ensure_indexes_v14();
}

/**
 * إضافة فهارس لجدول السجلات لتحسين أداء البحث والترتيب
 */
function libya_logs_ensure_indexes_v14()
{
    if (get_option('libya_logs_indexes_v14_done')) {
        return;
    }
    global $wpdb;
    $table = $wpdb->prefix . 'libya_system_logs';
    if ($wpdb->get_var($wpdb->prepare("SHOW TABLES LIKE %s", $table)) !== $table) {
        return;
    }
    $indexes = ['libya_logs_time' => 'time', 'libya_logs_email' => 'email', 'libya_logs_action' => 'action'];
    foreach ($indexes as $name => $col) {
        $exists = $wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema = DATABASE() AND table_name = %s AND index_name = %s", $wpdb->prefix . 'libya_system_logs', $name));
        if (empty($exists)) {
            $wpdb->query("ALTER TABLE {$table} ADD INDEX {$name} ({$col})");
        }
    }
    update_option('libya_logs_indexes_v14_done', 1);
}

/**
 * إنشاء جدول أرشفة السجلات (نفس بنية الجدول الرئيسي)
 */
function libya_create_logs_archive_table_v14()
{
    global $wpdb;
    $table = $wpdb->prefix . 'libya_system_logs_archive';
    if ($wpdb->get_var($wpdb->prepare("SHOW TABLES LIKE %s", $table)) === $table) {
        return;
    }
    $charset = $wpdb->get_charset_collate();
    $sql = "CREATE TABLE $table (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        time datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
        action varchar(50) NOT NULL,
        email varchar(100) NOT NULL,
        details text NOT NULL,
        note text DEFAULT NULL,
        ip varchar(45) NOT NULL,
        PRIMARY KEY (id),
        KEY time (time),
        KEY email (email),
        KEY action (action)
    ) $charset;";
    require_once ABSPATH . 'wp-admin/includes/upgrade.php';
    dbDelta($sql);
}

/**
 * نقل السجلات الأقدم من حد زمني إلى جدول الأرشفة ثم حذفها من الجدول الرئيسي (ضمن معاملة لضمان سلامة البيانات)
 * @param string $before_date تاريخ بصيغة Y-m-d H:i:s (مثلاً 6 أشهر)
 * @return array ['moved' => int, 'error' => string|null]
 */
function libya_archive_old_logs_v14($before_date)
{
    global $wpdb;
    $main = $wpdb->prefix . 'libya_system_logs';
    $archive = $wpdb->prefix . 'libya_system_logs_archive';
    if ($wpdb->get_var($wpdb->prepare("SHOW TABLES LIKE %s", $main)) !== $main) {
        return ['moved' => 0, 'error' => 'جدول السجلات غير موجود'];
    }
    libya_create_logs_archive_table_v14();

    $wpdb->query('START TRANSACTION');
    $inserted = $wpdb->query($wpdb->prepare(
        "INSERT INTO $archive (time, action, email, details, note, ip) SELECT time, action, email, details, note, ip FROM $main WHERE time < %s",
        $before_date
    ));
    if ($inserted === false || $wpdb->last_error) {
        $wpdb->query('ROLLBACK');
        return ['moved' => 0, 'error' => $wpdb->last_error ?: 'فشل نقل السجلات إلى الأرشفة'];
    }
    $moved = (int) $inserted;
    if ($moved > 0) {
        $deleted = $wpdb->query($wpdb->prepare("DELETE FROM $main WHERE time < %s", $before_date));
        if ($deleted === false || $wpdb->last_error) {
            $wpdb->query('ROLLBACK');
            return ['moved' => 0, 'error' => $wpdb->last_error ?: 'فشل حذف السجلات بعد الأرشفة'];
        }
    }
    $wpdb->query('COMMIT');
    return ['moved' => $moved, 'error' => null];
}

/**
 * تسجيل إجراء في نظام السجلات
 */
function libya_system_log_v14($action, $email, $details = '', $dedupe_ttl_seconds = 0, $note = '')
{
    global $wpdb;
    $table_name = $wpdb->prefix . 'libya_system_logs';

    if ($dedupe_ttl_seconds > 0) {
        $dedupe_key = 'libya_log_dedup_' . md5($action . '|' . $email . '|' . $details);
        if (get_transient($dedupe_key)) {
            return;
        }
        set_transient($dedupe_key, 1, $dedupe_ttl_seconds);
    }

    $cols = array(
        'time' => current_time('mysql'),
        'action' => $action,
        'email' => $email,
        'details' => $details,
        'ip' => filter_var($_SERVER['REMOTE_ADDR'] ?? 'unknown', FILTER_VALIDATE_IP) ?: 'unknown'
    );
    $cols['note'] = $note ? wp_kses_post($note) : '';

    $wpdb->insert($table_name, $cols);

    $log_entry = sprintf("[%s] %s | %s | %s\n", date('Y-m-d H:i:s'), $action, $email, $details);
    $log_file = WP_CONTENT_DIR . '/libya_system_v14.log';

    try {
        if (is_writable(WP_CONTENT_DIR) || (file_exists($log_file) && is_writable($log_file))) {
            $result = file_put_contents($log_file, $log_entry, FILE_APPEND);
            if ($result === false) {
                error_log('Libya System: Failed to write to log file: ' . $log_file);
            }
        }
    } catch (Exception $e) {
        error_log('Libya System Log Error: ' . $e->getMessage());
    }
}

function libya_format_wait_time_v14($timestamp)
{
    if (!$timestamp) return '0 دقيقة';
    $diff = time() - $timestamp;
    if ($diff < 60) return 'الآن';
    if ($diff < 3600) return floor($diff / 60) . ' دقيقة';
    if ($diff < 86400) {
        $hours = floor($diff / 3600);
        $mins = floor(($diff % 3600) / 60);
        return $hours . ' ساعة و ' . $mins . ' دقيقة';
    }
    if ($diff < 2592000) {
        $days = floor($diff / 86400);
        $hours = floor(($diff % 86400) / 3600);
        return $days . ' يوم و ' . $hours . ' ساعة';
    }
    $months = floor($diff / 2592000);
    $days = floor(($diff % 2592000) / 86400);
    return $months . ' شهر و ' . $days . ' يوم';
}
