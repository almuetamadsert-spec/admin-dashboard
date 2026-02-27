<?php
if (!defined('ABSPATH')) {
    return;
}


// ========================================================================
//  6. لوحة تحكم المدير (إدارة التجار)
// ========================================================================
add_action('admin_menu', 'libya_merchant_admin_menu_v14');
function libya_merchant_admin_menu_v14()
{
    add_menu_page('لوحة تحكم نظام المعتمد', 'نظام المعتمد', 'manage_options', 'merchant-main-dashboard', 'render_merchant_main_dashboard_v14', 'dashicons-store', 6);
    add_submenu_page('merchant-main-dashboard', 'متابعة المتاجر', 'متابعة المتاجر', 'manage_options', 'merchant-main-dashboard', 'render_merchant_main_dashboard_v14');
    add_submenu_page('merchant-main-dashboard', 'إحصائيات الأداء', 'إحصائيات الأداء', 'manage_options', 'merchant-performance', 'render_merchant_performance_v14');
    add_submenu_page('merchant-main-dashboard', 'إدارة المتاجر', 'إدارة المتاجر', 'manage_options', 'merchant-data-manager', 'render_merchant_data_manager_v14');
    add_submenu_page('merchant-main-dashboard', 'كشف الإيرادات', 'كشف الإيرادات', 'manage_options', 'admin-earnings-report', 'render_admin_earnings_report_v14');
    add_submenu_page('merchant-main-dashboard', 'سجل العمليات', 'سجل العمليات', 'manage_options', 'system-logs', 'render_system_logs_page_v14');
    add_submenu_page('merchant-main-dashboard', 'صيانة النظام', 'صيانة النظام', 'manage_options', 'system-maintenance', 'render_system_maintenance_v14');
    add_submenu_page(null, 'بيانات المتجر', 'بيانات المتجر', 'manage_options', 'merchant-details', 'render_merchant_details_page_v14');
}

// التأكد من عنوان الأيقونة (tooltip) في القائمة الجانبية — اسم النظام وليس اسم الصفحة
add_action('admin_menu', 'libya_fix_menu_icon_title_v14', 999);
function libya_fix_menu_icon_title_v14()
{
    global $menu;
    if (!is_array($menu)) return;
    foreach ($menu as $k => $item) {
        if (isset($item[2]) && $item[2] === 'merchant-main-dashboard') {
            $menu[$k][0] = 'نظام المعتمد';  // النص بجانب الأيقونة
            $menu[$k][3] = 'نظام المعتمد';  // عنوان التلميح (tooltip)
            break;
        }
    }
}

// ========================================================================
//  6. تصدير التقارير (CSV Export)
// ========================================================================
add_action('admin_init', 'libya_handle_csv_export_v14');
function libya_handle_csv_export_v14()
{
    if (isset($_POST['export_earnings_csv']) && check_admin_referer('libya_export_csv')) {
        if (!current_user_can('manage_options')) return;

        $merchants = get_libya_merchants_v14();
        $csv_data = [];

        // تجميع البيانات بنفس المنطق
        foreach ($merchants as $email => $m) {
            $recent = get_option("merchant_recent_orders_{$email}", []);
            $archive = get_option("merchant_archive_{$email}", []);
            $combined = array_unique(array_merge($recent, $archive));

            foreach ($combined as $order_id) {
                $order = wc_get_order($order_id);
                if (!$order) continue;

                $val = (float)$order->get_total();
                $breakdown = get_libya_merchant_commission_breakdown_v14($val, $m);
                $comm = (float)$breakdown['total'];
                $percentage_part = $breakdown['percentage'];
                $fixed = $breakdown['fixed'];

                $csv_data[] = [
                    'Order ID' => $order_id,
                    'Merchant' => $m['branch_name'],
                    'City' => $m['city'],
                    'Total' => $val,
                    'Percentage Comm' => $percentage_part,
                    'Fixed Comm' => $fixed,
                    'Total Comm' => $comm,
                    'Date' => $order->get_date_created()->date('Y-m-d H:i')
                ];
            }
        }

        // ترتيب البيانات
        usort($csv_data, function ($a, $b) {
            return strtotime($b['Date']) - strtotime($a['Date']);
        });

        // إرسال الملف
        header('Content-Type: text/csv; charset=utf-8');
        header('Content-Disposition: attachment; filename=earnings_report_' . date('Y-m-d') . '.csv');
        $output = fopen('php://output', 'w');

        // BOM لضمان ظهور العربية بشكل صحيح في Excel
        fprintf($output, chr(0xEF) . chr(0xBB) . chr(0xBF));

        // العناوين
        fputcsv($output, ['رقم الطلب', 'التاجر', 'المدينة', 'الإجمالي', 'عمولة النسبة', 'عمولة ثابتة', 'إجمالي العمولة', 'التاريخ']);

        foreach ($csv_data as $row) {
            fputcsv($output, $row);
        }

        fclose($output);
        exit;
    }
}

