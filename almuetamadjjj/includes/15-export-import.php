<?php
/**
 * نظام المعتمد – نسخ احتياطي / تصدير واستيراد
 * - تصدير قائمة المتاجر، أرشيف الطلبات (CSV)، نسخ احتياطي للإعدادات (JSON)
 * - استيراد تجار من CSV أو استعادة الإعدادات من JSON (نموذج واحد وزر واحد)
 */
if (!defined('ABSPATH')) {
    return;
}

add_action('admin_init', 'libya_export_import_handle_downloads_v14', 5);

function libya_export_import_handle_downloads_v14()
{
    if (!current_user_can('manage_options')) {
        return;
    }
    if (!isset($_GET['page']) || $_GET['page'] !== 'system-maintenance') {
        return;
    }
    $export = isset($_GET['libya_export']) ? sanitize_text_field(wp_unslash($_GET['libya_export'])) : '';
    $allowed = ['merchants', 'orders_archive', 'settings'];
    if ($export === '' || !in_array($export, $allowed, true)) {
        return;
    }
    if (!isset($_GET['_wpnonce']) || !wp_verify_nonce(sanitize_text_field(wp_unslash($_GET['_wpnonce'])), 'libya_export_' . $export)) {
        wp_die('الرابط غير صالح أو منتهي.');
    }

    if ($export === 'merchants') {
        libya_export_merchants_csv_v14();
        exit;
    }
    if ($export === 'orders_archive') {
        libya_export_orders_archive_csv_v14();
        exit;
    }
    if ($export === 'settings') {
        libya_export_settings_backup_v14();
        exit;
    }
}

function libya_export_merchants_csv_v14()
{
    $merchants = function_exists('get_libya_merchants_v14') ? get_libya_merchants_v14() : [];
    $filename = 'libya-merchants-' . date('Y-m-d-His') . '.csv';
    header('Content-Type: text/csv; charset=UTF-8');
    header('Content-Disposition: attachment; filename="' . $filename . '"');
    echo "\xEF\xBB\xBF";
    $out = fopen('php://output', 'w');
    fputcsv($out, ['البريد', 'المدينة', 'اسم المتجر', 'اسم المالك', 'الهاتف', 'لون البطاقة', 'حد الطلبات', 'الحالة']);
    foreach ($merchants as $email => $m) {
        $row = [
            $email,
            isset($m['city']) ? $m['city'] : '',
            isset($m['branch_name']) ? $m['branch_name'] : '',
            isset($m['owner_name']) ? $m['owner_name'] : '',
            isset($m['phone']) ? $m['phone'] : '',
            isset($m['card_color']) ? $m['card_color'] : '',
            isset($m['order_limit']) ? $m['order_limit'] : '',
            isset($m['status']) ? $m['status'] : 'active',
        ];
        fputcsv($out, $row);
    }
    fclose($out);
}

