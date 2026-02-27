/**
 * التحقق من توكن تطبيق الجوال (Authorization: Bearer <token>).
 * يضع على req: req.appUser = { id, email, role, merchant_id }
 */
async function requireAppToken(req, res, next) {
  const db = req.db;
  if (!db) return res.status(503).json({ ok: false, error: 'service_unavailable' });

  const auth = (req.headers.authorization || '').trim();
  const token = auth.startsWith('Bearer ') ? auth.slice(7).trim() : '';
  if (!token) {
    return res.status(401).json({ ok: false, error: 'unauthorized', message: 'مطلوب تسجيل الدخول' });
  }

  try {
    const now = new Date().toISOString().slice(0, 19).replace('T', ' ');
    const session = await db.prepare(`
      SELECT s.user_id, u.id, u.email, u.role, u.merchant_id
      FROM app_sessions s
      JOIN app_users u ON u.id = s.user_id
      WHERE s.token = ? AND s.expires_at > ?
    `).get(token, now);
    if (!session) {
      return res.status(401).json({ ok: false, error: 'invalid_token', message: 'انتهت الجلسة أو التوكن غير صالح' });
    }
    req.appUser = {
      id: session.id,
      email: session.email,
      role: session.role || 'customer',
      merchant_id: session.merchant_id != null ? session.merchant_id : null
    };
    next();
  } catch (e) {
    return res.status(500).json({ ok: false, error: 'server_error' });
  }
}

/** يتطلب أن يكون المستخدم تاجراً (role === 'merchant') */
function requireMerchant(req, res, next) {
  if (req.appUser.role !== 'merchant') {
    return res.status(403).json({ ok: false, error: 'forbidden', message: 'هذا المسار للتجار فقط' });
  }
  if (req.appUser.merchant_id == null) {
    return res.status(403).json({ ok: false, error: 'no_merchant', message: 'حساب التاجر غير مرتبط بمتجر' });
  }
  next();
}

module.exports = { requireAppToken, requireMerchant };
