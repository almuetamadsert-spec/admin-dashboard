<?php

/**
 * Plugin Name: تكامل المعتمد مع OneSignal (نسخة الأداء العالي v7.0)
 * Description: إرسال إشعارات تفصيلية للتجار + تسريع عملية الشراء عبر تأخير إرسال الإيميلات في الخلفية.
 * Version: 7.0
 * Author: Manus AI
 * License: GPL2
 */

if (! defined('ABSPATH')) {
    exit;
}

// ========================================================================
// 0. معالج صفحة معاينة الطلب للتاجر (قالب مماثل للإيميل)
// ========================================================================
add_action('init', function () {
    if (isset($_GET['libya_action']) && sanitize_text_field(wp_unslash($_GET['libya_action'])) === 'order_preview_v7') {
        $order_id = isset($_GET['order_id']) ? (int) $_GET['order_id'] : 0;
        $merchant_email = isset($_GET['m_email']) ? sanitize_email(wp_unslash($_GET['m_email'])) : '';
        $secret = isset($_GET['secret']) ? sanitize_text_field(wp_unslash($_GET['secret'])) : '';
        $token = isset($_GET['token']) ? sanitize_text_field(wp_unslash($_GET['token'])) : '';

        if (!$order_id || !$merchant_email) wp_die('بيانات غير مكتملة.');

        $valid_keys = function_exists('libya_get_valid_secret_keys_v14') ? libya_get_valid_secret_keys_v14() : [];
        if (empty($valid_keys)) {
            if (defined('LIBYA_MERCHANT_SECRET_KEY')) $valid_keys[] = trim((string) LIBYA_MERCHANT_SECRET_KEY);
            if (defined('MERCHANT_ACTION_SECRET_KEY_V14')) $valid_keys[] = trim((string) MERCHANT_ACTION_SECRET_KEY_V14);
            $valid_keys[] = 'LibyaSuperSystemSecureKeyV14';
        }
        // قائمة مقبولة: المفتاح الأصلي + نسخة بمسافة بدل + (لأن فتح الرابط من الإشعار قد يحوّل + إلى مسافة)
        $accepted = $valid_keys;
        foreach ($valid_keys as $k) {
            $k_space = str_replace('+', ' ', $k);
            if ($k_space !== $k && !in_array($k_space, $accepted, true)) {
                $accepted[] = $k_space;
            }
        }
        $secret_ok = in_array($secret, $accepted, true);
        if (!$secret_ok) {
            $secret_alt = str_replace('+', ' ', $secret);
            $secret_ok = in_array($secret_alt, $accepted, true);
        }
        if (!$secret_ok && $secret !== '') {
            $s = $secret;
            for ($i = 0; $i < 2; $i++) {
                $s = urldecode($s);
                if (in_array($s, $accepted, true) || in_array(str_replace('+', ' ', $s), $accepted, true)) {
                    $secret_ok = true;
                    break;
                }
            }
        }
        // إذا فُقد أو أُفسد المفتاح عند فتح الرابط من التطبيق: السماح إن كان token التاجر صحيحاً
        $stored_token = get_option('libya_merchant_access_token_' . $merchant_email);
        if (!$secret_ok && $token !== '' && $stored_token !== '' && $stored_token === $token) {
            $secret_ok = true;
        }
        if (!$secret_ok) {
            wp_die('خطأ في المفتاح السري.');
        }
        if ($stored_token && $token !== $stored_token) {
            wp_die('انتهت صلاحية الرابط.');
        }

        $order = wc_get_order($order_id);
        if (!$order) wp_die('الطلب غير موجود.');

        // نفس هيكل صفحة طلب جديد: عمود صورة + اسم + كمية + سعر، مع "المنتج" فوق الصورة فقط
        $items_text = "<table style='width: 100%; border-collapse: collapse; font-size: 11px; text-align: right;'>
            <tr style='font-weight: bold;'>
                <td style='padding: 4px 0;'>المنتج</td>
                <td style='padding: 4px 0;'></td>
                <td style='padding: 4px 0; text-align: center;'>الكمية</td>
                <td style='padding: 4px 0; text-align: left;'>السعر</td>
            </tr>";
        foreach ($order->get_items() as $item_id => $item) {
            $product = $item->get_product();
            $img_url = ($product && $product->get_image_id()) ? wp_get_attachment_image_url($product->get_image_id(), 'thumbnail') : wc_placeholder_img_src('thumbnail');
            $items_text .= "<tr>
                <td style='padding: 2px 0; vertical-align: middle;'><img src='" . esc_url($img_url) . "' alt='' style='width: 36px; height: 36px; object-fit: cover; border-radius: 4px;' /></td>
                <td style='padding: 2px 0;'>" . $item->get_name() . "</td>
                <td style='padding: 2px 0; text-align: center;'>" . $item->get_quantity() . "</td>
                <td style='padding: 2px 0; text-align: left;'>" . strip_tags(wc_price($item->get_total())) . "</td>
            </tr>";
        }
        $items_text .= "<tr style='font-weight: bold;'>
            <td style='padding: 4px 0; border-top: 1px solid #eee;' colspan='2'>المجموع</td>
            <td style='padding: 4px 0; border-top: 1px solid #eee;'></td>
            <td style='padding: 4px 0; border-top: 1px solid #eee; text-align: left;'>" . strip_tags(wc_price((float)$order->get_total())) . "</td>
        </tr></table>";

        // رابط قبول الطلب (المنطق الأصلي)
        // استخدام نفس منطق التحقق: محاولة جميع المفاتيح الممكنة
        $secret_key = 'LibyaSuperSystemSecureKeyV14'; // الافتراضي
        if (defined('MERCHANT_ACTION_SECRET_KEY_V14')) {
            $secret_key = MERCHANT_ACTION_SECRET_KEY_V14;
        } elseif (defined('LIBYA_MERCHANT_SECRET_KEY')) {
            $secret_key = LIBYA_MERCHANT_SECRET_KEY;
        }

        // 🔧 FIX: تشفير المفتاح السري للـ URL
        $url_proc = wp_nonce_url(add_query_arg([
            'order_id' => $order_id,
            'order_action' => 'confirm_processing',
            'm_email' => $merchant_email,
            'secret' => $secret_key
        ], home_url('/')), 'libya_order_action_' . $order_id, 'libya_nonce');

        // نسخ المحتوى الأصلي 100% (الأسطر 1948-1959)
        $content = "
        <div style='text-align: center;'>
            <p><strong>ملخص الطلب:</strong></p>
            {$items_text}
            <hr style='border: 0; border-top: 1px solid #eee; margin: 20px 0;'>
            <p style='font-size: 15px; color: #4a5568; margin-bottom: 10px; line-height: 1.4;'>متوفر؟ اضغط هنا</p>
            <div class='libya-buttons-container' style='margin-top: 20px;'>
                " . (function_exists('get_libya_btn_v14') ? get_libya_btn_v14("متوفر", $url_proc, "blue", true) : "<a href='{$url_proc}' style='background:#00a3ee; color:#fff; padding:15px 30px; text-decoration:none; border-radius:8px; font-weight:800; font-size:18px;'>متوفر</a>") . "
            </div>
            <div id='libya-result-message'></div>
            <p style='font-size: 10px; color: #666; margin-top: 10px;'>" . date('Y-m-d H:i') . "</p>
        </div>";

        $footer_order = "للمساعدة أو الاستفسار | 0914479920";
        if (function_exists('get_libya_msg_template_v14')) {
            echo get_libya_msg_template_v14("طلب جديد رقم {$order_id}", $content, $footer_order, "info");
        } else {
            echo $content;
        }
        exit;
    }
});

