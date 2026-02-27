<?php

/**
 * نظام المعتمد – الثوابت والمفتاح السري وتنبيهات الأمان
 * لا يُحمّل مباشرة؛ يُستدعى من libya-super-system.php
 */

if (!defined('ABSPATH')) {
    return;
}

// --- تعريف مفاتيح البيانات (Meta Keys) لضمان عدم التعارض في كامل النظام ---
define('LIBYA_META_CLAIMED_BY',        '_libya_claimed_by');
define('LIBYA_META_CLAIM_TIME',        '_libya_claim_time');
define('LIBYA_META_ATTENDANCE_CONFIRMED', '_libya_attendance_confirmed');
define('LIBYA_META_ATTENDANCE_TIME',     '_libya_attendance_time');
define('LIBYA_META_TRANSFERRED_MERCHANTS', '_libya_transferred_merchants');
define('LIBYA_META_PROCESSING_SINCE',      '_libya_processing_since');
define('LIBYA_META_NOTIFIED_PROCESSING',   '_libya_customer_notified_processing');
define('LIBYA_META_NEXT_CLAIM_ALLOWED',    '_libya_next_claim_allowed_for');
define('LIBYA_META_NOTIFIED_RECEIVED',    '_libya_customer_notified_received');

// --- ثوابت مقاييس أداء التجار (تخزن في الخيارات لكل تاجر) ---
define('LIBYA_PERF_MANUAL_TRANSFERS',  'libya_perf_manual_transfers_'); // يتبعها الإيميل
define('LIBYA_PERF_AUTO_TRANSFERS',    'libya_perf_auto_transfers_');
define('LIBYA_PERF_MANUAL_DELIVERIES', 'libya_perf_manual_deliveries_');
define('LIBYA_PERF_AUTO_DELIVERIES',   'libya_perf_auto_deliveries_');
define('LIBYA_PERF_FAILED_DELIVERIES', 'libya_perf_failed_deliveries_');
define('LIBYA_PERF_RESPONSE_TIME',     'libya_perf_total_response_time_'); // إجمالي ثواني الرد
define('LIBYA_PERF_RESPONSE_COUNT',    'libya_perf_response_count_');      // عدد الاستجابات لحساب المتوسط
define('LIBYA_PERF_DELIVERY_TIME',     'libya_perf_total_delivery_time_'); // من الاستلام حتى التسليم
define('LIBYA_PERF_DELIVERY_COUNT',    'libya_perf_delivery_count_');      // عدد التسليمات لحساب المتوسط
define('LIBYA_PERF_TOTAL_CLAIMS',      'libya_perf_total_claims_');         // عدد مرات الضغط على "متوفر"


define('MERCHANT_OPTION_KEY_V14', 'libya_merchants_list_v14');
define('DEFAULT_COMMISSION_RATE_V14', 10);
define('DEFAULT_ORDER_LIMIT_V14', 20);

// ألوان البطاقات المميزة للمتاجر (يمين البطاقة)
if (!function_exists('libya_merchant_card_colors_v14')) {
    function libya_merchant_card_colors_v14()
    {
        return [
            '' => 'افتراضي (أخضر هادئ)',
            '#7b9eb5' => 'أزرق هادئ',
            '#6b9b8a' => 'تركواز هادئ',
            '#7d9a7d' => 'أخضر هادئ',
            '#c4a35c' => 'ذهبي باهت',
            '#c98a7a' => 'مرجاني هادئ',
            '#5a6570' => 'رمادي داكن',
            '#8a9199' => 'رمادي فاتح',
            '#9a8ab5' => 'بنفسجي هادئ',
            '#9a8575' => 'بني باهت',
            '#a67b7b' => 'وردي داكن هادئ',
            '#6b8a9e' => 'أزرق رمادي',
            '#8b9a6b' => 'زيتوني باهت',
            '#a89b7a' => 'رملي',
            '#7a8a9b' => 'أزرق فضي',
            '#b59a8a' => 'بيج وردي',
            '#6b7a8a' => 'أزرق فولاذي',
            '#9a9a7a' => 'طحلب هادئ',
            '#6b9a9a' => 'سماوي باهت',
            '#c9b59a' => 'كريمي',
            '#8a7a9b' => 'خزامى باهت',
        ];
    }
}

