<?php

/**
 * نظام المعتمد – فلاتر الأمان والبريد وإخفاء إشعارات لوحة التحكم
 */

if (!defined('ABSPATH')) {
    return;
}

// تسجيل جدولة «كل 5 دقائق» مبكراً حتى يتعرّف عليها ووردبريس عند تشغيل الـ Cron (تفادي invalid_schedule)
add_filter('cron_schedules', function ($schedules) {
    if (!isset($schedules['every_five_minutes'])) {
        $schedules['every_five_minutes'] = array('interval' => 300, 'display' => 'كل 5 دقائق');
    }
    return $schedules;
}, 1);

/**
 * إيميل الطلبات/الأدمن — يُقرأ من الإعدادات؛ إن لم يُحفظ يُستخدم القيمة الافتراضية.
 * التعديل من: نظام المعتمد → صيانة النظام → إعدادات البريد.
 */
if (!function_exists('libya_orders_email_v14')) {
    function libya_orders_email_v14()
    {
        $saved = get_option('libya_orders_email', '');
        return is_email($saved) ? $saved : 'orders@almuetamad.com';
    }
}

// فلاتر الأمان والبريد الإلكتروني
add_filter('nonce_user_logged_out', function ($uid) {
    return (isset($_GET['libya_action']) || isset($_GET['order_action']) || isset($_GET['admin_action'])) ? 0 : $uid;
});

add_filter('wp_mail_from', function ($email) {
    return function_exists('libya_orders_email_v14') ? libya_orders_email_v14() : get_option('admin_email');
});

add_filter('wp_mail_from_name', function ($name) {
    return get_bloginfo('name');
});

add_filter('determine_current_user', function ($user_id) {
    if (isset($_GET['libya_action']) || isset($_GET['order_action']) || isset($_GET['admin_action'])) return 0;
    return $user_id;
}, 20);

// 🔍 تتبع الإيميلات المرسلة للعملاء (للتشخيص)
add_action('woocommerce_email_before_order_table', function ($order, $sent_to_admin, $plain_text, $email) {
    if (!$sent_to_admin && $order) {
        $log_entry = date('Y-m-d H:i:s') . ' | إيميل للعميل | الطلب: ' . $order->get_id() .
            ' | النوع: ' . (isset($email->id) ? $email->id : 'غير معروف') .
            ' | العميل: ' . $order->get_billing_email();
        error_log($log_entry);

        // حفظ في قاعدة البيانات أيضاً
        $email_log = get_option('libya_email_debug_log', []);
        $email_log[] = $log_entry;

        // ✅ Log Rotation - الاحتفاظ بآخر 100 سجل فقط
        if (count($email_log) > 100) {
            $email_log = array_slice($email_log, -100);
        }

        update_option('libya_email_debug_log', $email_log);
    }
}, 10, 4);

// 🚫 إيقاف جميع إيميلات WooCommerce للعملاء (حل قوي)
add_filter('woocommerce_email_enabled_customer_invoice', '__return_false');
add_filter('woocommerce_email_enabled_customer_processing_order', '__return_false');
add_filter('woocommerce_email_enabled_customer_completed_order', '__return_false');
add_filter('woocommerce_email_enabled_customer_on_hold_order', '__return_false');

// حل إضافي: منع الإرسال على مستوى المستلم
add_filter('woocommerce_email_recipient_customer_invoice', '__return_false');
add_filter('woocommerce_email_recipient_customer_processing_order', '__return_false');
add_filter('woocommerce_email_recipient_customer_completed_order', '__return_false');

add_action('phpmailer_init', function ($phpmailer) {
    $phpmailer->CharSet = 'UTF-8';
    $phpmailer->Encoding = 'base64';
});

// إخفاء إشعارات ووردبريس داخل صفحات نظام المعتمد
add_action('admin_head', 'libya_merchant_hide_notifications_v14');
function libya_merchant_hide_notifications_v14()
{
    $page = isset($_GET['page']) ? sanitize_text_field($_GET['page']) : '';
    $hide_by_page = in_array($page, ['system-logs', 'system-maintenance', 'custom-notifications-v7'], true);
    $screen = get_current_screen();
    $hide_by_screen = $screen && (strpos($screen->id, 'merchant-') !== false || strpos($screen->id, 'libya-') !== false || strpos($screen->id, 'admin-earnings-report') !== false);
    if ($hide_by_page || $hide_by_screen) {
        echo '<style>.update-nag, .updated, .error, .notice, .notice-success, .notice-warning, .notice-error, .notice-info, .is-dismissible, #setting-error-tgmpa { display: none !important; }.libya-admin-success-notice { display: block !important; margin: 15px 0; padding: 12px 16px; background: #d4edda; border: 1px solid #c3e6cb; border-radius: 4px; color: #155724; border-right-width: 4px; border-right-style: solid; border-right-color: #28a745; }.libya-admin-error-notice { display: block !important; margin: 15px 0; padding: 12px 16px; background: #f8d7da; border: 1px solid #f5c6cb; border-radius: 4px; color: #721c24; border-right-width: 4px; border-right-style: solid; border-right-color: #dc3545; }</style>';
        remove_all_actions('admin_notices');
        remove_all_actions('all_admin_notices');
    }
}
