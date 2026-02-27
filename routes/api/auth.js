const express = require('express');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const apiAuth = require('../../middleware/apiAuth');
const appAuth = require('../../middleware/appAuth');
const router = express.Router();

/** POST /api/auth/login — إيميل + كلمة مرور (يتطلب API key)، يرجع token و role و merchantId */
router.post('/login', apiAuth.requireApiKey, async (req, res) => {
  const db = req.db;
  const { email, password } = req.body || {};
  const emailTrim = (email || '').trim().toLowerCase();
  const passwordStr = typeof password === 'string' ? password : '';

  if (!emailTrim) {
    return res.status(400).json({ ok: false, error: 'email_required', message: 'الإيميل مطلوب' });
  }
  if (!passwordStr) {
    return res.status(400).json({ ok: false, error: 'password_required', message: 'كلمة المرور مطلوبة' });
  }

  try {
    const user = await db.prepare('SELECT id, email, password_hash, role, merchant_id FROM app_users WHERE LOWER(TRIM(email)) = ?').get(emailTrim);
    if (!user) {
      return res.status(401).json({ ok: false, error: 'invalid_credentials', message: 'الإيميل أو كلمة المرور غير صحيحة' });
    }
    if (!user.password_hash) {
      return res.status(401).json({ ok: false, error: 'password_not_set', message: 'هذا الحساب لا يستخدم كلمة مرور. استخدم الدخول بـ Google أو Apple.' });
    }
    const match = bcrypt.compareSync(passwordStr, user.password_hash);
    if (!match) {
      return res.status(401).json({ ok: false, error: 'invalid_credentials', message: 'الإيميل أو كلمة المرور غير صحيحة' });
    }

    const token = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
    await db.prepare('INSERT INTO app_sessions (user_id, token, expires_at) VALUES (?, ?, ?)').run(user.id, token, expiresAt);

    res.status(200).json({
      ok: true,
      token,
      role: user.role || 'customer',
      merchantId: user.merchant_id != null ? user.merchant_id : null,
      email: user.email
    });
  } catch (e) {
    res.status(500).json({ ok: false, error: 'server_error', message: e.message });
  }
});

/** GET /api/auth/me — يرجع المستخدم الحالي (يتطلب Authorization: Bearer <token>) */
router.get('/me', appAuth.requireAppToken, (req, res) => {
  const u = req.appUser;
  res.json({
    ok: true,
    user: {
      id: u.id,
      email: u.email,
      role: u.role,
      merchantId: u.merchant_id
    }
  });
});

/** POST /api/auth/logout — إبطال الجلسة (يتطلب Bearer token) */
router.post('/logout', appAuth.requireAppToken, async (req, res) => {
  const auth = (req.headers.authorization || '').trim();
  const token = auth.startsWith('Bearer ') ? auth.slice(7).trim() : '';
  if (token && req.db) {
    try {
      await req.db.prepare('DELETE FROM app_sessions WHERE token = ?').run(token);
    } catch (e) { /* ignore */ }
  }
  res.json({ ok: true });
});

module.exports = router;
