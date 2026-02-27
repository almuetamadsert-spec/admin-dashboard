<?php
/**
 * Libya Super System V14 - نظام إدارة التجار المتقدم
 * اللودر الرئيسي – يحمّل الملفات المقسمة بالترتيب.
 */

/**
 * Plugin Name:       نظام المعتمد المتكامل (الإصدار 15.4)
 * Description:       نظام متكامل لإدارة التجار مع تحديثات رسائل التنبيه، تجميد الحساب، والأرشفة التلقائية، ونظام المتابعة الآلي، ونظام النسب المتقدم.
 * Version:           15.4
 * Author:            Almuetamad
 * Author URI:        https://www.almuetamad.com
 * Copyright:         © 2026 Almuetamad. All rights reserved.
 */

if (! defined('ABSPATH')) exit;

// فحص متطلبات النظام
if (version_compare(PHP_VERSION, '7.4', '<')) {
    add_action('admin_notices', function () {
        echo '<div class="error"><p><strong>نظام المعتمد:</strong> يتطلب PHP 7.4 أو أحدث. الإصدار الحالي: ' . PHP_VERSION . '</p></div>';
    });
    return;
}

// فحص وجود WooCommerce
add_action('plugins_loaded', 'libya_check_woocommerce_v14');
function libya_check_woocommerce_v14()
{
    if (!class_exists('WooCommerce')) {
        add_action('admin_notices', function () {
            echo '<div class="error"><p><strong>نظام المعتمد:</strong> يتطلب تفعيل إضافة WooCommerce أولاً.</p></div>';
        });
        return;
    }
}

// تحميل الملفات المقسمة (بالترتيب) — منع أي ناتج غير متوقع (ترويسات أُرسلت بالفعل)
$libya_includes_dir = dirname(__FILE__) . DIRECTORY_SEPARATOR . 'includes' . DIRECTORY_SEPARATOR;
$libya_include_files = [
    '01-constants.php', '02-bootstrap.php', '03-scripts.php', '04-merchants.php', '05-commission.php',
    '06-logs.php', '07-woo-fields.php', '08-templates.php', '09-order-track.php', '10-actions.php',
    '11-notifications.php', '12-cron.php', '13-debug-cron.php', '14-admin.php', '15-export-import.php'
];
$libya_missing = [];
foreach ($libya_include_files as $f) {
    if (!is_file($libya_includes_dir . $f)) {
        $libya_missing[] = $f;
    }
}
if (!empty($libya_missing)) {
    add_action('admin_notices', function () use ($libya_missing) {
        $list = esc_html(implode(', ', $libya_missing));
        echo '<div class="notice notice-error"><p><strong>نظام المعتمد:</strong> ملفات ناقصة في مجلد includes: ' . $list . '. يرجى إعادة رفع الإضافة.</p></div>';
    });
    return;
}
ob_start();
require_once $libya_includes_dir . '01-constants.php';
require_once $libya_includes_dir . '02-bootstrap.php';
require_once $libya_includes_dir . '03-scripts.php';
require_once $libya_includes_dir . '04-merchants.php';
require_once $libya_includes_dir . '05-commission.php';
require_once $libya_includes_dir . '06-logs.php';

add_action('admin_init', 'libya_check_logs_table_v14');
add_action('admin_init', 'libya_ensure_merchants_table_v14');

require_once $libya_includes_dir . '07-woo-fields.php';
require_once $libya_includes_dir . '08-templates.php';
require_once $libya_includes_dir . '09-order-track.php';
require_once $libya_includes_dir . '10-actions.php';
require_once $libya_includes_dir . '11-notifications.php';
require_once $libya_includes_dir . '12-cron.php';

// عند تفعيل الإضافة: إنشاء جدول السجلات + جدول التجار والهجرة + إعادة جدولة الـ Cron
register_activation_hook(__FILE__, 'libya_activation_v14');
function libya_activation_v14()
{
    libya_create_logs_table_v14();
    if (function_exists('libya_create_merchants_table_v14')) {
        libya_create_merchants_table_v14();
        libya_migrate_merchants_to_table_v14();
    }
    libya_merchant_reset_cron_v14();
}

require_once $libya_includes_dir . '13-debug-cron.php';
require_once $libya_includes_dir . '14-admin.php';
require_once $libya_includes_dir . '15-export-import.php';
ob_end_clean();