function render_merchant_main_dashboard_v14()
{
    // معالجة تغيير حالة التاجر (تجميد/تفعيل)
    if (isset($_GET['merchant_status_action'], $_GET['m_email'], $_GET['_wpnonce'])) {
        $email = sanitize_email($_GET['m_email']);
        check_admin_referer('libya_merchant_status_' . $email);

        if (!current_user_can('manage_options')) wp_die('غير مصرح لك بذلك');

        $action = isset($_GET['merchant_status_action']) ? sanitize_text_field(wp_unslash($_GET['merchant_status_action'])) : '';
        if (!in_array($action, ['freeze', 'activate'], true)) {
            wp_die('إجراء غير صالح.');
        }
        $merchants = get_libya_merchants_v14();

        if (isset($merchants[$email])) {
            $merchants[$email]['status'] = ($action === 'freeze') ? 'frozen' : 'active';
            save_libya_merchants_v14($merchants);
            libya_system_log_v14('تغيير حالة المتجر', $email, 'الحالة الجديدة: ' . ($action === 'freeze' ? 'مجمد' : 'نشط'), 60);

            wp_redirect(admin_url('admin.php?page=merchant-main-dashboard'));
            exit;
        }
    }

    // معالجة توليد الرابط الجديد
    if (isset($_POST['regenerate_token_email']) && check_admin_referer('libya_regen_token')) {
        $email_to_regen = sanitize_email($_POST['regenerate_token_email']);
        $new_token = wp_generate_password(16, false);
        update_option('libya_merchant_access_token_' . $email_to_regen, $new_token);
        echo '<div class="updated"><p>تم توليد رابط جديد للتاجر (' . esc_html($email_to_regen) . ') بنجاح.</p></div>';
    }

    $merchants = get_libya_merchants_v14();
    $total_all_sales = 0;
    $total_all_commissions = 0;
    $total_all_fixed = 0;
    $total_stalled_orders = 0;

    foreach ($merchants as $email => $m) {
        $total_all_sales += (float)get_option("merchant_total_sales_{$email}", 0);
        $recent = get_option("merchant_recent_orders_{$email}", []);
        foreach ($recent as $oid) {
            $o = wc_get_order($oid);
            if ($o) {
                $b = get_libya_merchant_commission_breakdown_v14($o->get_total(), $m);
                $total_all_commissions += $b['total'];
                $total_all_fixed += $b['fixed'];
                $last_act = (int)get_option("merchant_last_action_time_{$oid}", 0);
                if ($last_act > 0 && (time() - $last_act) > 300 && $o->get_status() === 'processing') {
                    $total_stalled_orders++;
                }
            }
        }
    }

    $pending_list = get_option('libya_pending_notifications', []);
    $pending_emails_count = is_array($pending_list) ? count($pending_list) : 0;

    // فلترة المتاجر حسب البحث (الاسم، الإيميل، المتجر، رقم الهاتف، المدينة)
    $search = isset($_GET['s']) ? trim(sanitize_text_field(wp_unslash($_GET['s']))) : '';
    $filtered_merchants = $merchants;
    if ($search !== '') {
        $search_lower = mb_strtolower($search, 'UTF-8');
        $filtered_merchants = [];
        foreach ($merchants as $email => $m) {
            $branch = mb_strtolower($m['branch_name'] ?? '', 'UTF-8');
            $owner = mb_strtolower($m['owner_name'] ?? '', 'UTF-8');
            $phone = $m['phone'] ?? '';
            $city_val = mb_strtolower($m['city'] ?? '', 'UTF-8');
            $email_lower = mb_strtolower($email, 'UTF-8');
            if (
                mb_strpos($branch, $search_lower) !== false ||
                mb_strpos($owner, $search_lower) !== false ||
                mb_strpos($email_lower, $search_lower) !== false ||
                mb_strpos($phone, $search) !== false ||
                mb_strpos($city_val, $search_lower) !== false
            ) {
                $filtered_merchants[$email] = $m;
            }
        }
    }
?>
    <style>
        .libya-dashboard {
            direction: rtl;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 1000px;
            margin: 20px auto 40px;
            padding: 0 16px;
        }

        .libya-dashboard * {
            box-sizing: border-box;
        }

        .libya-dashboard .mgr-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            flex-wrap: wrap;
            gap: 12px;
            margin-bottom: 24px;
            padding-bottom: 20px;
            border-bottom: 2px solid #04acf4;
        }

        .libya-dashboard .mgr-title {
            margin: 0;
            font-size: 20px;
            font-weight: 700;
            color: #0284c7;
        }

        .libya-dashboard .mgr-stat-box {
            background: linear-gradient(135deg, #0284c7, #04acf4);
            color: #fff;
            padding: 14px 20px;
            border-radius: 10px;
            font-size: 14px;
            font-weight: 600;
        }

        .libya-dashboard .mgr-stat-box .val {
            font-size: 18px;
            font-weight: 800;
            margin-right: 8px;
        }

        .libya-dashboard .mgr-search {
            margin-bottom: 16px;
            display: flex;
            gap: 8px;
            align-items: center;
            flex-wrap: wrap;
        }

        .libya-dashboard .mgr-search input[type="search"] {
            padding: 8px 12px;
            border: 1px solid #cbd5e1;
            border-radius: 8px;
            font-size: 13px;
            width: 280px;
            max-width: 100%;
        }

        .libya-dashboard .mgr-btn {
            padding: 8px 18px;
            background: linear-gradient(135deg, #0284c7, #04acf4);
            color: #fff;
            border: none;
            border-radius: 8px;
            font-weight: 600;
            font-size: 13px;
            cursor: pointer;
            text-decoration: none;
            display: inline-flex;
            align-items: center;
        }

        .libya-dashboard .mgr-btn:hover {
            opacity: 0.95;
        }

        .libya-dashboard .mgr-btn-secondary {
            background: #f8fafc;
            color: #475569;
            border: 1px solid #cbd5e1;
        }

        .libya-dashboard .mgr-btn-secondary:hover {
            background: #bae6fd;
            color: #0369a1;
            border-color: #bae6fd;
        }

        .libya-dashboard .mgr-alert {
            background: #fffbeb;
            border: 1px solid #fcd34d;
            border-right: 4px solid #f59e0b;
            border-radius: 8px;
            padding: 12px 16px;
            margin-bottom: 20px;
        }

        .libya-dashboard .mgr-alert strong {
            color: #92400e;
        }

        .libya-dashboard .mgr-alert ul {
            margin: 8px 0 0 0;
            padding-right: 20px;
            color: #92400e;
        }

        .libya-dashboard .mgr-cards {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 14px;
        }

        .libya-dashboard .mgr-card {
            background: #fff;
            border: 1px solid #bae6fd;
            border-radius: 10px;
            padding: 14px;
            box-shadow: 0 2px 8px rgba(0, 0, 0, .08);
            border-right: 4px solid #04acf4;
        }

        .libya-dashboard .mgr-card h3 {
            margin-top: 0;
            padding-bottom: 8px;
            font-size: 14px;
            flex: 1;
        }

        .libya-dashboard .mgr-card p {
            margin: 4px 0;
            font-size: 12px;
        }

        .libya-dashboard .mgr-card .mgr-status-badge {
            padding: 3px 8px;
            border-radius: 5px;
            text-decoration: none;
            font-size: 10px;
            font-weight: bold;
        }

        .libya-dashboard .mgr-card .mgr-status-active {
            background: #28a745;
            color: #fff;
        }

        .libya-dashboard .mgr-card .mgr-status-frozen {
            background: #add8e6;
            color: #1a202c;
        }

        .libya-dashboard .mgr-card .mgr-stalled {
            background: #fff5f5;
            color: #c53030;
            padding: 5px 8px;
            border-radius: 6px;
            font-size: 11px;
            font-weight: 600;
            border: 1px solid #feb2b2;
            margin-bottom: 8px;
        }

        .libya-dashboard .mgr-card .mgr-progress {
            background: #e5e7eb;
            height: 8px;
            border-radius: 5px;
            margin: 8px 0;
            overflow: hidden;
        }

        .libya-dashboard .mgr-card .mgr-progress-inner {
            height: 100%;
            border-radius: 5px;
        }

        .libya-dashboard .mgr-card .mgr-actions {
            display: flex;
            align-items: center;
            gap: 8px;
            flex-wrap: wrap;
            margin-top: 8px;
        }

        .libya-dashboard .mgr-card .mgr-btn {
            padding: 6px 14px;
            font-size: 12px;
        }

        .libya-dashboard .mgr-card .mgr-badge-time {
            background: #e2e8f0;
            padding: 6px 10px;
            border-radius: 5px;
            font-size: 11px;
            color: #475569;
            font-weight: 600;
            border: 1px solid #cbd5e1;
            display: inline-flex;
            align-items: center;
            gap: 4px;
        }

        .libya-dashboard .mgr-empty {
            grid-column: 1 / -1;
            background: #f8fafc;
            border: 2px dashed #cbd5e1;
            border-radius: 12px;
            padding: 48px 24px;
            text-align: center;
            color: #64748b;
            font-size: 15px;
        }

        .libya-dashboard .mgr-empty a {
            color: #0284c7;
            font-weight: 600;
            text-decoration: none;
        }

        .libya-dashboard .mgr-empty a:hover {
            text-decoration: underline;
        }

        @media (max-width: 900px) {
            .libya-dashboard .mgr-cards {
                grid-template-columns: repeat(2, 1fr);
            }
        }

        @media (max-width: 600px) {
            .libya-dashboard {
                max-width: 100%;
                padding: 0 12px;
            }

            .libya-dashboard .mgr-cards {
                grid-template-columns: 1fr;
            }
        }
    </style>
    <div class="wrap libya-dashboard">
        <?php if ($total_stalled_orders > 0 || $pending_emails_count > 0): ?>
            <div class="mgr-alert">
                <strong>تنبيهات:</strong>
                <ul>
                    <?php if ($total_stalled_orders > 0): ?>
                        <li>يوجد <strong><?php echo (int) $total_stalled_orders; ?></strong> طلب تم قبوله بدون إجراء منذ أكثر من 5 دقائق (تظهر تحت كل تاجر أدناه).</li>
                    <?php endif; ?>
                    <?php if ($pending_emails_count > 0): ?>
                        <li>يوجد <strong><?php echo (int) $pending_emails_count; ?></strong> رسالة في قائمة انتظار الإيميلات. <a href="<?php echo esc_url(admin_url('admin.php?page=system-maintenance')); ?>">صيانة النظام → معالجة قائمة الإيميلات</a></li>
                    <?php endif; ?>
                </ul>
            </div>
        <?php endif; ?>
        <div class="mgr-header">
            <h1 class="mgr-title">لوحة تحكم متابعة المتاجر</h1>
            <div class="mgr-stat-box">
                <span>إجمالي العمولة المستحقة:</span>
                <span class="val"><?php echo wc_price($total_all_commissions); ?></span>
            </div>
        </div>
        <form method="get" class="mgr-search">
            <input type="hidden" name="page" value="merchant-main-dashboard">
            <input type="search" name="s" value="<?php echo esc_attr($search); ?>" placeholder="بحث بالاسم أو الإيميل أو المتجر أو رقم الهاتف...">
            <button type="submit" class="mgr-btn mgr-btn-secondary" style="cursor: pointer;">بحث</button>
            <?php if ($search !== ''): ?>
                <a href="<?php echo esc_url(admin_url('admin.php?page=merchant-main-dashboard')); ?>" class="mgr-btn mgr-btn-secondary" style="text-decoration: none; display: inline-flex; align-items: center;">إلغاء البحث</a>
            <?php endif; ?>
        </form>
        <div class="mgr-cards">
            <?php if (empty($filtered_merchants)): ?>
                <div class="mgr-empty">
                    <?php if ($search !== ''): ?>
                        لا توجد نتائج للبحث.
                    <?php else: ?>
                        لا يوجد متاجر مسجلة.<br>
                        <a href="<?php echo esc_url(admin_url('admin.php?page=merchant-data-manager')); ?>">إضافة متجر جديد ←</a>
                    <?php endif; ?>
                </div>
            <?php else: ?>
                <?php foreach ($filtered_merchants as $email => $m):
                    $city = $m['city'];
                    $count = count(array_filter(get_option("merchant_recent_orders_{$email}", [])));
                    $limit = !empty($m['order_limit']) ? (int)$m['order_limit'] : DEFAULT_ORDER_LIMIT_V14;
                    $total_sales = (float)get_option("merchant_total_sales_{$email}", 0);
                    $perc = ($count / $limit) * 100;
                    $color = ($perc >= 100) ? '#dc3545' : (($perc >= 50) ? '#ffc107' : '#28a745');
                    $status = $m['status'] ?? 'active';
                    $wait_time = libya_format_wait_time_v14($m['last_activity'] ?? 0);

                    // التحقق من الطلبات المعلقة التي تم قبولها ولم يتم اتخاذ إجراء (أكثر من 5 دقائق)
                    $stalled_orders_count = 0;
                    $recent_orders = get_option("merchant_recent_orders_{$email}", []);
                    foreach ($recent_orders as $oid) {
                        $last_act = (int)get_option("merchant_last_action_time_{$oid}", 0);
                        if ($last_act > 0 && (time() - $last_act) > 300) { // 300 ثانية = 5 دقائق
                            $order = wc_get_order($oid);
                            if ($order && $order->get_status() === 'processing') {
                                $stalled_orders_count++;
                            }
                        }
                    }
                    $card_color = !empty($m['card_color']) ? $m['card_color'] : '#7d9a7d';
                ?>
                    <div class="mgr-card" style="border-right-color: <?php echo esc_attr($card_color); ?>;">
                        <div style="display: flex; justify-content: space-between; align-items: flex-start;">
                            <h3 style="border-bottom: 2px solid #f9fafb; padding-bottom: 10px;">
                                <span><?php echo esc_html($m['branch_name']); ?> | <?php echo esc_html($city); ?></span>
                            </h3>
                            <?php
                            $status_url = wp_nonce_url(
                                add_query_arg([
                                    'page' => 'merchant-main-dashboard',
                                    'merchant_status_action' => ($status === 'active' ? 'freeze' : 'activate'),
                                    'm_email' => $email
                                ], admin_url('admin.php')),
                                'libya_merchant_status_' . $email
                            );
                            if ($status === 'active'): ?>
                                <a href="<?php echo esc_url($status_url); ?>" class="mgr-status-badge mgr-status-active" onclick="return confirm('هل أنت متأكد من تجميد حساب هذا المتجر؟')">نشط</a>
                            <?php else: ?>
                                <a href="<?php echo esc_url($status_url); ?>" class="mgr-status-badge mgr-status-frozen" onclick="return confirm('هل أنت متأكد من تفعيل حساب هذا المتجر؟')">مجمد</a>
                            <?php endif; ?>
                        </div>
                        <p><strong>الإيميل:</strong> <?php echo esc_html($email); ?></p>
                        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 5px;">
                            <span><strong>الطلبات:</strong> <?php echo $count; ?> / <?php echo $limit; ?></span>
                        </div>
                        <?php if ($stalled_orders_count > 0): ?>
                            <div class="mgr-stalled">
                                <span class="dashicons dashicons-warning" style="font-size: 16px; width: 16px; height: 16px; color: #e53e3e;"></span>
                                يوجد <?php echo $stalled_orders_count; ?> طلب تم قبوله بدون إجراء
                            </div>
                        <?php endif; ?>
                        <div class="mgr-progress">
                            <div class="mgr-progress-inner" style="background: <?php echo esc_attr($color); ?>; width: <?php echo min(100, $perc); ?>%;"></div>
                        </div>
                        <p><strong>إجمالي المبيعات:</strong> <?php echo wc_price($total_sales); ?></p>
                        <div class="mgr-actions">
                            <a href="?page=merchant-details&city=<?php echo urlencode($city); ?>&email=<?php echo urlencode($email); ?>" class="mgr-btn">عرض التفاصيل والأرشفة</a>
                            <span class="mgr-badge-time">
                                <span class="dashicons dashicons-clock" style="font-size: 16px; width: 16px; height: 16px;"></span>
                                <?php echo esc_html($wait_time); ?>
                            </span>
                        </div>
                    </div>
                <?php endforeach; ?>
            <?php endif; ?>
        </div>
    </div>
<?php
}




add_action('admin_init', 'libya_handle_merchant_save_v14');
function libya_handle_merchant_save_v14()
{
    if (isset($_POST['save_merchant'])) {
        check_admin_referer('libya_merchant_save_action', 'libya_merchant_nonce');
        if (!current_user_can('manage_options')) wp_die('غير مصرح لك بذلك');

        $merchants = get_libya_merchants_v14();
        $email = sanitize_email($_POST['m_email']);
        $is_new_merchant = !isset($merchants[$email]);
        $branch_name = sanitize_text_field($_POST['m_branch']);

        $m_city = sanitize_text_field($_POST['m_city']);
        $m_branch = sanitize_text_field($_POST['m_branch']);
        $m_owner = sanitize_text_field($_POST['m_owner']);
        $m_email = sanitize_email($_POST['m_email']); // Re-sanitized for clarity, though $email is already set
        $m_phone = sanitize_text_field($_POST['m_phone']);

        if (!empty($m_phone) && !preg_match('/^09[0-9]{8}$/', $m_phone)) {
            $url = add_query_arg(['msg' => 'merchant_error', 'err' => 'phone'], admin_url('admin.php?page=merchant-data-manager'));
            if (!$is_new_merchant) {
                $url = add_query_arg(['action' => 'edit', 'email' => $email], $url);
            }
            wp_redirect($url);
            exit;
        }

        $m_limit = !empty($_POST['m_limit']) ? intval($_POST['m_limit']) : get_option('libya_def_limit', 20);

        // بناء شرائح النسبة من النموذج
        $rate_tiers = [];
        $rate_from = isset($_POST['m_rate_from']) && is_array($_POST['m_rate_from']) ? $_POST['m_rate_from'] : [];
        $rate_to = isset($_POST['m_rate_to']) && is_array($_POST['m_rate_to']) ? $_POST['m_rate_to'] : [];
        $rate_pct = isset($_POST['m_rate_pct']) && is_array($_POST['m_rate_pct']) ? $_POST['m_rate_pct'] : [];
        $rate_count = max(count($rate_from), count($rate_to), count($rate_pct));
        for ($i = 0; $i < $rate_count; $i++) {
            $from = isset($rate_from[$i]) ? floatval($rate_from[$i]) : 0;
            $to = isset($rate_to[$i]) ? floatval($rate_to[$i]) : 0;
            $rate = isset($rate_pct[$i]) ? floatval($rate_pct[$i]) : 0;
            if ($rate > 0 || $from > 0 || $to > 0) {
                $rate_tiers[] = ['from' => $from, 'to' => $to, 'rate' => $rate];
            }
        }
        if (empty($rate_tiers)) {
            $rate_tiers = [['from' => 0, 'to' => 0, 'rate' => (float)get_option('libya_def_rate', 0)]];
        }

        // بناء شرائح العمولة الثابتة من النموذج
        $fixed_tiers = [];
        $fixed_from = isset($_POST['m_fixed_from']) && is_array($_POST['m_fixed_from']) ? $_POST['m_fixed_from'] : [];
        $fixed_to = isset($_POST['m_fixed_to']) && is_array($_POST['m_fixed_to']) ? $_POST['m_fixed_to'] : [];
        $fixed_val = isset($_POST['m_fixed_val']) && is_array($_POST['m_fixed_val']) ? $_POST['m_fixed_val'] : [];
        $fixed_count = max(count($fixed_from), count($fixed_to), count($fixed_val));
        for ($i = 0; $i < $fixed_count; $i++) {
            $from = isset($fixed_from[$i]) ? floatval($fixed_from[$i]) : 0;
            $to = isset($fixed_to[$i]) ? floatval($fixed_to[$i]) : 0;
            $fix = isset($fixed_val[$i]) ? floatval($fixed_val[$i]) : 0;
            if ($fix > 0 || $from > 0 || $to > 0) {
                $fixed_tiers[] = ['from' => $from, 'to' => $to, 'fixed' => $fix];
            }
        }
        if (empty($fixed_tiers)) {
            $fixed_tiers = [['from' => 0, 'to' => 0, 'fixed' => (float)get_option('libya_def_fixed', 0)]];
        }

        $m_card_color = isset($_POST['m_card_color']) ? sanitize_text_field($_POST['m_card_color']) : '';
        $allowed_colors = array_keys(libya_merchant_card_colors_v14());
        if (!in_array($m_card_color, $allowed_colors, true)) $m_card_color = '';

        $merchants[$email] = [
            'city' => $m_city,
            'email' => $m_email,
            'branch_name' => $m_branch,
            'owner_name' => $m_owner,
            'phone' => $m_phone,
            'card_color' => $m_card_color,
            'commission_rate_tiers' => $rate_tiers,
            'fixed_commission_tiers' => $fixed_tiers,
            'order_limit' => $m_limit,
            'status' => in_array($_POST['m_status'] ?? '', ['active', 'frozen'], true) ? $_POST['m_status'] : 'active',
            'last_activity' => (isset($merchants[$email]['last_activity']) ? $merchants[$email]['last_activity'] : time()),
        ];
        save_libya_merchants_v14($merchants);

        if (function_exists('libya_system_log_v14')) {
            libya_system_log_v14($is_new_merchant ? 'تم إضافة متجر' : 'تم تعديل متجر', $email, ($is_new_merchant ? 'تم إضافة المتجر: ' : 'تم تعديل بيانات المتجر: ') . $m_branch, 0);
        }

        // حفظ شرائح النسبة والعمولة كقيم افتراضية لتظهر عند إضافة التاجر التالي
        update_option('libya_def_rate_tiers', $rate_tiers);
        update_option('libya_def_fixed_tiers', $fixed_tiers);
        $first_rate = $rate_tiers[0];
        $first_fixed = $fixed_tiers[0];
        update_option('libya_def_rate', isset($first_rate['rate']) ? $first_rate['rate'] : get_option('libya_def_rate', 0));
        update_option('libya_def_fixed', isset($first_fixed['fixed']) ? $first_fixed['fixed'] : get_option('libya_def_fixed', 0));
        update_option('libya_def_limit', sanitize_text_field($_POST['m_limit']));

        // إرسال رسالة ترحيبية للتاجر الجديد
        if ($is_new_merchant) {
            $welcome_content = "
            <div style='text-align: right; line-height: 1.8; direction: rtl;'>
                <p style='font-size: 16px; margin-bottom: 15px;'>مرحباً <strong>{$branch_name}</strong>، تم الانضمام بنجاح</p>
                
                <p style='font-size: 14px; color: #4a5568; margin-bottom: 15px;'>يسعدنا جداً أن نرحب بك كشريك استراتيجي في نظام المعتمد. انضمامك إلينا ليس مجرد تسجيل حساب، بل هو خطوة نحو تنظيم وتطوير أعمالك بأدوات ذكية صُممت خصيصاً لتناسب طموحاتك.</p>
                
                <div style='background: #f0f9ff; border-right: 4px solid #0369a1; padding: 15px; border-radius: 8px; margin: 20px 0;'>
                    <p style='font-size: 14px; color: #1e40af; margin: 0;'><strong>كيف يعمل النظام؟</strong></p>
                    <p style='font-size: 13px; color: #4a5568; margin: 10px 0 0 0;'>سيبدأ نظام المعتمد بتحويل طلبات الزبائن إليك بشكل آلي ولحظي. سنوافيك بكل تفاصيل الطلب (المنتج، الكمية، والبيانات) عبر إشعارات التطبيق المباشرة، لضمان سرعة التنفيذ.</p>
                </div>
                
                <p style='font-size: 14px; color: #4a5568; margin-top: 20px;'>مع أطيب التحيات</p>
                <p style='font-size: 15px; font-weight: bold; color: #1a202c;'>المعتمد</p>
                <p style='font-size: 13px; color: #718096;'>لأي استفسار: <a href='tel:0914479920' style='color: #04acf4; text-decoration: none;'>0914479920</a></p>
            </div>";

            wp_mail($email, "تم انضمامك إلى المعتمد", get_libya_msg_template_v14("تم انضمامك إلى المعتمد", $welcome_content, "المعتمد | 0914479920", "success"), ['Content-Type: text/html; charset=UTF-8', 'From: ' . get_bloginfo('name') . ' <' . get_option('admin_email') . '>']);
        }

        wp_redirect(admin_url('admin.php?page=merchant-data-manager&msg=saved'));
        exit;
    }
}

add_action('admin_init', 'libya_handle_global_timing_save_v14');
function libya_handle_global_timing_save_v14()
{
    if (isset($_POST['save_global_timing'])) {
        check_admin_referer('libya_global_timing_action', 'libya_global_timing_nonce');
        if (!current_user_can('manage_options')) wp_die('غير مصرح لك بذلك');

        update_option('libya_def_deadline', sanitize_text_field($_POST['global_deadline']));
        update_option('libya_def_extra_time', sanitize_text_field($_POST['global_extra_time']));

        libya_system_log_v14('global_timing_updated', 'admin', 'تم تحديث إعدادات التوقيت العام');

        wp_redirect(admin_url('admin.php?page=merchant-data-manager&msg=global_saved'));
        exit;
    }
}

add_action('admin_init', 'libya_handle_bank_account_save_v14');
function libya_handle_bank_account_save_v14()
{
    // معالجة حذف حساب مصرفي
    if (isset($_GET['action']) && $_GET['action'] === 'delete_bank_account' && isset($_GET['account_id'])) {
        check_admin_referer('libya_delete_bank_account_' . $_GET['account_id']);
        if (!current_user_can('manage_options')) wp_die('غير مصرح لك بذلك');

        $accounts = get_option('libya_bank_accounts_v14', []);
        $account_id = sanitize_text_field($_GET['account_id']);

        if (isset($accounts[$account_id])) {
            unset($accounts[$account_id]);
            update_option('libya_bank_accounts_v14', $accounts);
            libya_system_log_v14('bank_account_deleted', 'المعتمد', 'تم حذف حساب مصرفي: ' . $account_id);
            wp_redirect(admin_url('admin.php?page=merchant-data-manager&bank_msg=deleted'));
        } else {
            wp_redirect(admin_url('admin.php?page=merchant-data-manager&bank_msg=delete_error'));
        }
        exit;
    }

    // معالجة حفظ/تعديل حساب مصرفي
    if (isset($_POST['save_bank_account'])) {
        check_admin_referer('libya_bank_account_save_action', 'libya_bank_account_nonce');
        if (!current_user_can('manage_options')) wp_die('غير مصرح لك بذلك');

        $accounts = get_option('libya_bank_accounts_v14', []);

        // إذا كان تعديل، استخدم المعرف الموجود، وإلا أنشئ معرف جديد
        $account_id = !empty($_POST['account_id']) ? sanitize_text_field($_POST['account_id']) : 'account_' . time();

        $accounts[$account_id] = [
            'bank_name' => sanitize_text_field($_POST['bank_name']),
            'account_number' => sanitize_text_field($_POST['account_number']),
            'iban' => sanitize_text_field($_POST['bank_iban']),
        ];

        update_option('libya_bank_accounts_v14', $accounts);
        libya_system_log_v14('bank_account_saved', 'المعتمد', 'تم حفظ حساب مصرفي: ' . $accounts[$account_id]['bank_name']);

        wp_redirect(admin_url('admin.php?page=merchant-data-manager&bank_msg=saved'));
        exit;
    }
}

function render_merchant_data_manager_v14()
{
    $merchants = get_libya_merchants_v14();
    $admin_notice = '';

    if (isset($_GET['action']) && $_GET['action'] === 'delete_merchant' && isset($_GET['email'])) {
        check_admin_referer('libya_delete_merchant_' . $_GET['email']);
        if (!current_user_can('manage_options')) wp_die('غير مصرح لك بذلك');

        $email = sanitize_email($_GET['email']);
        if (isset($merchants[$email])) {
            unset($merchants[$email]);
            save_libya_merchants_v14($merchants);
            delete_option("merchant_recent_orders_{$email}");
            delete_option("merchant_archive_{$email}");
            delete_option("merchant_orders_count_{$email}");
            delete_option("merchant_total_sales_{$email}");
            delete_option("merchant_limit_notified_{$email}");
            delete_option("merchant_limit_notified_2nd_{$email}");
            delete_option("merchant_payment_completed_{$email}");
            delete_option("merchant_payment_notified_{$email}");
            delete_option("admin_payment_processed_{$email}");
            delete_option("admin_payment_not_received_{$email}");
            delete_option("libya_merchant_access_token_{$email}");
            $admin_notice = '<div class="libya-admin-success-notice"><p>تم حذف المتجر وجميع بياناته.</p></div>';
        } else {
            $admin_notice = '<div class="libya-admin-error-notice"><p>فشل الحذف: المتجر غير موجود.</p></div>';
        }
    }

    if (isset($_GET['msg']) && $_GET['msg'] === 'saved') {
        $admin_notice .= '<div class="libya-admin-success-notice"><p>تم حفظ بيانات المتجر بنجاح.</p></div>';
    }
    if (isset($_GET['msg']) && $_GET['msg'] === 'global_saved') {
        $admin_notice .= '<div class="libya-admin-success-notice"><p>تم حفظ إعدادات التوقيت والمهل العامة بنجاح.</p></div>';
    }
    if (isset($_GET['bank_msg']) && $_GET['bank_msg'] === 'saved') {
        $admin_notice .= '<div class="libya-admin-success-notice"><p>تم حفظ الحساب المصرفي بنجاح.</p></div>';
    }
    if (isset($_GET['bank_msg']) && $_GET['bank_msg'] === 'deleted') {
        $admin_notice .= '<div class="libya-admin-success-notice"><p>تم حذف الحساب المصرفي بنجاح.</p></div>';
    }
    if (isset($_GET['msg']) && $_GET['msg'] === 'merchant_error' && isset($_GET['err']) && $_GET['err'] === 'phone') {
        $admin_notice .= '<div class="libya-admin-error-notice"><p>رقم الهاتف غير صحيح. يجب أن يبدأ بـ 09 ويتكون من 10 أرقام.</p></div>';
    }
    if (isset($_GET['bank_msg']) && $_GET['bank_msg'] === 'delete_error') {
        $admin_notice .= '<div class="libya-admin-error-notice"><p>فشل الحذف: الحساب المصرفي غير موجود.</p></div>';
    }

    $edit_email = (isset($_GET['action']) && $_GET['action'] === 'edit') ? sanitize_email($_GET['email']) : '';
    $edit_data = $edit_email ? ($merchants[$edit_email] ?? null) : null;
    // تحويل البيانات القديمة (نسبة/حد/ثابتة/حد ثابتة) إلى شرائح للعرض في النموذج
    if ($edit_data && empty($edit_data['commission_rate_tiers']) && isset($edit_data['commission_rate'])) {
        $edit_data['commission_rate_tiers'] = [
            ['from' => (float)($edit_data['commission_threshold'] ?? 0), 'to' => 0, 'rate' => (float)$edit_data['commission_rate']]
        ];
    }
    if ($edit_data && empty($edit_data['fixed_commission_tiers']) && isset($edit_data['fixed_commission'])) {
        $edit_data['fixed_commission_tiers'] = [
            ['from' => (float)($edit_data['fixed_threshold'] ?? 0), 'to' => 0, 'fixed' => (float)$edit_data['fixed_commission']]
        ];
    }
    // عند التعديل: استخدام بيانات التاجر. عند الإضافة: استخدام آخر شرائح محفوظة (تبقى في الحقول حتى يغيّرها المسؤول)
    $saved_rate_tiers = get_option('libya_def_rate_tiers', null);
    $saved_fixed_tiers = get_option('libya_def_fixed_tiers', null);
    $default_rate_tiers = (!empty($saved_rate_tiers) && is_array($saved_rate_tiers)) ? $saved_rate_tiers : [['from' => 0, 'to' => 0, 'rate' => (float)get_option('libya_def_rate', '0')]];
    $default_fixed_tiers = (!empty($saved_fixed_tiers) && is_array($saved_fixed_tiers)) ? $saved_fixed_tiers : [['from' => 0, 'to' => 0, 'fixed' => (float)get_option('libya_def_fixed', '0')]];
    $rate_tiers = ($edit_data && !empty($edit_data['commission_rate_tiers']) && is_array($edit_data['commission_rate_tiers'])) ? $edit_data['commission_rate_tiers'] : $default_rate_tiers;
    $fixed_tiers = ($edit_data && !empty($edit_data['fixed_commission_tiers']) && is_array($edit_data['fixed_commission_tiers'])) ? $edit_data['fixed_commission_tiers'] : $default_fixed_tiers;
?>
    <style>
        .libya-mgr {
            direction: rtl;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 1000px;
            margin: 20px auto 40px;
            padding: 0 16px;
        }

        .libya-mgr * {
            box-sizing: border-box;
        }

        .libya-mgr .mgr-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            flex-wrap: wrap;
            gap: 12px;
            margin-bottom: 24px;
            padding-bottom: 20px;
            border-bottom: 2px solid #04acf4;
        }

        .libya-mgr .mgr-title {
            margin: 0;
            font-size: 20px;
            font-weight: 700;
            color: #0284c7;
        }

        .libya-mgr .mgr-back {
            display: inline-flex;
            align-items: center;
            padding: 6px 12px;
            background: #f0f9ff;
            color: #0369a1;
            text-decoration: none;
            border-radius: 8px;
            font-size: 13px;
            font-weight: 500;
            border: 1px solid #bae6fd;
            transition: background .15s, color .15s;
        }

        .libya-mgr .mgr-back:hover {
            background: #bae6fd;
            color: #0284c7;
        }

        .libya-mgr .mgr-card {
            background: #fff;
            border: 1px solid #bae6fd;
            border-radius: 12px;
            padding: 20px;
            margin-bottom: 20px;
            box-shadow: 0 2px 8px rgba(0, 0, 0, .08);
            border-right: 4px solid #04acf4;
        }

        .libya-mgr .mgr-card h2 {
            margin: 0 0 16px;
            font-size: 15px;
            font-weight: 600;
            color: #0284c7;
            padding-bottom: 8px;
            border-bottom: 1px solid #e2e8f0;
        }

        .libya-mgr .mgr-row {
            margin-bottom: 12px;
        }

        .libya-mgr .mgr-row label {
            display: block;
            font-weight: 600;
            color: #374151;
            margin-bottom: 4px;
            font-size: 12px;
        }

        .libya-mgr .mgr-row input,
        .libya-mgr .mgr-row select {
            width: 100%;
            max-width: 100%;
            padding: 8px 12px;
            border: 1px solid #cbd5e1;
            border-radius: 8px;
            font-size: 13px;
        }

        .libya-mgr .mgr-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 16px;
        }

        .libya-mgr .mgr-grid-col {
            background: #f8fafc;
            padding: 14px;
            border-radius: 10px;
            border: 1px solid #e2e8f0;
        }

        .libya-mgr .mgr-btn {
            padding: 8px 18px;
            background: linear-gradient(135deg, #0284c7, #04acf4);
            color: #fff;
            border: none;
            border-radius: 8px;
            font-weight: 600;
            font-size: 13px;
            cursor: pointer;
        }

        .libya-mgr .mgr-btn:hover {
            opacity: 0.95;
        }

        .libya-mgr .mgr-btn-secondary {
            background: #f8fafc;
            color: #475569;
            border: 1px solid #cbd5e1;
        }

        .libya-mgr .mgr-btn-secondary:hover {
            background: #bae6fd;
            color: #0369a1;
            border-color: #bae6fd;
        }

        .libya-mgr .mgr-table {
            width: 100%;
            border-collapse: collapse;
            font-size: 12px;
        }

        .libya-mgr .mgr-table th,
        .libya-mgr .mgr-table td {
            padding: 10px 8px;
            text-align: right;
            border-bottom: 1px solid #e2e8f0;
        }

        .libya-mgr .mgr-table th {
            background: #f8fafc;
            color: #4a5568;
            font-weight: 600;
        }

        .libya-mgr .mgr-table tr:hover {
            background: #f9fafb;
        }

        .libya-mgr .mgr-badge {
            display: inline-block;
            padding: 4px 8px;
            border-radius: 6px;
            font-size: 11px;
            font-weight: 500;
        }

        .libya-mgr .mgr-badge-edit {
            background: #dbeafe;
            color: #1d4ed8;
        }

        .libya-mgr .mgr-badge-delete {
            background: #fee2e2;
            color: #dc2626;
        }

        .libya-mgr .mgr-hint {
            font-size: 11px;
            color: #9ca3af;
            margin-top: 4px;
        }

        .libya-mgr .mgr-tiers-block {}

        .libya-mgr .mgr-tiers-caption {
            font-weight: 600;
            color: #374151;
            margin-bottom: 6px;
            font-size: 12px;
        }

        .libya-mgr .mgr-tier-legend {
            font-size: 11px;
            color: #9ca3af;
            margin: 4px 0 10px 0;
            line-height: 1.4;
        }

        .libya-mgr .mgr-tier-row {
            display: flex;
            gap: 8px;
            align-items: center;
            margin-bottom: 8px;
            flex-wrap: wrap;
        }

        .libya-mgr .mgr-tier-row .mgr-tier-input {
            flex: 1;
            min-width: 80px;
            max-width: 120px;
            padding: 6px 10px;
            border: 1px solid #cbd5e1;
            border-radius: 8px;
            font-size: 13px;
        }

        .libya-mgr .mgr-tier-input::placeholder {
            color: #9ca3af;
            opacity: 0.75;
        }

        .libya-mgr .mgr-tier-remove {
            width: 28px;
            height: 28px;
            padding: 0;
            border: 1px solid #fecaca;
            background: #fee2e2;
            color: #dc2626;
            border-radius: 6px;
            cursor: pointer;
            font-size: 16px;
            line-height: 1;
            flex-shrink: 0;
        }

        .libya-mgr .mgr-tier-remove:hover {
            background: #fecaca;
        }

        .libya-mgr #rate-tiers-container .mgr-tier-row:only-child .mgr-tier-remove,
        .libya-mgr #fixed-tiers-container .mgr-tier-row:only-child .mgr-tier-remove {
            display: none;
        }

        .libya-mgr .mgr-tier-add {
            margin-top: 6px;
            padding: 6px 12px;
            background: #f0f9ff;
            color: #0369a1;
            border: 1px solid #bae6fd;
            border-radius: 8px;
            font-size: 12px;
            cursor: pointer;
        }

        .libya-mgr .mgr-tier-add:hover {
            background: #bae6fd;
        }

        .libya-mgr .tablenav-pages {
            margin: 12px 0;
            display: flex;
            align-items: center;
            gap: 12px;
            flex-wrap: wrap;
        }

        .libya-mgr .tablenav-pages .displaying-num {
            font-size: 12px;
            color: #6b7280;
        }

        .libya-mgr .mgr-section-title {
            font-size: 16px;
            font-weight: 600;
            color: #1e293b;
            margin: 28px 0 12px;
            padding-top: 20px;
            border-top: 2px solid #cbd5e1;
        }

        .libya-mgr .mgr-form-footer {
            margin-top: 20px;
        }

        .libya-mgr .mgr-form-footer .mgr-row-card-color {
            margin: 0;
            min-width: 200px;
            max-width: 280px;
        }

        .libya-mgr .mgr-form-footer .mgr-row-card-color label {
            display: block;
            text-align: right;
            margin-bottom: 8px;
        }

        .libya-mgr .mgr-form-footer .mgr-row-card-color select {
            width: 100%;
            padding: 8px 12px;
            padding-right: 36px;
            border: 1px solid #cbd5e1;
            border-radius: 8px;
            font-size: 13px;
            text-align: right;
        }

        @media (max-width: 600px) {
            .libya-mgr {
                max-width: 100%;
                padding: 0 12px;
            }

            .libya-mgr .mgr-card {
                padding: 16px;
            }

            .libya-mgr .mgr-grid {
                grid-template-columns: 1fr;
                gap: 12px;
            }

            .libya-mgr .mgr-title {
                font-size: 18px;
            }

            .libya-mgr .mgr-table th,
            .libya-mgr .mgr-table td {
                padding: 8px 6px;
                font-size: 11px;
            }

            .libya-mgr .mgr-form-footer .mgr-row-card-color {
                max-width: 100%;
            }
        }
    </style>
    <div class="wrap libya-mgr">
        <div class="mgr-header">
            <a href="<?php echo esc_url(admin_url('admin.php?page=merchant-main-dashboard')); ?>" class="mgr-back">← رجوع للرئيسية</a>
            <h1 class="mgr-title">إدارة بيانات المتاجر</h1>
        </div>
        <?php if ($admin_notice) {
            echo $admin_notice;
        } ?>
        <div class="mgr-card">
            <h2><?php echo $edit_data ? 'تعديل بيانات المتجر' : 'إضافة متجر جديد'; ?></h2>
            <form method="post" action="">
                <div class="mgr-grid">
                    <div class="mgr-grid-col">
                        <div class="mgr-row">
                            <label>المدينة</label>
                            <input type="text" name="m_city" value="<?php echo esc_attr($edit_data['city'] ?? ''); ?>" required>
                        </div>
                        <div class="mgr-row">
                            <label>اسم المتجر</label>
                            <input type="text" name="m_branch" value="<?php echo esc_attr($edit_data['branch_name'] ?? ''); ?>" required>
                        </div>
                        <div class="mgr-row">
                            <label>اسم المالك</label>
                            <input type="text" name="m_owner" value="<?php echo esc_attr($edit_data['owner_name'] ?? ''); ?>">
                        </div>
                        <div class="mgr-row">
                            <label>الإيميل</label>
                            <input type="email" name="m_email" value="<?php echo esc_attr($edit_data['email'] ?? ''); ?>" required <?php echo $edit_data ? 'readonly' : ''; ?>>
                        </div>
                        <div class="mgr-row">
                            <label>الهاتف</label>
                            <input type="text" name="m_phone" value="<?php echo esc_attr($edit_data['phone'] ?? ''); ?>" pattern="09[0-9]{8}" title="يجب أن يبدأ الرقم بـ 09 ويتكون من 10 أرقام">
                            <p class="mgr-hint">يجب أن يبدأ بـ 09 ويتكون من 10 أرقام</p>
                        </div>
                    </div>
                    <div class="mgr-grid-col">
                        <div class="mgr-row">
                            <label>النسبة والعمولة</label>
                        </div>
                        <p class="mgr-hint" style="margin: 0 0 10px; font-size: 12px; color: #64748b;">المنطق: لكل شريحة «من السعر» → «إلى السعر» (فارغ أو 0 = فما فوق). النسبة % تُطبّق على إجمالي الطلب؛ العمولة الثابتة (د.ل) تُضاف. هذه الشرائح لهذا التاجر فقط وتُستخدم في كشف الإيرادات.</p>
                        <div class="mgr-tiers-block">
                            <div class="mgr-tiers-caption">النسبة % (حسب النطاق السعري)</div>
                            <div id="rate-tiers-container">
                                <?php foreach ($rate_tiers as $i => $t): ?>
                                    <div class="mgr-tier-row">
                                        <input type="number" name="m_rate_from[]" value="<?php echo esc_attr($t['from'] ?? 0); ?>" placeholder="من السعر" title="بداية النطاق السعري" min="0" step="0.01" class="mgr-tier-input">
                                        <input type="number" name="m_rate_to[]" value="<?php echo esc_attr(isset($t['to']) && (float)$t['to'] > 0 ? $t['to'] : ''); ?>" placeholder="إلى السعر (0=فما فوق)" title="نهاية النطاق. فارغ أو 0 = فما فوق" min="0" step="0.01" class="mgr-tier-input">
                                        <input type="number" name="m_rate_pct[]" value="<?php echo esc_attr($t['rate'] ?? ''); ?>" placeholder="النسبة %" title="نسبة العمولة المئوية لهذا النطاق" min="0" max="100" step="0.01" class="mgr-tier-input">
                                        <button type="button" class="mgr-tier-remove" title="حذف">×</button>
                                    </div>
                                <?php endforeach; ?>
                            </div>
                            <button type="button" id="add-rate-tier" class="mgr-tier-add">+ إضافة شريحة نسبة</button>
                        </div>
                        <div class="mgr-tiers-block" style="margin-top: 16px;">
                            <div class="mgr-tiers-caption">عمولة ثابتة (د.ل) حسب النطاق السعري</div>
                            <div id="fixed-tiers-container">
                                <?php foreach ($fixed_tiers as $i => $t): ?>
                                    <div class="mgr-tier-row">
                                        <input type="number" name="m_fixed_from[]" value="<?php echo esc_attr($t['from'] ?? 0); ?>" placeholder="من السعر" title="بداية النطاق السعري" min="0" step="0.01" class="mgr-tier-input">
                                        <input type="number" name="m_fixed_to[]" value="<?php echo esc_attr(isset($t['to']) && (float)$t['to'] > 0 ? $t['to'] : ''); ?>" placeholder="إلى السعر (0=فما فوق)" title="نهاية النطاق. فارغ أو 0 = فما فوق" min="0" step="0.01" class="mgr-tier-input">
                                        <input type="number" name="m_fixed_val[]" value="<?php echo esc_attr($t['fixed'] ?? ''); ?>" placeholder="عمولة د.ل" title="العمولة الثابتة بالدينار لهذا النطاق" min="0" step="0.01" class="mgr-tier-input">
                                        <button type="button" class="mgr-tier-remove" title="حذف">×</button>
                                    </div>
                                <?php endforeach; ?>
                            </div>
                            <button type="button" id="add-fixed-tier" class="mgr-tier-add">+ إضافة شريحة عمولة ثابتة</button>
                        </div>
                        <div class="mgr-row" style="margin-top: 16px;">
                            <label>حد الطلبيات</label>
                            <input type="number" name="m_limit" value="<?php echo esc_attr($edit_data['order_limit'] ?? get_option('libya_def_limit', '20')); ?>">
                        </div>
                    </div>
                </div>
                <div class="mgr-form-footer">
                    <div class="mgr-row mgr-row-card-color">
                        <label>لون مميز للبطاقة</label>
                        <select name="m_card_color" class="mgr-card-color-select">
                            <?php
                            $card_colors = libya_merchant_card_colors_v14();
                            $current_color = $edit_data['card_color'] ?? '';
                            foreach ($card_colors as $hex => $label):
                                $swatch_bg = $hex !== '' ? $hex : '#7d9a7d';
                                $opt_style = 'background-color: ' . esc_attr($swatch_bg) . ';';
                            ?>
                                <option value="<?php echo esc_attr($hex); ?>" <?php selected($current_color, $hex); ?> style="<?php echo $opt_style; ?>">■ <?php echo esc_html($label); ?></option>
                            <?php endforeach; ?>
                        </select>
                        <p class="mgr-hint">يظهر على يمين بطاقة المتجر في لوحة التحكم</p>
                    </div>
                </div>
                <div style="margin-top: 20px; display: flex; gap: 10px; flex-wrap: wrap;">
                    <button type="submit" class="mgr-btn"><?php echo $edit_data ? 'حفظ التعديلات' : 'إضافة التاجر'; ?></button>
                    <?php if ($edit_data): ?><a href="?page=merchant-data-manager" class="mgr-btn mgr-btn-secondary" style="text-decoration:none;display:inline-flex;align-items:center;">إلغاء</a><?php endif; ?>
                </div>
                <input type="hidden" name="m_status" value="<?php echo esc_attr($edit_data['status'] ?? 'active'); ?>">
                <input type="hidden" name="save_merchant" value="1">
                <?php wp_nonce_field('libya_merchant_save_action', 'libya_merchant_nonce'); ?>
            </form>
        </div>
        <script>
            (function() {
                var rateContainer = document.getElementById('rate-tiers-container');
                var fixedContainer = document.getElementById('fixed-tiers-container');

                function makeRateRow() {
                    return '<div class="mgr-tier-row"><input type="number" name="m_rate_from[]" placeholder="من السعر" title="بداية النطاق السعري" min="0" step="0.01" class="mgr-tier-input"><input type="number" name="m_rate_to[]" placeholder="إلى السعر (0=فما فوق)" title="نهاية النطاق. فارغ أو 0 = فما فوق" min="0" step="0.01" class="mgr-tier-input"><input type="number" name="m_rate_pct[]" placeholder="النسبة %" title="نسبة العمولة المئوية لهذا النطاق" min="0" max="100" step="0.01" class="mgr-tier-input"><button type="button" class="mgr-tier-remove" title="حذف">×</button></div>';
                }

                function makeFixedRow() {
                    return '<div class="mgr-tier-row"><input type="number" name="m_fixed_from[]" placeholder="من السعر" title="بداية النطاق السعري" min="0" step="0.01" class="mgr-tier-input"><input type="number" name="m_fixed_to[]" placeholder="إلى السعر (0=فما فوق)" title="نهاية النطاق. فارغ أو 0 = فما فوق" min="0" step="0.01" class="mgr-tier-input"><input type="number" name="m_fixed_val[]" placeholder="عمولة د.ل" title="العمولة الثابتة بالدينار لهذا النطاق" min="0" step="0.01" class="mgr-tier-input"><button type="button" class="mgr-tier-remove" title="حذف">×</button></div>';
                }

                function bindRemove(container) {
                    container.querySelectorAll('.mgr-tier-remove').forEach(function(btn) {
                        btn.onclick = function() {
                            var row = this.closest('.mgr-tier-row');
                            if (container.querySelectorAll('.mgr-tier-row').length > 1) row.remove();
                        };
                    });
                }
                if (rateContainer) {
                    document.getElementById('add-rate-tier').onclick = function() {
                        rateContainer.insertAdjacentHTML('beforeend', makeRateRow());
                        bindRemove(rateContainer);
                    };
                    bindRemove(rateContainer);
                }
                if (fixedContainer) {
                    document.getElementById('add-fixed-tier').onclick = function() {
                        fixedContainer.insertAdjacentHTML('beforeend', makeFixedRow());
                        bindRemove(fixedContainer);
                    };
                    bindRemove(fixedContainer);
                }
            })();
        </script>

        <h2 class="mgr-section-title">قائمة المتاجر المسجلة</h2>
        <?php
        $search = isset($_GET['s']) ? trim(sanitize_text_field(wp_unslash($_GET['s']))) : '';
        ?>
        <form method="get" class="mgr-search" style="margin-bottom: 16px; display: flex; gap: 8px; align-items: center; flex-wrap: wrap;">
            <input type="hidden" name="page" value="merchant-data-manager">
            <input type="search" name="s" value="<?php echo esc_attr($search); ?>" placeholder="بحث بالاسم أو الإيميل أو المتجر أو رقم الهاتف..." style="padding: 8px 12px; border: 1px solid #cbd5e1; border-radius: 8px; font-size: 13px; width: 280px; max-width: 100%;">
            <button type="submit" class="mgr-btn mgr-btn-secondary" style="cursor: pointer;">بحث</button>
            <?php if ($search !== ''): ?>
                <a href="<?php echo esc_url(admin_url('admin.php?page=merchant-data-manager')); ?>" class="mgr-btn mgr-btn-secondary" style="text-decoration: none; display: inline-flex; align-items: center;">إلغاء البحث</a>
            <?php endif; ?>
        </form>
        <?php
        // فلترة المتاجر حسب البحث (الاسم، الإيميل، المتجر، رقم الهاتف، المدينة)
        $filtered_merchants = $merchants;
        if ($search !== '') {
            $search_lower = mb_strtolower($search, 'UTF-8');
            $filtered_merchants = [];
            foreach ($merchants as $email => $m) {
                $branch = mb_strtolower($m['branch_name'] ?? '', 'UTF-8');
                $owner = mb_strtolower($m['owner_name'] ?? '', 'UTF-8');
                $phone = $m['phone'] ?? '';
                $city_val = mb_strtolower($m['city'] ?? '', 'UTF-8');
                $email_lower = mb_strtolower($email, 'UTF-8');
                if (
                    mb_strpos($branch, $search_lower) !== false ||
                    mb_strpos($owner, $search_lower) !== false ||
                    mb_strpos($email_lower, $search_lower) !== false ||
                    mb_strpos($phone, $search) !== false ||
                    mb_strpos($city_val, $search_lower) !== false
                ) {
                    $filtered_merchants[$email] = $m;
                }
            }
        }

        $per_page = 20;
        $total_items = count($filtered_merchants);
        $total_pages = max(1, ceil($total_items / $per_page));
        $current_page = isset($_GET['paged']) ? max(1, min(intval($_GET['paged']), $total_pages)) : 1;
        $offset = ($current_page - 1) * $per_page;

        $paged_merchants = array_slice($filtered_merchants, $offset, $per_page, true);
        $grouped_merchants = [];
        foreach ($paged_merchants as $email => $m) {
            $grouped_merchants[$m['city']][] = $m;
        }
        ?>
        <div class="mgr-card">
            <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 12px; margin-bottom: 16px;">
                <div class="tablenav-pages">
                    <span class="displaying-num"><?php echo $total_items; ?> تاجر</span>
                    <?php if ($total_pages > 1): ?>
                        <span class="pagination-links" style="display: flex; gap: 4px; flex-wrap: wrap; margin-right: 12px;">
                            <?php for ($i = 1; $i <= $total_pages; $i++): ?>
                                <a class="mgr-btn <?php echo ($i == $current_page) ? '' : 'mgr-btn-secondary'; ?>" style="<?php echo ($i == $current_page) ? '' : 'background:#bae6fd;color:#0369a1;border:1px solid #bae6fd;'; ?>" href="<?php echo esc_url(add_query_arg('paged', $i)); ?>"><?php echo $i; ?></a>
                            <?php endfor; ?>
                        </span>
                    <?php endif; ?>
                </div>
            </div>
            <div style="overflow-x: auto;">
                <table class="mgr-table" id="merchant-table-body">
                    <thead>
                        <tr>
                            <th style="width: 4%;">#</th>
                            <th style="width: 12%;">المدينة</th>
                            <th style="width: 14%;">المتجر</th>
                            <th style="width: 14%;">اسم المالك</th>
                            <th style="width: 12%;">الهاتف</th>
                            <th style="width: 28%;">الإيميل</th>
                            <th style="width: 16%;">إجراءات</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php $i = $offset + 1;
                        foreach ($grouped_merchants as $city => $ms):
                            $first = $ms[0];
                        ?>
                            <tr>
                                <td style="text-align: right;"><?php echo $i++; ?></td>
                                <td style="text-align: right;"><strong><?php echo esc_html($city); ?></strong></td>
                                <td class="cell-branch" style="text-align: right;">
                                    <?php echo esc_html($first['branch_name']); ?>
                                </td>
                                <td class="cell-owner" style="text-align: right;"><?php echo esc_html($first['owner_name'] ?? 'غير محدد'); ?></td>
                                <td class="cell-phone" style="text-align: right;"><?php echo esc_html($first['phone'] ?? 'غير محدد'); ?></td>
                                <td>
                                    <div style="display: flex; align-items: center; gap: 8px; flex-direction: row-reverse;">
                                        <span style="font-size: 10px; color: #999; font-weight: normal;" title="عدد المتاجر في هذه المدينة">
                                            <?php echo count($ms); ?>
                                        </span>
                                        <select class="m-email-select" style="flex: 1; min-width: 0; width: 100%; padding: 8px 12px; border: 1px solid #cbd5e1; border-radius: 8px; font-size: 13px;">
                                            <?php foreach ($ms as $m): ?>
                                                <option value="<?php echo esc_attr($m['email']); ?>"
                                                    data-branch="<?php echo esc_attr($m['branch_name']); ?>"
                                                    data-owner="<?php echo esc_attr($m['owner_name'] ?? 'غير محدد'); ?>"
                                                    data-phone="<?php echo esc_attr($m['phone'] ?? 'غير محدد'); ?>"
                                                    data-del-url="<?php echo esc_url(wp_nonce_url('?page=merchant-data-manager&action=delete_merchant&email=' . urlencode($m['email']), 'libya_delete_merchant_' . $m['email'])); ?>">
                                                    <?php echo esc_html($m['email']); ?>
                                                </option>
                                            <?php endforeach; ?>
                                        </select>
                                    </div>
                                </td>
                                <td>
                                    <div style="display: flex; align-items: center; gap: 5px;">
                                        <a href="#" class="mgr-badge mgr-badge-edit btn-edit" style="text-decoration:none;padding:6px 12px;">تعديل</a>
                                        <a href="#" class="mgr-badge mgr-badge-delete btn-delete" style="text-decoration:none;padding:6px 12px;" onclick="return confirm('هل أنت متأكد من حذف هذا المتجر؟')">حذف</a>
                                    </div>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        </div>
        <script>
            jQuery(document).ready(function($) {
                $('.m-email-select').on('change', function() {
                    var opt = $(this).find(':selected');
                    var row = $(this).closest('tr');
                    row.find('.cell-branch').text(opt.data('branch'));
                    row.find('.cell-owner').text(opt.data('owner'));
                    row.find('.cell-phone').text(opt.data('phone'));
                });
                $('.btn-edit').on('click', function(e) {
                    e.preventDefault();
                    var email = $(this).closest('tr').find('.m-email-select').val();
                    window.location.href = '?page=merchant-data-manager&action=edit&email=' + encodeURIComponent(email);
                });
                $('.btn-delete').on('click', function(e) {
                    e.preventDefault();
                    var opt = $(this).closest('tr').find('.m-email-select option:selected');
                    if (confirm('هل أنت متأكد من حذف هذا المتجر؟')) {
                        window.location.href = opt.data('del-url');
                    }
                });
            });
        </script>

        <?php
        // ========================================================================
        // قسم إدارة الحسابات المصرفية (للمسؤول)
        // ========================================================================

        // جلب الحسابات المصرفية وبيانات التعديل
        $bank_accounts = get_option('libya_bank_accounts_v14', []);
        $edit_bank_id = (isset($_GET['action']) && $_GET['action'] === 'edit_bank' && isset($_GET['account_id'])) ? sanitize_text_field($_GET['account_id']) : '';
        $edit_bank_data = $edit_bank_id && isset($bank_accounts[$edit_bank_id]) ? $bank_accounts[$edit_bank_id] : null;
        ?>

        <h2 class="mgr-section-title">إدارة الحسابات المصرفية (للمسؤول)</h2>
        <p style="color: #6b7280; margin: -8px 0 20px; font-size: 14px;">الحسابات المصرفية التي تظهر لجميع التجار في صفحة التحويل المصرفي</p>

        <div class="mgr-card">
            <h2><?php echo $edit_bank_data ? 'تعديل حساب مصرفي' : 'إضافة حساب مصرفي جديد'; ?></h2>
            <form method="post">
                <div class="mgr-bank-form-row" style="display: flex; flex-wrap: wrap; gap: 16px; align-items: flex-end; margin-bottom: 16px;">
                    <div class="mgr-row" style="flex: 1 1 180px; min-width: 140px;">
                        <label for="bank_name">اسم المصرف</label>
                        <input type="text" name="bank_name" id="bank_name" value="<?php echo esc_attr($edit_bank_data['bank_name'] ?? ''); ?>" required placeholder="مثال: مصرف الأمان" style="width: 100%;">
                    </div>
                    <div class="mgr-row" style="flex: 1 1 160px; min-width: 130px;">
                        <label for="account_number">رقم الحساب</label>
                        <input type="text" name="account_number" id="account_number" value="<?php echo esc_attr($edit_bank_data['account_number'] ?? ''); ?>" required placeholder="مثال: 00123456789" maxlength="24" style="width: 100%;">
                    </div>
                    <div class="mgr-row" style="flex: 1 1 280px; min-width: 200px;">
                        <label for="bank_iban">رقم IBAN (اختياري)</label>
                        <input type="text" name="bank_iban" id="bank_iban" value="<?php echo esc_attr($edit_bank_data['iban'] ?? ''); ?>" placeholder="مثال: LY00123456789012345678901" maxlength="34" style="width: 100%;">
                    </div>
                </div>
                <div style="text-align: right; padding-bottom: 20px; margin-bottom: 0;">
                    <button type="submit" class="mgr-btn"><?php echo $edit_bank_data ? 'حفظ التعديلات' : 'إضافة الحساب'; ?></button>
                    <?php if ($edit_bank_data): ?><a href="?page=merchant-data-manager" class="mgr-btn mgr-btn-secondary" style="text-decoration:none;display:inline-flex;align-items:center;margin-right:8px;">إلغاء</a><?php endif; ?>
                </div>
                <?php if ($edit_bank_data): ?>
                    <input type="hidden" name="account_id" value="<?php echo esc_attr($edit_bank_id); ?>">
                <?php endif; ?>
                <input type="hidden" name="save_bank_account" value="1">
                <?php wp_nonce_field('libya_bank_account_save_action', 'libya_bank_account_nonce'); ?>
            </form>

            <h2 style="margin: 0 0 16px; padding-top: 20px; border-top: 2px solid #e2e8f0; font-size: 15px;">الحسابات المصرفية المضافة</h2>
            <?php if (!empty($bank_accounts)): ?>
                <div style="overflow-x: auto;">
                    <table class="mgr-table">
                        <thead>
                            <tr>
                                <th style="width: 5%;">#</th>
                                <th style="width: 28%;">اسم المصرف</th>
                                <th style="width: 22%;">رقم الحساب</th>
                                <th style="width: 30%;">IBAN</th>
                                <th style="width: 15%;">إجراءات</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php $counter = 1;
                            foreach ($bank_accounts as $acc_id => $acc): ?>
                                <tr>
                                    <td><?php echo $counter++; ?></td>
                                    <td><strong><?php echo esc_html($acc['bank_name']); ?></strong></td>
                                    <td><?php echo esc_html($acc['account_number']); ?></td>
                                    <td><?php echo !empty($acc['iban']) ? esc_html($acc['iban']) : '<span style="color: #9ca3af;">-</span>'; ?></td>
                                    <td>
                                        <a href="?page=merchant-data-manager&action=edit_bank&account_id=<?php echo urlencode($acc_id); ?>" class="mgr-badge mgr-badge-edit" style="text-decoration:none;margin-left:4px;">تعديل</a>
                                        <a href="<?php echo esc_url(wp_nonce_url('?page=merchant-data-manager&action=delete_bank_account&account_id=' . urlencode($acc_id), 'libya_delete_bank_account_' . $acc_id)); ?>" class="mgr-badge mgr-badge-delete" style="text-decoration:none;" onclick="return confirm('هل أنت متأكد من حذف هذا الحساب؟')">حذف</a>
                                    </td>
                                </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            <?php else: ?>
                <p style="text-align: center; color: #9ca3af; padding: 24px 0;">لا توجد حسابات مصرفية مضافة حتى الآن. استخدم النموذج أعلاه لإضافة حساب جديد.</p>
            <?php endif; ?>
        </div>

        <div class="mgr-card">
            <h2>إعدادات التوقيت والمهل العامة</h2>
            <p class="mgr-hint" style="margin-bottom: 20px;">تتحكم هذه المهل في وقت سحب الطلبات والمهل الإضافية لكل المتاجر.</p>

            <form method="post" action="">
                <?php wp_nonce_field('libya_global_timing_action', 'libya_global_timing_nonce'); ?>
                <div class="mgr-grid">
                    <div class="mgr-grid-col">
                        <div class="mgr-row">
                            <label>مهلة الطلب الأصلية (دقائق)</label>
                            <input type="number" name="global_deadline" value="<?php echo esc_attr(get_option('libya_def_deadline', '60')); ?>">
                            <p class="mgr-hint">الوقت المسموح به للتاجر لتسليم الطلب قبل تحويله تلقائياً.</p>
                        </div>
                    </div>
                    <div class="mgr-grid-col">
                        <div class="mgr-row">
                            <label>المهلة الإضافية بعد تأكيد الحضور (دقائق)</label>
                            <input type="number" name="global_extra_time" value="<?php echo esc_attr(get_option('libya_def_extra_time', '30')); ?>">
                            <p class="mgr-hint">الوقت الإضافي بعد ضغط التاجر على "أكد العميل الحضور".</p>
                        </div>
                    </div>
                </div>

                <div style="margin-top: 24px; padding-top: 20px; border-top: 1px solid #cbd5e1;">
                    <button type="submit" name="save_global_timing" class="mgr-btn">حفظ إعدادات التوقيت</button>
                </div>
            </form>
        </div>

    </div>