// ========================================================================
// 1. تحسين الأداء: تأخير إرسال إيميلات WooCommerce في الخلفية
// ========================================================================
// هذا السطر يقوم بنفس وظيفة تعريف WC_DEFER_EMAILS في wp-config.php
add_filter('woocommerce_defer_emails', '__return_true');

// ========================================================================
// 2. الإعدادات الخاصة بـ OneSignal
// ========================================================================
// قيم احتياطية إن لم تُعرّف في wp-config أو لم تُحفظ من لوحة التحكم
if (!defined('ALMUETAMAD_ONESIGNAL_APP_ID')) {
    define('ALMUETAMAD_ONESIGNAL_APP_ID', 'd12b85b5-ebc9-4c59-b1f5-bc0d8d69170a');
}
if (!defined('ALMUETAMAD_ONESIGNAL_REST_KEY')) {
    define('ALMUETAMAD_ONESIGNAL_REST_KEY', 'os_v2_app_2evylnplzfgftmpvxqgy22ixbk2loipe2y7es64ulakw345jl6vgcw6vr525ug6yeoj5lezssegtufcgx46xtc24gcdvu6eca2hcgka');
}

function libya_onesignal_app_id_v7()
{
    $saved = get_option('libya_onesignal_app_id_v7', '');
    return $saved !== '' ? $saved : (defined('ALMUETAMAD_ONESIGNAL_APP_ID') ? ALMUETAMAD_ONESIGNAL_APP_ID : '');
}

