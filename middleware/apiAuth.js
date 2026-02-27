/**
 * التحقق من Consumer Key + Consumer Secret لمفاتيح API.
 * يقبل الهيدرين: X-Consumer-Key و X-Consumer-Secret
 * أو Authorization: Basic base64(consumer_key:consumer_secret)
 * يضع على req: req.apiKeyPermission = 'read_only' | 'read_write'
 */
async function requireApiKey(req, res, next) {
  const db = req.db;
  if (!db) return res.status(503).json({ ok: false, error: 'service_unavailable' });

  let consumerKey = (req.headers['x-consumer-key'] || '').trim();
  let consumerSecret = (req.headers['x-consumer-secret'] || '').trim();

  if (!consumerKey && req.headers.authorization) {
    const m = req.headers.authorization.match(/^Basic\s+(.+)$/i);
    if (m) {
      try {
        const decoded = Buffer.from(m[1], 'base64').toString('utf8');
        const idx = decoded.indexOf(':');
        if (idx !== -1) {
          consumerKey = decoded.slice(0, idx).trim();
          consumerSecret = decoded.slice(idx + 1).trim();
        }
      } catch (e) { /* ignore */ }
    }
  }

  if (!consumerKey || !consumerSecret) {
    return res.status(401).json({ ok: false, error: 'missing_credentials', message: 'يجب إرسال X-Consumer-Key و X-Consumer-Secret أو Authorization: Basic' });
  }

  try {
    const row = await db.prepare('SELECT id, name, permission FROM api_keys WHERE consumer_key = ? AND consumer_secret = ? AND is_active = 1').get(consumerKey, consumerSecret);
    if (!row) {
      return res.status(401).json({ ok: false, error: 'invalid_credentials', message: 'مفتاح أو سر غير صحيح' });
    }
    req.apiKeyId = row.id;
    req.apiKeyName = row.name;
    req.apiKeyPermission = row.permission === 'read_write' ? 'read_write' : 'read_only';
    next();
  } catch (e) {
    return res.status(500).json({ ok: false, error: 'server_error' });
  }
}

/** يتطلب صلاحية قراءة وكتابة (للطلبات التي تغيّر البيانات) */
function requireWrite(req, res, next) {
  if (req.apiKeyPermission !== 'read_write') {
    return res.status(403).json({ ok: false, error: 'forbidden', message: 'هذا المفتاح للقراءة فقط' });
  }
  next();
}

module.exports = { requireApiKey, requireWrite };
