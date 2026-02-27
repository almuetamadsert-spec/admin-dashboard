<?php
if (!defined('ABSPATH')) {
    return;
}


// ========================================================================
//  4. معالجة الإجراءات والصفحات الأنيقة
// ========================================================================
add_action('init', 'handle_libya_system_actions_v14');
function handle_libya_system_actions_v14()
{
    if (is_admin() || (defined('REST_REQUEST') && REST_REQUEST)) return;
    if (!isset($_GET['libya_action']) && !isset($_GET['order_action']) && !isset($_GET['admin_action'])) return;

    // صفحة تتبع الطلب للعميل — تم إلغاؤها (يتم التتبع عبر إشعارات التطبيق فقط)
    if (isset($_GET['libya_action']) && sanitize_text_field($_GET['libya_action']) === 'order_track') {
        wp_die('هذه الصفحة لم تعد متوفرة.');
    }

    $secret = $_GET['secret'] ?? ($_GET['secret_key'] ?? ($_GET['key'] ?? ''));
    $secret = is_string($secret) ? trim($secret) : '';

    // التحقق من المفتاح السري: في الإنتاج لا يُقبل المفتاح الافتراضي (يجب تعريف LIBYA_MERCHANT_SECRET_KEY في wp-config)
    $valid_keys = function_exists('libya_get_valid_secret_keys_v14') ? libya_get_valid_secret_keys_v14() : [];
    $secret_ok = in_array($secret, $valid_keys, true);

    // استثناءات عندما يكون الـ nonce صالحاً:
    // 1) روابط الطلب (order_action): قبول الطلب + الأزرار داخل صفحة الطلب (AJAX)
    if (
        !$secret_ok
        && isset($_GET['order_action'], $_GET['order_id'], $_GET['libya_nonce'])
    ) {
        $oid = (int) $_GET['order_id'];
        $current_uid_backup = get_current_user_id();
        wp_set_current_user(0);
        $nonce_ok = wp_verify_nonce(sanitize_text_field($_GET['libya_nonce']), 'libya_order_action_' . $oid);
        wp_set_current_user($current_uid_backup);

        if ($nonce_ok) {
            // السماح دائماً لـ confirm_processing حتى لو فُقد secret من الإيميل
            // والسماح لباقي الإجراءات إذا كانت عبر AJAX من داخل صفحة الطلب
            if (
                $_GET['order_action'] === 'confirm_processing'
                || isset($_GET['ajax'])
            ) {
                $secret_ok = true;
            }
        }
    }

    // 2) روابط "تحويل القيمة" وصفحة التحويل البنكي (bank_transfer_page / confirm_payment)
    if (
        !$secret_ok
        && isset($_GET['libya_action'], $_GET['m_email'])
        && in_array($_GET['libya_action'], ['bank_transfer_page', 'confirm_payment'], true)
    ) {
        $merchant_email_norm = sanitize_email($_GET['m_email']);
        $m_email_raw = isset($_GET['m_email']) ? trim(sanitize_text_field(wp_unslash($_GET['m_email']))) : '';

        // 2a) صمّة مؤقتة (pay_token) من رسالة تنبيه المتجر – تعمل حتى لو أُزيلت معاملات أخرى من الرابط
        $pay_token = isset($_GET['pay_token']) ? sanitize_text_field($_GET['pay_token']) : '';
        if ($pay_token !== '' && strlen($pay_token) === 48 && ctype_xdigit($pay_token)) {
            $stored = get_transient('libya_pay_token_' . $pay_token);
            if (is_array($stored) && isset($stored['email']) && $merchant_email_norm !== '' && strtolower((string) $stored['email']) === strtolower($merchant_email_norm)) {
                delete_transient('libya_pay_token_' . $pay_token);
                $secret_ok = true;
            }
        }

        if (!$secret_ok) {
            $current_uid_backup = get_current_user_id();
            wp_set_current_user(0);
            $nonce_ok = false;
            if (!empty($_GET['libya_nonce'])) {
                $nonce_val = sanitize_text_field($_GET['libya_nonce']);
                if ($merchant_email_norm !== '' && wp_verify_nonce($nonce_val, 'libya_pay_page_' . $merchant_email_norm)) {
                    $nonce_ok = true;
                }
                if (!$nonce_ok && $m_email_raw !== '' && wp_verify_nonce($nonce_val, 'libya_pay_page_' . $m_email_raw)) {
                    $nonce_ok = true;
                }
            }
            wp_set_current_user($current_uid_backup);
            if (!$nonce_ok && $secret !== '' && defined('MERCHANT_ACTION_SECRET_KEY_V14') && trim((string) MERCHANT_ACTION_SECRET_KEY_V14) === $secret) {
                $secret_ok = true;
            } elseif ($nonce_ok) {
                $secret_ok = true;
            }
        }
    }

    // 3) روابط "تم استلام القيمة" و "لم يتم الاستلام" (admin_action)
    if (
        !$secret_ok
        && isset($_GET['admin_action'], $_GET['m_email'], $_GET['libya_nonce'])
        && in_array($_GET['admin_action'], ['payment_received', 'payment_not_received'], true)
    ) {
        $current_uid_backup = get_current_user_id();
        wp_set_current_user(0);
        $nonce_ok = wp_verify_nonce(sanitize_text_field($_GET['libya_nonce']), 'libya_admin_payment');
        wp_set_current_user($current_uid_backup);
        if ($nonce_ok) {
            $secret_ok = true;
        }
    }

    if (!$secret_ok) {
        wp_die('الرابط غير صالح.');
    }

    // التحقق من Nonce للأمان (باستثناء صفحة التحويل البنكي العامة)
    if (isset($_GET['admin_action'])) {
        $current_uid_backup = get_current_user_id();
        wp_set_current_user(0);
        $valid_nonce = wp_verify_nonce(sanitize_text_field($_GET['libya_nonce'] ?? ''), 'libya_admin_payment');
        wp_set_current_user($current_uid_backup);

        if (!isset($_GET['libya_nonce']) || !$valid_nonce) {
            wp_die('عذراً، ليس لديك صلاحية للقيام بهذا الإجراء أو انتهت صلاحية الرابط.');
        }
    }
    if (isset($_GET['order_action'])) {
        $oid = isset($_GET['order_id']) ? intval($_GET['order_id']) : 0;
        $current_uid_backup = get_current_user_id();
        wp_set_current_user(0);
        $valid_nonce = isset($_GET['libya_nonce']) && wp_verify_nonce(sanitize_text_field($_GET['libya_nonce']), 'libya_order_action_' . $oid);
        wp_set_current_user($current_uid_backup);
        if (!$valid_nonce) {
            wp_die('عذراً، انتهت صلاحية الرابط أو الطلب غير صالح.');
        }
    }

    $admin_email = function_exists('libya_orders_email_v14') ? libya_orders_email_v14() : 'orders@almuetamad.com';

    // --- إجراءات حالة التاجر (تجميد/تفعيل) ---
    if (isset($_GET['merchant_status_action'], $_GET['m_email'])) {
        $email = sanitize_email($_GET['m_email']);
        $action = sanitize_text_field($_GET['merchant_status_action']);
        $merchants = get_libya_merchants_v14();
        if (isset($merchants[$email])) {
            $merchants[$email]['status'] = ($action === 'freeze') ? 'frozen' : 'active';
            save_libya_merchants_v14($merchants);
            libya_system_log_v14('تغيير حالة المتجر', $email, 'الحالة الجديدة: ' . ($action === 'freeze' ? 'مجمد' : 'نشط'), 60);
            wp_redirect(admin_url('admin.php?page=merchant-main-dashboard'));
            exit;
        }
    }

    // --- إجراءات الطلبات ---
    if (isset($_GET['order_action'], $_GET['order_id'])) {
        $order_id = intval($_GET['order_id']);
        $action = sanitize_text_field($_GET['order_action']);
        $merchant_email = isset($_GET['m_email']) ? sanitize_email($_GET['m_email']) : '';

        if ($action === 'log_wa_open' || $action === 'log_sms_open') {
            $order = wc_get_order($order_id);
            $city = $order ? ($order->get_shipping_city() ?: $order->get_billing_city()) : '';
            if ($action === 'log_wa_open') {
                libya_system_log_v14('تم فتح تطبيق واتساب', $merchant_email, "المعتمد - رقم الطلب: {$order_id} - المدينة: {$city}", 120);
            } else {
                libya_system_log_v14('تم فتح تطبيق الرسائل', $merchant_email, "المعتمد - رقم الطلب: {$order_id} - المدينة: {$city}", 120);
            }
            if (isset($_GET['ajax'])) {
                wp_send_json(['success' => true]);
            }
            exit;
        }

        // 🔒 Rate Limiting - منع الإساءة
        $rate_key = "libya_rate_limit_{$merchant_email}_{$order_id}";
        $attempts = get_transient($rate_key);
        if ($attempts && $attempts >= 5) {
            if (isset($_GET['ajax'])) {
                wp_send_json(['success' => false, 'message' => 'تم تجاوز الحد المسموح. حاول مرة أخرى بعد 30 ثانية.']);
            }
            echo get_libya_msg_template_v14("تنبيه", "تم تجاوز الحد المسموح. حاول مرة أخرى بعد 30 ثانية.", "المعتمد | 0914479920", "warning");
            exit;
        }
        set_transient($rate_key, ($attempts ? $attempts + 1 : 1), 30); // 30 ثانية

        $transferred_merchants = get_post_meta($order_id, LIBYA_META_TRANSFERRED_MERCHANTS, true);
        if (!is_array($transferred_merchants)) $transferred_merchants = [];

        if (in_array($merchant_email, $transferred_merchants)) {
            if (isset($_GET['ajax'])) {
                wp_send_json([
                    'success' => false,
                    'message' => "لقد قمت بتحويل الطلب رقم {$order_id} مسبقاً لتاجر آخر. شكراً لك.",
                    'action' => $action
                ]);
            }
            echo get_libya_msg_template_v14("تنبيه", "لقد قمت بتحويل الطلب رقم {$order_id} مسبقاً لتاجر آخر. شكراً لك.", "المعتمد | 0914479920", "info");
            exit;
        }

        $claimed_by = get_post_meta($order_id, LIBYA_META_CLAIMED_BY, true);
        $next_claim_allowed = get_post_meta($order_id, LIBYA_META_NEXT_CLAIM_ALLOWED, true);

        // بعد التحويل: فقط التاجر الذي وُجه إليه الطلب يمكنه قبوله؛ الباقون يمنعون حتى لا يحدث لبس
        if (!$claimed_by && $next_claim_allowed !== '' && $next_claim_allowed !== $merchant_email) {
            if (isset($_GET['ajax'])) {
                wp_send_json([
                    'success' => false,
                    'message' => 'الطلب محول لتاجر آخر. إذا وصلك إشعار بالطلب فاستخدم الرابط في الإشعار.',
                    'action' => $action
                ]);
            }
            echo get_libya_msg_template_v14("تنبيه", "الطلب محول لتاجر آخر. إذا وصلك إشعار بالطلب فاستخدم الرابط في الإشعار.", "المعتمد | 0914479920", "info");
            exit;
        }

        // منع أي تاجر آخر من اتخاذ إجراء إذا كان الطلب مستولى عليه من قبل شخص آخر
        if ($claimed_by && $claimed_by !== $merchant_email) {
            if (isset($_GET['ajax'])) {
                wp_send_json([
                    'success' => false,
                    'message' => "تم تسليم الطلب رقم {$order_id} لتاجر آخر وهو الآن قيد التنفيذ. شكراً لك.",
                    'action' => $action
                ]);
            }
            echo get_libya_msg_template_v14("تنبيه", "تم تسليم الطلب رقم {$order_id} لتاجر آخر وهو الآن قيد التنفيذ. شكراً لك.", "المعتمد | 0914479920", "info");
            exit;
        }

        $last_action_time = get_option("merchant_last_action_time_{$order_id}");
        if ($last_action_time && !in_array($action, ['processing', 'confirm_processing'])) {
            // إذا كان التاجر الحالي هو نفسه الذي استولى على الطلب وقام بإجراء، نمنعه.
            // أما إذا كان الطلب قد تم تحريره (claimed_by فارغ) فهذا يعني أنه محول ويسمح للتاجر الجديد بالعمل.
            if ($claimed_by === $merchant_email) {
                if (isset($_GET['ajax'])) {
                    wp_send_json([
                        'success' => false,
                        'message' => "عذراً، تم اتخاذ إجراء مسبق على هذا الطلب ولا يمكن تكراره.",
                        'action' => $action
                    ]);
                }
                echo get_libya_msg_template_v14("تنبيه", "عذراً، تم اتخاذ إجراء مسبق على هذا الطلب ولا يمكن تكراره.", "المعتمد | 0914479920", "warning");
                exit;
            }
        }
        $order = wc_get_order($order_id);
        if (!$order) wp_die('الطلب غير موجود.');

        $merchants = get_libya_merchants_v14();
        $m_data = $merchants[$merchant_email] ?? [];
        $m_name = $m_data['branch_name'] ?? 'تاجر';

        if (in_array($action, ['processing', 'confirm_processing'])) {
            // فحص وصول التاجر للحد المقرر قبل عرض البيانات
            $order_count = (int)get_option("merchant_orders_count_{$merchant_email}", 0);

            // سد ثغرة التهرب: احتساب الطلبات المعلقة (Processing) التي مر عليها أكثر من 48 ساعة
            $recent_orders = get_option("merchant_recent_orders_{$merchant_email}", []);
            $pending_count = 0;
            foreach ($recent_orders as $oid) {
                $last_act = (int)get_option("merchant_last_action_time_{$oid}", 0);
                if ($last_act > 0 && (time() - $last_act) > (48 * 3600)) {
                    $pending_count++;
                }
            }
            $effective_count = $order_count + $pending_count;
            $order_limit = isset($m_data['order_limit']) ? (int)$m_data['order_limit'] : 10;

            if ($effective_count >= $order_limit) {
                $secret = MERCHANT_ACTION_SECRET_KEY_V14;
                $base_url = home_url('/');
                $url_pay = wp_nonce_url(add_query_arg(['libya_action' => 'bank_transfer_page', 'm_email' => $merchant_email, 'secret' => $secret], $base_url), 'libya_pay_page_' . $merchant_email, 'libya_nonce');

                $content = "
					                <div style='text-align: center; padding: 10px;'>
					                    <p style='font-size: 18px; font-weight: bold; color: #2d3748;'>نعتذر، لا يمكن اتخاذ أي إجراء بخصوص هذا الطلب</p>
					                    <p style='font-size: 15px; color: #4a5568; margin-bottom: 25px;'>حتى يتم تسوية حسابك</p>
					                    " . get_libya_btn_v14("تحويل القيمة", $url_pay, "green") . "
					                </div>";
                echo get_libya_msg_template_v14("تنبيه تسوية الحساب", $content, "المعتمد | 0914479920", "warning");
                exit;
            }

            // قواعد الاستيلاء على الطلب:
            // - عندما يصل الطلب لعدة تجار بالمدينة، من يضغط "قبول الطلب" أولاً يستولي على الطلب ويمنع الباقين.
            // - الاستثناء: إذا قام المستولي بتحويل الطلب لتاجر آخر يُحرَّر الطلب ويستطيع تاجر آخر قبوله.
            // - إذا ضغط تاجران في نفس اللحظة، الأسرع (أول من يحصل على القفل) يستولي على الطلب.
            // القفل الحديدي (Atomic Lock): استخدام قفل MySQL حقيقي لضمان عدم التزامن
            if (!$claimed_by) {
                global $wpdb;

                // محاولة الحصول على قفل MySQL فريد لهذا الطلب (timeout: 5 ثوانٍ) — الأسرع يفوز
                $lock_name = 'libya_order_lock_' . $order_id;
                $lock_result = $wpdb->get_var($wpdb->prepare("SELECT GET_LOCK(%s, 5)", $lock_name));

                if ($lock_result == 1) {
                    // نجح الحصول على القفل - التحقق مرة أخرى من عدم وجود claim
                    $current_claim = get_post_meta($order_id, LIBYA_META_CLAIMED_BY, true);

                    if (!$current_claim) {
                        // الطلب متاح - نقوم بالاستيلاء عليه
                        update_post_meta($order_id, LIBYA_META_CLAIMED_BY, $merchant_email);
                        update_post_meta($order_id, LIBYA_META_CLAIM_TIME, time());
                        delete_post_meta($order_id, LIBYA_META_NEXT_CLAIM_ALLOWED);

                        // --- تتبع إحصائيات سرعة الرد ---
                        $created_time = $order->get_date_created()->getTimestamp();
                        $resp_time = time() - $created_time;
                        $total_resp_time = (int)get_option(LIBYA_PERF_RESPONSE_TIME . $merchant_email, 0) + $resp_time;
                        $resp_count = (int)get_option(LIBYA_PERF_RESPONSE_COUNT . $merchant_email, 0) + 1;
                        update_option(LIBYA_PERF_RESPONSE_TIME . $merchant_email, $total_resp_time);
                        update_option(LIBYA_PERF_RESPONSE_COUNT . $merchant_email, $resp_count);
                        update_option(LIBYA_PERF_TOTAL_CLAIMS . $merchant_email, (int)get_option(LIBYA_PERF_TOTAL_CLAIMS . $merchant_email, 0) + 1);

                        // نجاح الاستيلاء — لا نسجل "استلم الطلب" (استُبدل بـ "تم استلام الطلب" عند وصول الطلب للتاجر)
                        $city = $order->get_shipping_city() ?: $order->get_billing_city();
                        $order->add_order_note("المعتمد - رقم الطلب: {$order_id} - المدينة: {$city}");

                        // تم إلغاء إرسال الإيميل للمسؤول (يتم الاكتفاء بالتسجيل في سجل العمليات)

                        // تحرير القفل
                        $wpdb->query($wpdb->prepare("SELECT RELEASE_LOCK(%s)", $lock_name));
                    } else {
                        // تم الاستيلاء على الطلب من قبل تاجر آخر أثناء انتظار القفل
                        $wpdb->query($wpdb->prepare("SELECT RELEASE_LOCK(%s)", $lock_name));
                        echo get_libya_msg_template_v14("تنبيه", "تم تسليم الطلب رقم {$order_id} لتاجر آخر وهو الآن قيد التنفيذ. شكراً لك.", "المعتمد | 0914479920", "info");
                        exit;
                    }
                } else {
                    // فشل الحصول على القفل - تاجر آخر يعمل على الطلب الآن
                    echo get_libya_msg_template_v14("تنبيه", "تم تسليم الطلب رقم {$order_id} لتاجر آخر وهو الآن قيد التنفيذ. شكراً لك.", "المعتمد | 0914479920", "info");
                    exit;
                }
            } elseif ($claimed_by !== $merchant_email) {
                // إذا كان الطلب محجوزاً مسبقاً لتاجر آخر
                echo get_libya_msg_template_v14("تنبيه", "تم تسليم الطلب رقم {$order_id} لتاجر آخر وهو الآن قيد التنفيذ. شكراً لك.", "المعتمد | 0914479920", "info");
                exit;
            } else {
                // إذا كان التاجر هو المستولي الحالي ولكن لم يتم تسجيل وقت الاستلام (طلبات قديمة قبل التحديث)
                if (!get_post_meta($order_id, LIBYA_META_CLAIM_TIME, true)) {
                    update_post_meta($order_id, LIBYA_META_CLAIM_TIME, time());
                }
            }

            // التحقق من الوقت (48 ساعة) والحالة النهائية
            $last_action_time = (int)get_option("merchant_last_action_time_{$order_id}", 0);
            $is_within_48h = ($last_action_time > 0) ? ((time() - $last_action_time) < (48 * 3600)) : true;

            // إعادة تحميل الطلب لتجنب كاش يظهر "مكتمل أو ملغي" بعد التحويل أو الاستيلاء
            $order = wc_get_order($order_id);
            if (!$order) {
                echo get_libya_msg_template_v14("تنبيه", "الطلب غير موجود.", "المعتمد | 0914479920", "info");
                exit;
            }
            // السماح بالدخول طالما الطلب ليس مكتملاً أو ملغياً — منع الرجوع بعد الإجراء النهائي
            $order_status = $order->get_status();
            if (in_array($order_status, ['completed', 'cancelled', 'trash', 'refunded', 'failed'])) {
                echo get_libya_msg_template_v14("تنبيه", "عذراً، هذا الطلب مكتمل أو ملغي.", "المعتمد | 0914479920", "info");
                exit;
            }

            $is_attendance_confirmed = get_post_meta($order_id, LIBYA_META_ATTENDANCE_CONFIRMED, true) === 'yes';
            $attendance_time = (int)get_post_meta($order_id, LIBYA_META_ATTENDANCE_TIME, true);

            // إذا مر وقت طويل جداً (أكثر من 48 ساعة من آخر إجراء فعلي)
            if ($last_action_time > 0 && !$is_within_48h) {
                echo get_libya_msg_template_v14("تنبيه", "عذراً، لقد انتهت صلاحية التعامل مع هذا الطلب (مرور 48 ساعة).", "المعتمد | 0914479920", "info");
                exit;
            }
            // تأجيل التسجيل وإرسال إشعار "قيد التنفيذ" إلى ما بعد إرسال الصفحة للمتصفح (تقليل تأخير فتح الصفحة)
            if ($action === 'confirm_processing') {
                $city = $order->get_shipping_city() ?: $order->get_billing_city();
                $already_sent = get_post_meta($order_id, LIBYA_META_NOTIFIED_PROCESSING, true) === 'yes';
                $is_full_page = !isset($_GET['ajax']);
                $cust_targets = array();
                if (!$already_sent && $is_full_page) {
                    $cid = $order->get_customer_id();
                    if ($cid) $cust_targets[] = (string) $cid;
                    $billing_email = $order->get_billing_email();
                    if ($billing_email) $cust_targets[] = $billing_email;
                }
                $cust_title = 'قيد التنفيذ';
                $cust_message = 'جاري🔄 العمل على تنفيذ طلبك الآن ترقب اتصالاً 📞هاتفيًا أو رسالة واتساب منا بعد لحظات';
                register_shutdown_function(function () use ($order_id, $merchant_email, $city, $already_sent, $is_full_page, $cust_targets, $cust_title, $cust_message) {
                    if (function_exists('libya_system_log_v14')) {
                        libya_system_log_v14('تم قبول الطلب', $merchant_email, "المعتمد - رقم الطلب: {$order_id} - المدينة: {$city}", 120);
                    }
                    if (!$already_sent && $is_full_page && !empty($cust_targets) && function_exists('almuetamad_send_onesignal_v7')) {
                        almuetamad_send_onesignal_v7($cust_targets, $cust_title, $cust_message, '', array('order_id' => $order_id));
                        update_post_meta($order_id, LIBYA_META_NOTIFIED_PROCESSING, 'yes');
                        update_post_meta($order_id, LIBYA_META_PROCESSING_SINCE, time());
                    }
                });
            }
            $customer_name = $order->get_billing_first_name() . ' ' . $order->get_billing_last_name();
            $customer_phone = $order->get_billing_phone();
            $customer_phone_clean = preg_replace('/[^0-9]/', '', $customer_phone);
            if (substr($customer_phone_clean, 0, 1) === '0') $customer_phone_clean = '218' . substr($customer_phone_clean, 1);
            $customer_address = $order->get_billing_address_1() . ' ' . $order->get_billing_address_2() . ' ' . $order->get_billing_city();

            $items_text = "<table align='center' style='width: 100%; max-width: 400px; margin-left: auto; margin-right: auto; border-collapse: collapse; font-size: 11px; text-align: right;'>
			                <tr style='font-weight: bold;'>
			                    <td style='padding: 4px 0;'>المنتج</td>
			                    <td style='padding: 4px 0;'></td>
			                    <td style='padding: 4px 0; text-align: center;'>الكمية</td>
			                    <td style='padding: 4px 0; text-align: left;'>السعر</td>
			                </tr>";
            foreach ($order->get_items() as $item) {
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
			                <td style='padding: 4px 0; border-top: 1px solid #cbd5e1;' colspan='2'>المجموع</td>
			                <td style='padding: 4px 0; border-top: 1px solid #cbd5e1;'></td>
			                <td style='padding: 4px 0; border-top: 1px solid #cbd5e1; text-align: left;'>" . strip_tags(wc_price((float)$order->get_total())) . "</td>
			            </tr></table>";

            $secret = MERCHANT_ACTION_SECRET_KEY_V14;

            $base_url = home_url('/');
            // بيانات AJAX للأزرار
            $ajax_data = [
                'order_id' => $order_id,
                'm_email' => $merchant_email,
                'secret' => $secret,
                'nonce' => wp_create_nonce('libya_order_action_' . $order_id)
            ];

            $content = "
             <div style='text-align: right; background: #f8fafc; padding: 20px; border-radius: 10px; border: 1px solid #cbd5e1;'>
                 <div id='libya-deadline-timer'>
                    جاري تحميل العداد...
                </div>
                <p><strong>رقم الطلب:</strong> {$order_id}</p>
                <p><strong>ملخص الطلب:</strong><br>{$items_text}</p>
                <hr style='border: 0; border-top: 1px solid #cbd5e1; margin: 15px 0;'>
                    <p><strong>اسم العميل:</strong> {$customer_name}</p>
                    <div class='libya-contact-links-wrap'>
                    <p><strong>مراسلة العميل واتساب:</strong> <a href='#' class='libya-wa-link' data-wa='" . esc_attr($customer_phone_clean) . "' style='display:inline-flex;align-items:center;justify-content:center;width:28px;height:28px;background:#25D366;color:white;border-radius:50%;margin-right:6px;vertical-align:middle;text-decoration:none;'><span style='display:inline-block;width:14px;height:14px;'><svg width='14' height='14' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z'></path></svg></span></a></p>
                    <p><strong>مراسلة العميل SMS:</strong> <a href='#' class='libya-sms-link' data-sms='" . esc_attr(preg_replace('/[^0-9+]/', '', $customer_phone)) . "' style='display:inline-flex;align-items:center;justify-content:center;width:28px;height:28px;background:#ecc94b;color:#212529;border-radius:50%;margin-right:6px;vertical-align:middle;text-decoration:none;'><span style='display:inline-block;width:14px;height:14px;'><svg width='14' height='14' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z'></path></svg></span></a></p>
                    </div>
                    <p><strong><span style='display:inline-block;width:14px;height:14px;vertical-align:middle;margin-left:4px;'><svg width='14' height='14' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z'></path><circle cx='12' cy='10' r='3'></circle></svg></span>العنوان:</strong> {$customer_address}</p>
                    <p><strong><span style='display:inline-block;width:14px;height:14px;vertical-align:middle;margin-left:4px;'><svg width='14' height='14' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><rect x='3' y='4' width='18' height='18' rx='2' ry='2'></rect><line x1='16' y1='2' x2='16' y2='6'></line><line x1='8' y1='2' x2='8' y2='6'></line><line x1='3' y1='10' x2='21' y2='10'></line></svg></span>التاريخ:</strong> <span style='font-size: 13px; color: #718096;'>" . $order->get_date_created()->date('Y-m-d H:i') . "</span></p>
            </div>
            <p style='margin-top: 20px; font-size: 13px; color: #4a5568; line-height: 1.4;'>بعد إكمال الطلب، يرجى تحديث الحالة أدناه:</p>
            <div class='libya-buttons-container' style='margin-top: 20px;'>
                <div class='libya-buttons-grid'>
                    " . (!$is_attendance_confirmed ? "
                    <div class='libya-call-btn-wrap btn-full' style='text-align: center; margin: 10px 5px; grid-column: span 2;' data-ajax-payload='" . esc_attr(json_encode($ajax_data)) . "'>
                        <a href='#' class='libya-btn libya-btn-link btn-green libya-call-confirm-link' data-phone='" . esc_attr($customer_phone) . "' style='display:block; width:100%; text-decoration: none; color: #fff; gap: 8px;'><span class='btn-icon-circle'><svg width='16' height='16' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='3' stroke-linecap='round' stroke-linejoin='round'><path d='M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z'></path></svg></span><span class='btn-text'>اتصل بالعميل</span></a>
                    </div>
                    " . get_libya_ajax_btn_v14("تحويل الطلب", "transfer_order", $ajax_data, "yellow", '<span class="btn-icon-circle"><svg width=\'16\' height=\'16\' viewBox=\'0 0 24 24\' fill=\'none\' stroke=\'currentColor\' stroke-width=\'3\' stroke-linecap=\'round\' stroke-linejoin=\'round\'><polyline points=\'17 1 21 5 17 9\'></polyline><path d=\'M3 11V9a4 4 0 0 1 4-4h14\'></path><polyline points=\'7 23 3 19 7 15\'></polyline><path d=\'M21 13v2a4 4 0 0 1-4 4H3\'></path></svg></span>') . "
                    <div class='libya-post-confirm' style='display:none;'>" . get_libya_ajax_btn_v14("تم التسليم", "delivered", $ajax_data, "green", '<span class="btn-icon-circle"><svg width=\'16\' height=\'16\' viewBox=\'0 0 24 24\' fill=\'none\' stroke=\'currentColor\' stroke-width=\'4\' stroke-linecap=\'round\' stroke-linejoin=\'round\'><polyline points=\'20 6 9 17 4 12\'></polyline></svg></span>') . " " . get_libya_ajax_btn_v14("تعذر التسليم", "rejected", $ajax_data, "red", '<span class="btn-icon-circle"><svg width=\'16\' height=\'16\' viewBox=\'0 0 24 24\' fill=\'none\' stroke=\'currentColor\' stroke-width=\'3\' stroke-linecap=\'round\' stroke-linejoin=\'round\'><circle cx=\'12\' cy=\'12\' r=\'10\'></circle><line x1=\'12\' y1=\'8\' x2=\'12\' y2=\'12\'></line><line x1=\'12\' y1=\'16\' x2=\'12.01\' y2=\'16\'></line></svg></span>') . "</div>
                    <div class='libya-pre-confirm-rejected'>" . get_libya_ajax_btn_v14("تعذر التسليم", "rejected", $ajax_data, "red", '<span class="btn-icon-circle"><svg width=\'16\' height=\'16\' viewBox=\'0 0 24 24\' fill=\'none\' stroke=\'currentColor\' stroke-width=\'3\' stroke-linecap=\'round\' stroke-linejoin=\'round\'><circle cx=\'12\' cy=\'12\' r=\'10\'></circle><line x1=\'12\' y1=\'8\' x2=\'12\' y2=\'12\'></line><line x1=\'12\' y1=\'16\' x2=\'12.01\' y2=\'16\'></line></svg></span>') . "</div>
                    " : "
                    " . get_libya_ajax_btn_v14("تم التسليم", "delivered", $ajax_data, "green", '<span class="btn-icon-circle"><svg width=\'16\' height=\'16\' viewBox=\'0 0 24 24\' fill=\'none\' stroke=\'currentColor\' stroke-width=\'4\' stroke-linecap=\'round\' stroke-linejoin=\'round\'><polyline points=\'20 6 9 17 4 12\'></polyline></svg></span>') . "
                    " . get_libya_ajax_btn_v14("تعذر التسليم", "rejected", $ajax_data, "red", '<span class="btn-icon-circle"><svg width=\'16\' height=\'16\' viewBox=\'0 0 24 24\' fill=\'none\' stroke=\'currentColor\' stroke-width=\'3\' stroke-linecap=\'round\' stroke-linejoin=\'round\'><circle cx=\'12\' cy=\'12\' r=\'10\'></circle><line x1=\'12\' y1=\'8\' x2=\'12\' y2=\'12\'></line><line x1=\'12\' y1=\'16\' x2=\'12.01\' y2=\'16\'></line></svg></span>') . "
                    ") . "
                </div>
            </div>
            <script>
            (function() {
                var claimTime = " . ((int)get_post_meta($order_id, LIBYA_META_CLAIM_TIME, true) ?: (int)$order->get_date_created()->getTimestamp()) . ";
                var attendanceConfirmed = " . ($is_attendance_confirmed ? 'true' : 'false') . ";
                var attendanceTime = " . $attendance_time . ";
                var deadlineMinutes = " . (int)get_option('libya_def_deadline', 60) . ";
                var extraMinutes = " . (int)get_option('libya_def_extra_time', 30) . ";
                
                var state = {
                    attendanceConfirmed: attendanceConfirmed,
                    attendanceTime: attendanceTime,
                    claimTime: claimTime,
                    deadlineMinutes: deadlineMinutes,
                    extraMinutes: extraMinutes
                };
                state.expiryTime = (state.attendanceConfirmed ? (state.attendanceTime + (state.extraMinutes * 60)) : (state.claimTime + (state.deadlineMinutes * 60))) * 1000;
                window.libyaTimerState = state;
                
                window.libyaSwitchToExtraTime = function() {
                    if (window.libyaTimerState && !window.libyaTimerState.attendanceConfirmed) {
                        window.libyaTimerState.attendanceConfirmed = true;
                        window.libyaTimerState.attendanceTime = Math.floor(Date.now() / 1000);
                        window.libyaTimerState.expiryTime = (window.libyaTimerState.attendanceTime + (window.libyaTimerState.extraMinutes * 60)) * 1000;
                    }
                };
                
                function updateTimer() {
                    var s = window.libyaTimerState || state;
                    var expiryTime = s.expiryTime;
                    var attendanceConfirmed = s.attendanceConfirmed;
                    var totalTime = (attendanceConfirmed ? (s.extraMinutes * 60) : (s.deadlineMinutes * 60)) * 1000;
                    var now = new Date().getTime();
                    var distance = expiryTime - now;
                    
                    if (distance < 0) {
                        if (!window.libyaExpired) {
                            window.libyaExpired = true;
                            if (window.libyaTimerInterval) {
                                clearInterval(window.libyaTimerInterval);
                                window.libyaTimerInterval = null;
                            }
                            var timerElExp = document.getElementById('libya-deadline-timer');
                            if (timerElExp) {
                                timerElExp.style.opacity = '0';
                                timerElExp.style.maxHeight = timerElExp.offsetHeight + 'px';
                                setTimeout(function() {
                                    timerElExp.style.maxHeight = '0';
                                    timerElExp.style.margin = '0';
                                    timerElExp.style.padding = '0';
                                    timerElExp.style.overflow = 'hidden';
                                    setTimeout(function() { timerElExp.style.display = 'none'; }, 350);
                                }, 50);
                            }
                            var msg = attendanceConfirmed ? 
                                'انتهت المهلة الإضافية. سيُحسب الطلب كأنه تم تسليمه تلقائياً.' : 
                                'انتهت المهلة المحددة، تم تحويل الطلب لمتجر اخر لضمان سرعة الخدمة.';
                            var notifType = attendanceConfirmed ? 'deadline2' : 'deadline1';
                            var btnContainer = document.querySelector('.libya-buttons-container');
                            if (btnContainer) {
                                var grid = btnContainer.querySelector('.libya-buttons-grid');
                                if (grid) grid.style.display = 'none';
                                var contactWrap = document.querySelector('.libya-contact-links-wrap');
                                if (contactWrap) contactWrap.style.display = 'none';
                                var notifDiv = document.createElement('div');
                                notifDiv.innerHTML = (typeof getStateNotificationHtml === 'function' ? getStateNotificationHtml(notifType, msg) : '<div class=\"libya-state-notification libya-notif-' + (attendanceConfirmed ? 'green' : 'yellow') + '\"><span>' + msg + '</span></div>');
                                if (notifDiv.firstElementChild) {
                                    btnContainer.insertBefore(notifDiv.firstElementChild, btnContainer.firstChild);
                                }
                            }
                            window.scrollTo({ top: 0, behavior: 'smooth' });
                        }
                        return;
                    }
                    
                    var minutes = Math.floor((distance % (1000 * 3600)) / (1000 * 60));
                    var seconds = Math.floor((distance % (1000 * 60)) / 1000);
                    
                    var timerEl = document.getElementById('libya-deadline-timer');
                    if (timerEl) {
                        timerEl.innerHTML = (attendanceConfirmed ? 'الوقت الإضافي المتبقي: ' : 'الوقت المتبقي للتسليم: ') + minutes + 'د ' + seconds + 'ث';
                         if (distance < (totalTime * 0.25)) {
                            timerEl.classList.add('low-time');
                        } else {
                            timerEl.classList.remove('low-time');
                        }
                    }
                }
                
                updateTimer();
                var timerInterval = setInterval(updateTimer, 1000);
                window.libyaTimerInterval = timerInterval;
                window.libyaStopAndHideTimer = function() {
                    if (window.libyaTimerInterval) {
                        clearInterval(window.libyaTimerInterval);
                        window.libyaTimerInterval = null;
                    }
                    var timerEl = document.getElementById('libya-deadline-timer');
                    if (timerEl) {
                        timerEl.style.opacity = '0';
                        timerEl.style.maxHeight = timerEl.offsetHeight + 'px';
                        setTimeout(function() {
                            timerEl.style.maxHeight = '0';
                            timerEl.style.margin = '0';
                            timerEl.style.padding = '0';
                            timerEl.style.overflow = 'hidden';
                            setTimeout(function() { timerEl.style.display = 'none'; }, 350);
                        }, 50);
                    }
                };
            })();
            </script>
            <div id='libya-result-message'></div>";

            $footer_order = "للمساعدة أو الاستفسار | 0914479920";
            // دعم AJAX
            if (isset($_GET['ajax'])) {
                wp_send_json([
                    'success' => true,
                    'message' => 'تم قبول الطلب بنجاح، يمكنك الآن معالجته',
                    'action' => 'confirm_processing',
                    'redirect' => true,
                    'content' => get_libya_msg_template_v14("بيانات الطلب {$order_id}", $content, $footer_order, "primary")
                ]);
            }

            echo get_libya_msg_template_v14("بيانات الطلب {$order_id}", $content, $footer_order, "primary");
            exit;
        } elseif ($action === 'confirm_attendance') {
            $city = $order->get_shipping_city() ?: $order->get_billing_city();
            libya_system_log_v14('تم الاتصال بالعميل', $merchant_email, "المعتمد - رقم الطلب: {$order_id} - المدينة: {$city}", 120);
            $order->add_order_note("المعتمد - رقم الطلب: {$order_id} - المدينة: {$city}");
            update_post_meta($order_id, LIBYA_META_ATTENDANCE_CONFIRMED, 'yes');
            update_post_meta($order_id, LIBYA_META_ATTENDANCE_TIME, time());
            // تم إلغاء إشعار "سيتم التواصل معك الان" بناءً على طلب العميل

            if (isset($_GET['ajax'])) {
                wp_send_json([
                    'success' => true,
                    'message' => 'تم تأكيد حضور العميل وتمديد المهلة بنجاح.',
                    'action' => 'confirm_attendance',
                    'reload' => true
                ]);
            }
            wp_redirect($_SERVER['HTTP_REFERER']);
            exit;
        } elseif ($action === 'delivered') {
            $city = $m_data['city'] ?? $order->get_billing_city();
            $archive = get_option("merchant_archive_{$merchant_email}", []);
            if (in_array($order_id, $archive)) wp_die('هذا الطلب مؤرشف مسبقاً ولا يمكن إعادة احتسابه.');
            $order_count = (int)get_option("merchant_orders_count_{$merchant_email}", 0) + 1;
            $total_sales = (float)get_option("merchant_total_sales_{$merchant_email}", 0) + $order->get_total();
            $recent_orders = get_option("merchant_recent_orders_{$merchant_email}", []);
            if (!in_array($order_id, $recent_orders)) {
                $recent_orders[] = $order_id;
            }
            update_option("merchant_orders_count_{$merchant_email}", $order_count);
            update_option("merchant_total_sales_{$merchant_email}", $total_sales);
            update_option("merchant_recent_orders_{$merchant_email}", $recent_orders);
            update_option("merchant_last_action_time_{$order_id}", time());

            // --- تتبع إحصائيات التسليم اليدوي وسرعة التسليم ---
            $claim_time = (int)get_post_meta($order_id, LIBYA_META_CLAIM_TIME, true);
            if ($claim_time > 0) {
                $deliv_time = time() - $claim_time;
                $total_deliv_time = (int)get_option(LIBYA_PERF_DELIVERY_TIME . $merchant_email, 0) + $deliv_time;
                $deliv_count = (int)get_option(LIBYA_PERF_DELIVERY_COUNT . $merchant_email, 0) + 1;
                update_option(LIBYA_PERF_DELIVERY_TIME . $merchant_email, $total_deliv_time);
                update_option(LIBYA_PERF_DELIVERY_COUNT . $merchant_email, $deliv_count);
            }
            $manual_deliv_count = (int)get_option(LIBYA_PERF_MANUAL_DELIVERIES . $merchant_email, 0) + 1;
            update_option(LIBYA_PERF_MANUAL_DELIVERIES . $merchant_email, $manual_deliv_count);

            // تصفير وقت الانتظار عند الضغط على تم التسليم
            $merchants = get_libya_merchants_v14();
            if (isset($merchants[$merchant_email])) {
                $merchants[$merchant_email]['last_activity'] = time();
                save_libya_merchants_v14($merchants);
            }

            // تحديث حالة الطلب (بدون إرسال إيميل للعميل)
            add_filter('woocommerce_email_enabled_customer_completed_order', '__return_false');
            add_filter('woocommerce_email_enabled_customer_processing_order', '__return_false');
            $order->update_status('completed', 'تم تأكيد التسليم من التاجر: ' . $merchant_email);
            remove_filter('woocommerce_email_enabled_customer_completed_order', '__return_false');
            remove_filter('woocommerce_email_enabled_customer_processing_order', '__return_false');

            // تأجيل التسجيل وإشعار العميل وحد الطلبيات و notify إلى ما بعد إرسال الاستجابة
            $city_log = $order->get_shipping_city() ?: $order->get_billing_city();
            register_shutdown_function(function () use ($order_id, $merchant_email, $city_log, $m_data, $m_name) {
                if (function_exists('libya_system_log_v14')) {
                    libya_system_log_v14('تم التسليم', $merchant_email, "المعتمد - رقم الطلب: {$order_id} - المدينة: {$city_log}", 120);
                }
                $order = wc_get_order($order_id);
                if ($order) {
                    $cust_targets = array();
                    $cid = $order->get_customer_id();
                    if ($cid) $cust_targets[] = (string) $cid;
                    $be = $order->get_billing_email();
                    if ($be) $cust_targets[] = $be;
                    if (!empty($cust_targets) && function_exists('almuetamad_send_onesignal_v7')) {
                        almuetamad_send_onesignal_v7($cust_targets, 'تم التسليم', 'تم الانتهاء من تسليم طلبك رقم ' . $order_id . ' بنجاح ✨, نتطلع لخدمتك مرة أخرى قريباً', '', array('order_id' => $order_id));
                    }
                }
                $current_count = (int)get_option("merchant_orders_count_{$merchant_email}", 0);
                $order_limit = isset($m_data['order_limit']) ? (int)$m_data['order_limit'] : DEFAULT_ORDER_LIMIT_V14;
                $last_notify = (int)get_option("merchant_limit_notified_{$merchant_email}");
                $last_payment = (int)get_option("merchant_payment_completed_{$merchant_email}", 0);
                if ($current_count >= $order_limit && (!$last_notify || $last_notify < $last_payment)) {
                    $recent_orders = get_option("merchant_recent_orders_{$merchant_email}", []);
                    $total_sales = (float)get_option("merchant_total_sales_{$merchant_email}", 0);
                    $total_comm_due = 0;
                    foreach ($recent_orders as $oid) {
                        $o_tmp = wc_get_order($oid);
                        if ($o_tmp) $total_comm_due += calculate_libya_merchant_commission_v14($o_tmp->get_total(), $m_data);
                    }
                    $secret = MERCHANT_ACTION_SECRET_KEY_V14;
                    $base_url = home_url('/');
                    $old_uid = get_current_user_id();
                    wp_set_current_user(0);
                    $url_pay_page = wp_nonce_url(add_query_arg(['libya_action' => 'bank_transfer_page', 'm_email' => $merchant_email, 'secret' => $secret], $base_url), 'libya_pay_page_' . $merchant_email, 'libya_nonce');
                    wp_set_current_user($old_uid);
                    $m_msg = "
	                <div style='text-align: right; line-height: 1.6;'>
	                    <p>مرحباً عزيزي: <strong>{$m_name}</strong></p>
	                    <p>نود إعلامك بأنك بلغت الحد الأقصى للطلبات لاستئناف الخدمة، نرجو إتمام التحويل المصرفي للمبلغ المحدد في الفاتورة إلى الحساب المرفق.</p>
	                    <hr style='border: 0; border-top: 1px solid #cbd5e1; margin: 15px 0;'>
	                    <p><strong>إحصائيات السجل الحالي:</strong></p>
	                    <p>• عدد الطلبات: {$current_count}</p>
	                    <p>• إجمالي المبيعات: " . wc_price($total_sales) . "</p>
	                    <p>• العمولة المستحقة: <strong>" . wc_price($total_comm_due) . "</strong></p>
	                    <hr style='border: 0; border-top: 1px solid #cbd5e1; margin: 15px 0;'>
	                    <p style='font-size: 13px; color: #4a5568; margin-bottom: 10px; line-height: 1.4;'>لإتمام العملية , اضغط على زر تحويل القيمة</p>
	                    <div style='margin-top: 20px;'>
	                        " . get_libya_btn_v14("تحويل القيمة", $url_pay_page, "green") . "
	                    </div>
	                </div>";
                    wp_mail($merchant_email, "تم بلوغ الحد الأقصى للطلبات 🔵", get_libya_msg_template_v14("تنبيه حد الطلبيات", $m_msg, "المعتمد | 0914479920", "warning"), ['Content-Type: text/html; charset=UTF-8']);
                    $admin_msg = "<div style='text-align: center; line-height: 1.8;'>
	                    <p>المتجر: <strong>{$m_name}</strong></p>
	                    <p>الحالة: <strong>وصل إلى حد الطلبات</strong></p>
	                    <p>عدد الطلبات: <strong>{$current_count}</strong></p>
	                    <p>القيمة المستحقة: <strong>" . wc_price($total_comm_due) . "</strong></p>
	                    <p>التاريخ: <strong>" . date('Y-m-d H:i') . "</strong></p>
	                </div>";
                    wp_mail(function_exists('libya_orders_email_v14') ? libya_orders_email_v14() : 'orders@almuetamad.com', "تنبيه حد الطلبات: {$m_name}", get_libya_msg_template_v14("وصول حد الطلبيات", $admin_msg, "المعتمد | 0914479920", "warning"), ['Content-Type: text/html; charset=UTF-8']);
                    update_option("merchant_limit_notified_{$merchant_email}", time());
                    delete_option("merchant_payment_completed_{$merchant_email}");
                }
                if (function_exists('notify_merchant_on_new_order_v14')) {
                    notify_merchant_on_new_order_v14(-1, $city_log);
                }
            });

            // دعم AJAX
            if (isset($_GET['ajax'])) {
                wp_send_json([
                    'success' => true,
                    'message' => 'تم تحديث حالة الطلب إلى "تم التسليم" بنجاح، شكراً لك',
                    'action' => 'delivered'
                ]);
            }

            echo get_libya_msg_template_v14("تم التحديث", "تم تحديث حالة الطلب إلى تم التسليم، شكراً لك", "المعتمد | 0914479920", "success", true);
            exit;
        } else $reasons_map = [
            'custom' => 'سبب مخصص',
            'price_high' => 'السعر غالي / الزبون يبي تخفيض',
            'no_response' => 'الزبون لا يرد / الهاتف مقفل',
            'customer_canceled' => 'الزبون ألغى الطلب',
            'wrong_item' => 'المنتج خطأ / غير مطابق',
            'delivery_issue' => 'لا يوجد مندوب / مكان بعيد',
            'duplicate' => 'طلب مكرر',
            'other' => 'سبب آخر'
        ];

        $reason_key = isset($_GET['reason_key']) ? sanitize_text_field($_GET['reason_key']) : '';
        $reason_note = isset($_GET['reason_note']) ? sanitize_text_field($_GET['reason_note']) : '';

        // إذا كان السبب مخصص، نستخدم الملاحظة مباشرة كسبب
        if ($reason_key === 'custom' && !empty($reason_note)) {
            $reason_text = $reason_note;
        } else {
            $reason_text = isset($reasons_map[$reason_key]) ? $reasons_map[$reason_key] : '';
            if ($reason_text && $reason_note) $reason_text .= " ({$reason_note})";
        }

        if ($reason_text) {
            $city = $order->get_shipping_city() ?: $order->get_billing_city();
            $order->add_order_note("المعتمد - رقم الطلب: {$order_id} - المدينة: {$city}");
        }

        $log_action_title = ($action === 'rejected') ? 'تعذر التسليم' : (($action === 'transfer_order') ? 'تحويل يدوي' : 'تعذر التسليم/تحويل');
        $city_log_reason = $order->get_shipping_city() ?: $order->get_billing_city();
        register_shutdown_function(function () use ($log_action_title, $merchant_email, $order_id, $city_log_reason, $reason_text) {
            if (function_exists('libya_system_log_v14')) {
                libya_system_log_v14($log_action_title, $merchant_email, "المعتمد - رقم الطلب: {$order_id} - المدينة: {$city_log_reason}", 120, $reason_text);
            }
        });

        $admin_msg_reason = $reason_text ? "<p style='color: #d63638; font-weight: bold;'>السبب: {$reason_text}</p>" : "";

        if ($action === 'unavailable') {
            $order->update_status('on-hold', 'المنتج غير متوفر');
            update_option("merchant_last_action_time_{$order_id}", time());
            // تم إلغاء إرسال الإيميل للمسؤول (يتم الاكتفاء بالتسجيل في سجل العمليات)
            echo get_libya_msg_template_v14("تم التحديث", "تم تحديث حالة المنتج إلى غير متوفر، شكراً لك", "المعتمد | 0914479920", "warning", true);
            exit;
        } elseif ($action === 'rejected') {
            $order->update_status('cancelled', 'تعذر التسليم');
            update_option("merchant_last_action_time_{$order_id}", time());

            // --- تتبع إحصائيات تعذر التسليم ---
            $failed_deliv_count = (int)get_option(LIBYA_PERF_FAILED_DELIVERIES . $merchant_email, 0) + 1;
            update_option(LIBYA_PERF_FAILED_DELIVERIES . $merchant_email, $failed_deliv_count);

            // تأجيل إيميل المسؤول وإشعار العميل إلى ما بعد إرسال الاستجابة
            $city_rej = $m_data['city'] ?? $order->get_billing_city();
            register_shutdown_function(function () use ($order_id, $merchant_email, $m_name, $admin_email, $city_rej, $admin_msg_reason) {
                $msg = "<div style='text-align: center; line-height: 1.8;'>
		                <p>المتجر: <strong>{$m_name}</strong></p>
		                <p>المدينة: <strong>{$city_rej}</strong></p>
		                <p>رقم الطلب: <strong>{$order_id}</strong></p>
		                <p>الحالة: <strong>تعذر تسليم الطلب</strong></p>
                        {$admin_msg_reason}
		            </div>";
                wp_mail($admin_email, "تعذر التسليم {$order_id} - {$m_name}", get_libya_msg_template_v14("إشعار تعذر تسليم", $msg, "المعتمد | 0914479920", "danger", false, true), ['Content-Type: text/html; charset=UTF-8', 'From: ' . get_bloginfo('name') . ' <' . get_option('admin_email') . '>']);
                $order = wc_get_order($order_id);
                if ($order) {
                    $cust_targets = array();
                    $cid = $order->get_customer_id();
                    if ($cid) $cust_targets[] = (string) $cid;
                    $be = $order->get_billing_email();
                    if ($be) $cust_targets[] = $be;
                    if (!empty($cust_targets) && function_exists('almuetamad_send_onesignal_v7')) {
                        almuetamad_send_onesignal_v7($cust_targets, 'تعذر التسليم', 'نود إبلاغكم بأنه قد تم إلغاء طلبكم رقم ' . $order_id . ' إذا كنتم ترغبون بإعادة الطلب مستقبلاً , يمكنكم ذلك في أي وقت 💙', '', array('order_id' => $order_id));
                    }
                }
            });

            // دعم AJAX
            if (isset($_GET['ajax'])) {
                wp_send_json([
                    'success' => true,
                    'message' => 'تم تحديث حالة الطلب إلى "تعذر التسليم"، شكراً لك',
                    'action' => 'rejected'
                ]);
            }

            echo get_libya_msg_template_v14("تم التحديث", "تم تحديث حالة الطلب إلى تعذر التسليم، شكراً لك", "المعتمد | 0914479920", "danger", true);
            exit;
        } elseif ($action === 'transfer_order') {
            $transferred_merchants = get_post_meta($order_id, '_libya_transferred_merchants', true);
            if (!is_array($transferred_merchants)) $transferred_merchants = [];
            if (!in_array($merchant_email, $transferred_merchants)) {
                $transferred_merchants[] = $merchant_email;
                update_post_meta($order_id, '_libya_transferred_merchants', $transferred_merchants);
            }
            delete_post_meta($order_id, LIBYA_META_CLAIMED_BY);
            delete_post_meta($order_id, LIBYA_META_CLAIM_TIME);
            delete_post_meta($order_id, LIBYA_META_ATTENDANCE_CONFIRMED);
            delete_post_meta($order_id, LIBYA_META_ATTENDANCE_TIME);
            delete_option("merchant_last_action_time_{$order_id}");

            // --- تتبع إحصائيات التحويل اليدوي ---
            $manual_trans_count = (int)get_option(LIBYA_PERF_MANUAL_TRANSFERS . $merchant_email, 0) + 1;
            update_option(LIBYA_PERF_MANUAL_TRANSFERS . $merchant_email, $manual_trans_count);

            // تأجيل إشعار التجار بالطلب المحوّل إلى ما بعد إرسال الاستجابة
            $city_trans = $m_data['city'] ?? $order->get_billing_city();
            register_shutdown_function(function () use ($order_id, $city_trans) {
                if (function_exists('notify_merchant_on_new_order_v14')) {
                    notify_merchant_on_new_order_v14($order_id, $city_trans, true);
                }
            });

            // دعم AJAX
            if (isset($_GET['ajax'])) {
                wp_send_json([
                    'success' => true,
                    'message' => 'تم تحويل الطلب لتاجر آخر بنجاح، شكراً لك',
                    'action' => 'transfer_order'
                ]);
            }

            echo get_libya_msg_template_v14("تم التحويل", "تم تحويل الطلب لتاجر آخر بنجاح، شكراً لك.", "المعتمد | 0914479920", "success", true);
            exit;
        }
    }

    // --- صفحة التحويل البنكي (للتاجر) ولوحة التحكم (Magic Link) ---
    if (isset($_GET['libya_action']) && in_array($_GET['libya_action'], ['bank_transfer_page', 'confirm_payment'])) {
        $action = sanitize_text_field($_GET['libya_action']);
        $merchant_email = isset($_GET['m_email']) ? sanitize_email($_GET['m_email']) : '';

        if ($action === 'confirm_payment') {
            if (!isset($_GET['libya_nonce']) || !wp_verify_nonce(sanitize_text_field($_GET['libya_nonce']), 'libya_pay_page_' . $merchant_email)) {
                wp_die('عذراً، انتهت صلاحية الرابط أو الطلب غير صالح.');
            }
        }

        $merchants = get_libya_merchants_v14();
        $m_data = $merchants[$merchant_email] ?? [];
        if ($m_data === [] && $merchant_email !== '') {
            foreach ($merchants as $k => $v) {
                if (strtolower((string) $k) === strtolower($merchant_email)) {
                    $m_data = $v;
                    $merchant_email = $k;
                    break;
                }
            }
        }
        $m_name = $m_data['branch_name'] ?? 'تاجر';
        $admin_email = function_exists('libya_orders_email_v14') ? libya_orders_email_v14() : 'orders@almuetamad.com';

        if ($action === 'bank_transfer_page') {
            if (get_option("merchant_payment_completed_{$merchant_email}")) {
                echo get_libya_msg_template_v14("تم الاستلام", "لقد تم استلام دفعتك مسبقاً، شكراً لك.", "المعتمد | 0914479920", "success", true);
                exit;
            }
            // تم إزالة التحقق التلقائي هنا للسماح للتاجر برؤية صفحة الحسابات حتى لو أرسل إشعاراً سابقاً، أو يمكن تركه إذا كان المطلوب منعه تماماً.
            // لكن المشكلة كانت في تداخل الإجراءات. سنبقي الصفحة متاحة للعرض.
            $recent = get_option("merchant_recent_orders_{$merchant_email}", []);
            $total_comm_due = 0;
            foreach ($recent as $oid) {
                $o = wc_get_order($oid);
                if ($o) $total_comm_due += calculate_libya_merchant_commission_v14($o->get_total(), $m_data);
            }

            $secret = MERCHANT_ACTION_SECRET_KEY_V14;

            // بيانات AJAX لزر التأكيد
            $ajax_data = [
                'm_email' => $merchant_email,
                'secret' => $secret,
                'nonce' => wp_create_nonce('libya_pay_page_' . $merchant_email)
            ];

            // ------------------------------------------------------------------
            // إضافة كود AJAX مباشرة في الصفحة لضمان عمل الزر حتى لو لم يتم تحميل المكتبات الخارجية
            // ------------------------------------------------------------------
            $inline_js = "
            <script>
            document.addEventListener('DOMContentLoaded', function() {
                var btn = document.getElementById('btn-confirm-payment');
                if(!btn) return;
                
                btn.addEventListener('click', function(e) {
                    e.preventDefault();
                    
                    var action = this.getAttribute('data-action');
                    var data = JSON.parse(this.getAttribute('data-payload'));
                    var container = this.closest('.libya-buttons-container');
                    
                    // تغيير حالة الزر
                    var originalText = this.innerHTML;
                    this.disabled = true;
                    this.innerHTML = 'جاري المعالجة...';
                    
                    // بناء الرابط
                    var baseUrl = window.location.href.split('?')[0]; 
                    var params = new URLSearchParams(window.location.search);
                    params.delete('libya_action');
                    params.set('libya_action', 'confirm_payment');
                    params.set('m_email', data.m_email);
                    params.set('secret', data.secret);
                    params.set('libya_nonce', data.nonce);
                    
                    var url = baseUrl + '?' + params.toString() + '&ajax=1';
                    
                    fetch(url, {
                        method: 'GET',
                        headers: { 'X-Requested-With': 'XMLHttpRequest' }
                    })
                    .then(response => response.text())
                    .then(text => {
                        try {
                            var res = JSON.parse(text);
                            if(res.success) {
                                container.innerHTML = '<div style=\"background:#d4edda; color:#155724; font-weight:bold; font-size:16px; padding:15px 20px; border-radius:8px; border:1px solid #c3e6cb; margin-top:15px;\">✅ ' + res.message + '</div>';
                            } else {
                                container.innerHTML = '<div style=\"background:#cce5ff; color:#004085; font-weight:bold; font-size:16px; padding:15px 20px; border-radius:8px; border:1px solid #b8daff; margin-top:15px;\">ℹ️ ' + res.message + '</div>';
                            }
                        } catch(err) {
                            console.error('Parse error:', err);
                            // محاولة استخراج الرسالة إذا كان هناك خطأ PHP
                            if(text.indexOf('لقد قمت بإرسال إشعار') !== -1) {
                                container.innerHTML = '<div style=\"background:#cce5ff; color:#004085; font-weight:bold; font-size:16px; padding:15px 20px; border-radius:8px; border:1px solid #b8daff; margin-top:15px;\">ℹ️ لقد قمت بإرسال إشعار التحويل مسبقاً. يرجى انتظار مراجعة المسؤول.</div>';
                            } else {
                                container.innerHTML = '<div style=\"background:#f8d7da; color:#721c24; font-weight:bold; font-size:16px; padding:15px 20px; border-radius:8px; border:1px solid #f5c6cb; margin-top:15px;\">❌ حدث خطأ غير متوقع. يرجى تحديث الصفحة والمحاولة مرة أخرى.</div>';
                            }
                        }
                    })
                    .catch(err => {
                        console.error('Fetch error:', err);
                        alert('خطأ في الاتصال.');
                        this.disabled = false;
                        this.innerHTML = originalText;
                    });
                });
            });
            </script>
            ";

            $content = $inline_js . "
            <div style='text-align: right; line-height: 1.6;'>
                <p>مرحباً: <strong>{$m_name}</strong></p>
                <p>القيمة الإجمالية المستحقة للتحويل هي: <strong style='color: #2d3748; font-size: 18px;'>" . wc_price($total_comm_due) . "</strong></p>
                <hr style='border: 0; border-top: 1px solid #cbd5e1; margin: 15px 0;'>
                <p><strong>بيانات الحسابات المصرفية:</strong></p>
                " . get_libya_bank_accounts_html_v14() . "
                <p style='font-size: 13px; color: #4a5568; margin-bottom: 10px; line-height: 1.4;'>بعد إتمام عملية التحويل، يرجى الضغط على الزر أدناه لتأكيد العملية:</p>
                <div class='libya-buttons-container' style='margin-top: 20px;'>
                    <button id='btn-confirm-payment' data-action='confirm_payment' data-payload='" . htmlspecialchars(json_encode($ajax_data), ENT_QUOTES, 'UTF-8') . "' 
                    style='display: inline-flex; align-items: center; gap: 8px; background: #28a745; color: #fff; border: none; padding: 12px 25px; border-radius: 5px; font-weight: bold; cursor: pointer; font-size: 14px; transition: all 0.3s ease;'>
                        <svg width='18' height='18' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='3' stroke-linecap='round' stroke-linejoin='round'><polyline points='20 6 9 17 4 12'></polyline></svg>
                        تم تحويل القيمة
                    </button>
                </div>
                <div id='libya-result-message'></div>
            </div>";
            echo get_libya_msg_template_v14("صفحة التحويل المصرفي", $content, "المعتمد | 0914479920", "info");
            exit;
        } elseif ($action === 'confirm_payment') {
            // السماح بمرور الإجراء لعرض رسالة النجاح الخضراء في المرة الأولى
            $already_notified = get_option("merchant_payment_notified_{$merchant_email}");
            $recent = get_option("merchant_recent_orders_{$merchant_email}", []);
            $total_comm_due = 0;
            foreach ($recent as $oid) {
                $o = wc_get_order($oid);
                if ($o) $total_comm_due += calculate_libya_merchant_commission_v14($o->get_total(), $m_data);
            }

            $secret = MERCHANT_ACTION_SECRET_KEY_V14;
            $base_url = home_url('/');
            $old_uid = get_current_user_id();
            wp_set_current_user(0);
            $url_received = wp_nonce_url(add_query_arg(['admin_action' => 'payment_received', 'm_email' => $merchant_email, 'secret' => $secret], $base_url), 'libya_admin_payment', 'libya_nonce');
            wp_set_current_user($old_uid);
            $old_uid = get_current_user_id();
            wp_set_current_user(0);
            $url_not_received = wp_nonce_url(add_query_arg(['admin_action' => 'payment_not_received', 'm_email' => $merchant_email, 'secret' => $secret], $base_url), 'libya_admin_payment', 'libya_nonce');
            wp_set_current_user($old_uid);

            $limit_notified = (int)get_option("merchant_limit_notified_{$merchant_email}");

            // إذا لم يتم إرسال إشعار من قبل، أو إذا تم إشعار الحد بعد آخر إشعار تحويل، نسمح بإرسال جديد
            if ($already_notified && $limit_notified && $already_notified > $limit_notified) {
                if (isset($_GET['ajax'])) {
                    wp_send_json([
                        'success' => false,
                        'message' => 'لقد قمت بإرسال إشعار التحويل مسبقاً. يرجى انتظار مراجعة المسؤول.',
                        'action' => 'confirm_payment'
                    ]);
                }
                echo get_libya_msg_template_v14("تنبيه", "لقد قمت بإرسال إشعار التحويل مسبقاً. يرجى انتظار مراجعة المسؤول.", "المعتمد | 0914479920", "info");
                exit;
            }

            $admin_msg = "
            <div style='text-align: right; line-height: 1.6;'>
                <p>قام التاجر: <strong>{$m_name}</strong></p>
                <p>بإرسال إشعار تحويل بقيمة: <strong>" . wc_price($total_comm_due) . "</strong></p>
                <p>هاتف التاجر: <strong><a href='tel:{$m_data['phone']}' style='color: #04acf4; text-decoration: none;'>{$m_data['phone']}</a></strong></p>
                <hr style='border: 0; border-top: 1px solid #cbd5e1; margin: 15px 0;'>
                <p>يرجى التأكد من وصول القيمة ثم اتخاذ إجراء:</p>
                <div class='libya-buttons-container' style='margin-top: 20px;'>
                    " . get_libya_btn_v14("تم استلام القيمة", $url_received, "green") . "
                    " . get_libya_btn_v14("لم يتم الاستلام", $url_not_received, "red") . "
                </div>
                <div id='libya-result-message'></div>
            </div>";
            wp_mail($admin_email, "تأكيد تحويل: {$m_name}", get_libya_msg_template_v14("إشعار تحويل جديد", $admin_msg, "المعتمد | 0914479920", "warning", false, true), ['Content-Type: text/html; charset=UTF-8']);
            update_option("merchant_payment_notified_{$merchant_email}", time());

            // دعم AJAX
            if (isset($_GET['ajax'])) {
                wp_send_json([
                    'success' => true,
                    'message' => 'شكراً لك، تم إرسال إشعار التحويل للمراجعة وسيتم التواصل معك قريباً',
                    'action' => 'confirm_payment'
                ]);
            }

            echo get_libya_msg_template_v14("تم الإرسال", "شكراً لك، تم إرسال إشعار التحويل للمراجعة.", "المعتمد | 0914479920", "success", true);
            exit;
        }
    }



    if (isset($_GET['admin_action'])) {
        $action = sanitize_text_field($_GET['admin_action']);
        $merchant_email = isset($_GET['m_email']) ? sanitize_email($_GET['m_email']) : '';
        $merchants = get_libya_merchants_v14();
        $m_data = $merchants[$merchant_email] ?? [];
        $m_name = $m_data['branch_name'] ?? 'تاجر';

        if ($action === 'payment_received') {
            // التحقق من توقيت آخر إجراء اتُخذ
            $last_received = (int)get_option("admin_payment_processed_{$merchant_email}", 0);
            $last_not_received = (int)get_option("admin_payment_not_received_{$merchant_email}", 0);
            $last_merchant_notify = (int)get_option("merchant_payment_notified_{$merchant_email}", 0);

            // تحديد آخر إجراء تم اتخاذه
            $last_action_time = max($last_received, $last_not_received);

            // إذا كان هناك إجراء سابق وهو أحدث من إشعار التاجر الحالي
            if ($last_action_time > 0 && $last_action_time >= $last_merchant_notify) {
                echo get_libya_msg_template_v14("تنبيه", "لقد تم اتخاذ إجراء على هذا الإشعار مسبقاً. هذا الرابط لا يعمل إلا مع الإشعارات الجديدة فقط.", "المعتمد | 0914479920", "info");
                exit;
            }

            update_option("admin_payment_processed_{$merchant_email}", time());
            delete_option("admin_payment_not_received_{$merchant_email}");
            libya_system_log_v14('تم استلام الدفعة', $merchant_email, 'تم تأكيد الاستلام من قبل المسؤول', 60);

            $recent = get_option("merchant_recent_orders_{$merchant_email}", []);
            $archive = get_option("merchant_archive_{$merchant_email}", []);
            $total_comm_due = 0;
            foreach ($recent as $oid) {
                $o = wc_get_order($oid);
                if ($o) $total_comm_due += calculate_libya_merchant_commission_v14($o->get_total(), $m_data);
            }

            $new_archive = array_unique(array_merge($archive, $recent));
            update_option("merchant_archive_{$merchant_email}", $new_archive);
            update_option("merchant_orders_count_{$merchant_email}", 0);
            update_option("merchant_total_sales_{$merchant_email}", 0);
            update_option("merchant_recent_orders_{$merchant_email}", []);

            // تحديث حالة التاجر إلى نشط عند استلام الدفعة
            $merchants[$merchant_email]['status'] = 'active';
            save_libya_merchants_v14($merchants);
            update_option("merchant_payment_completed_{$merchant_email}", time());
            delete_option("merchant_payment_notified_{$merchant_email}");
            delete_option("merchant_limit_notified_{$merchant_email}");
            delete_option("merchant_limit_notified_2nd_{$merchant_email}");

            $m_msg = "
            <div style='text-align: right; line-height: 1.6;'>
                <p>مرحباً: <strong>{$m_name}</strong></p>
                <p>تم استلام القيمة <strong>" . wc_price($total_comm_due) . "</strong> بنجاح على حسابنا.</p>
                <p>تم تصفير سجل الطلبات المكتملة، يمكنك الآن البدء باستلام طلبات جديدة.</p>
                <hr style='border: 0; border-top: 1px solid #cbd5e1; margin: 15px 0;'>
                <p style='font-size: 13px; color: #666;'><strong>تاريخ الاستلام:</strong> " . date('Y-m-d H:i') . "</p>
                <p>شكراً لك .</p>
            </div>";
            wp_mail($merchant_email, "تأكيد استلام القيمة ✅", get_libya_msg_template_v14("تم استلام القيمة", $m_msg, "المعتمد | 0914479920", "success", true), ['Content-Type: text/html; charset=UTF-8', 'From: ' . get_bloginfo('name') . ' <' . get_option('admin_email') . '>']);

            // دعم AJAX
            if (isset($_GET['ajax'])) {
                wp_send_json([
                    'success' => true,
                    'message' => 'تم تصفير حساب التاجر وإرسال رسالة التأكيد بنجاح',
                    'action' => 'payment_received'
                ]);
            }

            echo get_libya_msg_template_v14("تم التأكيد", "تم تصفير حساب التاجر وإرسال رسالة التأكيد بنجاح.", "المعتمد | 0914479920", "success", true);
            exit;
        } elseif ($action === 'payment_not_received') {
            // التحقق من توقيت آخر إجراء اتُخذ
            $last_received = (int)get_option("admin_payment_processed_{$merchant_email}", 0);
            $last_not_received = (int)get_option("admin_payment_not_received_{$merchant_email}", 0);
            $last_merchant_notify = (int)get_option("merchant_payment_notified_{$merchant_email}", 0);

            // تحديد آخر إجراء تم اتخاذه
            $last_action_time = max($last_received, $last_not_received);

            // إذا كان هناك إجراء سابق وهو أحدث من إشعار التاجر الحالي
            if ($last_action_time > 0 && $last_action_time >= $last_merchant_notify) {
                echo get_libya_msg_template_v14("تنبيه", "لقد تم اتخاذ إجراء على هذا الإشعار مسبقاً. هذا الرابط لا يعمل إلا مع الإشعارات الجديدة فقط.", "المعتمد | 0914479920", "info");
                exit;
            }

            // التأكد من الحصول على أحدث بيانات التاجر
            $merchants = get_libya_merchants_v14();
            if (!isset($merchants[$merchant_email])) {
                wp_die('التاجر غير موجود.');
            }
            $m_data = $merchants[$merchant_email];
            $m_name = $m_data['branch_name'] ?? 'تاجر';

            update_option("admin_payment_not_received_{$merchant_email}", time());
            delete_option("admin_payment_processed_{$merchant_email}");
            delete_option("merchant_payment_notified_{$merchant_email}");

            // حساب القيمة المستحقة بدقة
            $recent = get_option("merchant_recent_orders_{$merchant_email}", []);
            if (!is_array($recent)) $recent = [];
            $recent = array_filter(array_map('intval', $recent));
            $total_comm_due = 0.0;

            // التأكد من وجود بيانات عمولة (شرائح أو نسبة/ثابتة قديمة)
            if (empty($m_data)) {
                $m_data = [];
            }
            if (empty($m_data['commission_rate_tiers']) && !isset($m_data['commission_rate'])) {
                $m_data['commission_rate'] = !empty($m_data['commission_rate']) ? (float)$m_data['commission_rate'] : DEFAULT_COMMISSION_RATE_V14;
                $m_data['commission_threshold'] = !empty($m_data['commission_threshold']) ? (float)$m_data['commission_threshold'] : 0;
            }
            if (empty($m_data['fixed_commission_tiers']) && !isset($m_data['fixed_commission'])) {
                $m_data['fixed_commission'] = !empty($m_data['fixed_commission']) ? (float)$m_data['fixed_commission'] : 0;
                $m_data['fixed_threshold'] = !empty($m_data['fixed_threshold']) ? (float)$m_data['fixed_threshold'] : 0;
            }

            foreach ($recent as $oid) {
                if ($oid <= 0) continue;
                $o = wc_get_order($oid);
                if ($o && $o->get_id() > 0) {
                    $order_total = (float)$o->get_total();
                    if ($order_total >= 0) {
                        $commission = (float)calculate_libya_merchant_commission_v14($order_total, $m_data);
                        $total_comm_due += $commission;
                    }
                }
            }

            $secret = MERCHANT_ACTION_SECRET_KEY_V14;
            $base_url = home_url('/');
            $url_pay_page = wp_nonce_url(
                add_query_arg([
                    'libya_action' => 'bank_transfer_page',
                    'm_email' => $merchant_email,
                    'secret' => $secret
                ], $base_url),
                'libya_pay_page_' . $merchant_email,
                'libya_nonce'
            );

            // التأكد من أن القيمة محسوبة بدقة وتُعرض بشكل صحيح
            $total_comm_due = round((float)$total_comm_due, 2);
            $formatted_amount = wc_price($total_comm_due);

            $m_msg = "
            <div style='text-align: right; line-height: 1.6;'>
                <p>مرحباً: <strong>{$m_name}</strong></p>
                <p>نود إفادتكم بأننا لم نستلم القيمة بعد.</p>
                <p>القيمة المستحقة: <strong>" . wc_price($total_comm_due) . "</strong></p>
                <hr style='border: 0; border-top: 1px solid #cbd5e1; margin: 15px 0;'>
                <div style='margin-top: 20px; text-align: center;'>
                    <p style='font-size: 13px; color: #4a5568; margin-bottom: 10px; line-height: 1.4;'>• يرجى تحويل القيمة إلى احد حساباتنا المصرفية عبر الضغط على هذا الزر</p>
                    <div style='display: inline-block; width: 100%; max-width: 300px;'>
                        " . get_libya_btn_v14("تحويل القيمة", $url_pay_page, "green") . "
                    </div>
                </div>
            </div>";

            wp_mail($merchant_email, "تنبيه: لم يتم استلام الدفعة", get_libya_msg_template_v14("تنبيه الاستلام", $m_msg, "المعتمد | 0914479920", "danger"), ['Content-Type: text/html; charset=UTF-8', 'From: ' . get_bloginfo('name') . ' <' . get_option('admin_email') . '>']);

            // ✅ Email Retry - إعادة المحاولة عند الفشل
            $email_sent = wp_mail($merchant_email, "تنبيه: لم يتم استلام الدفعة", get_libya_msg_template_v14("تنبيه الاستلام", $m_msg, "المعتمد | 0914479920", "danger"), ['Content-Type: text/html; charset=UTF-8', 'From: ' . get_bloginfo('name') . ' <' . get_option('admin_email') . '>']);

            if (!$email_sent) {
                error_log('فشل إرسال إيميل payment_not_received إلى: ' . $merchant_email);
                // يمكن إضافة retry logic هنا أو حفظ في قائمة انتظار
            }

            // دعم AJAX
            if (isset($_GET['ajax'])) {
                wp_send_json([
                    'success' => true,
                    'message' => 'تم إرسال التنبيه للتاجر بنجاح. القيمة المستحقة: ' . wc_price($total_comm_due),
                    'action' => 'payment_not_received'
                ]);
            }

            echo get_libya_msg_template_v14("تم الإرسال", "تم إرسال التنبيه للتاجر بنجاح. القيمة المستحقة: " . wc_price($total_comm_due), "المعتمد | 0914479920", "success", true);
            exit;
        }
    }
}