function libya_onesignal_rest_key_v7()
{
    $saved = get_option('libya_onesignal_rest_key_v7', '');
    return $saved !== '' ? $saved : (defined('ALMUETAMAD_ONESIGNAL_REST_KEY') ? ALMUETAMAD_ONESIGNAL_REST_KEY : '');
}

// ========================================================================
// 3. جدولة الإشعارات في الخلفية (Server Cron سينفذها)
// ========================================================================
add_action('woocommerce_checkout_order_processed', 'schedule_merchant_notification_background_v7', 20, 1);
add_action('woocommerce_rest_insert_shop_order_object', 'schedule_merchant_notification_background_v7', 20, 1);

function schedule_merchant_notification_background_v7($order_id_or_obj)
{
    // التأكد من الحصول على المعرف الرقمي كـ (int) لضمان دقة عمل wp_next_scheduled
    $order_id = ($order_id_or_obj instanceof WC_Order) ? (int)$order_id_or_obj->get_id() : (int)$order_id_or_obj;

    if (!$order_id) return;

    // منع مكرر الجدولة إذا تم الإرسال مسبقاً أو الطلب قيد المعالجة فعلياً
    if (get_post_meta($order_id, '_onesignal_notified_v7', true)) return;

    // جدولة الإرسال بعد 5 ثوانٍ فقط ليصل الإشعار قبل أو مع الإيميل
    if (! wp_next_scheduled('libya_send_delayed_onesignal_notification', array($order_id))) {
        wp_schedule_single_event(time() + 5, 'libya_send_delayed_onesignal_notification', array($order_id));
    }
}

// دالة الخطاف التي سينفذها الكرون
add_action('libya_send_delayed_onesignal_notification', 'send_targeted_onesignal_notification_v7', 10, 1);

