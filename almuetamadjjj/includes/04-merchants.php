<?php
/**
 * نظام المعتمد – قائمة التجار وتطبيع المدن + تخزين في جدول للأداء
 */
if (!defined('ABSPATH')) { return; }

function normalize_libya_city_v14($city)
{
    $city = trim($city);
    $city = preg_replace('/[\x{064B}-\x{0652}\s\.\-\_\/]/u', '', $city);
    $city = preg_replace('/[أإآ]/u', 'ا', $city);
    $city = preg_replace('/ؤ/u', 'و', $city);
    $city = preg_replace('/[ةه]$/u', 'ة', $city);
    $city = preg_replace('/[يى]$/u', 'ي', $city);
    $city = preg_replace('/^ال/u', '', $city);
    return $city;
}

/**
 * إنشاء جدول التجار (فهرس على status و last_activity للأداء)
 */
function libya_create_merchants_table_v14()
{
    global $wpdb;
    $table = $wpdb->prefix . 'libya_merchants';
    $charset = $wpdb->get_charset_collate();
    $sql = "CREATE TABLE $table (
        email varchar(100) NOT NULL,
        city varchar(255) DEFAULT '',
        branch_name varchar(255) DEFAULT '',
        owner_name varchar(255) DEFAULT '',
        phone varchar(50) DEFAULT '',
        card_color varchar(20) DEFAULT '',
        commission_rate_tiers longtext,
        fixed_commission_tiers longtext,
        order_limit int unsigned DEFAULT 20,
        status varchar(20) DEFAULT 'active',
        last_activity bigint unsigned DEFAULT 0,
        PRIMARY KEY (email),
        KEY status (status),
        KEY last_activity (last_activity)
    ) $charset;";
    require_once ABSPATH . 'wp-admin/includes/upgrade.php';
    dbDelta($sql);
}

/**
 * هل نستخدم جدول التجار (بعد الهجرة)
 */
function libya_merchants_use_table_v14()
{
    global $wpdb;
    $table = $wpdb->prefix . 'libya_merchants';
    if ($wpdb->get_var($wpdb->prepare("SHOW TABLES LIKE %s", $table)) !== $table) {
        return false;
    }
    return (bool) get_option('libya_merchants_migrated_v14', 0);
}

/**
 * هجرة بيانات التجار من الخيار إلى الجدول (تُستدعى مرة واحدة)
 */
function libya_migrate_merchants_to_table_v14()
{
    if (get_option('libya_merchants_migrated_v14')) {
        return;
    }
    global $wpdb;
    $table = $wpdb->prefix . 'libya_merchants';
    if ($wpdb->get_var($wpdb->prepare("SHOW TABLES LIKE %s", $table)) !== $table) {
        return;
    }
    $list = get_option(MERCHANT_OPTION_KEY_V14, []);
    if (!is_array($list) || empty($list)) {
        update_option('libya_merchants_migrated_v14', 1);
        return;
    }
    $migration_ok = true;
    foreach ($list as $email => $m) {
        if (!is_array($m)) continue;
        $row = [
            'email' => $email,
            'city' => isset($m['city']) ? $m['city'] : '',
            'branch_name' => isset($m['branch_name']) ? $m['branch_name'] : '',
            'owner_name' => isset($m['owner_name']) ? $m['owner_name'] : '',
            'phone' => isset($m['phone']) ? $m['phone'] : '',
            'card_color' => isset($m['card_color']) ? $m['card_color'] : '',
            'commission_rate_tiers' => maybe_serialize(isset($m['commission_rate_tiers']) ? $m['commission_rate_tiers'] : []),
            'fixed_commission_tiers' => maybe_serialize(isset($m['fixed_commission_tiers']) ? $m['fixed_commission_tiers'] : []),
            'order_limit' => isset($m['order_limit']) ? (int) $m['order_limit'] : 20,
            'status' => isset($m['status']) && in_array($m['status'], ['active', 'frozen'], true) ? $m['status'] : 'active',
            'last_activity' => isset($m['last_activity']) ? (int) $m['last_activity'] : 0,
        ];
        if ($wpdb->replace($table, $row) === false || $wpdb->last_error) {
            $migration_ok = false;
            break;
        }
    }
    if ($migration_ok) {
        update_option('libya_merchants_migrated_v14', 1);
        wp_cache_delete(MERCHANT_OPTION_KEY_V14, 'libya_system_v14_cache');
    }
}

/**
 * تحويل صف الجدول إلى مصفوفة تاجر (نفس شكل الخيار)
 */