function libya_export_orders_archive_csv_v14()
{
    global $wpdb;
    $merchants = function_exists('get_libya_merchants_v14') ? get_libya_merchants_v14() : [];
    $prefix = $wpdb->esc_like('merchant_recent_orders_') . '%';
    $recent_names = $wpdb->get_col($wpdb->prepare(
        "SELECT option_name FROM {$wpdb->options} WHERE option_name LIKE %s",
        $prefix
    ));
    $prefix_arch = $wpdb->esc_like('merchant_archive_') . '%';
    $archive_names = $wpdb->get_col($wpdb->prepare(
        "SELECT option_name FROM {$wpdb->options} WHERE option_name LIKE %s",
        $prefix_arch
    ));
    $email_to_order_ids = [];
    foreach ($recent_names as $name) {
        $email = str_replace('merchant_recent_orders_', '', $name);
        if ($email === '') continue;
        $val = get_option($name, []);
        if (!is_array($val)) $val = [];
        foreach ($val as $oid) {
            $email_to_order_ids[$email][(int) $oid] = true;
        }
    }
    foreach ($archive_names as $name) {
        $email = str_replace('merchant_archive_', '', $name);
        if ($email === '') continue;
        $val = get_option($name, []);
        if (!is_array($val)) $val = [];
        if (!isset($email_to_order_ids[$email])) $email_to_order_ids[$email] = [];
        foreach ($val as $oid) {
            $email_to_order_ids[$email][(int) $oid] = true;
        }
    }

    $rows = [];
    foreach ($email_to_order_ids as $email => $ids) {
        $order_ids = array_keys($ids);
        $m = isset($merchants[$email]) ? $merchants[$email] : [];
        foreach ($order_ids as $order_id) {
            if ($order_id <= 0) continue;
            $order = function_exists('wc_get_order') ? wc_get_order($order_id) : null;
            if (!$order) continue;
            $total = (float) $order->get_total();
            $breakdown = function_exists('get_libya_merchant_commission_breakdown_v14') ? get_libya_merchant_commission_breakdown_v14($total, $m) : ['total' => 0, 'percentage' => 0, 'fixed' => 0];
            $rows[] = [
                'order_id' => $order_id,
                'email' => $email,
                'branch_name' => isset($m['branch_name']) ? $m['branch_name'] : '',
                'city' => isset($m['city']) ? $m['city'] : '',
                'total' => $total,
                'commission' => $breakdown['total'],
                'date' => $order->get_date_created() ? $order->get_date_created()->date('Y-m-d H:i:s') : '',
            ];
        }
    }
    usort($rows, function ($a, $b) {
        return strcmp($b['date'], $a['date']);
    });

    $filename = 'libya-orders-archive-' . date('Y-m-d-His') . '.csv';
    header('Content-Type: text/csv; charset=UTF-8');
    header('Content-Disposition: attachment; filename="' . $filename . '"');
    echo "\xEF\xBB\xBF";
    $out = fopen('php://output', 'w');
    fputcsv($out, ['رقم الطلب', 'بريد التاجر', 'المتجر', 'المدينة', 'الإجمالي', 'العمولة', 'التاريخ']);
    foreach ($rows as $r) {
        fputcsv($out, $r);
    }
    fclose($out);
}