// ========================================================================
// 4. الدالة الرئيسية لإرسال الإشعار بالصيغة المطلوبة
// ========================================================================
function send_targeted_onesignal_notification_v7($order_id)
{
    if (!$order_id || get_post_meta($order_id, '_onesignal_notified_v7', true)) return;

    $order = wc_get_order($order_id);
    if (!$order) return;

    $city = $order->get_billing_city();
    $address_2 = $order->get_billing_address_2();
    if (empty($city)) return;

    if (!function_exists('get_libya_merchants_v14') || !function_exists('normalize_libya_city_v14')) {
        return;
    }

    $merchants = get_libya_merchants_v14();
    $normalized_input_city = normalize_libya_city_v14($city);
    $target_merchants_emails = [];

    foreach ($merchants as $email => $m) {
        $normalized_merchant_city = normalize_libya_city_v14($m['city']);
        if ($normalized_merchant_city === $normalized_input_city) {
            if (($m['status'] ?? 'active') === 'active') {
                $target_merchants_emails[] = $email;
            }
        }
    }

    $target_merchants_emails = array_unique($target_merchants_emails);
    if (empty($target_merchants_emails)) return;

    $order_number = $order->get_order_number();
    $items = $order->get_items();
    $product_names = array();
    foreach ($items as $item) {
        $product_names[] = $item->get_name();
    }
    $products_list = implode(', ', $product_names);

    $total_price_raw = $order->get_total();
    $currency_symbol = get_woocommerce_currency_symbol();
    $total_price = html_entity_decode(strip_tags($total_price_raw . ' ' . $currency_symbol));

    foreach ($target_merchants_emails as $merchant_email) {
        $user = get_user_by('email', $merchant_email);

        $targets = array();
        if ($user) {
            $targets[] = (string)$user->ID; // الأولوية لمعرف المستخدم
        } elseif ($merchant_email) {
            $targets[] = $merchant_email; // البديل هو البريد إذا لم يوجد مستخدم
        }

        if (empty($targets)) continue;

        $m_name = $merchants[$merchant_email]['branch_name'] ?? 'تاجر';
        $first_name = explode(' ', trim($m_name))[0];
        $title = "مرحبًا " . $first_name;

        // رابط معاينة الطلب (بدون nonce) ليعمل عند الفتح من التطبيق؛ من صفحة المعاينة زر "متوفر" يوجّه لصفحة الطلب الكاملة
        $base_url = home_url('/');
        $secret_key = defined('MERCHANT_ACTION_SECRET_KEY_V14') ? MERCHANT_ACTION_SECRET_KEY_V14 : (defined('LIBYA_MERCHANT_SECRET_KEY') ? LIBYA_MERCHANT_SECRET_KEY : 'LibyaSuperSystemSecureKeyV14');
        $m_token = get_option('libya_merchant_access_token_' . $merchant_email);
        $order_url = add_query_arg([
            'libya_action' => 'order_preview_v7',
            'order_id'     => $order_id,
            'm_email'      => $merchant_email,
            'secret'       => $secret_key,
        ], $base_url);
        if (!empty($m_token)) {
            $order_url = add_query_arg('token', $m_token, $order_url);
        }

        // التنسيق المطلوب: سطر تنبيه وسطر رقم الطلب ثم الباقي (الترحيب موجود في العنوان)
        $personal_message = "لديك طلب جديد ✨\n";
        $personal_message .= "رقم الطلب : " . $order_number . "\n";
        $personal_message .= "المدينة : " . $city . "\n";
        $personal_message .= "الحي : " . ($address_2 ? $address_2 : "غير محدد") . "\n";
        $personal_message .= "المنتج : " . $products_list . "\n";
        $personal_message .= "الاجمالي : " . $total_price . "\n\n";
        $personal_message .= "يرجى الضغط على الإشعار لمعاينة وقبول الطلب ✉️";


        $fields = array(
            'app_id' => libya_onesignal_app_id_v7(),
            'include_external_user_ids' => $targets,
            'url' => $order_url,
            'headings' => array("en" => $title, "ar" => $title),
            'contents' => array("en" => $personal_message, "ar" => $personal_message),
            'data' => array("order_id" => $order_id),
            'priority' => 10,
            'android_group' => 'merchant_orders'
        );

        $response = wp_remote_post('https://onesignal.com/api/v1/notifications', array(
            'method'    => 'POST',
            'headers'   => array(
                'Authorization' => 'Basic ' . libya_onesignal_rest_key_v7(),
                'Content-Type'  => 'application/json; charset=utf-8',
            ),
            'body'      => json_encode($fields),
            'timeout'   => 15, // زيادة المهلة لضمان الإرسال
            'blocking'  => true,
        ));

        // تحسين 2: تسجيل تفصيلي للأخطاء (سيظهر في error_log الخاص بالسيرفر)
        if (is_wp_error($response)) {
            error_log("OneSignal Error (Order $order_id): " . $response->get_error_message());
        } else {
            $code = wp_remote_retrieve_response_code($response);
            if ($code !== 200) {
                $body = wp_remote_retrieve_body($response);
                error_log("OneSignal API Error $code (Order $order_id): " . $body);
            }
        }
    }
    // وضع نظام حماية لمنع إرسال نفس الطلب مرتين مستقبلاً
    update_post_meta($order_id, '_onesignal_notified_v7', 'yes');
}

// ========================================================================
// 5. إرسال إشعار للزبون عند اكتمال الطلب (مع أزرار التأكيد)
// ========================================================================
// add_action('woocommerce_order_status_completed', 'send_customer_completion_notification_v7', 10, 1);

function send_customer_completion_notification_v7($order_id)
{
    $order = wc_get_order($order_id);
    if (!$order) return;

    $customer_id = $order->get_customer_id();
    $customer_email = $order->get_billing_email();

    // الاستهداف المزدوج للزبون (ID أو Email) لضمان الوصول للزوار والأعضاء
    $targets = array();
    if ($customer_id) $targets[] = (string)$customer_id;
    if ($customer_email) $targets[] = $customer_email;

    if (empty($targets)) return;

    $order_number = $order->get_order_number();

    $title = "شكراً لاستخدامك تطبيقنا";
    $message = "تم تحديث حالة طلبك إلى مستلم ✓، نتطلع لخدمتك مرة أخرى";

    $fields = array(
        'app_id' => libya_onesignal_app_id_v7(),
        'include_external_user_ids' => $targets,
        'headings' => array("en" => $title, "ar" => $title),
        'contents' => array("en" => $message, "ar" => $message),
        'data' => array("order_id" => $order_id),
        'priority' => 10
    );

    wp_remote_post('https://onesignal.com/api/v1/notifications', array(
        'method'    => 'POST',
        'headers'   => array(
            'Authorization' => 'Basic ' . libya_onesignal_rest_key_v7(),
            'Content-Type'  => 'application/json; charset=utf-8',
        ),
        'body'      => json_encode($fields),
        'timeout'   => 5,
        'blocking'  => true,
    ));
}

