<?php
if (!defined('ABSPATH')) {
    return;
}

add_action('wp', 'libya_merchant_ensure_cron_active_v14');
function libya_merchant_ensure_cron_active_v14()
{
    if (! wp_next_scheduled('libya_merchant_background_check')) {
        wp_schedule_event(time(), 'every_five_minutes', 'libya_merchant_background_check');
    }
}
// إعادة ضبط الجدولة – يُسجّل من اللودر الرئيسي (libya-super-system.php)
function libya_merchant_reset_cron_v14()
{
    wp_clear_scheduled_hook('libya_merchant_background_check');
    if (! wp_next_scheduled('libya_merchant_background_check')) {
        wp_schedule_event(time(), 'every_five_minutes', 'libya_merchant_background_check');
    }
}
add_action('libya_merchant_background_check', 'run_libya_merchant_auto_check_v14');

// إضافة توقيت مخصص كل 5 دقائق
add_filter('cron_schedules', 'libya_merchant_add_cron_intervals');
function libya_merchant_add_cron_intervals($schedules)
{
    if (!isset($schedules['every_five_minutes'])) {
        $schedules['every_five_minutes'] = array(
            'interval' => 300,
            'display'  => 'كل 5 دقائق'
        );
    }
    return $schedules;
}

/**
 * جلب meta لعدة طلبات دفعة واحدة (تجميع استعلامات قاعدة البيانات)
 * @param int[] $post_ids مصفوفة معرفات الطلبات
 * @param string[] $meta_keys مصفوفة مفاتيح الـ meta المطلوبة
 * @return array [post_id => [meta_key => value]] القيم غير الموجودة تُرجع ''
 */
function libya_batch_get_order_meta_v14($post_ids, $meta_keys = null)
{
    global $wpdb;
    if (empty($post_ids)) return [];
    $ids = array_map('intval', $post_ids);
    $ids = array_unique(array_filter($ids));
    if (empty($ids)) return [];

    $keys = $meta_keys ?: [LIBYA_META_CLAIMED_BY, LIBYA_META_CLAIM_TIME, LIBYA_META_ATTENDANCE_CONFIRMED, LIBYA_META_ATTENDANCE_TIME, LIBYA_META_TRANSFERRED_MERCHANTS];
    $placeholders_ids = implode(',', array_fill(0, count($ids), '%d'));
    $placeholders_keys = implode(',', array_fill(0, count($keys), '%s'));
    $params = array_merge($ids, $keys);
    $query = $wpdb->prepare(
        "SELECT post_id, meta_key, meta_value FROM {$wpdb->postmeta} WHERE post_id IN ({$placeholders_ids}) AND meta_key IN ({$placeholders_keys})",
        $params
    );
    $rows = $wpdb->get_results($query);
    $result = [];
    foreach ($ids as $id) $result[$id] = array_fill_keys($keys, '');
    foreach ($rows as $row) {
        $val = $row->meta_value;
        if ($row->meta_key === LIBYA_META_TRANSFERRED_MERCHANTS && $val !== '') {
            $val = maybe_unserialize($val);
            if (!is_array($val)) $val = [];
        }
        $result[(int)$row->post_id][$row->meta_key] = $val;
    }
    return $result;
}