function libya_export_settings_backup_v14()
{
    $keys = [
        'libya_orders_email',
        'libya_def_deadline',
        'libya_def_extra_time',
        'libya_def_limit',
        'libya_def_rate',
        'libya_def_fixed',
        'libya_def_rate_tiers',
        'libya_def_fixed_tiers',
        'libya_bank_accounts_v14',
    ];
    $data = ['version' => 'libya_v14', 'exported' => date('Y-m-d H:i:s')];
    foreach ($keys as $key) {
        $data['options'][$key] = get_option($key, null);
    }
    $filename = 'libya-settings-backup-' . date('Y-m-d-His') . '.json';
    header('Content-Type: application/json; charset=UTF-8');
    header('Content-Disposition: attachment; filename="' . $filename . '"');
    echo wp_json_encode($data, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
}

/**
 * استيراد تجار من مسار ملف CSV (بدون التحقق من POST)
 */
function libya_import_merchants_from_file_v14($tmp)
{
    if (!is_uploaded_file($tmp)) {
        return ['type' => 'warning', 'text' => 'الملف المرفوع غير صالح.'];
    }
    $merchants = function_exists('get_libya_merchants_v14') ? get_libya_merchants_v14() : [];
    $def_rate = get_option('libya_def_rate_tiers', [['from' => 0, 'to' => 0, 'rate' => (float) get_option('libya_def_rate', 10)]]);
    $def_fixed = get_option('libya_def_fixed_tiers', [['from' => 0, 'to' => 0, 'fixed' => (float) get_option('libya_def_fixed', 0)]]);
    if (!is_array($def_rate) || empty($def_rate)) {
        $def_rate = [['from' => 0, 'to' => 0, 'rate' => 10]];
    }
    if (!is_array($def_fixed) || empty($def_fixed)) {
        $def_fixed = [['from' => 0, 'to' => 0, 'fixed' => 0]];
    }
    $allowed_colors = function_exists('libya_merchant_card_colors_v14') ? array_keys(libya_merchant_card_colors_v14()) : [];
    $imported = 0;
    $skipped = 0;
    $max_rows = 5000;
    $fp = @fopen($tmp, 'r');
    if (!$fp) {
        return ['type' => 'warning', 'text' => 'تعذر فتح الملف. تأكد من أن الملف غير تالف.'];
    }

    $first = true;
    $hit_limit = false;
    while (($row = fgetcsv($fp, 0, ',')) !== false) {
        if ($imported + $skipped >= $max_rows) {
            $hit_limit = true;
            break;
        }
        if (count($row) < 2) {
            continue;
        }
        $row0 = isset($row[0]) ? trim($row[0]) : '';
        if (substr($row0, 0, 3) === "\xEF\xBB\xBF") {
            $row0 = substr($row0, 3);
        }
        if ($first && (strpos($row0, 'البريد') !== false || stripos($row0, 'email') !== false)) {
            $first = false;
            continue;
        }
        $first = false;
        $email = sanitize_email($row0);
        if (!is_email($email)) {
            $skipped++;
            continue;
        }
        $city = isset($row[1]) ? sanitize_text_field($row[1]) : '';
        $branch_name = isset($row[2]) ? sanitize_text_field($row[2]) : '';
        $owner_name = isset($row[3]) ? sanitize_text_field($row[3]) : '';
        $phone = isset($row[4]) ? sanitize_text_field($row[4]) : '';
        $card_color = isset($row[5]) ? sanitize_text_field(trim($row[5])) : '';
        if ($card_color !== '' && !in_array($card_color, $allowed_colors, true)) {
            $card_color = '';
        }
        $order_limit = isset($row[6]) ? max(0, (int) $row[6]) : (int) get_option('libya_def_limit', 20);
        $status = isset($row[7]) && in_array(trim($row[7]), ['active', 'frozen'], true) ? trim($row[7]) : 'active';

        $merchants[$email] = [
            'email' => $email,
            'city' => $city,
            'branch_name' => $branch_name,
            'owner_name' => $owner_name,
            'phone' => $phone,
            'card_color' => $card_color,
            'commission_rate_tiers' => isset($merchants[$email]['commission_rate_tiers']) && is_array($merchants[$email]['commission_rate_tiers']) ? $merchants[$email]['commission_rate_tiers'] : $def_rate,
            'fixed_commission_tiers' => isset($merchants[$email]['fixed_commission_tiers']) && is_array($merchants[$email]['fixed_commission_tiers']) ? $merchants[$email]['fixed_commission_tiers'] : $def_fixed,
            'order_limit' => $order_limit,
            'status' => $status,
            'last_activity' => isset($merchants[$email]['last_activity']) ? $merchants[$email]['last_activity'] : time(),
        ];
        $imported++;
    }
    fclose($fp);

    if ($imported > 0 && function_exists('save_libya_merchants_v14')) {
        save_libya_merchants_v14($merchants);
    }

    $text = "تم استيراد {$imported} تاجر بنجاح.";
    if ($skipped > 0) {
        $text .= " تم تخطي {$skipped} صف (بريد غير صالح أو فارغ).";
    }
    if ($hit_limit) {
        $text .= " تم الاكتفاء بأول " . $max_rows . " صف من الملف.";
    }
    if ($imported === 0 && $skipped === 0) {
        $text = 'لم يتم استيراد أي تاجر. تأكد من صيغة الملف: البريد، المدينة، اسم المتجر، اسم المالك، الهاتف، لون البطاقة، حد الطلبات، الحالة.';
        return ['type' => 'warning', 'text' => $text];
    }
    return ['type' => 'updated', 'text' => $text];
}

/**
 * استعادة الإعدادات من مسار ملف JSON (بدون التحقق من POST)
 */
function libya_restore_settings_from_file_v14($tmp)
{
    if (!file_exists($tmp) || !is_readable($tmp)) {
        return ['type' => 'warning', 'text' => 'الملف غير صالح أو غير قابل للقراءة.'];
    }
    $raw = @file_get_contents($tmp);
    if ($raw === false) {
        return ['type' => 'warning', 'text' => 'تعذر قراءة الملف.'];
    }
    $data = json_decode($raw, true);
    if (!is_array($data) || empty($data['options']) || !is_array($data['options'])) {
        return ['type' => 'warning', 'text' => 'ملف غير صالح. تأكد أنه نسخة احتياطية من نظام المعتمد (JSON).'];
    }

    $allowed_keys = [
        'libya_orders_email',
        'libya_def_deadline',
        'libya_def_extra_time',
        'libya_def_limit',
        'libya_def_rate',
        'libya_def_fixed',
        'libya_def_rate_tiers',
        'libya_def_fixed_tiers',
        'libya_bank_accounts_v14',
    ];
    $restored = 0;
    foreach ($allowed_keys as $key) {
        if (!array_key_exists($key, $data['options'])) {
            continue;
        }
        $value = $data['options'][$key];
        if ($key === 'libya_orders_email') {
            $value = is_string($value) ? sanitize_email($value) : '';
        } elseif (in_array($key, ['libya_def_deadline', 'libya_def_extra_time', 'libya_def_limit'], true)) {
            $value = max(0, (int) $value);
        } elseif (in_array($key, ['libya_def_rate', 'libya_def_fixed'], true)) {
            $value = (float) $value;
        } elseif ($key === 'libya_bank_accounts_v14') {
            if (!is_array($value)) {
                $value = [];
            } else {
                $value = array_values(array_filter(array_map(function ($item) {
                    if (!is_array($item)) return null;
                    return [
                        'bank_name'   => isset($item['bank_name']) ? sanitize_text_field($item['bank_name']) : '',
                        'account_number' => isset($item['account_number']) ? sanitize_text_field($item['account_number']) : '',
                        'iban'        => isset($item['iban']) ? sanitize_text_field($item['iban']) : '',
                    ];
                }, $value)));
            }
        } elseif (in_array($key, ['libya_def_rate_tiers', 'libya_def_fixed_tiers'], true)) {
            if (!is_array($value)) {
                $value = [];
            }
        }
        update_option($key, $value);
        $restored++;
    }

    $exported_date = isset($data['exported']) ? ' (تاريخ النسخة: ' . $data['exported'] . ')' : '';
    return ['type' => 'updated', 'text' => 'تم استعادة ' . $restored . ' إعداد بنجاح من النسخة الاحتياطية.' . $exported_date];
}

/**
 * معالجة رفع ملف واحد: CSV = استيراد تجار، JSON = استعادة إعدادات
 * ترجع مصفوفة رسالة أو null.
 */
function libya_process_import_or_restore_v14()
{
    if (!current_user_can('manage_options')) {
        return null;
    }
    if (!isset($_POST['libya_upload_backup']) || empty($_FILES['libya_backup_file']['tmp_name'])) {
        return null;
    }
    if (!isset($_POST['_wpnonce']) || !wp_verify_nonce(sanitize_text_field(wp_unslash($_POST['_wpnonce'])), 'libya_maintenance_actions')) {
        return ['type' => 'warning', 'text' => 'الرابط غير صالح. يرجى المحاولة مرة أخرى.'];
    }
    $tmp = $_FILES['libya_backup_file']['tmp_name'];
    if (!is_uploaded_file($tmp)) {
        return ['type' => 'warning', 'text' => 'الملف المرفوع غير صالح.'];
    }
    $name = isset($_FILES['libya_backup_file']['name']) ? $_FILES['libya_backup_file']['name'] : '';
    $ext = strtolower(pathinfo($name, PATHINFO_EXTENSION));
    $allowed_ext = ['json', 'csv', 'txt'];
    if (!in_array($ext, $allowed_ext, true)) {
        return ['type' => 'warning', 'text' => 'نوع الملف غير مدعوم. استخدم ملف CSV أو TXT (لتجار) أو JSON (لإعدادات).'];
    }
    if ($ext === 'json') {
        return libya_restore_settings_from_file_v14($tmp);
    }
    return libya_import_merchants_from_file_v14($tmp);
}

function libya_render_export_import_section_v14()
{
    $base = admin_url('admin.php?page=system-maintenance');
    ?>
    <div class="maint-section">
        <h2>نسخ احتياطي وتصدير</h2>
        <p class="maint-desc" style="margin-bottom: 16px;">تصدير قائمة المتاجر أو أرشيف الطلبات (CSV) أو نسخ احتياطي للإعدادات لاسترجاعها عند الحاجة.</p>
        <div id="libya-export-success-msg" class="maint-msg updated" style="display: none; margin-bottom: 12px;"></div>
        <div class="maint-action libya-export-links" style="flex-wrap: wrap; gap: 12px;">
            <a href="<?php echo esc_url(wp_nonce_url(add_query_arg('libya_export', 'merchants', $base), 'libya_export_merchants')); ?>" class="btn btn-secondary libya-export-link" data-label="قائمة المتاجر">تحميل قائمة المتاجر (CSV)</a>
            <a href="<?php echo esc_url(wp_nonce_url(add_query_arg('libya_export', 'orders_archive', $base), 'libya_export_orders_archive')); ?>" class="btn btn-secondary libya-export-link" data-label="أرشيف الطلبات">تحميل أرشيف الطلبات (CSV)</a>
            <a href="<?php echo esc_url(wp_nonce_url(add_query_arg('libya_export', 'settings', $base), 'libya_export_settings')); ?>" class="btn btn-secondary libya-export-link" data-label="نسخة الإعدادات">تحميل نسخة احتياطية للإعدادات (JSON)</a>
        </div>
        <script>
        (function() {
            var msgEl = document.getElementById('libya-export-success-msg');
            var links = document.querySelectorAll('.libya-export-link');
            function showExportSuccess(label) {
                if (!msgEl) return;
                msgEl.textContent = 'تم تحميل ' + (label || 'الملف') + ' بنجاح.';
                msgEl.style.display = 'block';
                setTimeout(function() { msgEl.style.display = 'none'; }, 5000);
            }
            links.forEach(function(a) {
                a.addEventListener('click', function(e) {
                    e.preventDefault();
                    var url = a.getAttribute('href');
                    var label = a.getAttribute('data-label') || 'الملف';
                    fetch(url, { credentials: 'same-origin' }).then(function(r) {
                        var name = 'libya-export.csv';
                        var disp = r.headers.get('Content-Disposition');
                        if (disp && disp.indexOf('filename=') !== -1) {
                            var m = disp.match(/filename=["']?([^"'\s]+)/);
                            if (m) name = m[1];
                        }
                        return r.blob().then(function(blob) { return { blob: blob, name: name }; });
                    }).then(function(o) {
                        var u = URL.createObjectURL(o.blob);
                        var d = document.createElement('a');
                        d.href = u;
                        d.download = o.name;
                        d.click();
                        URL.revokeObjectURL(u);
                        showExportSuccess(label);
                    }).catch(function() {
                        window.location.href = url;
                    });
                });
            });
        })();
        </script>
        <h2 style="margin-top: 28px;">استيراد / استعادة</h2>
        <?php
        $upload_result = get_transient('libya_upload_result_v14');
        if (is_array($upload_result) && !empty($upload_result['text'])) {
            delete_transient('libya_upload_result_v14');
            $utype = isset($upload_result['type']) ? $upload_result['type'] : 'updated';
            echo '<div class="maint-msg ' . esc_attr($utype) . '" style="margin-bottom: 16px;">' . esc_html($upload_result['text']) . '</div>';
        }
        ?>
        <p class="maint-desc" style="margin-bottom: 16px;">اختر ملفاً واحداً: <strong>CSV</strong> لاستيراد أو تحديث قائمة التجار، أو <strong>JSON</strong> لاستعادة الإعدادات من نسخة احتياطية. يتم تحديد النوع تلقائياً حسب امتداد الملف.</p>
        <form method="post" enctype="multipart/form-data">
            <?php wp_nonce_field('libya_maintenance_actions'); ?>
            <input type="hidden" name="libya_upload_backup" value="1" />
            <div class="maint-action">
                <div>
                    <input type="file" name="libya_backup_file" accept=".csv,.txt,.json,application/json" required style="padding: 8px 0;" />
                </div>
                <button type="submit" class="btn btn-primary" id="libya-upload-backup-btn">استيراد من CSV / استعادة من JSON</button>
            </div>
        </form>
        <script>
        document.getElementById('libya-upload-backup-btn').closest('form').addEventListener('submit', function(e) {
            var inp = this.querySelector('input[name="libya_backup_file"]');
            if (inp && inp.files.length && /\.json$/i.test(inp.files[0].name)) {
                if (!confirm('سيتم استبدال الإعدادات الحالية بقيم النسخة الاحتياطية. هل أنت متأكد؟')) e.preventDefault();
            }
        });
        </script>
        <p class="maint-desc" style="margin-top: 8px; font-size: 13px; color: #64748b;">CSV: البريد، المدينة، اسم المتجر، اسم المالك، الهاتف، لون البطاقة، حد الطلبات، الحالة. — JSON: نسخة احتياطية مصدّرة من الأعلى.</p>
    </div>
    <?php
}