// ========================================================================
// 6. صفحة إشعارات مخصصة (للعميل وللتجار) – هوية نظام المعتمد
// ========================================================================
add_action('admin_menu', 'almuetamad_register_custom_notifications_page_v7', 20);

add_action('admin_head', 'almuetamad_hide_notices_on_custom_notifications_v7');
function almuetamad_hide_notices_on_custom_notifications_v7()
{
    $page = isset($_GET['page']) ? sanitize_text_field($_GET['page']) : '';
    if ($page !== 'custom-notifications-v7') return;
    // إخفاء إشعارات ووردبريس في أعلى الصفحة فقط (لا نؤثر على رسائل النجاح/الخطأ داخل محتوى الصفحة)
    echo '<style>#wpbody-content > .update-nag, #wpbody-content > .updated, #wpbody-content > .error, #wpbody-content > .notice, #wpbody-content > .is-dismissible, #wpbody-content > #setting-error-tgmpa { display: none !important; }.cn-v7 .notice { display: block !important; }</style>';
    remove_all_actions('admin_notices');
    remove_all_actions('all_admin_notices');
}

function almuetamad_register_custom_notifications_page_v7()
{
    if (!function_exists('get_libya_merchants_v14')) return;
    add_submenu_page(
        'merchant-main-dashboard',
        'إشعارات مخصصة',
        'إشعارات مخصصة',
        'manage_options',
        'custom-notifications-v7',
        'render_custom_notifications_page_v7'
    );
}

function almuetamad_send_onesignal_v7($targets, $title, $message, $url = '', $data = array())
{
    if (empty($targets)) return false;
    $targets = array_map('strval', array_unique(array_filter($targets)));
    $fields = array(
        'app_id' => libya_onesignal_app_id_v7(),
        'include_external_user_ids' => $targets,
        'headings' => array('en' => $title, 'ar' => $title),
        'contents' => array('en' => $message, 'ar' => $message),
        'data' => array_merge(array('order_id' => 0), $data),
        'priority' => 10,
    );
    if ($url) $fields['url'] = $url;
    $response = wp_remote_post('https://onesignal.com/api/v1/notifications', array(
        'method' => 'POST',
        'headers' => array(
            'Authorization' => 'Basic ' . libya_onesignal_rest_key_v7(),
            'Content-Type'  => 'application/json; charset=utf-8',
        ),
        'body' => json_encode($fields),
        'timeout' => 15,
        'blocking' => false,
    ));
    return !is_wp_error($response);
}

