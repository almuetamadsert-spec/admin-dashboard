/**
 * منطق النسبة والعمولة (نظام المعتمد)
 * شرائح النسبة المئوية وشرائح العمولة الثابتة حسب نطاق إجمالي الطلب.
 */

const TIER_MAX = 999999999;

function parseTiers(json) {
  if (!json || typeof json !== 'string') return [];
  try {
    const arr = JSON.parse(json);
    return Array.isArray(arr) ? arr : [];
  } catch (e) {
    return [];
  }
}

/**
 * النسبة المئوية المنطبقة على مبلغ من شرائح النسبة
 */
function getRateForAmount(orderTotal, tiers) {
  if (!tiers || !tiers.length) return 0;
  const total = Number(orderTotal) || 0;
  for (const t of tiers) {
    const from = Number(t.from) || 0;
    let to = Number(t.to) || 0;
    if (to <= 0) to = TIER_MAX;
    if (total >= from && total <= to) return Number(t.rate) || 0;
  }
  return 0;
}

/**
 * العمولة الثابتة المنطبقة على مبلغ من شرائح العمولة الثابتة
 */
function getFixedForAmount(orderTotal, tiers) {
  if (!tiers || !tiers.length) return 0;
  const total = Number(orderTotal) || 0;
  for (const t of tiers) {
    const from = Number(t.from) || 0;
    let to = Number(t.to) || 0;
    if (to <= 0) to = TIER_MAX;
    if (total >= from && total <= to) return Number(t.fixed) || 0;
  }
  return 0;
}

/**
 * تفصيل العمولة (نسبة + ثابتة) لطلب بإجمالي معيّن وتاجر
 * merchant: { commission_rate_tiers, fixed_commission_tiers } (نص JSON أو مصفوفات)
 */
function getCommissionBreakdown(orderTotal, merchant) {
  const total = Number(orderTotal) || 0;
  let rateTiers = merchant.commission_rate_tiers;
  let fixedTiers = merchant.fixed_commission_tiers;
  if (typeof rateTiers === 'string') rateTiers = parseTiers(rateTiers);
  else if (!Array.isArray(rateTiers)) rateTiers = [];
  if (typeof fixedTiers === 'string') fixedTiers = parseTiers(fixedTiers);
  else if (!Array.isArray(fixedTiers)) fixedTiers = [];

  const rate = getRateForAmount(total, rateTiers);
  const percentageAmount = total * (rate / 100);
  const fixedAmount = getFixedForAmount(total, fixedTiers);
  return {
    rate,
    percentage: percentageAmount,
    fixed: fixedAmount,
    total: percentageAmount + fixedAmount,
  };
}

function calculateCommission(orderTotal, merchant) {
  const b = getCommissionBreakdown(orderTotal, merchant);
  return b.total;
}

/** قيم افتراضية لشرائح التاجر الجديد */
const DEFAULT_RATE_TIERS = [{ from: 0, to: 0, rate: 10 }];
const DEFAULT_FIXED_TIERS = [{ from: 0, to: 0, fixed: 0 }];

module.exports = {
  parseTiers,
  getRateForAmount,
  getFixedForAmount,
  getCommissionBreakdown,
  calculateCommission,
  DEFAULT_RATE_TIERS,
  DEFAULT_FIXED_TIERS,
};