function run_libya_merchant_auto_check_v14()
{
    if (function_exists('set_time_limit')) {
        @set_time_limit(300);
    }
    try {
        // التحقق من صحة البيئة
        if (!function_exists('wc_get_orders')) {
            libya_system_log_v14('ERROR_CRON', '', 'WooCommerce غير متوفر');
            return;
        }

        // تسجيل وقت التشغيل للتنقيح
        update_option('libya_cron_last_run', time());

        // 🔍 كود تشخيصي مؤقت - يمكن حذفه لاحقاً
        $debug_log = [];
        $debug_log[] = '=== بدء تشغيل Cron: ' . date('Y-m-d H:i:s') . ' ===';

        // إرسال تنبيه تجريبي للمسؤول كل 24 ساعة للتأكد أن الكرون يعمل
        $last_test = (int)get_option('libya_cron_test_sent', 0);
        if (time() - $last_test > 86400) {
            $admin_email = get_option('admin_email');
            // wp_mail($admin_email, 'نظام المعتمد: تأكيد عمل الجدولة الزمنية', 'هذه رسالة آلية لتأكيد أن نظام المهام المجدولة (Cron) يعمل بنجاح.');
            update_option('libya_cron_test_sent', time());
        }

        // معالجة قائمة الانتظار: إرسال الإيميلات المؤجلة مع rate limiting
        $pending_orders = get_option('libya_pending_notifications', []);
        if (!empty($pending_orders)) {
            $processed = 0;
            $max_per_run = 20; // حد أقصى 20 طلب في كل تشغيل
            foreach ($pending_orders as $key => $order_id) {
                if ($processed >= $max_per_run) break;
                try {
                    notify_merchant_on_new_order_v14($order_id);
                    unset($pending_orders[$key]);
                    $processed++;
                } catch (Exception $e) {
                    libya_system_log_v14('ERROR_NOTIFICATION', '', "فشل إرسال إشعار للطلب #{$order_id}: " . $e->getMessage());
                    // الاستمرار في معالجة الطلبات الأخرى
                    continue;
                }
            }
            update_option('libya_pending_notifications', array_values($pending_orders));
        }
    } catch (Exception $e) {
        // تسجيل الخطأ الحرج
        libya_system_log_v14('ERROR_CRON_CRITICAL', '', 'خطأ حرج في Cron: ' . $e->getMessage() . ' | الملف: ' . $e->getFile() . ' | السطر: ' . $e->getLine());
        error_log('Libya System Critical Cron Error: ' . $e->getMessage());
        return;
    }

    // === منطق إعادة التوزيع التلقائي (Auto-Reassignment) ===

    // 🔍 تشخيص موسع: فحص جميع الطلبات قيد المعالجة
    $all_processing = wc_get_orders(['status' => 'processing', 'limit' => 20]);
    $debug_log[] = 'إجمالي طلبات processing: ' . count($all_processing);

    // ✅ تجميع استدعاءات get_post_meta: جلب كل meta للطلبات دفعة واحدة
    $all_order_ids = array_map(function ($o) {
        return $o->get_id();
    }, $all_processing);
    $meta_cache = libya_batch_get_order_meta_v14($all_order_ids);

    foreach ($all_processing as $ord) {
        $oid_tmp = $ord->get_id();
        $m = $meta_cache[$oid_tmp] ?? [];
        $claimed = $m[LIBYA_META_CLAIMED_BY] ?? '';
        $claim_t = $m[LIBYA_META_CLAIM_TIME] ?? '';
        $debug_log[] = "  طلب #{$oid_tmp}: claimed=" . ($claimed ? $claimed : 'لا') . ", claim_time=" . ($claim_t ? date('H:i:s', $claim_t) : 'لا');
    }

    // استخدام الطلبات التي تم جلبها بالفعل بدلاً من meta_query
    $orders_to_check = [];
    foreach ($all_processing as $ord) {
        $oid = $ord->get_id();
        $m = $meta_cache[$oid] ?? [];
        $claimed_by = $m[LIBYA_META_CLAIMED_BY] ?? '';
        $claim_time = $m[LIBYA_META_CLAIM_TIME] ?? '';

        // فقط الطلبات المحجوزة ولها وقت استيلاء
        if ($claimed_by && $claim_time > 0) {
            $orders_to_check[] = $ord;
        }
    }

    // 🔍 تشخيص: عدد الطلبات المستهدفة
    $debug_log[] = 'عدد الطلبات قيد الفحص: ' . count($orders_to_check);

    // ✅ Database Optimization - تحميل بيانات التجار مرة واحدة
    $merchants = get_libya_merchants_v14();

    foreach ($orders_to_check as $order) {
        $oid = $order->get_id();
        $m = $meta_cache[$oid] ?? [];
        $claimed_by = $m[LIBYA_META_CLAIMED_BY] ?? '';
        $claim_time = (int)($m[LIBYA_META_CLAIM_TIME] ?? 0);

        // 🔍 تشخيص: معلومات الطلب
        $debug_log[] = "طلب #{$oid}: claimed_by={$claimed_by}, claim_time=" . date('H:i:s', $claim_time);

        if ($claimed_by && $claim_time > 0) {
            $is_confirmed = ($m[LIBYA_META_ATTENDANCE_CONFIRMED] ?? '') === 'yes';
            $attendance_time = (int)($m[LIBYA_META_ATTENDANCE_TIME] ?? 0);

            // 🔍 تشخيص: حالة التأكيد
            $debug_log[] = "  - is_confirmed={$is_confirmed}, attendance_time=" . ($attendance_time ? date('H:i:s', $attendance_time) : 'لا يوجد');

            if ($is_confirmed && $attendance_time > 0) {
                $extra_minutes = (int)get_option('libya_def_extra_time', 30);
                $expiry_time = $attendance_time + ($extra_minutes * 60);
                $time_left = $expiry_time - time();

                // 🔍 تشخيص: المهلة الثانية
                $debug_log[] = "  - المهلة الثانية: متبقي {$time_left} ثانية";

                if (time() > $expiry_time) {
                    $debug_log[] = "  ✅ تطبيق منطق المهلة الثانية (تم التسليم تلقائياً)";
                    // إضافة ملاحظة في سجل الطلب
                    $city = $order->get_shipping_city() ?: $order->get_billing_city();
                    $order->add_order_note("المعتمد - رقم الطلب: {$oid} - المدينة: {$city}");

                    // احتساب الطلب على التاجر (نفس منطق زر "تم التسليم")
                    $order_count = (int)get_option("merchant_orders_count_{$claimed_by}", 0) + 1;
                    $total_sales = (float)get_option("merchant_total_sales_{$claimed_by}", 0) + $order->get_total();
                    $recent_orders = get_option("merchant_recent_orders_{$claimed_by}", []);
                    if (!in_array($oid, $recent_orders)) $recent_orders[] = $oid;

                    update_option("merchant_orders_count_{$claimed_by}", $order_count);
                    update_option("merchant_total_sales_{$claimed_by}", $total_sales);
                    update_option("merchant_recent_orders_{$claimed_by}", $recent_orders);
                    update_option("merchant_last_action_time_{$oid}", time());

                    // تحديث وقت النشاط الأخير للتاجر
                    $merchants = get_libya_merchants_v14();
                    if (isset($merchants[$claimed_by])) {
                        $merchants[$claimed_by]['last_activity'] = time();
                        save_libya_merchants_v14($merchants);
                    }

                    // تحديث حالة الطلب (بدون إرسال إيميل للعميل)
                    add_filter('woocommerce_email_enabled_customer_completed_order', '__return_false');
                    add_filter('woocommerce_email_enabled_customer_processing_order', '__return_false');
                    $order->update_status('completed', 'تم تسليم الطلب (تلقائياً - انتهاء المهلة الإضافية).');
                    remove_filter('woocommerce_email_enabled_customer_completed_order', '__return_false');
                    remove_filter('woocommerce_email_enabled_customer_processing_order', '__return_false');

                    // حذف بيانات الاستيلاء
                    delete_post_meta($oid, LIBYA_META_CLAIMED_BY);
                    delete_post_meta($oid, LIBYA_META_CLAIM_TIME);
                    delete_post_meta($oid, LIBYA_META_ATTENDANCE_CONFIRMED);
                    delete_post_meta($oid, LIBYA_META_ATTENDANCE_TIME);

                    // تسجيل في قاعدة البيانات
                    libya_system_log_v14('تم التسليم (تلقائي)', $claimed_by, 'رقم الطلب: ' . $oid . ' - وحسبت تم التسليم', 120, 'حُسب تسليم لانتهاء الوقت');

                    // --- تتبع إحصائيات التسليم التلقائي ---
                    $auto_deliv_count = (int)get_option(LIBYA_PERF_AUTO_DELIVERIES . $claimed_by, 0) + 1;
                    update_option(LIBYA_PERF_AUTO_DELIVERIES . $claimed_by, $auto_deliv_count);

                    // إرسال إشعار للمسؤول (نفس منطق زر "تم التسليم")
                    $admin_email = function_exists('libya_orders_email_v14') ? libya_orders_email_v14() : 'orders@almuetamad.com';
                    $m_name = $merchants[$claimed_by]['branch_name'] ?? 'تاجر';
                    $m_city = $merchants[$claimed_by]['city'] ?? $order->get_billing_city();
                    $admin_msg = "<div style='text-align: center; line-height: 1.8;'>
                        <p>المتجر: <strong>{$m_name}</strong></p>
                        <p>المدينة: <strong>{$m_city}</strong></p>
                        <p>رقم الطلب: <strong>{$oid}</strong></p>
                        <p>الحالة: <strong>تم تسليم الطلب (تلقائياً - انتهاء الوقت الإضافي)</strong></p>
                        <p>التاريخ: <strong>" . date('Y-m-d H:i') . "</strong></p>
                    </div>";
                    wp_mail($admin_email, "تم التسليم {$oid} - {$m_name}", get_libya_msg_template_v14("إشعار تسليم", $admin_msg, "المعتمد | 0914479920", "success", false, true), ['Content-Type: text/html; charset=UTF-8']);

                    // إرسال إشعار للتاجر
                    $penalty_msg = "<div style='text-align: right;'>تم احتساب الطلب رقم <strong>#{$oid}</strong> تلقائياً<br>تم التسليم ، لانتهاء المهلة الإضافية<br>دون تحديث الحالة.</div>";
                    wp_mail($claimed_by, "تنبيه: احتساب طلب #{$oid}", get_libya_msg_template_v14("انتهاء الوقت الإضافي", $penalty_msg, "المعتمد | 0914479920", "danger"), ['Content-Type: text/html; charset=UTF-8']);

                    // فحص إذا وصل التاجر للحد بعد هذا التسليم (نفس منطق زر "تم التسليم")
                    $current_count = (int)get_option("merchant_orders_count_{$claimed_by}", 0);
                    $m_data = $merchants[$claimed_by] ?? [];
                    $order_limit = isset($m_data['order_limit']) ? (int)$m_data['order_limit'] : DEFAULT_ORDER_LIMIT_V14;
                    $last_notify = (int)get_option("merchant_limit_notified_{$claimed_by}");
                    $last_payment = (int)get_option("merchant_payment_completed_{$claimed_by}", 0);

                    if ($current_count >= $order_limit && (!$last_notify || $last_notify < $last_payment)) {
                        $total_comm_due = 0;
                        foreach ($recent_orders as $oid_tmp) {
                            $o_tmp = wc_get_order($oid_tmp);
                            if ($o_tmp) $total_comm_due += calculate_libya_merchant_commission_v14($o_tmp->get_total(), $m_data);
                        }

                        $secret = MERCHANT_ACTION_SECRET_KEY_V14;
                        $base_url = home_url('/');
                        $old_uid = get_current_user_id();
                        wp_set_current_user(0);
                        $url_pay_page = wp_nonce_url(add_query_arg(['libya_action' => 'bank_transfer_page', 'm_email' => $claimed_by, 'secret' => $secret], $base_url), 'libya_pay_page_' . $claimed_by, 'libya_nonce');
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

                        wp_mail($claimed_by, "تم بلوغ الحد الأقصى للطلبات 🔵", get_libya_msg_template_v14("تنبيه حد الطلبيات", $m_msg, "المعتمد | 0914479920", "warning"), ['Content-Type: text/html; charset=UTF-8']);

                        $admin_limit_msg = "<div style='text-align: center; line-height: 1.8;'>
                            <p>المتجر: <strong>{$m_name}</strong></p>
                            <p>الحالة: <strong>وصل إلى حد الطلبات</strong></p>
                            <p>عدد الطلبات: <strong>{$current_count}</strong></p>
                            <p>القيمة المستحقة: <strong>" . wc_price($total_comm_due) . "</strong></p>
                            <p>التاريخ: <strong>" . date('Y-m-d H:i') . "</strong></p>
                        </div>";
                        wp_mail(function_exists('libya_orders_email_v14') ? libya_orders_email_v14() : 'orders@almuetamad.com', "تنبيه حد الطلبات: {$m_name}", get_libya_msg_template_v14("وصول حد الطلبيات", $admin_limit_msg, "المعتمد | 0914479920", "warning"), ['Content-Type: text/html; charset=UTF-8']);

                        update_option("merchant_limit_notified_{$claimed_by}", time());
                        delete_option("merchant_payment_completed_{$claimed_by}");
                    }

                    // إرسال إشعارات للتجار الآخرين (نفس منطق زر "تم التسليم")
                    notify_merchant_on_new_order_v14(-1, $m_city);

                    continue;
                }
            } else {
                $deadline_minutes = (int)get_option('libya_def_deadline', 60);
                $expiry_time = $claim_time + ($deadline_minutes * 60);
                $time_left = $expiry_time - time();

                // 🔍 تشخيص: المهلة الأولى
                $debug_log[] = "  - المهلة الأولى: متبقي {$time_left} ثانية";

                if (time() > $expiry_time) {
                    $debug_log[] = "  ✅ تطبيق منطق المهلة الأولى (تحويل تلقائي)";
                    // إضافة ملاحظة في سجل الطلب
                    $city = $order->get_shipping_city() ?: $order->get_billing_city();
                    $order->add_order_note("المعتمد - رقم الطلب: {$oid} - المدينة: {$city}");
                    libya_system_log_v14('تحويل تلقائي', $claimed_by, "رقم الطلب: {$oid} - المدينة: {$city}", 120, 'تحويل تلقائي بانتهاء الوقت');

                    // --- تتبع إحصائيات التحويل التلقائي ---
                    $auto_trans_count = (int)get_option(LIBYA_PERF_AUTO_TRANSFERS . $claimed_by, 0) + 1;
                    update_option(LIBYA_PERF_AUTO_TRANSFERS . $claimed_by, $auto_trans_count);

                    // حذف بيانات الاستيلاء
                    delete_post_meta($oid, LIBYA_META_CLAIMED_BY);
                    delete_post_meta($oid, LIBYA_META_CLAIM_TIME);

                    // إضافة التاجر لقائمة المحولين
                    $transferred = $meta_cache[$oid][LIBYA_META_TRANSFERRED_MERCHANTS] ?? [];
                    if (!is_array($transferred)) $transferred = [];
                    if (!in_array($claimed_by, $transferred)) {
                        $transferred[] = $claimed_by;
                        update_post_meta($oid, LIBYA_META_TRANSFERRED_MERCHANTS, $transferred);
                    }

                    // إرسال إشعار للمسؤول
                    $admin_email = function_exists('libya_orders_email_v14') ? libya_orders_email_v14() : 'orders@almuetamad.com';
                    $m_name = $merchants[$claimed_by]['branch_name'] ?? 'تاجر';
                    $m_city = $merchants[$claimed_by]['city'] ?? $order->get_billing_city();
                    $admin_msg = "<div style='text-align: center; line-height: 1.8;'>
                        <p>التاجر: <strong>{$m_name}</strong></p>
                        <p>المدينة: <strong>{$m_city}</strong></p>
                        <p>رقم الطلب: <strong>{$oid}</strong></p>
                        <p>الإجراء: <strong>تحويل الطلب لتاجر آخر (تلقائي - انتهاء المهلة)</strong></p>
                        <p>التاريخ: <strong>" . date('Y-m-d H:i') . "</strong></p>
                    </div>";
                    wp_mail($admin_email, "تحويل طلب {$oid} - {$m_name}", get_libya_msg_template_v14("إشعار تحويل طلب", $admin_msg, "المعتمد | 0914479920", "warning", false, true), ['Content-Type: text/html; charset=UTF-8']);

                    // إرسال إشعار للتاجر
                    $expiry_msg = "<div style='text-align: right;'>نعتذر منك، لقد انتهت المهلة المحددة لك لتسليم الطلب رقم <strong>#{$oid}</strong>، ولذلك تم تحويل الطلب لتاجر آخر لضمان سرعة الخدمة.</div>";
                    wp_mail($claimed_by, "تنبيه: تحويل الطلب #{$oid}", get_libya_msg_template_v14("انتهت المهلة", $expiry_msg, "المعتمد | 0914479920", "warning"), ['Content-Type: text/html; charset=UTF-8']);

                    // تحويل الطلب لتاجر آخر
                    notify_merchant_on_new_order_v14($oid, '', true);
                }
            }
        }
    }

    $merchants = get_libya_merchants_v14();
    $cities = [];
    foreach ($merchants as $m) {
        if (!in_array($m['city'], $cities)) $cities[] = $m['city'];
    }
    foreach ($cities as $city) {
        notify_merchant_on_new_order_v14(-1, $city);
    }

    // 🔍 حفظ سجل التشخيص (معطّل لتجنب تضخم قاعدة البيانات)
    // if (isset($debug_log)) {
    //     $debug_log[] = '=== انتهاء تشغيل Cron ===';
    //     update_option('libya_cron_debug_log', implode("\n", $debug_log));
    // }
}