function render_custom_notifications_page_v7()
{
    if (!current_user_can('manage_options')) {
        wp_die('غير مصرح.');
    }

    $feedback = '';
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['_wpnonce']) && wp_verify_nonce($_POST['_wpnonce'], 'custom_notifications_v7')) {

        if (!empty($_POST['save_onesignal_settings'])) {
            $app_id = isset($_POST['onesignal_app_id']) ? sanitize_text_field(wp_unslash($_POST['onesignal_app_id'])) : '';
            $rest_key = isset($_POST['onesignal_rest_key']) ? sanitize_text_field(wp_unslash($_POST['onesignal_rest_key'])) : '';
            update_option('libya_onesignal_app_id_v7', $app_id);
            update_option('libya_onesignal_rest_key_v7', $rest_key);
            $feedback = '<div class="notice notice-success"><p>تم حفظ إعدادات OneSignal.</p></div>';
        }

        if (!empty($_POST['send_to_customer'])) {
            $order_id = isset($_POST['customer_order_id']) ? (int)$_POST['customer_order_id'] : 0;
            $title = isset($_POST['customer_title']) ? sanitize_text_field($_POST['customer_title']) : 'إشعار من المعتمد';
            $message = isset($_POST['customer_message']) ? sanitize_textarea_field($_POST['customer_message']) : '';
            if ($order_id && $message) {
                $order = wc_get_order($order_id);
                if ($order) {
                    $targets = array();
                    $cid = $order->get_customer_id();
                    if ($cid) $targets[] = (string)$cid;
                    $em = $order->get_billing_email();
                    if ($em) $targets[] = $em;
                    if (!empty($targets) && almuetamad_send_onesignal_v7($targets, $title, $message, '', array('order_id' => $order_id))) {
                        $feedback = '<div class="notice notice-success"><p>تم إرسال الإشعار للعميل بنجاح (طلب #' . $order_id . ').</p></div>';
                    } else {
                        $feedback = '<div class="notice notice-error"><p>فشل الإرسال أو العميل غير مرتبط بتطبيق الإشعارات.</p></div>';
                    }
                } else {
                    $feedback = '<div class="notice notice-error"><p>الطلب غير موجود.</p></div>';
                }
            } else {
                $feedback = '<div class="notice notice-error"><p>يرجى إدخال رقم الطلب والرسالة.</p></div>';
            }
        }

        if (!empty($_POST['send_to_merchants'])) {
            $filter_type = isset($_POST['merchant_filter']) ? sanitize_text_field($_POST['merchant_filter']) : '';
            $filter_value = isset($_POST['merchant_filter_value']) ? sanitize_text_field($_POST['merchant_filter_value']) : '';
            $title = isset($_POST['merchant_title']) ? sanitize_text_field($_POST['merchant_title']) : 'إشعار من المعتمد';
            $message = isset($_POST['merchant_message']) ? sanitize_textarea_field($_POST['merchant_message']) : '';
            if ($message && $filter_type && $filter_value !== '') {
                $targets = array();
                if (!function_exists('get_libya_merchants_v14') || !function_exists('normalize_libya_city_v14')) {
                    $feedback = '<div class="notice notice-error"><p>نظام المعتمد غير متاح.</p></div>';
                } else {
                    $merchants = get_libya_merchants_v14();
                    $normalized_value = normalize_libya_city_v14($filter_value);
                    foreach ($merchants as $email => $m) {
                        $match = false;
                        if ($filter_type === 'email') $match = (stripos($email, $filter_value) !== false);
                        elseif ($filter_type === 'store') $match = (stripos($m['branch_name'] ?? '', $filter_value) !== false);
                        elseif ($filter_type === 'city') $match = (normalize_libya_city_v14($m['city'] ?? '') === $normalized_value);
                        if (!$match) continue;
                        if (($m['status'] ?? 'active') !== 'active') continue;
                        $user = get_user_by('email', $email);
                        if ($user) $targets[] = (string)$user->ID;
                        else $targets[] = $email;
                    }
                    $targets = array_unique(array_filter($targets));
                    if (!empty($targets) && almuetamad_send_onesignal_v7($targets, $title, $message)) {
                        $feedback = '<div class="notice notice-success"><p>تم إرسال الإشعار إلى ' . count($targets) . ' مستلم بنجاح.</p></div>';
                    } else {
                        $feedback = '<div class="notice notice-error"><p>لم يتم العثور على تجار مطابقين أو فشل الإرسال.</p></div>';
                    }
                }
            } else {
                $feedback = '<div class="notice notice-error"><p>يرجى اختيار نوع الاستهداف وإدخال القيمة والرسالة.</p></div>';
            }
        }
    }

    $back_url = admin_url('admin.php?page=merchant-main-dashboard');
