const https = require('https');
const { getSettings } = require('./settings');

/**
 * إرسال إشعار push للتجار عبر OneSignal.
 * @param {object} db - قاعدة البيانات
 * @param {object} opts - { subscriptionIds: string[], heading_ar: string, content_ar: string, data?: object }
 * @returns {Promise<{ ok: boolean, error?: string }>}
 */
function sendToMerchants(db, opts) {
  const settings = getSettings(db);
  const appId = (settings.onesignal_app_id || '').trim();
  const restKey = (settings.onesignal_rest_api_key || '').trim();
  if (!appId || !restKey) return Promise.resolve({ ok: false, error: 'missing_onesignal_config' });

  const ids = (opts.subscriptionIds || []).filter(Boolean);
  if (ids.length === 0) return Promise.resolve({ ok: true });

  const body = JSON.stringify({
    app_id: appId,
    include_subscription_ids: ids,
    target_channel: 'push',
    headings: { ar: opts.heading_ar || 'إشعار', en: opts.heading_en || opts.heading_ar || 'Notification' },
    contents: { ar: opts.content_ar || '', en: opts.content_en || opts.content_ar || '' },
    data: opts.data || {}
  });

  return new Promise((resolve) => {
    const req = https.request(
      {
        hostname: 'api.onesignal.com',
        path: '/notifications',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Key ' + restKey,
          'Content-Length': Buffer.byteLength(body, 'utf8')
        }
      },
      (res) => {
        let data = '';
        res.on('data', (ch) => { data += ch; });
        res.on('end', () => {
          if (res.statusCode >= 200 && res.statusCode < 300) resolve({ ok: true });
          else resolve({ ok: false, error: data || res.statusCode.toString() });
        });
      }
    );
    req.on('error', (err) => resolve({ ok: false, error: err.message }));
    req.write(body);
    req.end();
  });
}

/**
 * إشعار للتجار عند إنشاء طلب جديد.
 * @param {object} db - قاعدة البيانات
 * @param {string} orderNumber - رقم الطلب
 * @param {number} totalAmount - المبلغ الإجمالي
 * @param {object} opts - اختياري: { cityId: number } لإرسال لتجار مدينة معينة فقط، { customerName, customerPhone } لظهور بيانات العميل في الإشعار
 */
function notifyMerchantsNewOrder(db, orderNumber, totalAmount, opts = {}) {
  let sql = "SELECT onesignal_player_id FROM merchants WHERE is_active = 1 AND onesignal_player_id IS NOT NULL AND onesignal_player_id != ''";
  const params = [];
  if (opts.cityId != null) {
    sql += " AND city_id = ?";
    params.push(opts.cityId);
  }
  const merchants = db.prepare(sql).all(...params);
  const subscriptionIds = merchants.map((m) => m.onesignal_player_id).filter(Boolean);
  if (subscriptionIds.length === 0) return Promise.resolve({ ok: true });

  const customerLine = [opts.customerName, opts.customerPhone].filter(Boolean).join(' — ') || '';
  const contentAr = customerLine
    ? `طلب جديد ${orderNumber} — ${customerLine} — ${Number(totalAmount).toFixed(2)} د.ل`
    : `طلب جديد ${orderNumber} — المبلغ: ${Number(totalAmount).toFixed(2)} د.ل`;

  return sendToMerchants(db, {
    subscriptionIds,
    heading_ar: 'طلب جديد',
    content_ar: contentAr,
    data: {
      type: 'new_order',
      order_number: orderNumber,
      customer_name: opts.customerName || '',
      customer_phone: opts.customerPhone || '',
      total_amount: totalAmount
    }
  });
}

module.exports = { sendToMerchants, notifyMerchantsNewOrder };
