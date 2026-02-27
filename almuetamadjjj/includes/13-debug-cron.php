<?php
if (!defined('ABSPATH')) { return; }

// 🔍 صفحة التشخيص - تحميل بعد WordPress
add_action('init', function () {
    $debug_key = isset($_GET['libya_debug_cron']) ? sanitize_text_field(wp_unslash($_GET['libya_debug_cron'])) : '';
    if ($debug_key !== '1') {
        return;
    }
    // 🔒 تقييد الوصول للمسؤولين فقط
    if (!current_user_can('manage_options')) {
        wp_die('عذراً، ليس لديك صلاحية للوصول لهذه الصفحة.');
    }

    $last_run = get_option('libya_cron_last_run', 0);
    $debug_log = get_option('libya_cron_debug_log', 'لا يوجد سجل بعد');

    echo '<!DOCTYPE html><html dir="rtl"><head><meta charset="UTF-8"><title>تشخيص Cron</title>';
    echo '<style>body{font-family:Arial;padding:20px;background:#f5f5f5}';
    echo '.box{background:white;padding:20px;margin:10px 0;border-radius:5px;box-shadow:0 2px 5px rgba(0,0,0,0.1)}';
    echo '.log{background:#263238;color:#aed581;padding:15px;border-radius:5px;white-space:pre-wrap;font-family:monospace;max-height:500px;overflow-y:auto;direction:ltr;text-align:left}';
    echo '.btn{display:inline-block;padding:10px 20px;background:#04acf4;color:white;text-decoration:none;border-radius:5px;margin:5px}';
    echo '</style></head><body>';
    echo '<div class="box"><h1>🔍 سجل تشخيص Cron</h1>';
    echo '<p><strong>آخر تشغيل:</strong> ' . esc_html($last_run ? date('Y-m-d H:i:s', $last_run) . ' (قبل ' . floor((time() - $last_run) / 60) . ' دقيقة)' : 'لم يتم التشغيل') . '</p>';
    echo '<p><strong>الوقت الحالي:</strong> ' . esc_html(date('Y-m-d H:i:s')) . '</p>';
    echo '<p><strong>المهلة الأولى:</strong> ' . esc_html(get_option('libya_def_deadline', 60)) . ' دقيقة</p>';
    echo '<p><strong>المهلة الثانية:</strong> ' . esc_html(get_option('libya_def_extra_time', 30)) . ' دقيقة</p>';
    echo '</div>';

    $nonce_ok = isset($_GET['_wpnonce']) && wp_verify_nonce(sanitize_text_field(wp_unslash($_GET['_wpnonce'])), 'libya_debug_cron');

    // تشغيل يدوي (مع nonce)
    if ($nonce_ok && isset($_GET['run_now'])) {
        echo '<div class="box" style="background:#c8e6c9"><strong>✅ جاري التشغيل...</strong><br>';
        run_libya_merchant_auto_check_v14();
    }

    // مسح السجل (مع nonce)
    if ($nonce_ok && isset($_GET['clear'])) {
        delete_option('libya_cron_debug_log');
        $debug_log = 'تم مسح السجل';
        echo '<div class="box" style="background:#ffecb3">🗑️ تم مسح السجل</div>';
    }

    // مسح سجل الإيميلات (مع nonce)
    if ($nonce_ok && isset($_GET['clear_email'])) {
        delete_option('libya_email_debug_log');
        echo '<div class="box" style="background:#ffecb3">🗑️ تم مسح سجل الإيميلات</div>';
    }

        echo '<div class="box"><h2>📋 السجل:</h2><div class="log">' . htmlspecialchars($debug_log) . '</div></div>';

        // عرض سجل الإيميلات
        $email_log = get_option('libya_email_debug_log', []);
        if (!empty($email_log)) {
            echo '<div class="box"><h2>📧 سجل الإيميلات المرسلة:</h2><div class="log">';
            echo htmlspecialchars(implode("\n", array_reverse($email_log)));
            echo '</div></div>';
        }

        $base = add_query_arg('libya_debug_cron', '1', home_url('/'));
        echo '<div class="box">';
        echo '<a href="' . esc_url(wp_nonce_url(add_query_arg('run_now', '1', $base), 'libya_debug_cron')) . '" class="btn">▶️ تشغيل الآن</a>';
        echo '<a href="' . esc_url(wp_nonce_url(add_query_arg('clear', '1', $base), 'libya_debug_cron')) . '" class="btn" style="background:#f44336">🗑️ مسح السجل</a>';
        echo '<a href="' . esc_url(wp_nonce_url(add_query_arg('clear_email', '1', $base), 'libya_debug_cron')) . '" class="btn" style="background:#ff9800">🗑️ مسح سجل الإيميلات</a>';
        echo '</div>';

        echo '</body></html>';
        exit;
});