?>
    <style>
        .cn-v7 {
            direction: rtl;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 900px;
            margin: 20px auto 40px;
        }

        .cn-v7 * {
            box-sizing: border-box;
        }

        .cn-v7 .cn-header {
            margin-bottom: 24px;
            padding-bottom: 20px;
            border-bottom: 2px solid #04acf4;
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 12px;
        }

        .cn-v7 .cn-title {
            margin: 0;
            font-size: 22px;
            font-weight: 700;
            color: #0284c7;
        }

        .cn-v7 .cn-back {
            display: inline-flex;
            align-items: center;
            padding: 6px 14px;
            background: #f0f9ff;
            color: #0369a1;
            text-decoration: none;
            border-radius: 8px;
            font-size: 13px;
            font-weight: 500;
            border: 1px solid #bae6fd;
        }

        .cn-v7 .cn-back:hover {
            background: #e0f2fe;
            color: #0284c7;
        }

        .cn-v7 .cn-card {
            background: #fff;
            border: 1px solid #cbd5e1;
            border-radius: 12px;
            padding: 24px;
            margin-bottom: 24px;
            box-shadow: 0 2px 8px rgba(0, 0, 0, .08);
            border-right: 4px solid #04acf4;
        }

        .cn-v7 .cn-card h2 {
            margin: 0 0 16px;
            font-size: 16px;
            font-weight: 600;
            color: #0284c7;
            padding-bottom: 10px;
            border-bottom: 1px solid #cbd5e1;
        }

        .cn-v7 .cn-row {
            margin-bottom: 14px;
        }

        .cn-v7 .cn-row label {
            display: block;
            font-weight: 600;
            color: #374151;
            margin-bottom: 4px;
            font-size: 13px;
        }

        .cn-v7 .cn-row input[type="text"],
        .cn-v7 .cn-row input[type="password"],
        .cn-v7 .cn-row input[type="number"],
        .cn-v7 .cn-row select,
        .cn-v7 .cn-row textarea {
            width: 100%;
            max-width: 400px;
            padding: 10px 12px;
            border: 1px solid #94a3b8;
            border-radius: 8px;
            font-size: 14px;
        }

        .cn-v7 .cn-hint {
            margin: 0 0 14px;
            color: #64748b;
            font-size: 13px;
            line-height: 1.5;
        }

        .cn-v7 .cn-row textarea {
            min-height: 80px;
            resize: vertical;
        }

        .cn-v7 .cn-btn {
            padding: 10px 20px;
            background: linear-gradient(135deg, #0284c7, #04acf4);
            color: #fff;
            border: none;
            border-radius: 8px;
            font-weight: 600;
            font-size: 14px;
            cursor: pointer;
        }

        .cn-v7 .cn-btn:hover {
            opacity: 0.95;
        }

        .cn-v7 .cn-templates {
            display: flex;
            flex-wrap: wrap;
            gap: 8px;
            margin-top: 6px;
        }

        .cn-v7 .cn-tpl {
            padding: 6px 12px;
            background: #f0f9ff;
            border: 1px solid #bae6fd;
            border-radius: 6px;
            font-size: 12px;
            color: #0369a1;
            cursor: pointer;
        }

        .cn-v7 .cn-tpl:hover {
            background: #e0f2fe;
        }

        .cn-v7 .cn-v7-feedback {
            margin: 0 0 20px 0;
            padding: 12px 16px;
            border-radius: 8px;
        }

        .cn-v7 .cn-v7-feedback.cn-v7-success {
            background: #d1fae5;
            border-right: 4px solid #059669;
            color: #065f46;
        }

        .cn-v7 .cn-v7-feedback.cn-v7-error {
            background: #fee2e2;
            border-right: 4px solid #dc2626;
            color: #991b1b;
        }
    </style>
    <div class="wrap cn-v7">
        <div class="cn-header">
            <a href="<?php echo esc_url($back_url); ?>" class="cn-back">← رجوع للوحة التحكم</a>
            <h1 class="cn-title">إشعارات مخصصة (تطبيق المعتمد)</h1>
        </div>
        <?php echo $feedback; ?>

        <div class="cn-card">
            <h2>إعدادات OneSignal</h2>
            <p class="cn-hint">يمكنك تخزين المفاتيح هنا بدلاً من تركها في الكود. إن تركت الحقلين فارغين، تُستخدم القيم الافتراضية (إن وُجدت في الكود أو wp-config).</p>
            <form method="post">
                <?php wp_nonce_field('custom_notifications_v7'); ?>
                <input type="hidden" name="save_onesignal_settings" value="1" />
                <div class="cn-row">
                    <label>OneSignal App ID</label>
                    <input type="text" name="onesignal_app_id" value="<?php echo esc_attr(libya_onesignal_app_id_v7()); ?>" placeholder="مثال: d12b85b5-ebc9-4c59-b1f5-bc0d8d69170a" autocomplete="off" />
                </div>
                <div class="cn-row">
                    <label>OneSignal REST API Key</label>
                    <input type="password" name="onesignal_rest_key" value="<?php echo esc_attr(libya_onesignal_rest_key_v7()); ?>" placeholder="مفتاح REST API من لوحة OneSignal" autocomplete="off" />
                </div>
                <div class="cn-row"><button type="submit" class="cn-btn">حفظ إعدادات OneSignal</button></div>
            </form>
        </div>

        <div class="cn-card">
            <h2>إرسال إشعار للعميل (حسب رقم الطلب)</h2>
            <form method="post">
                <?php wp_nonce_field('custom_notifications_v7'); ?>
                <input type="hidden" name="send_to_customer" value="1" />
                <div class="cn-row">
                    <label>رقم الطلب</label>
                    <input type="number" name="customer_order_id" value="<?php echo isset($_POST['customer_order_id']) ? (int)$_POST['customer_order_id'] : ''; ?>" placeholder="مثال: 1234" min="1" />
                </div>
                <div class="cn-row">
                    <label>عنوان الإشعار</label>
                    <input type="text" name="customer_title" value="<?php echo esc_attr(isset($_POST['customer_title']) ? $_POST['customer_title'] : 'إشعار من المعتمد'); ?>" placeholder="مثال: تنبيه" />
                </div>
                <div class="cn-row">
                    <label>نص الرسالة</label>
                    <textarea name="customer_message" id="customer_message" placeholder="مثال: هل استلمت طلبك؟ أو: شكراً لثقتك."><?php echo esc_textarea(isset($_POST['customer_message']) ? $_POST['customer_message'] : ''); ?></textarea>
                    <div class="cn-templates">
                        <span class="cn-tpl" data-target="customer_message" data-text="هل استلمت طلبك؟ نأمل أن تكون راضياً عن الخدمة.">هل استلمت طلبك؟</span>
                        <span class="cn-tpl" data-target="customer_message" data-text="شكراً لثقتك بنا. نتطلع لخدمتك مرة أخرى.">شكر</span>
                        <span class="cn-tpl" data-target="customer_message" data-text="تنبيه: يرجى التأكد من استلام طلبك والتواصل معنا في حال أي استفسار.">تنبيه</span>
                    </div>
                </div>
                <div class="cn-row"><button type="submit" class="cn-btn">إرسال للعميل</button></div>
            </form>
        </div>

        <div class="cn-card">
            <h2>إرسال إشعار للتجار</h2>
            <form method="post">
                <?php wp_nonce_field('custom_notifications_v7'); ?>
                <input type="hidden" name="send_to_merchants" value="1" />
                <div class="cn-row">
                    <label>استهداف حسب</label>
                    <select name="merchant_filter" id="merchant_filter">
                        <option value="email" <?php selected(isset($_POST['merchant_filter']) ? $_POST['merchant_filter'] : '', 'email'); ?>>بريد التاجر</option>
                        <option value="store" <?php selected(isset($_POST['merchant_filter']) ? $_POST['merchant_filter'] : '', 'store'); ?>>اسم المتجر</option>
                        <option value="city" <?php selected(isset($_POST['merchant_filter']) ? $_POST['merchant_filter'] : '', 'city'); ?>>المدينة</option>
                    </select>
                </div>
                <div class="cn-row">
                    <label>القيمة (ايميل / اسم متجر / اسم المدينة)</label>
                    <input type="text" name="merchant_filter_value" value="<?php echo esc_attr(isset($_POST['merchant_filter_value']) ? $_POST['merchant_filter_value'] : ''); ?>" placeholder="مثال: طرابلس أو جزء من الإيميل أو اسم المتجر" />
                </div>
                <div class="cn-row">
                    <label>عنوان الإشعار</label>
                    <input type="text" name="merchant_title" value="<?php echo esc_attr(isset($_POST['merchant_title']) ? $_POST['merchant_title'] : 'إشعار من المعتمد'); ?>" />
                </div>
                <div class="cn-row">
                    <label>نص الرسالة</label>
                    <textarea name="merchant_message" placeholder="اكتب الرسالة التي تصل للتجار على التطبيق."><?php echo esc_textarea(isset($_POST['merchant_message']) ? $_POST['merchant_message'] : ''); ?></textarea>
                </div>
                <div class="cn-row"><button type="submit" class="cn-btn">إرسال للتجار</button></div>
            </form>
        </div>
    </div>
    <script>
        (function() {
            document.querySelectorAll('.cn-tpl').forEach(function(el) {
                el.addEventListener('click', function() {
                    var id = this.getAttribute('data-target');
                    var text = this.getAttribute('data-text');
                    var ta = document.getElementById(id);
                    if (ta) ta.value = text;
                });
            });
        })();
    </script>
<?php
}