function libya_row_to_merchant_v14($row)
{
    if (!is_object($row) && !is_array($row)) return [];
    $m = (array) $row;
    return [
        'city' => isset($m['city']) ? $m['city'] : '',
        'email' => isset($m['email']) ? $m['email'] : '',
        'branch_name' => isset($m['branch_name']) ? $m['branch_name'] : '',
        'owner_name' => isset($m['owner_name']) ? $m['owner_name'] : '',
        'phone' => isset($m['phone']) ? $m['phone'] : '',
        'card_color' => isset($m['card_color']) ? $m['card_color'] : '',
        'commission_rate_tiers' => isset($m['commission_rate_tiers']) ? maybe_unserialize($m['commission_rate_tiers']) : [],
        'fixed_commission_tiers' => isset($m['fixed_commission_tiers']) ? maybe_unserialize($m['fixed_commission_tiers']) : [],
        'order_limit' => isset($m['order_limit']) ? (int) $m['order_limit'] : 20,
        'status' => isset($m['status']) ? $m['status'] : 'active',
        'last_activity' => isset($m['last_activity']) ? (int) $m['last_activity'] : 0,
    ];
}

function get_libya_merchants_v14()
{
    $cache_group = 'libya_system_v14_cache';
    $merchants = wp_cache_get(MERCHANT_OPTION_KEY_V14, $cache_group);

    if (false !== $merchants && is_array($merchants)) {
        return $merchants;
    }

    if (libya_merchants_use_table_v14()) {
        global $wpdb;
        $table = $wpdb->prefix . 'libya_merchants';
        $rows = $wpdb->get_results("SELECT * FROM $table", ARRAY_A);
        $merchants = [];
        foreach ($rows as $row) {
            $email = isset($row['email']) ? $row['email'] : '';
            if ($email !== '') {
                $merchants[$email] = libya_row_to_merchant_v14($row);
            }
        }
        wp_cache_set(MERCHANT_OPTION_KEY_V14, $merchants, $cache_group, 12 * HOUR_IN_SECONDS);
        return $merchants;
    }

    $merchants = get_option(MERCHANT_OPTION_KEY_V14, []);
    if (!is_array($merchants)) $merchants = [];
    wp_cache_set(MERCHANT_OPTION_KEY_V14, $merchants, $cache_group, 12 * HOUR_IN_SECONDS);
    return $merchants;
}

/**
 * حفظ قائمة التجار كاملة (إما في الجدول أو الخيار)
 */
function save_libya_merchants_v14($merchants)
{
    if (!is_array($merchants)) return;
    wp_cache_delete(MERCHANT_OPTION_KEY_V14, 'libya_system_v14_cache');

    if (libya_merchants_use_table_v14()) {
        global $wpdb;
        $table = $wpdb->prefix . 'libya_merchants';
        $wpdb->query("TRUNCATE TABLE $table");
        foreach ($merchants as $email => $m) {
            if (!is_array($m)) continue;
            $row = [
                'email' => $email,
                'city' => isset($m['city']) ? $m['city'] : '',
                'branch_name' => isset($m['branch_name']) ? $m['branch_name'] : '',
                'owner_name' => isset($m['owner_name']) ? $m['owner_name'] : '',
                'phone' => isset($m['phone']) ? $m['phone'] : '',
                'card_color' => isset($m['card_color']) ? $m['card_color'] : '',
                'commission_rate_tiers' => maybe_serialize(isset($m['commission_rate_tiers']) ? $m['commission_rate_tiers'] : []),
                'fixed_commission_tiers' => maybe_serialize(isset($m['fixed_commission_tiers']) ? $m['fixed_commission_tiers'] : []),
                'order_limit' => isset($m['order_limit']) ? (int) $m['order_limit'] : 20,
                'status' => isset($m['status']) && in_array($m['status'], ['active', 'frozen'], true) ? $m['status'] : 'active',
                'last_activity' => isset($m['last_activity']) ? (int) $m['last_activity'] : 0,
            ];
            $wpdb->replace($table, $row);
        }
        return;
    }

    update_option(MERCHANT_OPTION_KEY_V14, $merchants);
}

/**
 * التأكد من وجود جدول التجار وهجرة البيانات (للتحديثات دون إعادة تفعيل)
 */
function libya_ensure_merchants_table_v14()
{
    global $wpdb;
    $table = $wpdb->prefix . 'libya_merchants';
    if ($wpdb->get_var($wpdb->prepare("SHOW TABLES LIKE %s", $table)) !== $table) {
        libya_create_merchants_table_v14();
    }
    libya_migrate_merchants_to_table_v14();
}