// المفتاح السري – يجب تعريفه في wp-config.php في بيئة الإنتاج
// في wp-config.php أضف: define('LIBYA_MERCHANT_SECRET_KEY', 'مفتاحك-السري-القوي-والطويل');
define('LIBYA_SECRET_DEFAULT_V14', 'LibyaSuperSystemSecureKeyV14');
if (!defined('LIBYA_MERCHANT_SECRET_KEY')) {
    define('LIBYA_MERCHANT_SECRET_KEY', LIBYA_SECRET_DEFAULT_V14);
    add_action('admin_notices', function () {
        if (current_user_can('manage_options')) {
            echo '<div class="notice notice-warning"><p><strong>تنبيه أمني:</strong> يُرجى تعريف المفتاح السري <code>LIBYA_MERCHANT_SECRET_KEY</code> في ملف wp-config.php وعدم الاعتماد على القيمة الافتراضية، خاصة في بيئة الإنتاج.</p></div>';
        }
    });
}
define('MERCHANT_ACTION_SECRET_KEY_V14', LIBYA_MERCHANT_SECRET_KEY);

// في الإنتاج: عدم قبول المفتاح الافتراضي. في wp-config.php عرّف: define('LIBYA_PRODUCTION', true);
if (!function_exists('libya_is_production_v14')) {
    function libya_is_production_v14()
    {
        return defined('LIBYA_PRODUCTION') && LIBYA_PRODUCTION;
    }
}
if (!function_exists('libya_get_valid_secret_keys_v14')) {
    function libya_get_valid_secret_keys_v14()
    {
        $default = LIBYA_SECRET_DEFAULT_V14;
        $keys = [];
        if (defined('MERCHANT_ACTION_SECRET_KEY_V14')) {
            $v = trim((string) MERCHANT_ACTION_SECRET_KEY_V14);
            if ($v !== '') {
                $keys[] = $v;
            }
        }
        if (defined('LIBYA_MERCHANT_SECRET_KEY')) {
            $v = trim((string) LIBYA_MERCHANT_SECRET_KEY);
            if ($v !== '') {
                if (!in_array($v, $keys, true)) {
                    $keys[] = $v;
                }
            }
        }
        if (!libya_is_production_v14()) {
            $keys[] = $default;
        }
        return array_map('trim', $keys);
    }
}
// تنبيه في لوحة التحكم: في الإنتاج يجب تعريف مفتاح سري من wp-config
add_action('admin_notices', function () {
    if (!current_user_can('manage_options') || !function_exists('libya_is_production_v14') || !libya_is_production_v14()) {
        return;
    }
    $key = defined('LIBYA_MERCHANT_SECRET_KEY') ? (string) LIBYA_MERCHANT_SECRET_KEY : '';
    $default = defined('LIBYA_SECRET_DEFAULT_V14') ? LIBYA_SECRET_DEFAULT_V14 : 'LibyaSuperSystemSecureKeyV14';
    if (trim($key) === $default) {
        echo '<div class="notice notice-error"><p><strong>نظام المعتمد – أمان:</strong> أنت في وضع الإنتاج (<code>LIBYA_PRODUCTION</code>) والمفتاح السري لا يزال القيمة الافتراضية. يُرجى تعريف <code>LIBYA_MERCHANT_SECRET_KEY</code> في wp-config.php بمفتاح قوي خاص بموقعك؛ وإلا فإن روابط الطلبات والتحويل قد تتوقف عن العمل.</p></div>';
    }
}, 5);

// تنبيه: في الإنتاج يُفضّل استخدام HTTPS لروابط الطلبات والتحويل
add_action('admin_notices', function () {
    if (!current_user_can('manage_options') || !function_exists('libya_is_production_v14') || !libya_is_production_v14()) {
        return;
    }
    $home = home_url();
    if (strpos($home, 'https://') !== 0) {
        echo '<div class="notice notice-warning"><p><strong>نظام المعتمد – أمان:</strong> في وضع الإنتاج يُفضّل تشغيل الموقع عبر HTTPS لحماية روابط الطلبات والتحويل. تأكد من تفعيل SSL وإعداد <code>home</code> و <code>siteurl</code> على https في الإعدادات.</p></div>';
    }
}, 6);
