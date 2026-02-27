<?php
/**
 * نظام المعتمد – شرائح العمولة والنسبة والثابتة
 */
if (!defined('ABSPATH')) { return; }

/** أقصى سعر للشريحة (فما فوق) */
if (!defined('LIBYA_COMMISSION_TIER_MAX_PRICE_V14')) {
    define('LIBYA_COMMISSION_TIER_MAX_PRICE_V14', 999999999);
}

/**
 * إرجاع النسبة المئوية المنطبقة على مبلغ من شرائح النسبة
 */
function libya_get_rate_for_amount_v14($order_total, $tiers)
{
    if (empty($tiers) || !is_array($tiers)) return 0;
    $order_total = (float)$order_total;
    foreach ($tiers as $t) {
        $from = isset($t['from']) ? (float)$t['from'] : 0;
        $to = isset($t['to']) ? (float)$t['to'] : 0;
        if ($to <= 0) $to = LIBYA_COMMISSION_TIER_MAX_PRICE_V14;
        if ($order_total >= $from && $order_total <= $to) {
            return isset($t['rate']) ? (float)$t['rate'] : 0;
        }
    }
    return 0;
}

/**
 * إرجاع العمولة الثابتة المنطبقة على مبلغ من شرائح العمولة الثابتة
 */
function libya_get_fixed_for_amount_v14($order_total, $tiers)
{
    if (empty($tiers) || !is_array($tiers)) return 0;
    $order_total = (float)$order_total;
    foreach ($tiers as $t) {
        $from = isset($t['from']) ? (float)$t['from'] : 0;
        $to = isset($t['to']) ? (float)$t['to'] : 0;
        if ($to <= 0) $to = LIBYA_COMMISSION_TIER_MAX_PRICE_V14;
        if ($order_total >= $from && $order_total <= $to) {
            return isset($t['fixed']) ? (float)$t['fixed'] : 0;
        }
    }
    return 0;
}

/**
 * تفصيل العمولة (نسبة + ثابتة) لاستخدامها في التقارير والجداول
 */
function get_libya_merchant_commission_breakdown_v14($order_total, $data)
{
    $order_total = (float)$order_total;
    $percentage = 0;
    $fixed = 0;

    if (!empty($data['commission_rate_tiers']) && is_array($data['commission_rate_tiers'])) {
        $rate = libya_get_rate_for_amount_v14($order_total, $data['commission_rate_tiers']);
        $percentage = $order_total * ($rate / 100);
    } else {
        $rate = !empty($data['commission_rate']) ? (float)$data['commission_rate'] : DEFAULT_COMMISSION_RATE_V14;
        $threshold = !empty($data['commission_threshold']) ? (float)$data['commission_threshold'] : 0;
        $percentage = ($order_total > $threshold) ? ($order_total * ($rate / 100)) : 0;
    }

    if (!empty($data['fixed_commission_tiers']) && is_array($data['fixed_commission_tiers'])) {
        $fixed = libya_get_fixed_for_amount_v14($order_total, $data['fixed_commission_tiers']);
    } else {
        $fixed_val = !empty($data['fixed_commission']) ? (float)$data['fixed_commission'] : 0;
        $fixed_threshold = !empty($data['fixed_threshold']) ? (float)$data['fixed_threshold'] : 0;
        $fixed = ($order_total > $fixed_threshold) ? $fixed_val : 0;
    }

    return ['percentage' => $percentage, 'fixed' => $fixed, 'total' => $percentage + $fixed];
}

/**
 * حساب نسبة العمولة المتقدمة للتاجر
 */
function calculate_libya_merchant_commission_v14($order_total, $data)
{
    $b = get_libya_merchant_commission_breakdown_v14($order_total, $data);
    return $b['total'];
}

// دالة مساعدة لإرجاع HTML بيانات الحسابات المصرفية (لتجنب تكرار الكود)
function get_libya_bank_accounts_html_v14($merchant_data = null)
{
    $bank_accounts = get_option('libya_bank_accounts_v14', []);

    if (!empty($bank_accounts)) {
        $html = "<div style='background: #f7fafc; padding: 15px; border-radius: 10px; border: 1px solid #e2e8f0; margin-bottom: 15px;'>";
        foreach ($bank_accounts as $account) {
            $html .= "<p style='margin: 5px 0;'>• " . esc_html($account['bank_name']) . ": " . esc_html($account['account_number']);
            if (!empty($account['iban'])) {
                $html .= "<br><small style='color: #718096;'>IBAN: " . esc_html($account['iban']) . "</small>";
            }
            $html .= "</p>";
        }
        $html .= "</div>";
        return $html;
    }

    return "
    <div style='background: #fff3cd; padding: 15px; border-radius: 10px; border: 1px solid #ffc107; margin-bottom: 15px; text-align: center;'>
        <p style='margin: 0; color: #856404; font-weight: 500;'>⚠️ لم يتم إضافة حسابات مصرفية بعد. يرجى التواصل مع المسؤول.</p>
    </div>";
}
