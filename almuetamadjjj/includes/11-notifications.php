<?php
if (!defined('ABSPATH')) {
    return;
}


// ========================================================================
//  5. نظام التنبيهات والبريد الإلكتروني
// ========================================================================
add_action('woocommerce_checkout_order_processed', 'schedule_libya_notification_v14', 10, 1);
add_action('woocommerce_rest_insert_shop_order_object', 'schedule_libya_notification_v14', 10, 1);

function schedule_libya_notification_v14($order_id)
{
    // حفظ الطلب في قائمة الانتظار بدلاً من الإرسال المباشر لتجنب مشاكل shutdown hook
    $pending_orders = get_option('libya_pending_notifications', []);
    if (!in_array($order_id, $pending_orders)) {
        $pending_orders[] = $order_id;
        update_option('libya_pending_notifications', $pending_orders);
    }
}

function notify_merchant_on_new_order_v14($order_id, $city_override = '', $is_transfer = false)
{
    try {
        if (is_object($order_id)) $order_id = $order_id->get_id();
        if ($order_id > 0 && !$is_transfer) {
            if (get_transient("libya_order_notified_{$order_id}")) return;
            set_transient("libya_order_notified_{$order_id}", true, 60);
        }
        if ($order_id > 0) {
            $order = wc_get_order($order_id);
            if (!$order) {
                libya_system_log_v14('ERROR_NOTIFICATION', '', "الطلب غير موجود: #{$order_id}");
                return;
            }
            $city = $order->get_billing_city();
        } else {
            $city = $city_override;
        }

        if (empty($city)) {
            libya_system_log_v14('ERROR_NOTIFICATION', '', "المدينة غير محددة للطلب: #{$order_id}");
            return;
        }

        $merchants = get_libya_merchants_v14();
        $city_merchants = [];
        $normalized_input_city = normalize_libya_city_v14($city);
        foreach ($merchants as $email => $m) {
            $normalized_merchant_city = normalize_libya_city_v14($m['city']);
            if ($normalized_merchant_city === $normalized_input_city) {
                if (($m['status'] ?? 'active') === 'active') {
                    $city_merchants[$email] = $m;
                }
            }
        }

        if (empty($city_merchants)) {
            libya_system_log_v14('ERROR_NOTIFICATION', '', "لا يوجد تجار نشطون في المدينة: {$city}");
            return;
        }
    } catch (Exception $e) {
        libya_system_log_v14('ERROR_NOTIFICATION_CRITICAL', '', 'خطأ حرج في إرسال الإشعارات: ' . $e->getMessage() . ' | الملف: ' . $e->getFile() . ' | السطر: ' . $e->getLine());
        error_log('Libya System Notification Error: ' . $e->getMessage());
        return;
    }

    // سيناريو 1 — المرة الأولى: الطلب الجديد يُرسل لكل التجار بالمدينة حتى يستولي عليه أحدهم.
    // سيناريو 2 — بعد التحويل (غير متوفر أو حوّله التاجر): يُرسل للتجار بالتاجر فقط (واحد فواحد)، لا للكل.
    $transferred_merchants = ($order_id > 0) ? get_post_meta($order_id, LIBYA_META_TRANSFERRED_MERCHANTS, true) : [];
    if (!is_array($transferred_merchants)) $transferred_merchants = [];

    $available_merchants = [];
    foreach ($city_merchants as $email => $m) {
        if (!in_array($email, $transferred_merchants)) {
            $available_merchants[$email] = $m;
        }
    }

    if (empty($available_merchants) && $is_transfer) {
        // لا يوجد تاجر متاح — الطلب مر على الجميع وكلهم حوّلوه → يرجع للمسؤول
        try {
            libya_system_log_v14('الطلب غير متوفر', 'system@almuetamad.com', "رقم الطلب: {$order_id} | المدينة: {$city} | الحالة: تحويل نهائي", 120);
        } catch (Exception $e) {
            error_log('Libya System: Error logging unavailable order: ' . $e->getMessage());
        }

        $admin_email = function_exists('libya_orders_email_v14') ? libya_orders_email_v14() : 'orders@almuetamad.com';
        $msg = "المنتج غير متوفر بالمدينة \"{$city}\" للطلب رقم {$order_id}. تم تحويل الطلب من قبل جميع التجار المتاحين.";
        wp_mail($admin_email, "المنتج غير متوفر في {$city}", get_libya_msg_template_v14("تنبيه للمسؤول", $msg, "المعتمد | 0914479920", "danger", false, true), ['Content-Type: text/html; charset=UTF-8', 'From: ' . get_bloginfo('name') . ' <' . get_option('admin_email') . '>']);

        // إشعار للعميل: غير متوفر حاليًا
        if ($order_id > 0) {
            $order = wc_get_order($order_id);
            if ($order) {
                $cust_targets = array();
                $cid = $order->get_customer_id();
                if ($cid) $cust_targets[] = (string) $cid;
                $billing_email = $order->get_billing_email();
                if ($billing_email) $cust_targets[] = $billing_email;
                if (!empty($cust_targets) && function_exists('almuetamad_send_onesignal_v7')) {
                    almuetamad_send_onesignal_v7($cust_targets, 'غير متوفر حاليًا', 'نعتذر منك الطلب رقم ' . $order_id . ' غير متوفر حاليًا', '', array('order_id' => $order_id));
                }
            }
        }
        return;
    }

    // سيناريو 2 فقط: عند التحويل (يدوي أو تلقائي) إرسال الطلب لتاجر واحد — التالي في الترتيب — وليس للكل
    if ($is_transfer && !empty($available_merchants)) {
        $ordered_emails = array_keys($city_merchants);
        sort($ordered_emails);
        $next_email = null;
        foreach ($ordered_emails as $e) {
            if (!in_array($e, $transferred_merchants)) {
                $next_email = $e;
                break;
            }
        }
        if ($next_email !== null) {
            $available_merchants = [$next_email => $city_merchants[$next_email]];
            // منع فتح الطلب من تجار آخرين: فقط التاجر المُشعَر (المحول إليه) يمكنه قبول الطلب
            if ($order_id > 0) {
                update_post_meta($order_id, LIBYA_META_NEXT_CLAIM_ALLOWED, $next_email);
                // إعادة تعيين حد المعدل للتاجر المحول إليه حتى يتمكن من قبول الطلب دون "تجاوز الحد"
                delete_transient("libya_rate_limit_{$next_email}_{$order_id}");
            }
        }
    }

    // عند وصول الطلب للتاجر (أول مرة): إشعار للعميل "تم الاستلام" في نفس الوقت مع رابط التتبع
    if ($order_id > 0 && !$is_transfer && !empty($available_merchants)) {
        $already_received = get_post_meta($order_id, LIBYA_META_NOTIFIED_RECEIVED, true) === 'yes';
        if (!$already_received) {
            $order = wc_get_order($order_id);
            if ($order) {
                $cust_targets = array();
                $cid = $order->get_customer_id();
                if ($cid) $cust_targets[] = (string) $cid;
                $billing_email = $order->get_billing_email();
                if ($billing_email) $cust_targets[] = $billing_email;
                if (!empty($cust_targets) && function_exists('almuetamad_send_onesignal_v7')) {
                    almuetamad_send_onesignal_v7($cust_targets, 'تم الاستلام', 'مرحبًا تم استلام طلبك بنجاح ✅ رقم الطلب ' . $order_id, '', array('order_id' => $order_id));
                    update_post_meta($order_id, LIBYA_META_NOTIFIED_RECEIVED, 'yes');
                }
            }
        }
    }

    foreach ($available_merchants as $email => $m) {
        $order_count = (int)get_option("merchant_orders_count_{$email}", 0);

        // سد ثغرة التهرب: احتساب الطلبات المعلقة (Processing) التي مر عليها أكثر من 48 ساعة
        $recent_orders = get_option("merchant_recent_orders_{$email}", []);
        $pending_count = 0;
        foreach ($recent_orders as $oid) {
            $last_act = (int)get_option("merchant_last_action_time_{$oid}", 0);
            if ($last_act > 0 && (time() - $last_act) > (48 * 3600)) {
                $pending_count++;
            }
        }
        $effective_count = $order_count + $pending_count;

        $limit = !empty($m['order_limit']) ? (int)$m['order_limit'] : DEFAULT_ORDER_LIMIT_V14;

        if ($effective_count >= $limit) {
            // منع إرسال إيميل الطلب الجديد للتاجر المجمد
            $last_notify = (int)get_option("merchant_limit_notified_{$email}");
            $now = time();

            $recent_orders = get_option("merchant_recent_orders_{$email}", []);
            $total_sales = (float)get_option("merchant_total_sales_{$email}", 0);
            $total_comm_due = 0;
            foreach ($recent_orders as $oid) {
                $o_tmp = wc_get_order($oid);
                if ($o_tmp) $total_comm_due += calculate_libya_merchant_commission_v14($o_tmp->get_total(), $m);
            }

            $secret = MERCHANT_ACTION_SECRET_KEY_V14;
            $base_url = home_url('/');
            $old_uid = get_current_user_id();
            wp_set_current_user(0);
            $url_pay_page = wp_nonce_url(
                add_query_arg([
                    'libya_action' => 'bank_transfer_page',
                    'm_email' => $email,
                    'secret' => $secret
                ], $base_url),
                'libya_pay_page_' . $email,
                'libya_nonce'
            );
            wp_set_current_user($old_uid);

            // التنبيه عند وصول الحد (مرة واحدة فقط)
            if (!$last_notify) {
                $m_msg = "
                <div style='text-align: right; line-height: 1.6;'>
                    <p>مرحباً عزيزي: <strong>{$m['branch_name']}</strong></p>
                    <p>نود إعلامك بأنك بلغت الحد الأقصى للطلبات لاستئناف الخدمة، نرجو إتمام التحويل المصرفي للمبلغ المحدد في الفاتورة إلى الحساب المرفق.</p>
                    <hr style='border: 0; border-top: 1px solid #cbd5e1; margin: 15px 0;'>
                    <p><strong>إحصائيات السجل الحالي:</strong></p>
                    <p>• عدد الطلبات: " . count($recent_orders) . "</p>
                    <p>• إجمالي المبيعات: " . wc_price($total_sales) . "</p>
                    <p>• العمولة المستحقة: <strong>" . wc_price($total_comm_due) . "</strong></p>
                    <hr style='border: 0; border-top: 1px solid #cbd5e1; margin: 15px 0;'>
                    <p style='font-size: 13px; color: #4a5568; margin-bottom: 10px; line-height: 1.4;'>لإتمام العملية , اضغط على زر تحويل القيمة</p>
                    <div style='margin-top: 20px;'>
                        " . get_libya_btn_v14("تحويل القيمة", $url_pay_page, "green") . "
                    </div>
                </div>";

                wp_mail($email, "تم بلوغ الحد الأقصى للطلبات 🔵", get_libya_msg_template_v14("تنبيه حد الطلبيات", $m_msg, "المعتمد | 0914479920", "warning"), ['Content-Type: text/html; charset=UTF-8', 'From: ' . get_bloginfo('name') . ' <' . get_option('admin_email') . '>']);

                $admin_msg = "<div style='text-align: center; line-height: 1.8;'>
                    <p>المتجر: <strong>{$m['branch_name']}</strong></p>
                    <p>الحالة: <strong>وصل إلى حد الطلبات</strong></p>
                    <p>عدد الطلبات: <strong>" . count($recent_orders) . "</strong></p>
                    <p>القيمة المستحقة: <strong>" . wc_price($total_comm_due) . "</strong></p>
                    <p>التاريخ: <strong>" . date('Y-m-d H:i') . "</strong></p>
                </div>";
                wp_mail(function_exists('libya_orders_email_v14') ? libya_orders_email_v14() : 'orders@almuetamad.com', "تنبيه حد الطلبات: {$m['branch_name']}", get_libya_msg_template_v14("وصول حد الطلبيات", $admin_msg, "المعتمد | 0914479920", "warning", false, true), ['Content-Type: text/html; charset=UTF-8', 'From: ' . get_bloginfo('name') . ' <' . get_option('admin_email') . '>']);

                update_option("merchant_limit_notified_{$email}", $now);
                delete_option("merchant_payment_completed_{$email}");
            }
            // الاستمرار في إرسال الطلبات الجديدة حتى لو تجاوز الحد
        }

        if ($order_id > 0 && isset($order) && $order) {
            $secret = MERCHANT_ACTION_SECRET_KEY_V14;
            $base_url = home_url('/');
            // 🔧 FIX: تشفير المفتاح السري للـ URL
            $old_uid = get_current_user_id();
            wp_set_current_user(0);
            // عدم استخدام urlencode للـ secret لأن add_query_arg يشفّر القيم تلقائياً (تجنب ترميز مزدوج يفسد الرابط)
            $url_proc = wp_nonce_url(add_query_arg(['order_id' => $order_id, 'order_action' => 'confirm_processing', 'm_email' => $email, 'secret' => $secret], $base_url), 'libya_order_action_' . $order_id, 'libya_nonce');
            wp_set_current_user($old_uid);

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
                <td style='padding: 4px 0; border-top: 1px solid #cbd5e1;' colspan='2'>المجموع</td>
                <td style='padding: 4px 0; border-top: 1px solid #cbd5e1;'></td>
                <td style='padding: 4px 0; border-top: 1px solid #cbd5e1; text-align: left;'>" . strip_tags(wc_price((float)$order->get_total())) . "</td>
            </tr></table>";

            $transfer_note = $is_transfer ? "<p style='color: #1a202c; font-weight: 600; font-size: 15px; background: #fff3cd; padding: 10px 15px; border-radius: 8px; border-right: 4px solid #ffc107; margin-bottom: 15px;'>تم تحويل هذا الطلب إليك لعدم توفر المنتج لدى التاجر السابق</p>" : "";
            $content = "
            <div style='text-align: center;'>
                {$transfer_note}
                <p><strong>ملخص الطلب:</strong></p>
                {$items_text}
                <hr style='border: 0; border-top: 1px solid #cbd5e1; margin: 20px 0;'>
                <p style='font-size: 15px; color: #4a5568; margin-bottom: 10px; line-height: 1.4;'>متوفر؟ اضغط هنا</p>
                <div class='libya-buttons-container' style='margin-top: 20px;'>
                    " . get_libya_btn_v14("متوفر", $url_proc, "blue", true) . "
                </div>
                <div id='libya-result-message'></div>
                <p style='font-size: 10px; color: #666; margin-top: 10px;'>" . date('Y-m-d H:i') . "</p>
            </div>";

            $footer_order = "للمساعدة أو الاستفسار | 0914479920";
            wp_mail($email, "طلب جديد {$order_id} 🔔", get_libya_msg_template_v14("طلب جديد رقم {$order_id}", $content, $footer_order, "info"), ['Content-Type: text/html; charset=UTF-8', 'From: ' . get_bloginfo('name') . ' <' . get_option('admin_email') . '>']);

            // تسجيل "تم استلام الطلب" لكل تاجر وصل له الطلب (حتى لو 100 تاجر يظهر كل واحد في سجل العمليات)
            if ($order_id > 0 && function_exists('libya_system_log_v14')) {
                libya_system_log_v14('تم استلام الطلب', $email, "المعتمد - رقم الطلب: {$order_id} - المدينة: {$city}", 60);
            }

            // Rate limiting ذكي لتجنب حظر السيرفر من مزود البريد
            static $email_count = 0;
            $email_count++;

            // حد أقصى 20 إيميل في الدفعة الواحدة لتجنب الحمل الزائد
            if ($email_count >= 20) {
                error_log('Libya System: Email batch limit reached (20 emails). Remaining emails will be queued for next cron run.');
                break; // إيقاف الإرسال والسماح للـ cron التالي بإكمال الباقي
            }

            // تأخير تدريجي: يزداد مع عدد الإيميلات (0.2s, 0.3s, 0.4s, ...)
            $delay_microseconds = 200000 + ($email_count * 50000); // يبدأ من 0.2 ثانية ويزداد
            usleep(min($delay_microseconds, 1000000)); // حد أقصى 1 ثانية
        }
    }
}