<?php
}




function render_admin_earnings_report_v14()
{
    $admin_notice = '';
    // --- إجراءات المدير ---
    if (isset($_POST['bulk_delete_earnings'])) {
        $to_delete = isset($_POST['order_ids']) ? array_map('intval', $_POST['order_ids']) : [];
        if (!empty($to_delete)) {
            $merchants = get_libya_merchants_v14();
            foreach ($merchants as $email => $m) {
                $recent = get_option("merchant_recent_orders_{$email}", []);
                $archive = get_option("merchant_archive_{$email}", []);
                $new_recent = array_diff($recent, $to_delete);
                $new_archive = array_diff($archive, $to_delete);
                update_option("merchant_recent_orders_{$email}", array_values($new_recent));
                update_option("merchant_archive_{$email}", array_values($new_archive));
            }
            $admin_notice = '<div class="libya-admin-success-notice"><p>تم حذف الطلبات المحددة بنجاح.</p></div>';
        }
    }
    if (isset($_POST['clear_all_earnings'])) {
        $merchants = get_libya_merchants_v14();
        foreach ($merchants as $email => $m) {
            update_option("merchant_recent_orders_{$email}", []);
            update_option("merchant_archive_{$email}", []);
            update_option("merchant_orders_count_{$email}", 0);
            update_option("merchant_total_sales_{$email}", 0);
        }
        $admin_notice = '<div class="libya-admin-success-notice"><p>تم تصفير كافة الكشوفات نهائياً.</p></div>';
    }
    $merchants = get_libya_merchants_v14();
    $all_orders = [];

    foreach ($merchants as $email => $m) {
        $recent = get_option("merchant_recent_orders_{$email}", []);
        $archive = get_option("merchant_archive_{$email}", []);
        $combined = array_unique(array_merge($recent, $archive));

        foreach ($combined as $order_id) {
            $order = wc_get_order($order_id);
            if (!$order) continue;

            $val = (float)$order->get_total();
            $breakdown = get_libya_merchant_commission_breakdown_v14($val, $m);
            $comm = (float)$breakdown['total'];
            $percentage_part = $breakdown['percentage'];
            $fixed = $breakdown['fixed'];

            $order_date = $order->get_date_created()->date('Y-m-d H:i');
            $order_timestamp = $order->get_date_created()->getTimestamp();

            $all_orders[] = [
                'id' => $order_id,
                'merchant_name' => $m['branch_name'],
                'merchant_city' => $m['city'],
                'order_total' => $val,
                'date' => $order_date,
                'timestamp' => $order_timestamp,
                'percentage' => $percentage_part,
                'fixed' => $fixed,
                'total_comm' => $comm
            ];
        }
    }

    // فرز الطلبات حسب التاريخ (الأحدث أولاً) - تحسين الأداء باستخدام timestamp بدلاً من strtotime
    usort($all_orders, function ($a, $b) {
        return $b['timestamp'] - $a['timestamp'];
    });

    $per_page = 20;
    $total_items = count($all_orders);
    $total_pages = ceil($total_items / $per_page);
    $current_page = isset($_GET['paged']) ? max(1, intval($_GET['paged'])) : 1;
    $offset = ($current_page - 1) * $per_page;
    $paged_orders = array_slice($all_orders, $offset, $per_page);


    // حساب الإحصائيات الكلية
    $grand_total_sales = 0;
    $grand_total_percentage = 0;
    $grand_total_fixed = 0;
    $grand_total_commission = 0;

    foreach ($all_orders as $o) {
        $grand_total_sales += $o['order_total'];
        $grand_total_percentage += $o['percentage'];
        $grand_total_fixed += $o['fixed'];
        $grand_total_commission += $o['total_comm'];
    }

?>
    <style>
        .libya-earnings {
            direction: rtl;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 1000px;
            margin: 20px auto 40px;
            padding: 0 16px;
        }

        .libya-earnings * {
            box-sizing: border-box;
        }

        .libya-earnings .mgr-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            flex-wrap: wrap;
            gap: 12px;
            margin-bottom: 24px;
            padding-bottom: 20px;
            border-bottom: 2px solid #04acf4;
        }

        .libya-earnings .mgr-title {
            margin: 0;
            font-size: 20px;
            font-weight: 700;
            color: #0284c7;
        }

        .libya-earnings .mgr-back {
            display: inline-flex;
            align-items: center;
            padding: 6px 12px;
            background: #f0f9ff;
            color: #0369a1;
            text-decoration: none;
            border-radius: 8px;
            font-size: 13px;
            font-weight: 500;
            border: 1px solid #bae6fd;
            transition: background .15s, color .15s;
        }

        .libya-earnings .mgr-back:hover {
            background: #bae6fd;
            color: #0284c7;
        }

        .libya-earnings .mgr-card {
            background: #fff;
            border: 1px solid #bae6fd;
            border-radius: 12px;
            padding: 20px;
            margin-bottom: 20px;
            box-shadow: 0 2px 8px rgba(0, 0, 0, .08);
            border-right: 4px solid #04acf4;
        }

        .libya-earnings .mgr-stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(130px, 1fr));
            gap: 12px;
        }

        .libya-earnings .mgr-stat {
            background: linear-gradient(135deg, #0284c7, #04acf4);
            color: #fff;
            padding: 14px;
            border-radius: 10px;
            text-align: center;
        }

        .libya-earnings .mgr-stat:nth-child(2) {
            background: linear-gradient(135deg, #0369a1, #0284c7);
        }

        .libya-earnings .mgr-stat:nth-child(3) {
            background: linear-gradient(135deg, #059669, #10b981);
        }

        .libya-earnings .mgr-stat:nth-child(4) {
            background: linear-gradient(135deg, #0d9488, #14b8a6);
        }

        .libya-earnings .mgr-stat:nth-child(5) {
            background: linear-gradient(135deg, #7c3aed, #8b5cf6);
        }

        .libya-earnings .mgr-stat .label {
            font-size: 11px;
            opacity: 0.95;
            margin-bottom: 4px;
        }

        .libya-earnings .mgr-stat .val {
            font-size: 18px;
            font-weight: 700;
        }

        .libya-earnings .mgr-table {
            width: 100%;
            border-collapse: collapse;
            font-size: 12px;
        }

        .libya-earnings .mgr-table th,
        .libya-earnings .mgr-table td {
            padding: 10px 8px;
            text-align: right;
            border-bottom: 1px solid #d1d5db;
        }

        .libya-earnings .mgr-table th {
            background: #f8fafc;
            color: #4a5568;
            font-weight: 600;
        }

        .libya-earnings .mgr-table tr:hover {
            background: #f9fafb;
        }

        .libya-earnings .mgr-table tr.mgr-total-row {
            background: #f0f9ff;
            font-weight: 600;
            color: #0369a1;
        }

        .libya-earnings .mgr-btn {
            padding: 8px 18px;
            background: linear-gradient(135deg, #0284c7, #04acf4);
            color: #fff;
            border: none;
            border-radius: 8px;
            font-weight: 600;
            font-size: 13px;
            cursor: pointer;
            text-decoration: none;
            display: inline-flex;
            align-items: center;
        }

        .libya-earnings .mgr-btn:hover {
            opacity: 0.95;
        }

        .libya-earnings .mgr-btn-secondary {
            background: #f8fafc;
            color: #475569;
            border: 1px solid #cbd5e1;
        }

        .libya-earnings .mgr-btn-danger {
            background: transparent;
            color: #dc2626;
            border: 1px solid #fecaca;
        }

        .libya-earnings .mgr-btn-danger:hover {
            background: #fee2e2;
        }

        .libya-earnings .tablenav-pages {
            margin: 12px 0;
            display: flex;
            align-items: center;
            gap: 10px;
            flex-wrap: wrap;
        }

        .libya-earnings .tablenav-pages .displaying-num {
            font-size: 12px;
            color: #6b7280;
        }

        .libya-earnings .tablenav-pages .pagination-links .mgr-btn {
            padding: 6px 12px;
            font-size: 12px;
        }

        @media (max-width: 600px) {
            .libya-earnings {
                max-width: 100%;
                padding: 0 12px;
            }

            .libya-earnings .mgr-card {
                padding: 16px;
            }

            .libya-earnings .mgr-stats {
                grid-template-columns: repeat(2, 1fr);
            }

            .libya-earnings .mgr-stat .val {
                font-size: 16px;
            }

            .libya-earnings .mgr-table th,
            .libya-earnings .mgr-table td {
                padding: 8px 6px;
                font-size: 11px;
            }
        }
    </style>
    <div class="wrap libya-earnings">
        <div class="mgr-header">
            <a href="<?php echo esc_url(admin_url('admin.php?page=merchant-main-dashboard')); ?>" class="mgr-back">← رجوع للرئيسية</a>
            <h1 class="mgr-title">كشف الإيرادات</h1>
        </div>
        <?php if ($admin_notice) {
            echo $admin_notice;
        } ?>
        <p class="mgr-desc" style="margin: 0 0 16px; padding: 10px 14px; background: #f0f9ff; border: 1px solid #bae6fd; border-radius: 8px; font-size: 13px; color: #0369a1;">الأعمدة «النسبة %» و«عمولة ثابتة» تُحسب من <strong>شرائح كل تاجر</strong> المحفوظة في بياناته (إدارة المتاجر → تعديل التاجر). إذا ظهرت أرقام غير صفرية رغم أن الإعداد الافتراضي 0، فذلك لأن للتاجر شرائح خاصة محفوظة مسبقاً.</p>

        <div class="mgr-card">
            <div class="mgr-stats">
                <div class="mgr-stat">
                    <div class="label">إجمالي المبيعات</div>
                    <div class="val"><?php echo wc_price($grand_total_sales); ?></div>
                </div>
                <div class="mgr-stat">
                    <div class="label">عمولة النسبة المئوية</div>
                    <div class="val"><?php echo wc_price($grand_total_percentage); ?></div>
                </div>
                <div class="mgr-stat">
                    <div class="label">العمولة الثابتة</div>
                    <div class="val"><?php echo wc_price($grand_total_fixed); ?></div>
                </div>
                <div class="mgr-stat">
                    <div class="label">إجمالي الأرباح</div>
                    <div class="val"><?php echo wc_price($grand_total_commission); ?></div>
                </div>
                <div class="mgr-stat">
                    <div class="label">عدد الطلبات</div>
                    <div class="val"><?php echo number_format($total_items); ?></div>
                </div>
            </div>
        </div>

        <div class="mgr-card">
            <form method="post">
                <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 12px; margin-bottom: 16px;">
                    <div style="display: flex; gap: 8px; flex-wrap: wrap;">
                        <button type="submit" name="bulk_delete_earnings" class="mgr-btn mgr-btn-secondary" onclick="return confirm('هل أنت متأكد من حذف الطلبات المحددة؟')">حذف المحدد</button>
                        <button type="submit" name="export_earnings_csv" class="mgr-btn">تصدير إلى Excel (CSV)</button>
                        <?php wp_nonce_field('libya_export_csv'); ?>
                    </div>
                    <div class="tablenav-pages">
                        <span class="displaying-num"><?php echo $total_items; ?> طلب</span>
                        <?php if ($total_pages > 1): ?>
                            <span class="pagination-links" style="display: flex; gap: 4px; flex-wrap: wrap;">
                                <?php for ($i = 1; $i <= $total_pages; $i++): ?>
                                    <a class="mgr-btn <?php echo ($i == $current_page) ? '' : 'mgr-btn-secondary'; ?>" style="<?php echo ($i == $current_page) ? '' : 'background:#bae6fd;color:#0369a1;border:1px solid #bae6fd;'; ?>" href="<?php echo add_query_arg('paged', $i); ?>"><?php echo $i; ?></a>
                                <?php endfor; ?>
                            </span>
                        <?php endif; ?>
                    </div>
                </div>

                <div style="overflow-x: auto;">
                    <table class="mgr-table">
                        <thead>
                            <tr>
                                <th style="width: 28px;"><input type="checkbox" id="select_all_earnings"></th>
                                <th style="width: 36px;">#</th>
                                <th>رقم الطلب</th>
                                <th>التاجر</th>
                                <th>المدينة</th>
                                <th>إجمالي الطلب</th>
                                <th>النسبة %</th>
                                <th>عمولة ثابتة</th>
                                <th>إجمالي الربح</th>
                                <th>التاريخ</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php
                            $sum_order_total = 0;
                            $sum_percentage = 0;
                            $sum_fixed = 0;
                            $sum_total_comm = 0;
                            $row_num = $offset + 1;
                            foreach ($paged_orders as $o):
                                $sum_order_total += $o['order_total'];
                                $sum_percentage += $o['percentage'];
                                $sum_fixed += $o['fixed'];
                                $sum_total_comm += $o['total_comm'];
                            ?>
                                <tr>
                                    <td><input type="checkbox" name="order_ids[]" value="<?php echo $o['id']; ?>" class="earning_chk"></td>
                                    <td><?php echo $row_num++; ?></td>
                                    <td><a href="<?php echo esc_url(get_edit_post_link($o['id'])); ?>" target="_blank" style="color: #2271b1; font-weight: 600; text-decoration: none;">#<?php echo $o['id']; ?></a></td>
                                    <td><?php echo esc_html($o['merchant_name']); ?></td>
                                    <td><?php echo esc_html($o['merchant_city']); ?></td>
                                    <td><?php echo wc_price($o['order_total']); ?></td>
                                    <td><?php echo wc_price($o['percentage']); ?></td>
                                    <td><?php echo wc_price($o['fixed']); ?></td>
                                    <td><strong><?php echo wc_price($o['total_comm']); ?></strong></td>
                                    <td><?php echo $o['date']; ?></td>
                                </tr>
                            <?php endforeach; ?>
                            <tr class="mgr-total-row">
                                <td colspan="5">المجموع في هذه الصفحة</td>
                                <td><?php echo wc_price($sum_order_total); ?></td>
                                <td><?php echo wc_price($sum_percentage); ?></td>
                                <td><?php echo wc_price($sum_fixed); ?></td>
                                <td><?php echo wc_price($sum_total_comm); ?></td>
                                <td></td>
                            </tr>
                        </tbody>
                    </table>
                </div>

                <div style="margin-top: 16px; text-align: left;">
                    <button type="submit" name="clear_all_earnings" class="mgr-btn mgr-btn-danger" onclick="return confirm('تحذير: سيتم تصفير كافة الكشوفات نهائياً. هل أنت متأكد؟')">تصفير الكشف نهائياً</button>
                </div>
            </form>
        </div>

        <script>
            document.getElementById('select_all_earnings').onclick = function() {
                var checkboxes = document.getElementsByClassName('earning_chk');
                for (var checkbox of checkboxes) {
                    checkbox.checked = this.checked;
                }
            }
        </script>
    </div>
<?php
}




function render_merchant_performance_v14()
{
    // معالج مسح تحليل أداء متجر واحد
    if (isset($_GET['libya_clear_perf']) && isset($_GET['email']) && current_user_can('manage_options')) {
        $em = sanitize_email(wp_unslash($_GET['email']));
        if (wp_verify_nonce(isset($_GET['_wpnonce']) ? $_GET['_wpnonce'] : '', 'libya_clear_perf_' . $em)) {
            $prefixes = [
                LIBYA_PERF_MANUAL_TRANSFERS, LIBYA_PERF_AUTO_TRANSFERS,
                LIBYA_PERF_MANUAL_DELIVERIES, LIBYA_PERF_AUTO_DELIVERIES,
                LIBYA_PERF_FAILED_DELIVERIES, LIBYA_PERF_RESPONSE_TIME,
                LIBYA_PERF_RESPONSE_COUNT, LIBYA_PERF_DELIVERY_TIME,
                LIBYA_PERF_DELIVERY_COUNT, LIBYA_PERF_TOTAL_CLAIMS,
            ];
            foreach ($prefixes as $p) {
                delete_option($p . $em);
            }
            wp_safe_redirect(admin_url('admin.php?page=merchant-performance&perf_cleared=1'));
            exit;
        }
    }

    $merchants = get_libya_merchants_v14();

    // فلترة المتاجر حسب البحث
    $search = isset($_GET['s']) ? trim(sanitize_text_field(wp_unslash($_GET['s']))) : '';
    $filtered_merchants = $merchants;
    if ($search !== '') {
        $search_lower = mb_strtolower($search, 'UTF-8');
        $filtered_merchants = [];
        foreach ($merchants as $email => $m) {
            $branch = mb_strtolower($m['branch_name'] ?? '', 'UTF-8');
            $city_val = mb_strtolower($m['city'] ?? '', 'UTF-8');
            if (mb_strpos($branch, $search_lower) !== false || mb_strpos($city_val, $search_lower) !== false || mb_strpos($email, $search_lower) !== false) {
                $filtered_merchants[$email] = $m;
            }
        }
    }

?>
    <style>
        .libya-perf-dashboard {
            direction: rtl;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 1200px;
            margin: 20px auto 40px;
            padding: 0 16px;
        }

        .perf-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 24px;
            padding-bottom: 15px;
            border-bottom: 3px solid #0284c7;
        }

        .perf-title {
            margin: 0;
            font-size: 24px;
            color: #0284c7;
            font-weight: 800;
        }

        .perf-grid {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 20px;
        }

        .perf-card {
            background: #fff;
            border-radius: 12px;
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.05);
            border: 1px solid #e2e8f0;
            overflow: hidden;
            transition: transform 0.2s;
        }

        .perf-card:hover {
            transform: translateY(-3px);
        }

        .perf-card-header {
            background: #7d9a7d;
            color: #fff;
            padding: 10px 12px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .perf-card-header h3 {
            margin: 0;
            font-size: 14px;
            font-weight: 700;
            color: #fff;
        }

        .perf-body {
            padding: 12px 14px;
        }

        .perf-stat-row {
            display: flex;
            justify-content: space-between;
            margin-bottom: 8px;
            padding-bottom: 6px;
            border-bottom: 1px dashed #e2e8f0;
        }

        .perf-label {
            color: #64748b;
            font-size: 11px;
            display: flex;
            align-items: center;
            gap: 6px;
        }

        .perf-value {
            font-weight: 700;
            color: #1e293b;
            font-size: 12px;
        }

        .perf-badge {
            padding: 2px 8px;
            border-radius: 12px;
            font-size: 11px;
            font-weight: 600;
        }

        .badge-manual {
            background: #dcfce7;
            color: #166534;
        }

        .badge-auto {
            background: #fee2e2;
            color: #991b1b;
        }

        .badge-time {
            background: #f0f9ff;
            color: #0369a1;
        }

        .perf-footer {
            background: #f8fafc;
            padding: 8px 14px;
            border-top: 1px solid #e2e8f0;
            text-align: center;
            display: flex;
            justify-content: center;
            align-items: center;
            gap: 8px;
            flex-wrap: wrap;
        }

        .perf-btn-clear {
            font-size: 11px;
            padding: 4px 10px;
            background: #fef2f2;
            color: #b91c1c;
            border: 1px solid #fecaca;
            border-radius: 6px;
            text-decoration: none;
            font-weight: 600;
            transition: background 0.2s, color 0.2s;
        }

        .perf-btn-clear:hover {
            background: #fee2e2;
            color: #991b1b;
        }

        .perf-search-form {
            margin-bottom: 20px;
            display: flex;
            gap: 10px;
        }

        .perf-search-form input {
            padding: 10px;
            border-radius: 8px;
            border: 1px solid #cbd5e1;
            width: 300px;
        }

        .perf-btn {
            background: #0284c7;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 8px;
            cursor: pointer;
            font-weight: 600;
            text-decoration: none;
        }

        .speed-indicator {
            height: 6px;
            background: #e2e8f0;
            border-radius: 3px;
            margin-top: 5px;
            overflow: hidden;
        }

        .speed-fill {
            height: 100%;
            border-radius: 3px;
        }

        .speed-fast {
            background: #22c55e;
        }

        .speed-medium {
            background: #eab308;
        }

        .speed-slow {
            background: #ef4444;
        }

        .star-rating {
            display: flex;
            gap: 2px;
            color: #fbbf24;
            font-size: 14px;
        }

        .star-value {
            font-size: 11px;
            color: #fff;
            background: rgba(0, 0, 0, 0.2);
            padding: 2px 6px;
            border-radius: 4px;
            margin-right: 5px;
        }

        @media (max-width: 600px) {
            .perf-grid {
                grid-template-columns: 1fr;
            }

            .perf-search-form {
                flex-direction: column;
            }

            .perf-search-form input {
                width: 100%;
            }
        }
    </style>

    <div class="wrap libya-perf-dashboard">
        <div class="perf-header">
            <h1 class="perf-title">إحصائيات أداء التجار</h1>
            <div style="font-size: 13px; color: #64748b; font-weight: 600;">بناءً على نشاط الـ 30 يوماً الماضية</div>
        </div>
        <?php if (isset($_GET['perf_cleared']) && $_GET['perf_cleared'] === '1') : ?>
            <p style="margin: 0 0 16px; padding: 10px 14px; background: #ecfdf5; border: 1px solid #a7f3d0; border-radius: 8px; color: #065f46; font-size: 13px;">تم مسح تحليل أداء المتجر والبدء من جديد.</p>
        <?php endif; ?>

        <form method="get" class="perf-search-form">
            <input type="hidden" name="page" value="merchant-performance">
            <input type="search" name="s" value="<?php echo esc_attr($search); ?>" placeholder="بحث باسم المتجر، المدينة، أو البريد...">
            <button type="submit" class="perf-btn">بحث</button>
            <?php if ($search) : ?>
                <a href="?page=merchant-performance" class="perf-btn" style="background:#64748b">إلغاء</a>
            <?php endif; ?>
        </form>

        <div class="perf-grid">
            <?php if (empty($filtered_merchants)) : ?>
                <div style="grid-column: 1/-1; text-align: center; padding: 50px; background: #fff; border-radius: 12px; border: 2px dashed #cbd5e1; color: #64748b;">
                    لا يوجد بيانات لعرضها حالياً.
                </div>
            <?php else : ?>
                <?php foreach ($filtered_merchants as $email => $m) :
                    // جلب الإحصائيات
                    $m_trans_man = (int)get_option(LIBYA_PERF_MANUAL_TRANSFERS . $email, 0);
                    $m_trans_auto = (int)get_option(LIBYA_PERF_AUTO_TRANSFERS . $email, 0);
                    $m_deliv_man = (int)get_option(LIBYA_PERF_MANUAL_DELIVERIES . $email, 0);
                    $m_deliv_auto = (int)get_option(LIBYA_PERF_AUTO_DELIVERIES . $email, 0);
                    $m_failed = (int)get_option(LIBYA_PERF_FAILED_DELIVERIES . $email, 0);
                    $m_total_claims = (int)get_option(LIBYA_PERF_TOTAL_CLAIMS . $email, 0);

                    $total_resp_time = (int)get_option(LIBYA_PERF_RESPONSE_TIME . $email, 0);
                    $resp_count = (int)get_option(LIBYA_PERF_RESPONSE_COUNT . $email, 0);
                    $avg_resp = $resp_count > 0 ? round($total_resp_time / $resp_count) : 0;

                    $total_deliv_time = (int)get_option(LIBYA_PERF_DELIVERY_TIME . $email, 0);
                    $deliv_count = (int)get_option(LIBYA_PERF_DELIVERY_COUNT . $email, 0);
                    $avg_deliv = $deliv_count > 0 ? round($total_deliv_time / $deliv_count) : 0;

                    // خوارزمية التقييم (من 5 نجوم)
                    $score = 0;
                    // 1. سرعة الرد (ما يصل إلى 2.0 نجوم)
                    if ($avg_resp > 0) {
                        if ($avg_resp < 120) $score += 2.0;    // أقل من دقيقتين
                        elseif ($avg_resp < 300) $score += 1.5; // 5 دقائق
                        elseif ($avg_resp < 600) $score += 1.0; // 10 دقائق
                        else $score += 0.5;
                    }
                    // 2. نسبة النجاح (ما يصل إلى 2.0 نجوم)
                    $total_final_ops = $m_deliv_man + $m_failed;
                    if ($total_final_ops > 0) {
                        $success_ratio = $m_deliv_man / $total_final_ops;
                        $score += ($success_ratio * 2.0);
                    }
                    // 3. النشاط وقبول الطلبات (ما يصل إلى 1.0 نجمة)
                    if ($m_total_claims > 0) {
                        $score += min(1.0, ($m_total_claims / 10)); // نجمة كاملة بعد 10 طلبات مقبولة
                    }
                    $stars_val = round($score, 1);
                    $full_stars = floor($stars_val);
                    $has_half = ($stars_val - $full_stars) >= 0.5;

                    // دوال مساعدة للتنسيق داخل الحلقة
                    $format_time = function ($seconds) {
                        if ($seconds <= 0) return '---';
                        $m = floor($seconds / 60);
                        $s = $seconds % 60;
                        return ($m > 0 ? $m . 'د ' : '') . $s . 'ث';
                    };
                $perf_card_color = !empty($m['card_color']) ? $m['card_color'] : '#7d9a7d';
                ?>
                    <div class="perf-card">
                        <div class="perf-card-header" style="background: <?php echo esc_attr($perf_card_color); ?>;">
                            <div>
                                <h3><?php echo esc_html($m['branch_name']); ?></h3>
                                <span style="font-size: 11px; opacity: 0.9;"><?php echo esc_html($m['city']); ?></span>
                            </div>
                            <div style="text-align: left;">
                                <div class="star-rating">
                                    <span class="star-value"><?php echo esc_html($stars_val); ?></span>
                                    <?php
                                    for ($i = 1; $i <= 5; $i++) {
                                        if ($i <= $full_stars) {
                                            echo '<span class="dashicons dashicons-star-filled"></span>';
                                        } elseif ($i == $full_stars + 1 && $has_half) {
                                            echo '<span class="dashicons dashicons-star-half"></span>';
                                        } else {
                                            echo '<span class="dashicons dashicons-star-empty"></span>';
                                        }
                                    }
                                    ?>
                                </div>
                            </div>
                        </div>
                        <div class="perf-body">
                            <!-- قبول الطلبات -->
                            <div class="perf-stat-row">
                                <span class="perf-label">
                                    <span class="dashicons dashicons-yes-alt" style="font-size: 14px;"></span>
                                    إجمالي قبول الطلبات (متوفر)
                                </span>
                                <span class="perf-value" style="color:#0284c7; font-size: 12px;"><?php echo $m_total_claims; ?></span>
                            </div>

                            <!-- سرعة الاستجابة -->
                            <div class="perf-stat-row">
                                <span class="perf-label">
                                    <span class="dashicons dashicons-clock" style="font-size: 14px;"></span>
                                    متوسط سرعة الرد (قبول الطلب)
                                </span>
                                <span class="perf-value badge-time"><?php echo $format_time($avg_resp); ?></span>
                            </div>
                            <div class="speed-indicator">
                                <div class="speed-fill <?php echo ($avg_resp < 120 ? 'speed-fast' : ($avg_resp < 300 ? 'speed-medium' : 'speed-slow')); ?>" style="width: <?php echo min(100, ($avg_resp > 0 ? (600 / ($avg_resp ?: 1)) * 20 : 0)); ?>%"></div>
                            </div>
                            <br>

                            <!-- سرعة التسليم -->
                            <div class="perf-stat-row">
                                <span class="perf-label">
                                    <span class="dashicons dashicons-id-alt" style="font-size: 14px;"></span>
                                    متوسط وقت التسليم (من الاستلام)
                                </span>
                                <span class="perf-value badge-time"><?php echo $format_time($avg_deliv); ?></span>
                            </div>
                            <br>

                            <!-- التحويلات -->
                            <div class="perf-stat-row">
                                <span class="perf-label">التحويل اليدوي (اعتذار سريع)</span>
                                <span class="perf-value badge-manual"><?php echo $m_trans_man; ?></span>
                            </div>
                            <div class="perf-stat-row">
                                <span class="perf-label">التحويل التلقائي (إهمال التاجر)</span>
                                <span class="perf-value badge-auto"><?php echo $m_trans_auto; ?></span>
                            </div>

                            <!-- التسليم -->
                            <div class="perf-stat-row" style="margin-top: 15px;">
                                <span class="perf-label">تسليم يدوي (تاجر مهتم)</span>
                                <span class="perf-value badge-manual"><?php echo $m_deliv_man; ?></span>
                            </div>
                            <div class="perf-stat-row">
                                <span class="perf-label">تسليم تلقائي (نسيان التحديث)</span>
                                <span class="perf-value badge-auto"><?php echo $m_deliv_auto; ?></span>
                            </div>

                            <!-- تعذر التسليم -->
                            <div class="perf-stat-row" style="border-bottom: none; margin-top: 10px;">
                                <span class="perf-label" style="color: #ef4444;">تعذر التسليم (إلغاء طلبات)</span>
                                <span class="perf-value" style="color: #ef4444;"><?php echo $m_failed; ?></span>
                            </div>
                        </div>
                        <div class="perf-footer">
                            <a href="<?php echo esc_attr(admin_url('admin.php?page=merchant-details&email=' . urlencode($email))); ?>" class="perf-btn" style="font-size: 11px; padding: 4px 12px;">عرض ملف التاجر</a>
                            <a href="<?php echo esc_url(wp_nonce_url(admin_url('admin.php?page=merchant-performance&libya_clear_perf=1&email=' . urlencode($email)), 'libya_clear_perf_' . $email)); ?>" class="perf-btn-clear" onclick="return confirm('مسح تحليل أداء هذا المتجر والبدء من جديد؟');">مسح التحليل</a>
                        </div>
                    </div>
                <?php endforeach; ?>
            <?php endif; ?>
        </div>
    </div>
<?php
}

function render_merchant_details_page_v14()
{
    $email = sanitize_email($_GET['email']);
    $city = sanitize_text_field($_GET['city']);
    $merchants = get_libya_merchants_v14();
    $m = $merchants[$email] ?? null;

    if (!$m) wp_die('التاجر غير موجود.');

    if (isset($_POST['archive_orders'])) {
        $recent = get_option("merchant_recent_orders_{$email}", []);
        $archive = get_option("merchant_archive_{$email}", []);
        $new_archive = array_unique(array_merge($archive, $recent));
        update_option("merchant_archive_{$email}", $new_archive);
        update_option("merchant_orders_count_{$email}", 0);
        update_option("merchant_total_sales_{$email}", 0);
        update_option("merchant_recent_orders_{$email}", []);
        update_option("merchant_payment_completed_{$email}", time());
        delete_option("merchant_limit_notified_{$email}");
        echo '<div class="updated"><p>تمت أرشفة الطلبات وتصفير الحساب بنجاح.</p></div>';
    }

    if (isset($_POST['clear_archive'])) {
        update_option("merchant_archive_{$email}", []);
        echo '<div class="updated"><p>تم تصفير سجل الأرشيف نهائياً.</p></div>';
    }

    if (isset($_POST['notify_merchant'])) {
        $recent = get_option("merchant_recent_orders_{$email}", []);
        $total_comm_due = 0;
        foreach ($recent as $oid) {
            $o = wc_get_order($oid);
            if ($o) $total_comm_due += calculate_libya_merchant_commission_v14($o->get_total(), $m);
        }

        // إنشاء رابط بصمّة مؤقتة (token) لضمان عمل الرابط حتى لو أزل البريد/nonce المعاملات
        $pay_token = bin2hex(random_bytes(24));
        set_transient('libya_pay_token_' . $pay_token, ['email' => $email, 'created' => time()], 86400);
        $base_url = home_url('/');
        $url_pay_page = add_query_arg([
            'libya_action' => 'bank_transfer_page',
            'm_email'      => $email,
            'pay_token'    => $pay_token
        ], $base_url);

        $m_msg = "
        <div style='text-align: right; line-height: 1.6;'>
            <p>مرحباً عزيزي: <strong>{$m['branch_name']}</strong></p>
            <p>نعتذر، لم نستلم القيمة المستحقة بعد.</p>
            <hr style='border: 0; border-top: 1px solid #cbd5e1; margin: 15px 0;'>
            <p><strong>ملخص الحساب:</strong></p>
            <p>• عدد الطلبات: " . count($recent) . "</p>
            <p>• القيمة المستحقة: <strong>" . wc_price($total_comm_due) . "</strong></p>
            <hr style='border: 0; border-top: 1px solid #cbd5e1; margin: 15px 0;'>
            <div style='margin-top: 20px; text-align: center;'>
                <p style='font-size: 13px; color: #4a5568; margin-bottom: 10px; line-height: 1.4;'>• يرجى تحويل القيمة إلى أحد حساباتنا المصرفية عبر الضغط على هذا الزر</p>
                <div style='display: inline-block; width: 100%; max-width: 300px;'>
                    " . get_libya_btn_v14("تحويل القيمة", $url_pay_page, "green") . "
                </div>
            </div>
            <p style='margin-top: 15px; font-size: 12px; color: #666;'>شكراً لك.</p>
        </div>";

        wp_mail($email, "تنبيه: لم يتم استلام القيمة", get_libya_msg_template_v14("تنبيه الاستلام", $m_msg, "المعتمد | 0914479920", "warning"), ['Content-Type: text/html; charset=UTF-8']);

        echo '<div class="updated"><p>تم إرسال التنبيه للمتجر بنجاح. القيمة المستحقة: ' . wc_price($total_comm_due) . '</p></div>';
    }
    if (isset($_POST['bulk_delete_merchant_orders'])) {
        $to_delete = isset($_POST['order_ids']) ? array_map('intval', $_POST['order_ids']) : [];
        if (!empty($to_delete)) {
            $recent = get_option("merchant_recent_orders_{$email}", []);
            $archive = get_option("merchant_archive_{$email}", []);
            update_option("merchant_recent_orders_{$email}", array_values(array_diff($recent, $to_delete)));
            update_option("merchant_archive_{$email}", array_values(array_diff($archive, $to_delete)));
            echo '<div class="updated"><p>تم حذف الطلبات المحددة بنجاح.</p></div>';
        }
    }

    $recent_ids = get_option("merchant_recent_orders_{$email}", []);
    if (!is_array($recent_ids)) $recent_ids = [];
    // تنظيف المصفوفة من أي قيم غير صالحة أو مكررة لضمان دقة العرض لجميع التجار
    $recent_ids = array_filter(array_unique($recent_ids));

    $archive_ids = get_option("merchant_archive_{$email}", []);
    if (!is_array($archive_ids)) $archive_ids = [];
    $archive_ids = array_filter(array_unique($archive_ids));
    // ترقيم سجل الأرشيف: 20 عنصراً في الصفحة
    $archive_per_page = 20;
    $archive_ids_reversed = array_reverse($archive_ids);
    $archive_total_items = count($archive_ids_reversed);
    $archive_total_pages = $archive_total_items > 0 ? (int) ceil($archive_total_items / $archive_per_page) : 1;
    $archive_paged = isset($_GET['archive_paged']) ? max(1, min((int) $_GET['archive_paged'], $archive_total_pages)) : 1;
    $archive_offset = ($archive_paged - 1) * $archive_per_page;
    $archive_ids_page = array_slice($archive_ids_reversed, $archive_offset, $archive_per_page);
    $details_base_url = admin_url('admin.php?page=merchant-details&email=' . urlencode($email) . '&city=' . urlencode($city));
?>
    <style>
        .libya-details {
            direction: rtl;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 1000px;
            margin: 20px auto 40px;
            padding: 0 16px;
        }

        .libya-details * {
            box-sizing: border-box;
        }

        .libya-details .mgr-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            flex-wrap: wrap;
            gap: 12px;
            margin-bottom: 24px;
            padding-bottom: 20px;
            border-bottom: 2px solid #04acf4;
        }

        .libya-details .mgr-title {
            margin: 0;
            font-size: 20px;
            font-weight: 700;
            color: #0284c7;
        }

        .libya-details .mgr-back {
            display: inline-flex;
            align-items: center;
            padding: 6px 12px;
            background: #f0f9ff;
            color: #0369a1;
            text-decoration: none;
            border-radius: 8px;
            font-size: 13px;
            font-weight: 500;
            border: 1px solid #bae6fd;
            transition: background .15s, color .15s;
        }

        .libya-details .mgr-back:hover {
            background: #bae6fd;
            color: #0284c7;
        }

        .libya-details .mgr-card {
            background: #fff;
            border: 1px solid #bae6fd;
            border-radius: 12px;
            padding: 20px;
            margin-bottom: 20px;
            box-shadow: 0 2px 8px rgba(0, 0, 0, .08);
            border-right: 4px solid #04acf4;
        }

        .libya-details .mgr-card h2 {
            margin: 0 0 16px;
            font-size: 15px;
            font-weight: 600;
            color: #0284c7;
            padding-bottom: 8px;
            border-bottom: 1px solid #bae6fd;
        }

        .libya-details .mgr-btn {
            padding: 8px 18px;
            background: linear-gradient(135deg, #0284c7, #04acf4);
            color: #fff;
            border: none;
            border-radius: 8px;
            font-weight: 600;
            font-size: 13px;
            cursor: pointer;
        }

        .libya-details .mgr-btn:hover {
            opacity: 0.95;
        }

        .libya-details .mgr-btn-secondary {
            background: #f8fafc;
            color: #475569;
            border: 1px solid #cbd5e1;
        }

        .libya-details .mgr-btn-danger {
            background: #dc3545;
            color: #fff;
            border: 1px solid #dc3545;
        }

        .libya-details .mgr-table {
            width: 100%;
            border-collapse: collapse;
            font-size: 12px;
        }

        .libya-details .mgr-table th,
        .libya-details .mgr-table td {
            padding: 10px 8px;
            text-align: right;
            border-bottom: 1px solid #d1d5db;
        }

        .libya-details .mgr-table th {
            background: #f8fafc;
            color: #4a5568;
            font-weight: 600;
        }

        .libya-details .mgr-table tr:hover {
            background: #f9fafb;
        }

        .libya-details .mgr-table tr.mgr-total-row {
            background: #f0f9ff;
            font-weight: 600;
            color: #0369a1;
        }

        .libya-details .mgr-hint {
            background: #f9fafb;
            padding: 10px 15px;
            border-radius: 8px;
            border: 1px solid #e2e8f0;
            margin-bottom: 12px;
            font-size: 14px;
            color: #4a5568;
        }

        /* إخفاء سطر حد النسبة وحد العمولة الثابتة في بطاقة الطلبات الحالية */
        .libya-details .mgr-card.mgr-card-orders-current>.mgr-hint {
            display: none !important;
        }

        .libya-details .mgr-link-delete {
            color: #d63638;
            text-decoration: none;
        }

        .libya-details .mgr-link-delete:hover {
            text-decoration: underline;
        }

        @media (max-width: 600px) {
            .libya-details {
                max-width: 100%;
                padding: 0 12px;
            }

            .libya-details .mgr-card {
                padding: 16px;
            }

            .libya-details .mgr-table th,
            .libya-details .mgr-table td {
                padding: 8px 6px;
                font-size: 11px;
            }
        }
    </style>
    <div class="wrap libya-details">
        <div class="mgr-header">
            <a href="<?php echo esc_url(admin_url('admin.php?page=merchant-main-dashboard')); ?>" class="mgr-back">← رجوع للرئيسية</a>
            <h1 class="mgr-title">بيانات المتجر: <?php echo esc_html($m['branch_name']); ?></h1>
        </div>
        <div class="mgr-card">
            <p><strong>المدينة:</strong> <?php echo esc_html($city); ?></p>
            <p><strong>الاسم:</strong> <?php echo esc_html($m['owner_name'] ?? 'غير محدد'); ?></p>
            <p><strong>الإيميل:</strong> <?php echo esc_html($email); ?></p>
            <p><strong>الهاتف:</strong> <a href="tel:<?php echo esc_attr($m['phone']); ?>" style="color: #04acf4; text-decoration: none;"><?php echo esc_html($m['phone']); ?></a></p>

            <div style="display: flex; align-items: flex-start; gap: 10px; flex-wrap: wrap; margin-top: 15px;">
                <form method="post" onsubmit="return confirm('هل أنت متأكد من أرشفة جميع الطلبات الحالية وتصفير الحساب؟')" style="margin: 0; padding: 0;">
                    <input type="hidden" name="archive_orders" value="1">
                    <button type="submit" class="mgr-btn mgr-btn-secondary">أرشفة الطلبات الحالية وتصفير الحساب</button>
                </form>
                <form method="post" onsubmit="return confirm('هل أنت متأكد من إرسال التنبيه؟')" style="margin: 0; padding: 0;">
                    <input type="hidden" name="notify_merchant" value="1">
                    <button type="submit" class="mgr-btn mgr-btn-secondary">تنبيه المتجر</button>
                </form>
            </div>
        </div>

        <div class="mgr-card mgr-card-orders-current">
            <h2>الطلبات الحالية (غير مؤرشفة)</h2>
            <form method="post">
                <div style="margin: 10px 0;">
                    <button type="submit" name="bulk_delete_merchant_orders" class="mgr-btn mgr-btn-danger" onclick="return confirm('حذف الطلبات المحددة؟')">حذف المحدد</button>
                </div>
                <table class="mgr-table">
                    <thead>
                        <tr>
                            <th style="width: 30px;"><input type="checkbox" onclick="var chks=document.getElementsByClassName('recent_chk'); for(var c of chks) c.checked=this.checked;"></th>
                            <th style="width: 50px;">#</th>
                            <th>رقم الطلب</th>
                            <th>الإجمالي</th>
                            <th>النسبة</th>
                            <th>ثابتة</th>
                            <th>إجمالي العمولة</th>
                            <th>التاريخ</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php if (empty($recent_ids)): ?>
                            <tr>
                                <td colspan="8">لا توجد طلبات حالية.</td>
                            </tr>
                            <?php else:
                            $sum_total = 0;
                            $sum_comm = 0;
                            $sum_perc = 0;
                            $sum_fix = 0;
                            $row_idx = 1;
                            foreach ($recent_ids as $oid):
                                $order = wc_get_order($oid);
                                if (!$order) continue;
                                $total = (float)$order->get_total();
                                $breakdown = get_libya_merchant_commission_breakdown_v14($total, $m);
                                $comm = (float)$breakdown['total'];
                                $perc_val = $breakdown['percentage'];
                                $fixed_val = $breakdown['fixed'];

                                $sum_total += $total;
                                $sum_comm += $comm;
                                $sum_perc += $perc_val;
                                $sum_fix += $fixed_val;
                            ?>
                                <tr>
                                    <td><input type="checkbox" name="order_ids[]" value="<?php echo $oid; ?>" class="recent_chk"></td>
                                    <td><?php echo $row_idx++; ?></td>
                                    <td><a href="<?php echo get_edit_post_link($oid); ?>" target="_blank" style="text-decoration: none; font-weight: bold; color: #2271b1;">#<?php echo $oid; ?></a></td>
                                    <td><?php echo wc_price($total); ?></td>
                                    <td><?php echo wc_price($perc_val); ?></td>
                                    <td><?php echo wc_price($fixed_val); ?></td>
                                    <td style="font-weight:bold;"><?php echo wc_price($comm); ?></td>
                                    <td style="font-size: 12px; color: #666;"><?php echo $order->get_date_created()->date('Y-m-d H:i'); ?></td>
                                </tr>
                            <?php endforeach; ?>
                            <tr class="mgr-total-row">
                                <td colspan="3">المجموع</td>
                                <td><?php echo wc_price($sum_total); ?></td>
                                <td><?php echo wc_price($sum_perc); ?></td>
                                <td><?php echo wc_price($sum_fix); ?></td>
                                <td><?php echo wc_price($sum_comm); ?></td>
                                <td></td>
                            </tr>
                        <?php endif; ?>
                    </tbody>
                </table>
            </form>
        </div>

        <div class="mgr-card">
            <h2>سجل الأرشيف</h2>
            <form method="post">
                <div style="margin: 10px 0;">
                    <button type="submit" name="bulk_delete_merchant_orders" class="mgr-btn mgr-btn-danger" onclick="return confirm('حذف الطلبات المحددة؟')">حذف المحدد</button>
                </div>
                <table class="mgr-table">
                    <thead>
                        <tr>
                            <th style="width: 30px;"><input type="checkbox" onclick="var chks=document.getElementsByClassName('archive_chk'); for(var c of chks) c.checked=this.checked;"></th>
                            <th style="width: 50px;">#</th>
                            <th>رقم الطلب</th>
                            <th>الإجمالي</th>
                            <th>النسبة</th>
                            <th>ثابتة</th>
                            <th>إجمالي العمولة</th>
                            <th>التاريخ</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php if (empty($archive_ids_page)): ?>
                            <tr>
                                <td colspan="8"><?php echo $archive_total_items > 0 ? 'لا توجد عناصر في هذه الصفحة.' : 'الأرشيف فارغ.'; ?></td>
                            </tr>
                            <?php else:
                            $sum_total_arc = 0;
                            $sum_comm_arc = 0;
                            $sum_perc_arc = 0;
                            $sum_fix_arc = 0;
                            $row_idx_arc = $archive_offset + 1;
                            foreach ($archive_ids_page as $oid):
                                $order = wc_get_order($oid);
                                if (!$order) continue;
                                $total = (float)$order->get_total();
                                $breakdown = get_libya_merchant_commission_breakdown_v14($total, $m);
                                $comm = (float)$breakdown['total'];
                                $perc_val = $breakdown['percentage'];
                                $fixed_val = $breakdown['fixed'];

                                $sum_total_arc += $total;
                                $sum_comm_arc += $comm;
                                $sum_perc_arc += $perc_val;
                                $sum_fix_arc += $fixed_val;
                            ?>
                                <tr>
                                    <td><input type="checkbox" name="order_ids[]" value="<?php echo $oid; ?>" class="archive_chk"></td>
                                    <td><?php echo $row_idx_arc++; ?></td>
                                    <td><a href="<?php echo get_edit_post_link($oid); ?>" target="_blank" style="text-decoration: none; font-weight: bold; color: #2271b1;">#<?php echo $oid; ?></a></td>
                                    <td><?php echo wc_price($total); ?></td>
                                    <td><?php echo wc_price($perc_val); ?></td>
                                    <td><?php echo wc_price($fixed_val); ?></td>
                                    <td style="font-weight:bold;"><?php echo wc_price($comm); ?></td>
                                    <td style="font-size: 12px; color: #666;"><?php echo $order->get_date_created()->date('Y-m-d H:i'); ?></td>
                                </tr>
                            <?php endforeach; ?>
                            <tr class="mgr-total-row">
                                <td colspan="3">المجموع</td>
                                <td><?php echo wc_price($sum_total_arc); ?></td>
                                <td><?php echo wc_price($sum_perc_arc); ?></td>
                                <td><?php echo wc_price($sum_fix_arc); ?></td>
                                <td><?php echo wc_price($sum_comm_arc); ?></td>
                                <td></td>
                            </tr>
                        <?php endif; ?>
                    </tbody>
                </table>
            </form>
            <?php if ($archive_total_pages > 1): ?>
                <div class="tablenav-pages" style="margin-top: 12px; display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
                    <span class="displaying-num" style="font-size: 13px; color: #50575e;"><?php echo $archive_total_items; ?> عنصر</span>
                    <span class="pagination-links">
                        <?php
                        for ($p = 1; $p <= $archive_total_pages; $p++) {
                            $url = add_query_arg('archive_paged', $p, $details_base_url);
                            if ($p == $archive_paged) {
                                echo '<span class="current" style="margin: 0 4px; padding: 4px 10px; background: #2271b1; color: #fff; border-radius: 4px; font-weight: bold;">' . $p . '</span>';
                            } else {
                                echo '<a href="' . esc_url($url) . '" style="margin: 0 4px; padding: 4px 10px; background: #f0f0f1; color: #2271b1; border-radius: 4px; text-decoration: none;">' . $p . '</a>';
                            }
                        }
                        ?>
                    </span>
                </div>
            <?php endif; ?>
            <form method="post" onsubmit="return confirm('تحذير: سيتم مسح سجل الأرشيف بالكامل نهائياً. هل أنت متأكد؟')" style="margin-top: 10px;">
                <input type="hidden" name="clear_archive" value="1">
                <button type="submit" class="mgr-link-delete" style="background:none;border:none;cursor:pointer;font-size:13px;padding:0;color:#d63638;">تصفير سجل الأرشيف نهائياً</button>
            </form>
        </div>
    </div>
<?php
}




function render_system_diagnostics_v14()
{
    global $wpdb;

    $diagnostics = [];
    $critical_count = 0;
    $warning_count = 0;
    $ok_count = 0;

    // 1. فحص PHP
    $php_version = phpversion();
    $php_required = '7.4';
    if (version_compare($php_version, $php_required, '>=')) {
        $diagnostics[] = ['status' => 'ok', 'title' => 'إصدار PHP', 'message' => "الإصدار: {$php_version}", 'details' => ''];
        $ok_count++;
    } else {
        $diagnostics[] = ['status' => 'critical', 'title' => 'إصدار PHP قديم', 'message' => "الإصدار الحالي: {$php_version}", 'details' => "المطلوب: {$php_required} أو أحدث. يرجى ترقية PHP من لوحة الاستضافة."];
        $critical_count++;
    }

    // 2. فحص الذاكرة
    $memory_limit = ini_get('memory_limit');
    $memory_usage = memory_get_usage(true);
    $memory_limit_bytes = wp_convert_hr_to_bytes($memory_limit);
    $memory_percent = ($memory_usage / $memory_limit_bytes) * 100;

    if ($memory_percent >= 90) {
        $diagnostics[] = ['status' => 'critical', 'title' => 'استهلاك الذاكرة مرتفع جداً', 'message' => sprintf('%.1f%% (%s / %s)', $memory_percent, size_format($memory_usage), $memory_limit), 'details' => 'خطر: قريب من الحد الأقصى. قد يتوقف الموقع. الحل: زيادة memory_limit إلى 512M في php.ini'];
        $critical_count++;
    } elseif ($memory_percent >= 70) {
        $diagnostics[] = ['status' => 'warning', 'title' => 'استهلاك الذاكرة مرتفع', 'message' => sprintf('%.1f%% (%s / %s)', $memory_percent, size_format($memory_usage), $memory_limit), 'details' => 'يُنصح بزيادة memory_limit لتجنب المشاكل المستقبلية.'];
        $warning_count++;
    } else {
        $diagnostics[] = ['status' => 'ok', 'title' => 'استهلاك الذاكرة', 'message' => sprintf('%.1f%% (%s / %s)', $memory_percent, size_format($memory_usage), $memory_limit), 'details' => ''];
        $ok_count++;
    }

    // 3. فحص WordPress
    $wp_version = get_bloginfo('version');
    $wp_required = '5.0';
    if (version_compare($wp_version, $wp_required, '>=')) {
        $diagnostics[] = ['status' => 'ok', 'title' => 'إصدار WordPress', 'message' => "الإصدار: {$wp_version}", 'details' => ''];
        $ok_count++;
    } else {
        $diagnostics[] = ['status' => 'warning', 'title' => 'إصدار WordPress قديم', 'message' => "الإصدار: {$wp_version}", 'details' => "يُنصح بالترقية إلى {$wp_required} أو أحدث."];
        $warning_count++;
    }

    // 4. فحص WooCommerce
    if (class_exists('WooCommerce')) {
        $wc_version = WC()->version;
        $diagnostics[] = ['status' => 'ok', 'title' => 'WooCommerce نشط', 'message' => "الإصدار: {$wc_version}", 'details' => ''];
        $ok_count++;
    } else {
        $diagnostics[] = ['status' => 'critical', 'title' => 'WooCommerce غير مثبت', 'message' => 'النظام يحتاج WooCommerce للعمل', 'details' => 'الحل: تثبيت وتفعيل إضافة WooCommerce'];
        $critical_count++;
    }

    // 5. فحص قاعدة البيانات
    $db_start = microtime(true);
    $test_query = $wpdb->get_var("SELECT 1");
    $db_time = (microtime(true) - $db_start) * 1000;

    if ($db_time > 1000) {
        $diagnostics[] = ['status' => 'critical', 'title' => 'قاعدة البيانات بطيئة جداً', 'message' => sprintf('وقت الاستجابة: %.0fms', $db_time), 'details' => 'السبب: جداول كبيرة أو استضافة ضعيفة. التأثير: بطء شديد في الموقع.'];
        $critical_count++;
    } elseif ($db_time > 500) {
        $diagnostics[] = ['status' => 'warning', 'title' => 'قاعدة البيانات بطيئة', 'message' => sprintf('وقت الاستجابة: %.0fms', $db_time), 'details' => 'يُنصح بتحسين الجداول أو ترقية الاستضافة.'];
        $warning_count++;
    } else {
        $diagnostics[] = ['status' => 'ok', 'title' => 'قاعدة البيانات', 'message' => sprintf('وقت الاستجابة: %.0fms', $db_time), 'details' => ''];
        $ok_count++;
    }

    // 6. فحص Cron
    $cron_next = wp_next_scheduled('libya_merchant_background_check');
    if ($cron_next) {
        $time_until = $cron_next - time();
        if ($time_until > 600) {
            $diagnostics[] = ['status' => 'warning', 'title' => 'Cron متأخر', 'message' => sprintf('التشغيل التالي بعد %.0f دقيقة', $time_until / 60), 'details' => 'قد يكون هناك تأخير في الإشعارات التلقائية.'];
            $warning_count++;
        } else {
            $diagnostics[] = ['status' => 'ok', 'title' => 'Cron يعمل', 'message' => sprintf('التشغيل التالي بعد %.0f دقيقة', $time_until / 60), 'details' => ''];
            $ok_count++;
        }
    } else {
        $diagnostics[] = ['status' => 'critical', 'title' => 'Cron معطّل', 'message' => 'لا يوجد جدولة نشطة', 'details' => 'التأثير: الإشعارات التلقائية لا تعمل. الحل: تفعيل wp-cron.php في cPanel أو إعادة تفعيل الإضافة.'];
        $critical_count++;
    }

    // 7. فحص نظام التجار
    $merchants = get_libya_merchants_v14();
    $total_merchants = count($merchants);
    $active_merchants = 0;
    $frozen_merchants = 0;

    foreach ($merchants as $m) {
        if (($m['status'] ?? 'active') === 'active') {
            $active_merchants++;
        } else {
            $frozen_merchants++;
        }
    }

    $diagnostics[] = ['status' => 'ok', 'title' => 'التجار المسجلين', 'message' => sprintf('%d تاجر (%d نشط، %d مجمد)', $total_merchants, $active_merchants, $frozen_merchants), 'details' => ''];
    $ok_count++;

    // 8. فحص حجم جدول wp_options (استخدام معلومات الجدول لتجنب البطء)
    $table_info = $wpdb->get_row($wpdb->prepare(
        "SELECT (data_length + index_length) as size FROM information_schema.TABLES WHERE table_schema = %s AND table_name = %s",
        DB_NAME,
        $wpdb->options
    ));
    $options_size_mb = $table_info ? ($table_info->size / 1024 / 1024) : 0;

    if ($options_size_mb > 50) {
        $diagnostics[] = ['status' => 'warning', 'title' => 'جدول wp_options كبير', 'message' => sprintf('الحجم: %.1f MB', $options_size_mb), 'details' => 'يُنصح بتنظيف autoload لتحسين الأداء.'];
        $warning_count++;
    } else {
        $diagnostics[] = ['status' => 'ok', 'title' => 'جدول wp_options', 'message' => sprintf('الحجم: %.1f MB', $options_size_mb), 'details' => ''];
        $ok_count++;
    }

    // حساب درجة صحة النظام
    // المنطق: كل فحص سليم = 100 نقطة، كل تحذير = 30 نقطة، كل خطأ حرج = 0 نقطة
    // ثم نحسب المتوسط: (مجموع النقاط) / (عدد الفحوصات الكلي)
    $total_checks = count($diagnostics);
    $health_score = (($ok_count * 100) + ($warning_count * 30)) / $total_checks;

?>
    <style>
        .libya-diagnostics {
            direction: rtl;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 1000px;
            margin: 20px auto 40px;
            padding: 0 16px;
        }

        .libya-diagnostics * {
            box-sizing: border-box;
        }

        .libya-diagnostics .mgr-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            flex-wrap: wrap;
            gap: 12px;
            margin-bottom: 24px;
            padding-bottom: 20px;
            border-bottom: 2px solid #04acf4;
        }

        .libya-diagnostics .mgr-title {
            margin: 0;
            font-size: 20px;
            font-weight: 700;
            color: #0284c7;
        }

        .libya-diagnostics .mgr-back {
            display: inline-flex;
            align-items: center;
            padding: 6px 12px;
            background: #f0f9ff;
            color: #0369a1;
            text-decoration: none;
            border-radius: 8px;
            font-size: 13px;
            font-weight: 500;
            border: 1px solid #bae6fd;
            transition: background .15s, color .15s;
        }

        .libya-diagnostics .mgr-back:hover {
            background: #bae6fd;
            color: #0284c7;
        }

        .libya-diagnostics .mgr-card {
            background: #fff;
            border: 1px solid #bae6fd;
            border-radius: 12px;
            padding: 20px;
            margin-bottom: 20px;
            box-shadow: 0 2px 8px rgba(0, 0, 0, .08);
            border-right: 4px solid #04acf4;
        }

        .libya-diagnostics .mgr-card.mgr-card-critical {
            border-right-color: #dc3545;
        }

        .libya-diagnostics .mgr-card.mgr-card-warning {
            border-right-color: #ffc107;
        }

        .libya-diagnostics .mgr-card.mgr-card-ok {
            border-right-color: #28a745;
        }

        .libya-diagnostics .mgr-stats {
            display: flex;
            flex-wrap: wrap;
            gap: 12px;
            align-items: center;
            margin-bottom: 20px;
        }

        .libya-diagnostics .mgr-stat {
            text-align: center;
            padding: 14px 20px;
            border-radius: 10px;
            font-size: 12px;
        }

        .libya-diagnostics .mgr-stat-critical {
            background: #dc3545;
            color: #fff;
        }

        .libya-diagnostics .mgr-stat-warning {
            background: #ffc107;
            color: #1a202c;
        }

        .libya-diagnostics .mgr-stat-ok {
            background: #28a745;
            color: #fff;
        }

        .libya-diagnostics .mgr-stat .val {
            font-size: 24px;
            font-weight: 700;
            display: block;
        }

        .libya-diagnostics .mgr-diagnostic-item {
            padding: 15px;
            margin-bottom: 10px;
            border-radius: 8px;
            border: 1px solid;
        }

        .libya-diagnostics .mgr-diagnostic-item.mgr-item-critical {
            background: #fff5f5;
            border-color: #feb2b2;
        }

        .libya-diagnostics .mgr-diagnostic-item.mgr-item-critical h4 {
            color: #c53030;
            margin: 0 0 8px 0;
        }

        .libya-diagnostics .mgr-diagnostic-item.mgr-item-warning {
            background: #fffaf0;
            border-color: #fbd38d;
        }

        .libya-diagnostics .mgr-diagnostic-item.mgr-item-warning h4 {
            color: #b7791f;
            margin: 0 0 8px 0;
        }

        .libya-diagnostics .mgr-diagnostic-item.mgr-item-ok {
            background: #f0fff4;
            border-color: #9ae6b4;
        }

        .libya-diagnostics .mgr-diagnostic-item.mgr-item-ok h4 {
            color: #276749;
            margin: 0 0 8px 0;
        }

        @media (max-width: 600px) {
            .libya-diagnostics {
                max-width: 100%;
                padding: 0 12px;
            }

            .libya-diagnostics .mgr-card {
                padding: 16px;
            }
        }
    </style>
    <div class="wrap libya-diagnostics">
        <div class="mgr-header">
            <a href="<?php echo esc_url(admin_url('admin.php?page=merchant-main-dashboard')); ?>" class="mgr-back">← رجوع للرئيسية</a>
            <h1 class="mgr-title">تشخيص المعتمد</h1>
        </div>

        <div class="mgr-card">
            <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 20px;">
                <div>
                    <h2 style="margin: 0; font-size: 22px;">صحة المعتمد: <span style="color: <?php echo esc_attr($health_score >= 80 ? '#28a745' : ($health_score >= 50 ? '#ffc107' : '#dc3545')); ?>"><?php echo round($health_score); ?>/100</span></h2>
                    <p style="margin: 5px 0 0 0; color: #6b7280; font-size: 14px;">آخر فحص: <?php echo esc_html(date('Y-m-d H:i:s')); ?></p>
                </div>
                <div class="mgr-stats">
                    <div class="mgr-stat mgr-stat-critical"><span class="val"><?php echo (int) $critical_count; ?></span> حرج</div>
                    <div class="mgr-stat mgr-stat-warning"><span class="val"><?php echo (int) $warning_count; ?></span> تحذير</div>
                    <div class="mgr-stat mgr-stat-ok"><span class="val"><?php echo (int) $ok_count; ?></span> سليم</div>
                </div>
            </div>
        </div>

        <?php if ($critical_count > 0): ?>
            <div class="mgr-card mgr-card-critical">
                <h3 style="margin-top: 0; color: #dc3545;">🔴 أخطاء حرجة (يجب الإصلاح فوراً)</h3>
                <?php foreach ($diagnostics as $d): ?>
                    <?php if ($d['status'] === 'critical'): ?>
                        <div class="mgr-diagnostic-item mgr-item-critical">
                            <h4><?php echo esc_html($d['title']); ?></h4>
                            <p style="margin: 0 0 5px 0; font-weight: bold;"><?php echo esc_html($d['message']); ?></p>
                            <?php if (!empty($d['details'])): ?>
                                <p style="margin: 5px 0 0 0; font-size: 13px; color: #6b7280; line-height: 1.6;"><?php echo esc_html($d['details']); ?></p>
                            <?php endif; ?>
                        </div>
                    <?php endif; ?>
                <?php endforeach; ?>
            </div>
        <?php endif; ?>

        <?php if ($warning_count > 0): ?>
            <div class="mgr-card mgr-card-warning">
                <h3 style="margin-top: 0; color: #d69e2e;">🟡 تحذيرات (انتبه)</h3>
                <?php foreach ($diagnostics as $d): ?>
                    <?php if ($d['status'] === 'warning'): ?>
                        <div class="mgr-diagnostic-item mgr-item-warning">
                            <h4><?php echo esc_html($d['title']); ?></h4>
                            <p style="margin: 0 0 5px 0; font-weight: bold;"><?php echo esc_html($d['message']); ?></p>
                            <?php if (!empty($d['details'])): ?>
                                <p style="margin: 5px 0 0 0; font-size: 13px; color: #6b7280; line-height: 1.6;"><?php echo esc_html($d['details']); ?></p>
                            <?php endif; ?>
                        </div>
                    <?php endif; ?>
                <?php endforeach; ?>
            </div>
        <?php endif; ?>

        <div class="mgr-card mgr-card-ok">
            <h3 style="margin-top: 0; color: #28a745;">🟢 عناصر سليمة</h3>
            <?php foreach ($diagnostics as $d): ?>
                <?php if ($d['status'] === 'ok'): ?>
                    <div class="mgr-diagnostic-item mgr-item-ok">
                        <h4><?php echo esc_html($d['title']); ?></h4>
                        <p style="margin: 0; font-weight: bold;"><?php echo esc_html($d['message']); ?></p>
                    </div>
                <?php endif; ?>
            <?php endforeach; ?>
        </div>
    </div>
    <?php
}

if (!function_exists('render_system_logs_page_v14')) {
    function render_system_logs_page_v14()
    {
        global $wpdb;
        $table_name = $wpdb->prefix . 'libya_system_logs';
        $admin_notice = '';

        // معالجة حذف سجل واحد
        if (isset($_GET['delete_log']) && isset($_GET['_wpnonce']) && wp_verify_nonce($_GET['_wpnonce'], 'delete_log_' . $_GET['delete_log'])) {
            $delete_id = intval($_GET['delete_log']);
            $wpdb->delete($table_name, ['id' => $delete_id], ['%d']);
            $admin_notice = '<div class="libya-admin-success-notice"><p>تم حذف السجل بنجاح.</p></div>';
        }

        // معالجة حذف سجلات متعددة (مع حماية من SQL Injection)
        if (isset($_POST['bulk_delete_logs']) && isset($_POST['log_ids']) && wp_verify_nonce($_POST['_wpnonce'], 'bulk_delete_logs')) {
            $ids_to_delete = array_map('intval', $_POST['log_ids']);
            if (!empty($ids_to_delete)) {
                // إنشاء placeholders آمنة (%d لكل رقم)
                $placeholders = implode(',', array_fill(0, count($ids_to_delete), '%d'));
                $query = $wpdb->prepare("DELETE FROM $table_name WHERE id IN ($placeholders)", $ids_to_delete);
                $wpdb->query($query);
                $admin_notice = '<div class="libya-admin-success-notice"><p>تم حذف ' . count($ids_to_delete) . ' سجل بنجاح.</p></div>';
            }
        }

        // معالجة حذف الكل
        if (isset($_POST['delete_all_logs']) && wp_verify_nonce($_POST['_wpnonce'], 'delete_all_logs')) {
            $wpdb->query("TRUNCATE TABLE $table_name");
            $admin_notice = '<div class="libya-admin-success-notice"><p>تم حذف جميع السجلات بنجاح.</p></div>';
        }

        // التصفية والبحث
        $search = isset($_GET['s']) ? sanitize_text_field($_GET['s']) : '';
        $where = '';
        if ($search) {
            $search_term = '%' . $wpdb->esc_like($search) . '%';
            $where = $wpdb->prepare("WHERE email LIKE %s OR action LIKE %s OR details LIKE %s OR note LIKE %s", $search_term, $search_term, $search_term, $search_term);
        }

        // التقسيم للصفحات
        $per_page = 25;
        $current_page = isset($_GET['paged']) ? max(1, intval($_GET['paged'])) : 1;
        $offset = ($current_page - 1) * $per_page;

        $total_items = $wpdb->get_var("SELECT COUNT(id) FROM $table_name $where");
        $total_pages = ceil($total_items / $per_page);

        $logs = $wpdb->get_results("SELECT * FROM $table_name $where ORDER BY time DESC LIMIT $per_page OFFSET $offset");

    ?>
        <style>
            .libya-logs {
                direction: rtl;
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                max-width: 1000px;
                margin: 20px auto 40px;
                padding: 0 16px;
            }

            .libya-logs * {
                box-sizing: border-box;
            }

            .libya-logs .mgr-header {
                display: flex;
                align-items: center;
                justify-content: space-between;
                flex-wrap: wrap;
                gap: 12px;
                margin-bottom: 24px;
                padding-bottom: 20px;
                border-bottom: 2px solid #04acf4;
            }

            .libya-logs .mgr-title {
                margin: 0;
                font-size: 20px;
                font-weight: 700;
                color: #0284c7;
            }

            .libya-logs .mgr-back {
                display: inline-flex;
                align-items: center;
                padding: 6px 12px;
                background: #f0f9ff;
                color: #0369a1;
                text-decoration: none;
                border-radius: 8px;
                font-size: 13px;
                font-weight: 500;
                border: 1px solid #bae6fd;
                transition: background .15s, color .15s;
            }

            .libya-logs .mgr-back:hover {
                background: #bae6fd;
                color: #0284c7;
            }

            .libya-logs .mgr-card {
                background: #fff;
                border: 1px solid #bae6fd;
                border-radius: 12px;
                padding: 20px;
                margin-bottom: 20px;
                box-shadow: 0 2px 8px rgba(0, 0, 0, .08);
                border-right: 4px solid #04acf4;
            }

            .libya-logs .mgr-search {
                display: flex;
                gap: 8px;
                align-items: center;
                flex-wrap: wrap;
                margin-bottom: 16px;
            }

            .libya-logs .mgr-search input[type="search"] {
                padding: 8px 12px;
                border: 1px solid #cbd5e1;
                border-radius: 8px;
                font-size: 13px;
                width: 200px;
            }

            .libya-logs .mgr-btn {
                padding: 8px 18px;
                background: linear-gradient(135deg, #0284c7, #04acf4);
                color: #fff;
                border: none;
                border-radius: 8px;
                font-weight: 600;
                font-size: 13px;
                cursor: pointer;
            }

            .libya-logs .mgr-btn:hover {
                opacity: 0.95;
            }

            .libya-logs .mgr-btn-danger {
                background: #dc3545;
                color: #fff;
                border: 1px solid #dc3545;
            }

            .libya-logs .mgr-btn-danger:hover {
                background: #c82333;
            }

            .libya-logs .mgr-btn-secondary {
                background: #f8fafc;
                color: #475569;
                border: 1px solid #cbd5e1;
            }

            .libya-logs .mgr-table-wrap {
                overflow-x: auto;
                -webkit-overflow-scrolling: touch;
            }

            .libya-logs .mgr-table {
                width: 100%;
                min-width: 700px;
                border-collapse: collapse;
                font-size: 12px;
            }

            .libya-logs .mgr-table th,
            .libya-logs .mgr-table td {
                word-wrap: break-word;
                padding: 10px 8px;
                text-align: right;
                border-bottom: 1px solid #d1d5db;
                vertical-align: top;
            }

            .libya-logs .mgr-table th {
                background: #f8fafc;
                color: #4a5568;
                font-weight: 600;
            }

            .libya-logs .mgr-table tr:hover {
                background: #f9fafb;
            }

            .libya-logs .tablenav-pages {
                margin: 12px 0;
                display: flex;
                align-items: center;
                gap: 12px;
                flex-wrap: wrap;
            }

            .libya-logs .tablenav-pages .displaying-num {
                font-size: 12px;
                color: #6b7280;
            }

            @media (max-width: 600px) {
                .libya-logs {
                    max-width: 100%;
                    padding: 0 12px;
                }

                .libya-logs .mgr-card {
                    padding: 16px;
                }

                .libya-logs .mgr-table th,
                .libya-logs .mgr-table td {
                    padding: 8px 6px;
                    font-size: 11px;
                }
            }
        </style>
        <div class="wrap libya-logs">
            <div class="mgr-header">
                <a href="<?php echo esc_url(admin_url('admin.php?page=merchant-main-dashboard')); ?>" class="mgr-back">← رجوع للرئيسية</a>
                <h1 class="mgr-title">سجل العمليات</h1>
            </div>
            <?php if ($admin_notice) {
                echo $admin_notice;
            } ?>

            <div class="mgr-card">
                <div class="mgr-search" style="justify-content: space-between;">
                    <form method="get" style="margin: 0; display: flex; gap: 8px; align-items: center;">
                        <input type="hidden" name="page" value="system-logs">
                        <input type="search" id="post-search-input" name="s" value="<?php echo esc_attr($search); ?>" placeholder="بحث..." style="padding:8px 12px;border:1px solid #cbd5e1;border-radius:8px;font-size:13px;">
                        <button type="submit" class="mgr-btn mgr-btn-secondary" style="cursor:pointer;">بحث</button>
                    </form>

                    <?php if ($total_items > 0): ?>
                        <form method="post" style="margin: 0;" onsubmit="return confirm('هل أنت متأكد من حذف جميع السجلات؟ هذا الإجراء لا يمكن التراجع عنه!')">
                            <?php wp_nonce_field('delete_all_logs'); ?>
                            <button type="submit" name="delete_all_logs" class="mgr-btn mgr-btn-danger">حذف الكل</button>
                        </form>
                    <?php endif; ?>
                </div>

                <form method="post">
                    <?php wp_nonce_field('bulk_delete_logs'); ?>

                    <div style="margin-bottom: 12px;">
                        <button type="submit" name="bulk_delete_logs" class="mgr-btn mgr-btn-danger" onclick="return confirm('حذف السجلات المحددة؟')">حذف المحدد</button>
                    </div>

                    <div class="mgr-table-wrap">
                        <table class="mgr-table">
                            <thead>
                                <tr>
                                    <th class="col-check" style="width: 30px;"><input type="checkbox" id="select_all_logs"></th>
                                    <th class="col-num">#</th>
                                    <th class="col-time">التاريخ والوقت</th>
                                    <th class="col-action">الإجراء</th>
                                    <th class="col-source">مصدر الحالة</th>
                                    <th class="col-details">رقم الطلب</th>
                                    <th class="col-note">ملاحظة</th>
                                    <th class="col-ip">IP</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php if (empty($logs)): ?>
                                    <tr>
                                        <td colspan="8">لا توجد سجلات.</td>
                                    </tr>
                                <?php else: ?>
                                    <?php
                                    $row_num = $offset + 1;
                                    $merchants = get_libya_merchants_v14(); // جلب بيانات التجار مرة واحدة
                                    foreach ($logs as $log):
                                        // رموز احترافية بسيطة (SVG) حسب نوع الإجراء
                                        $status_icon = '';
                                        $action_lower = $log->action;
                                        $ic = function ($svg, $color, $title) {
                                            return '<span style="display:inline-block;width:16px;height:16px;margin-left:6px;vertical-align:middle;color:' . $color . ';" title="' . esc_attr($title) . '">' . $svg . '</span>';
                                        };
                                        if (strpos($action_lower, 'تعذر') !== false || strpos($action_lower, 'رفض') !== false) {
                                            $status_icon = $ic('<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg>', '#dc3545', 'تعذر التسليم');
                                        } elseif (strpos($action_lower, 'الاضافي') !== false) {
                                            $status_icon = $ic('<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>', '#fd7e14', 'انتهاء الوقت الاضافي');
                                        } elseif (strpos($action_lower, 'تم الاتصال بالعميل') !== false) {
                                            $status_icon = $ic('<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"/></svg>', '#7c3aed', 'اتصال بالعميل (موفي)');
                                        } elseif (strpos($action_lower, 'تم فتح تطبيق واتساب') !== false) {
                                            $status_icon = $ic('<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"/></svg>', '#075E54', 'فتح تطبيق واتساب');
                                        } elseif (strpos($action_lower, 'تم فتح تطبيق الرسائل') !== false) {
                                            $status_icon = $ic('<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>', '#f59e0b', 'فتح تطبيق الرسائل');
                                        } elseif (strpos($action_lower, 'حظور') !== false) {
                                            $status_icon = $ic('<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="8.5" cy="7" r="4"/><polyline points="17 11 19 13 23 9"/></svg>', '#9b59b6', 'تأكيد الحضور');
                                        } elseif (strpos($action_lower, 'غير متوفر') !== false) {
                                            $status_icon = $ic('<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="4.93" y1="4.93" x2="19.07" y2="19.07"/></svg>', '#6c757d', 'الطلب غير متوفر');
                                        } elseif (strpos($action_lower, 'تم استلام الدفعة') !== false) {
                                            $status_icon = $ic('<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="1" x2="12" y2="23"/><path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>', '#0d9488', 'تم استلام الدفعة');
                                        } elseif (strpos($action_lower, 'ERROR_') !== false || strpos($action_lower, 'خطأ حرج') !== false || strpos($action_lower, 'خطأ في') !== false) {
                                            $status_icon = $ic('<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>', '#dc3545', 'سجل نظام / خطأ');
                                        } elseif (strpos($action_lower, 'تغيير حالة المتجر') !== false) {
                                            $status_icon = $ic('<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>', '#6366f1', 'تغيير حالة المتجر');
                                        } elseif (strpos($action_lower, 'تم إضافة متجر') !== false) {
                                            $status_icon = $ic('<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>', '#059669', 'تم إضافة متجر');
                                        } elseif (strpos($action_lower, 'تم تعديل متجر') !== false) {
                                            $status_icon = $ic('<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>', '#2563eb', 'تم تعديل متجر');
                                        } elseif (strpos($action_lower, 'تنظيف السجلات') !== false || strpos($action_lower, 'تنظيف wp_options') !== false) {
                                            $status_icon = $ic('<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/><line x1="10" y1="11" x2="10" y2="17"/><line x1="14" y1="11" x2="14" y2="17"/></svg>', '#64748b', 'تنظيف السجلات');
                                        } elseif (strpos($action_lower, 'إعادة تشغيل Cron') !== false) {
                                            $status_icon = $ic('<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="23 4 23 10 17 10"/><polyline points="1 20 1 14 7 14"/><path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"/></svg>', '#7c3aed', 'إعادة تشغيل Cron');
                                        } elseif (strpos($action_lower, 'معالجة قائمة الإيميلات') !== false) {
                                            $status_icon = $ic('<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/><polyline points="22,6 12,13 2,6"/></svg>', '#0ea5e9', 'معالجة قائمة الإيميلات');
                                        } elseif (strpos($action_lower, 'تفريغ اللوج') !== false) {
                                            $status_icon = $ic('<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/><polyline points="10 9 9 9 8 9"/></svg>', '#64748b', 'تفريغ اللوج');
                                        } elseif (strpos($action_lower, 'bank_account') !== false || strpos($action_lower, 'حساب مصرفي') !== false) {
                                            $status_icon = $ic('<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="1" x2="12" y2="23"/><path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>', '#0d9488', 'حساب مصرفي');
                                        } elseif (strpos($action_lower, 'global_timing') !== false || strpos($action_lower, 'تحديث إعدادات التوقيت') !== false) {
                                            $status_icon = $ic('<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>', '#6366f1', 'إعدادات التوقيت');
                                        } elseif ((strpos($action_lower, 'تم استلام الطلب') !== false || strpos($action_lower, 'استلام طلب تم تحويله') !== false || strpos($action_lower, 'استلم الطلب') !== false || strpos($action_lower, 'استلم طلب محول') !== false || strpos($action_lower, 'تم تسليم الطلب') !== false || strpos($action_lower, 'تم تسليم طلب محوّل') !== false) && strpos($action_lower, 'تلقائي') === false) {
                                            $status_icon = $ic('<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/></svg>', '#1e3a8a', 'تم استلام الطلب');
                                        } elseif (strpos($action_lower, 'تحويل يدوي') !== false || strpos($action_lower, 'تم تحويل الطلب') !== false || strpos($action_lower, 'تحويل تلقائي') !== false || strpos($action_lower, 'تحويل لتاجر') !== false) {
                                            $status_icon = $ic('<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="17 1 21 5 17 9"/><path d="M3 11V9a4 4 0 0 1 4-4h14"/><polyline points="7 23 3 19 7 15"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/></svg>', '#f39c12', 'تحويل الطلب');
                                        } elseif (strpos($action_lower, 'الوقت الاول') !== false || strpos($action_lower, 'بعد انتهاء الوقت الاول') !== false || strpos($action_lower, 'تحويل') !== false) {
                                            $status_icon = $ic('<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>', '#ffc107', 'انتهاء المهلة / تحويل');
                                        } elseif (strpos($action_lower, 'تم قبول') !== false || strpos($action_lower, 'قبول') !== false || strpos($action_lower, 'قبل') !== false) {
                                            $status_icon = $ic('<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>', '#04acf4', 'قبول الطلب');
                                        } elseif (strpos($action_lower, 'تم التسليم (تلقائي)') !== false || strpos($action_lower, 'استلام تلقائي') !== false || strpos($action_lower, 'تسليم') !== false || strpos($action_lower, 'سلم') !== false) {
                                            $status_icon = $ic('<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>', '#28a745', 'تم التسليم');
                                        }
                                        // عمود رقم الطلب: الرمز دائماً، مع رابط الطلب إن وُجد
                                        if (preg_match('/(?:رقم الطلب|الطلب)[:\s#]*(\d+)/', $log->details, $m_order)) {
                                            $oid = $m_order[1];
                                            $order_url = admin_url('post.php?post=' . $oid . '&action=edit');
                                            $order_number_cell = $status_icon . ' <a href="' . $order_url . '" target="_blank" style="color: #2271b1; font-weight: bold; text-decoration: none;">#' . $oid . '</a>';
                                        } else {
                                            $order_number_cell = $status_icon . ' <span style="color:#94a3b8;">—</span>';
                                        }
                                        // عمود الملاحظات: ملاحظات التاجر أو النظام فقط
                                        $note_cell = isset($log->note) && $log->note ? esc_html($log->note) : '—';

                                    ?>
                                        <tr>
                                            <td><input type="checkbox" name="log_ids[]" value="<?php echo $log->id; ?>" class="log_chk"></td>
                                            <td style="text-align: center; font-weight: bold;"><?php echo $row_num++; ?></td>
                                            <td style="direction: ltr; text-align: right; font-size: 12px;"><?php echo $log->time; ?></td>
                                            <td><strong><?php echo esc_html($log->action); ?></strong></td>
                                            <td style="font-size: 12px;"><?php
                                                                            if (strpos($action_lower, 'غير متوفر') !== false && preg_match('/المدينة:\s*([^|]+)/', $log->details, $m_city)) {
                                                                                echo esc_html(trim($m_city[1]));
                                                                            } else {
                                                                                $store_name = $log->email;
                                                                                if (isset($merchants[$log->email]['branch_name'])) {
                                                                                    $store_name = $merchants[$log->email]['branch_name'];
                                                                                } else {
                                                                                    foreach ($merchants as $k => $v) {
                                                                                        if (strtolower((string)$k) === strtolower((string)$log->email) && !empty($v['branch_name'])) {
                                                                                            $store_name = $v['branch_name'];
                                                                                            break;
                                                                                        }
                                                                                    }
                                                                                }
                                                                                echo esc_html($store_name);
                                                                            }
                                                                            ?></td>
                                            <td><?php echo $order_number_cell; ?></td>
                                            <td class="col-note"><?php echo $note_cell; ?></td>
                                            <td style="font-size: 11px;"><?php echo esc_html($log->ip); ?></td>
                                        </tr>
                                    <?php endforeach; ?>
                                <?php endif; ?>
                            </tbody>
                        </table>
                    </div>
                </form>

                <script>
                    document.getElementById('select_all_logs').onclick = function() {
                        var checkboxes = document.getElementsByClassName('log_chk');
                        for (var checkbox of checkboxes) {
                            checkbox.checked = this.checked;
                        }
                    }
                </script>

                <?php if ($total_pages > 1): ?>
                    <div class="tablenav-pages" style="margin-top:16px;">
                        <span class="displaying-num"><?php echo $total_items; ?> عنصر</span>
                        <?php
                        echo paginate_links(array(
                            'base' => add_query_arg('paged', '%#%'),
                            'format' => '',
                            'prev_text' => __('&laquo; السابق'),
                            'next_text' => __('التالي &raquo;'),
                            'total' => $total_pages,
                            'current' => $current_page
                        ));
                        ?>
                    </div>
                <?php endif; ?>
            </div>
        </div>
    <?php
    }
}


if (!function_exists('render_system_maintenance_v14')) {
    /**
     * صفحة صيانة النظام – نسخة مبسّطة وآمنة
     *
     * - لا تستخدم information_schema
     * - لا تعتمد على استعلامات معقدة قد تسبب أخطاء
     * - تقدّم فقط عمليات صيانة أساسية ومضمونة قدر الإمكان
     */
    function render_system_maintenance_v14()
    {
        if (!current_user_can('manage_options')) {
            wp_die('عذراً، ليس لديك صلاحية للوصول إلى هذه الصفحة.');
        }

        global $wpdb;
        $logs_table = $wpdb->prefix . 'libya_system_logs';
        $messages = [];

        // معالجة الطلبات (POST) مع تحقق nonce واحد مشترك
        if (!empty($_POST) && isset($_POST['_wpnonce']) && wp_verify_nonce($_POST['_wpnonce'], 'libya_maintenance_actions')) {
            // 0) حفظ إيميل الطلبات/الأدمن
            if (isset($_POST['save_orders_email'])) {
                $new_email = isset($_POST['libya_orders_email']) ? sanitize_email(wp_unslash($_POST['libya_orders_email'])) : '';
                update_option('libya_orders_email', $new_email);
                $messages[] = ['type' => 'updated', 'text' => 'تم حفظ إيميل الطلبات/الأدمن.'];
            }

            // 1) أرشفة السجلات الأقدم من 6 أشهر (نقل إلى جدول الأرشفة ثم الحذف)
            if (isset($_POST['archive_old_logs']) && function_exists('libya_archive_old_logs_v14')) {
                $six_months_ago = date('Y-m-d H:i:s', strtotime('-6 months'));
                $result = libya_archive_old_logs_v14($six_months_ago);
                if ($result['error']) {
                    $messages[] = ['type' => 'warning', 'text' => $result['error']];
                } else {
                    if (function_exists('libya_system_log_v14') && $result['moved'] > 0) {
                        libya_system_log_v14('أرشفة السجلات', 'المعتمد', "تم نقل {$result['moved']} سجل أقدم من 6 أشهر إلى جدول الأرشفة.");
                    }
                    $messages[] = ['type' => 'updated', 'text' => "تم أرشفة {$result['moved']} سجل قديم (نقل إلى الجدول الاحتياطي ثم حذفها من الجدول الرئيسي)."];
                }
            }

            // 2) تنظيف السجلات القديمة (حذف مباشر بدون أرشفة)
            if (isset($_POST['clean_old_logs'])) {
                $table_exists = ($wpdb->get_var($wpdb->prepare("SHOW TABLES LIKE %s", $logs_table)) === $logs_table);
                if ($table_exists) {
                    $six_months_ago = date('Y-m-d H:i:s', strtotime('-6 months'));
                    $deleted = $wpdb->query(
                        $wpdb->prepare("DELETE FROM {$logs_table} WHERE time < %s", $six_months_ago)
                    );
                    $deleted = ($deleted !== false) ? (int) $deleted : 0;
                    if (function_exists('libya_system_log_v14')) {
                        libya_system_log_v14('تنظيف السجلات', 'المعتمد', "تم حذف {$deleted} سجل أقدم من 6 أشهر من جدول السجلات.");
                    }
                    $messages[] = ['type' => 'updated', 'text' => "تم حذف {$deleted} سجل قديم من جدول السجلات (إن وجد)."];
                } else {
                    $messages[] = ['type' => 'warning', 'text' => 'جدول السجلات غير موجود حالياً، لم يتم تنفيذ عملية الحذف.'];
                }
            }

            // 3) تنظيف خيارات wp_options الخاصة بالـ transients المنتهية
            if (isset($_POST['clean_wp_options'])) {
                // استعلام مبسّط وآمن نسبياً: نحذف جميع timeouts من الماضي بدون REGEXP معقّد
                $now = time();
                $deleted = $wpdb->query(
                    $wpdb->prepare(
                        "DELETE FROM {$wpdb->options} WHERE option_name LIKE %s AND CAST(option_value AS UNSIGNED) < %d",
                        $wpdb->esc_like('_transient_timeout_') . '%',
                        $now
                    )
                );
                $deleted = ($deleted !== false) ? (int) $deleted : 0;
                if (function_exists('libya_system_log_v14')) {
                    libya_system_log_v14('تنظيف wp_options', 'المعتمد', "تم حذف {$deleted} خيار مؤقت منتهي (transient timeouts).");
                }
                $messages[] = ['type' => 'updated', 'text' => "تم حذف {$deleted} خيار مؤقت منتهي من wp_options."];
            }

            // 4) إعادة تشغيل كرون التجار
            if (isset($_POST['restart_cron'])) {
                wp_clear_scheduled_hook('libya_merchant_background_check');
                if (function_exists('libya_merchant_add_cron_intervals')) {
                    add_filter('cron_schedules', 'libya_merchant_add_cron_intervals');
                }
                if (!wp_next_scheduled('libya_merchant_background_check')) {
                    wp_schedule_event(time(), 'every_five_minutes', 'libya_merchant_background_check');
                }
                if (function_exists('libya_system_log_v14')) {
                    libya_system_log_v14('إعادة تشغيل Cron', 'المعتمد', 'تم مسح وجدولة مهمة libya_merchant_background_check من جديد.');
                }
                $messages[] = ['type' => 'updated', 'text' => 'تمت إعادة تشغيل مهام Cron الخاصة بالتجار بنجاح.'];
            }

            // 5) معالجة قائمة انتظار الإيميلات (أرقام الطلبات المؤجلة)
            if (isset($_POST['process_email_queue'])) {
                $pending = get_option('libya_pending_notifications', []);
                $processed = 0;
                if (is_array($pending)) {
                    foreach ($pending as $key => $item) {
                        $order_id = is_array($item) ? (isset($item['order_id']) ? (int)$item['order_id'] : 0) : (int)$item;
                        if ($order_id > 0 && function_exists('notify_merchant_on_new_order_v14')) {
                            notify_merchant_on_new_order_v14($order_id);
                            unset($pending[$key]);
                            $processed++;
                        } elseif (is_array($item) && isset($item['email'], $item['subject'], $item['message'])) {
                            wp_mail($item['email'], $item['subject'], $item['message'], ['Content-Type: text/html; charset=UTF-8']);
                            unset($pending[$key]);
                            $processed++;
                        }
                    }
                    update_option('libya_pending_notifications', array_values($pending));
                }
                if (function_exists('libya_system_log_v14')) {
                    libya_system_log_v14('معالجة قائمة الإيميلات', 'المعتمد', "تم إرسال {$processed} رسالة من قائمة الانتظار.");
                }
                $messages[] = ['type' => 'updated', 'text' => "تمت معالجة {$processed} رسالة بريدية من قائمة الانتظار."];
            }

            // 6) تصفير كاش حجم بيانات التجار
            if (isset($_POST['refresh_merchant_cache'])) {
                delete_option('libya_cached_merchants_size_mb');
                $messages[] = ['type' => 'updated', 'text' => 'تم تصفير كاش حجم بيانات التجار. سيتم إعادة احتسابه تلقائياً عند الحاجة.'];
            }

            // استيراد (CSV) أو استعادة إعدادات (JSON) من ملف واحد
            if (function_exists('libya_process_import_or_restore_v14')) {
                $upload_msg = libya_process_import_or_restore_v14();
                if ($upload_msg !== null) {
                    $messages[] = $upload_msg;
                    set_transient('libya_upload_result_v14', $upload_msg, 60);
                }
            }

            // 7) تفريغ ملف اللوج النصي libya_system_v14.log
            if (isset($_POST['clear_log_file'])) {
                $log_file = WP_CONTENT_DIR . '/libya_system_v14.log';
                if (file_exists($log_file) && is_writable($log_file)) {
                    if (file_put_contents($log_file, '') !== false) {
                        if (function_exists('libya_system_log_v14')) {
                            libya_system_log_v14('تفريغ اللوج النصي', 'المعتمد', 'تم تفريغ ملف libya_system_v14.log من لوحة الصيانة.');
                        }
                        $messages[] = ['type' => 'updated', 'text' => 'تم تفريغ ملف اللوج النصي (libya_system_v14.log) بنجاح.'];
                    } else {
                        $messages[] = ['type' => 'warning', 'text' => 'تعذّر الكتابة على ملف اللوج. تحقق من صلاحيات الملف.'];
                    }
                } else {
                    $messages[] = ['type' => 'warning', 'text' => 'ملف اللوج غير موجود أو غير قابل للكتابة.'];
                }
            }
        }

        // إحصائيات بسيطة وآمنة للعرض فقط
        $table_exists = ($wpdb->get_var($wpdb->prepare("SHOW TABLES LIKE %s", $logs_table)) === $logs_table);
        $old_logs_6m = 0;
        if ($table_exists) {
            $six_months_ago = date('Y-m-d H:i:s', strtotime('-6 months'));
            $old_logs_6m = (int) $wpdb->get_var(
                $wpdb->prepare("SELECT COUNT(*) FROM {$logs_table} WHERE time < %s", $six_months_ago)
            );
        }

        $cron_next = wp_next_scheduled('libya_merchant_background_check');
        $cron_status = $cron_next ? 'يعمل' : 'غير مجدول';
        $cron_next_text = $cron_next ? sprintf('بعد حوالي %d دقيقة', max(0, floor(($cron_next - time()) / 60))) : 'لا يوجد';

        $pending_emails = get_option('libya_pending_notifications', []);
        $pending_count = is_array($pending_emails) ? count($pending_emails) : 0;

        $libya_production_defined = defined('LIBYA_PRODUCTION');
        $libya_production_active = $libya_production_defined && function_exists('libya_is_production_v14') && libya_is_production_v14();

    ?>
        <style>
            .libya-maint {
                direction: rtl;
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
                max-width: 1000px;
                margin: 20px auto 40px;
                padding: 0 16px;
            }

            .libya-maint * {
                box-sizing: border-box;
            }

            .libya-maint .maint-header {
                display: flex;
                align-items: center;
                justify-content: space-between;
                flex-wrap: wrap;
                gap: 12px;
                margin-bottom: 24px;
                padding-bottom: 20px;
                border-bottom: 2px solid #04acf4;
            }

            .libya-maint .maint-title {
                margin: 0;
                font-size: 22px;
                font-weight: 700;
                color: #0284c7;
            }

            .libya-maint .maint-back {
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
                transition: background .15s, color .15s;
            }

            .libya-maint .maint-back:hover {
                background: #bae6fd;
                color: #0284c7;
            }

            .libya-maint .maint-desc {
                margin: 0 0 24px;
                font-size: 14px;
                line-height: 1.6;
                color: #6b7280;
            }

            .libya-maint .maint-msg {
                margin: 0 0 12px;
                padding: 12px 16px;
                border-radius: 8px;
                font-size: 14px;
                border: 1px solid transparent;
            }

            .libya-maint .maint-msg.updated {
                background: #ecfdf5;
                color: #065f46;
                border-color: #a7f3d0;
            }

            .libya-maint .maint-msg.warning {
                background: #fffbeb;
                color: #92400e;
                border-color: #fde68a;
            }

            .libya-maint .maint-cards {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
                gap: 16px;
                margin-bottom: 28px;
            }

            .libya-maint .maint-card {
                background: #fff;
                border: 1px solid #d1d5db;
                border-radius: 12px;
                padding: 20px;
                box-shadow: 0 1px 3px rgba(0, 0, 0, .05);
                position: relative;
                overflow: hidden;
            }

            .libya-maint .maint-card::before {
                content: '';
                position: absolute;
                top: 0;
                right: 0;
                width: 4px;
                height: 100%;
                border-radius: 0 12px 12px 0;
            }

            .libya-maint .maint-card:nth-child(1)::before {
                background: linear-gradient(180deg, #0284c7, #04acf4);
            }

            .libya-maint .maint-card:nth-child(2)::before {
                background: linear-gradient(180deg, #059669, #10b981);
            }

            .libya-maint .maint-card:nth-child(3)::before {
                background: linear-gradient(180deg, #7c3aed, #a78bfa);
            }

            .libya-maint .maint-card h3 {
                margin: 0 0 12px;
                font-size: 13px;
                font-weight: 600;
                text-transform: uppercase;
                letter-spacing: .02em;
            }

            .libya-maint .maint-card:nth-child(1) h3 {
                color: #0284c7;
            }

            .libya-maint .maint-card:nth-child(2) h3 {
                color: #059669;
            }

            .libya-maint .maint-card:nth-child(3) h3 {
                color: #7c3aed;
            }

            .libya-maint .maint-card .val {
                font-size: 20px;
                font-weight: 700;
                color: #111827;
            }

            .libya-maint .maint-card .sub {
                font-size: 12px;
                color: #9ca3af;
                margin-top: 4px;
            }

            .libya-maint .maint-section {
                background: #fff;
                border: 1px solid #cbd5e1;
                border-radius: 12px;
                padding: 24px;
                margin-bottom: 24px;
                box-shadow: 0 2px 8px rgba(0, 0, 0, .08);
                border-right: 4px solid #04acf4;
            }

            .libya-maint .maint-section h2 {
                margin: 0 0 20px;
                font-size: 16px;
                font-weight: 600;
                color: #0284c7;
                padding-bottom: 10px;
                border-bottom: 1px solid #cbd5e1;
            }

            .libya-maint .maint-action {
                display: flex;
                align-items: center;
                justify-content: space-between;
                flex-wrap: wrap;
                gap: 12px;
                padding: 14px 0;
                border-bottom: 1px solid #cbd5e1;
            }

            .libya-maint .maint-action:last-of-type {
                border-bottom: none;
                padding-bottom: 0;
            }

            .libya-maint .maint-action .label {
                font-size: 14px;
                color: #374151;
                font-weight: 500;
            }

            .libya-maint .maint-action .hint {
                font-size: 12px;
                color: #9ca3af;
                margin-top: 2px;
            }

            .libya-maint .maint-action .btn {
                padding: 8px 16px;
                border-radius: 8px;
                font-size: 13px;
                font-weight: 500;
                cursor: pointer;
                border: 1px solid transparent;
                transition: background .15s, border-color .15s;
            }

            .libya-maint .maint-action .btn-primary {
                background: linear-gradient(135deg, #0284c7, #04acf4);
                color: #fff;
                border-color: #0284c7;
            }

            .libya-maint .maint-action .btn-primary:hover {
                background: linear-gradient(135deg, #0369a1, #0284c7);
            }

            .libya-maint .maint-action .btn-secondary {
                background: #f8fafc;
                color: #475569;
                border-color: #cbd5e1;
            }

            .libya-maint .maint-action .btn-secondary:hover {
                background: #bae6fd;
                color: #0369a1;
                border-color: #bae6fd;
            }

            .libya-maint .maint-alert {
                margin-top: 20px;
                padding: 14px 18px;
                background: #fef3c7;
                border: 1px solid #fcd34d;
                border-radius: 8px;
                font-size: 13px;
                color: #92400e;
                border-right: 4px solid #f59e0b;
            }

            .libya-maint .maint-alert strong {
                display: inline-block;
                margin-left: 4px;
            }

            #wpbody-content .update-nag,
            #wpbody-content .updated,
            #wpbody-content .error,
            #wpbody-content .notice,
            #wpbody-content .notice-success,
            #wpbody-content .notice-warning,
            #wpbody-content .notice-error,
            #wpbody-content .notice-info,
            #wpbody-content .is-dismissible,
            #wpbody-content #setting-error-tgmpa {
                display: none !important;
            }

            @media (max-width: 600px) {
                .libya-maint {
                    max-width: 100%;
                    padding: 0 12px;
                }

                .libya-maint .maint-card,
                .libya-maint .maint-section {
                    padding: 16px;
                }
            }
        </style>
        <div class="wrap libya-maint">
            <div class="maint-header">
                <a href="<?php echo esc_url(admin_url('admin.php?page=merchant-main-dashboard')); ?>" class="maint-back">← رجوع للرئيسية</a>
                <h1 class="maint-title">صيانة المعتمد</h1>
            </div>
            <p class="maint-desc">عمليات صيانة آمنة للنظام. يُفضّل أخذ نسخة احتياطية من قاعدة البيانات قبل أي عملية حذف.</p>

            <p class="maint-desc" style="margin-bottom: 12px; padding: 10px 14px; background: <?php echo $libya_production_active ? '#ecfdf5' : '#fef3c7'; ?>; border: 1px solid <?php echo $libya_production_active ? '#a7f3d0' : '#fde68a'; ?>; border-radius: 8px; font-size: 13px;">
                <strong>حالة البيئة:</strong>
                <?php if ($libya_production_defined && $libya_production_active) : ?>
                    <code>LIBYA_PRODUCTION</code> معرّف ومفعّل ✓ (وضع إنتاج)
                <?php elseif ($libya_production_defined) : ?>
                    <code>LIBYA_PRODUCTION</code> معرّف لكنه غير مفعّل (قيمته false)
                <?php else : ?>
                    <code>LIBYA_PRODUCTION</code> غير معرّف في wp-config.php (وضع تطوير)
                <?php endif; ?>
            </p>

            <?php foreach ($messages as $msg): ?>
                <div class="maint-msg <?php echo esc_attr($msg['type']); ?>"><?php echo esc_html($msg['text']); ?></div>
            <?php endforeach; ?>

            <div class="maint-cards">
                <div class="maint-card">
                    <h3>جدول السجلات</h3>
                    <div class="val"><?php echo $table_exists ? 'موجود' : 'غير موجود'; ?></div>
                    <div class="sub">سجلات أقدم من 6 أشهر: <?php echo number_format($old_logs_6m); ?></div>
                </div>
                <div class="maint-card">
                    <h3>Cron</h3>
                    <div class="val"><?php echo esc_html($cron_status); ?></div>
                    <div class="sub"><?php echo esc_html($cron_next_text); ?></div>
                </div>
                <div class="maint-card">
                    <h3>قائمة الإيميلات</h3>
                    <div class="val"><?php echo (int) $pending_count; ?></div>
                    <div class="sub">رسالة في الانتظار</div>
                </div>
            </div>

            <?php
            $libya_orders_email_display = get_option('libya_orders_email', '');
            if ($libya_orders_email_display === '' || !is_email($libya_orders_email_display)) {
                $libya_orders_email_display = 'orders@almuetamad.com';
            }
            ?>
            <div class="maint-section">
                <h2>إعدادات البريد</h2>
                <form method="post" style="margin-bottom: 24px;">
                    <?php wp_nonce_field('libya_maintenance_actions'); ?>
                    <input type="hidden" name="save_orders_email" value="1" />
                    <div class="maint-action">
                        <div>
                            <div class="label">إيميل الطلبات / الأدمن</div>
                            <div class="hint">يُستخدم كمستلم لتنبيهات الأدمن (التسليم، التحويل، حد الطلبيات) وكعنوان «من» لرسائل النظام للتجار والعملاء. إن تركت الحقل فارغاً يُستخدم الافتراضي (orders@almuetamad.com).</div>
                            <input type="email" name="libya_orders_email" value="<?php echo esc_attr($libya_orders_email_display); ?>" placeholder="orders@almuetamad.com" style="max-width: 320px; margin-top: 6px; padding: 8px 12px; border: 1px solid #cbd5e1; border-radius: 8px; font-size: 14px;" />
                        </div>
                        <button type="submit" class="btn btn-secondary">حفظ</button>
                    </div>
                </form>

            <?php if (function_exists('libya_render_export_import_section_v14')) { libya_render_export_import_section_v14(); } ?>

                <h2>إجراءات الصيانة</h2>
                <form method="post">
                    <?php wp_nonce_field('libya_maintenance_actions'); ?>

                    <div class="maint-action">
                        <div>
                            <div class="label">أرشفة السجلات القديمة</div>
                            <div class="hint">نقل السجلات الأقدم من 6 أشهر إلى جدول الأرشفة ثم حذفها (يحافظ على البيانات للرجوع)</div>
                        </div>
                        <button type="submit" name="archive_old_logs" class="btn btn-secondary" onclick="return confirm('سيتم نقل السجلات الأقدم من 6 أشهر إلى جدول الأرشفة ثم حذفها من الجدول الرئيسي. هل أنت متأكد؟');">تنفيذ</button>
                    </div>
                    <div class="maint-action">
                        <div>
                            <div class="label">تنظيف السجلات القديمة (حذف مباشر)</div>
                            <div class="hint">حذف السجلات الأقدم من 6 أشهر بدون أرشفة</div>
                        </div>
                        <button type="submit" name="clean_old_logs" class="btn btn-primary" onclick="return confirm('سيتم حذف السجلات الأقدم من 6 أشهر. هل أنت متأكد؟');">تنفيذ</button>
                    </div>

                    <div class="maint-action">
                        <div>
                            <div class="label">تنظيف الخيارات المؤقتة</div>
                            <div class="hint">حذف transients المنتهية من wp_options</div>
                        </div>
                        <button type="submit" name="clean_wp_options" class="btn btn-secondary" onclick="return confirm('سيتم حذف الخيارات المؤقتة المنتهية. هل أنت متأكد؟');">تنفيذ</button>
                    </div>

                    <div class="maint-action">
                        <div>
                            <div class="label">إعادة تشغيل Cron</div>
                            <div class="hint">إعادة جدولة مهام التجار</div>
                        </div>
                        <button type="submit" name="restart_cron" class="btn btn-secondary">تنفيذ</button>
                    </div>

                    <div class="maint-action">
                        <div>
                            <div class="label">معالجة قائمة الإيميلات</div>
                            <div class="hint">إرسال الرسائل المعلقة في قائمة الانتظار</div>
                        </div>
                        <button type="submit" name="process_email_queue" class="btn btn-secondary">تنفيذ</button>
                    </div>

                    <div class="maint-action">
                        <div>
                            <div class="label">تفريغ ملف اللوج النصي</div>
                            <div class="hint">تفريغ محتوى libya_system_v14.log لتقليل حجم الملف (السجلات تبقى في جدول السجلات)</div>
                        </div>
                        <button type="submit" name="clear_log_file" class="btn btn-secondary" onclick="return confirm('سيتم تفريغ محتوى ملف اللوج النصي. هل أنت متأكد؟');">تفريغ اللوج</button>
                    </div>

                    <div class="maint-action">
                        <div>
                            <div class="label">تصفير كاش التجار</div>
                            <div class="hint">إعادة احتساب حجم البيانات عند الحاجة</div>
                        </div>
                        <button type="submit" name="refresh_merchant_cache" class="btn btn-secondary">تنفيذ</button>
                    </div>

                    <div class="maint-alert">
                        <strong>تنبيه:</strong> يُنصح بأخذ نسخة احتياطية من قاعدة البيانات قبل عمليات الحذف أو التنظيف.
                    </div>
                </form>
            </div>
        </div>
<?php
    }
}
