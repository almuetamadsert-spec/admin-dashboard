const express = require('express');
const bcrypt = require('bcryptjs');

const router = express.Router({ mergeParams: true });

// تعديل مستخدم — يُعرّف قبل المسارات العامة
router.get('/edit/:id', async (req, res) => {
  const db = req.db;
  const user = await db.prepare('SELECT id, email, role, merchant_id FROM app_users WHERE id = ?').get(req.params.id);
  if (!user) return res.redirect('/admin/app-users');
  const merchants = await db.prepare('SELECT id, name, store_name FROM merchants WHERE is_active = 1 ORDER BY name').all();
  res.render('app_users/edit', { user, merchants, adminUsername: req.session.adminUsername });
});

router.post('/edit/:id', async (req, res) => {
  const db = req.db;
  const id = req.params.id;
  const { role, merchant_id, password } = req.body || {};
  const roleVal = role === 'merchant' ? 'merchant' : 'customer';
  const merchantId = roleVal === 'merchant' && merchant_id ? parseInt(merchant_id, 10) : null;
  const user = await db.prepare('SELECT id FROM app_users WHERE id = ?').get(id);
  if (!user) return res.redirect('/admin/app-users');
  if (password && password.trim().length >= 4) {
    const hash = bcrypt.hashSync(password.trim(), 10);
    await db.prepare('UPDATE app_users SET role = ?, merchant_id = ?, password_hash = ? WHERE id = ?').run(roleVal, merchantId, hash, id);
  } else {
    await db.prepare('UPDATE app_users SET role = ?, merchant_id = ? WHERE id = ?').run(roleVal, merchantId, id);
  }
  res.redirect('/admin/app-users');
});

router.get('/', async (req, res) => {
  const db = req.db;

  // Pagination
  const page = Math.max(1, parseInt(req.query.page) || 1);
  const limit = 50;
  const offset = (page - 1) * limit;

  // Search logic (optional, keeping it simple as before, but supporting standard pagination)
  let baseQuery = 'FROM app_users u LEFT JOIN merchants m ON m.id = u.merchant_id';
  let queryParams = [];

  // Stats
  const statsRow = await db.prepare(`
    SELECT 
      COUNT(u.id) as total_users,
      SUM(CASE WHEN u.role = 'customer' THEN 1 ELSE 0 END) as total_customers,
      SUM(CASE WHEN u.role = 'merchant' THEN 1 ELSE 0 END) as total_merchants
    FROM app_users u
  `).get();

  const stats = {
    total: statsRow.total_users || 0,
    customers: statsRow.total_customers || 0,
    merchants: statsRow.total_merchants || 0
  };

  const totalUsersCount = statsRow.total_users || 0;
  const totalPages = Math.ceil(totalUsersCount / limit);

  const [users, merchants] = await Promise.all([
    db.prepare(`
      SELECT u.id, u.email, u.role, u.merchant_id, u.created_at, m.name as merchant_name, m.store_name
      ${baseQuery}
      ORDER BY u.created_at DESC
      LIMIT ? OFFSET ?
    `).all(limit, offset),
    db.prepare('SELECT id, name, store_name FROM merchants WHERE is_active = 1 ORDER BY name').all()
  ]);

  res.render('app_users/list', {
    users,
    merchants,
    stats,
    page,
    totalPages,
    query: req.query,
    adminUsername: req.session.adminUsername,
    title: 'مستخدمو التطبيق'
  });
});

router.post('/', async (req, res) => {
  const db = req.db;
  const { email, password, role, merchant_id } = req.body || {};
  const emailTrim = (email || '').trim().toLowerCase();
  if (!emailTrim) return res.redirect('/admin/app-users');
  const roleVal = role === 'merchant' ? 'merchant' : 'customer';
  const merchantId = roleVal === 'merchant' && merchant_id ? parseInt(merchant_id, 10) : null;
  const pass = (password || '').trim();
  if (!pass || pass.length < 4) {
    return res.redirect('/admin/app-users?error=password_short');
  }
  try {
    const existing = await db.prepare('SELECT id FROM app_users WHERE LOWER(TRIM(email)) = ?').get(emailTrim);
    if (existing) return res.redirect('/admin/app-users?error=email_exists');
    const hash = bcrypt.hashSync(pass, 10);
    await db.prepare('INSERT INTO app_users (email, password_hash, role, merchant_id) VALUES (?, ?, ?, ?)').run(emailTrim, hash, roleVal, merchantId);
    res.redirect('/admin/app-users');
  } catch (e) {
    res.redirect('/admin/app-users?error=server');
  }
});

router.post('/delete/:id', async (req, res) => {
  const db = req.db;
  const id = req.params.id;
  await db.prepare('DELETE FROM app_sessions WHERE user_id = ?').run(id);
  await db.prepare('DELETE FROM app_users WHERE id = ?').run(id);
  res.redirect('/admin/app-users');
});

module.exports = router;
