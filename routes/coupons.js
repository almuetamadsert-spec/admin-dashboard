const express = require('express');
const { logActivity } = require('../lib/settings');

const router = express.Router();

router.get('/', (req, res) => {
  const db = req.db;
  const coupons = db.prepare('SELECT * FROM coupons ORDER BY created_at DESC').all();
  res.render('coupons/list', { coupons, adminUsername: req.session.adminUsername });
});

router.get('/new', (req, res) => {
  res.render('coupons/form', { coupon: null, adminUsername: req.session.adminUsername });
});

router.get('/edit/:id', (req, res) => {
  const db = req.db;
  const coupon = db.prepare('SELECT * FROM coupons WHERE id = ?').get(req.params.id);
  if (!coupon) return res.redirect('/admin/coupons');
  res.render('coupons/form', { coupon, adminUsername: req.session.adminUsername });
});

router.post('/', (req, res) => {
  const db = req.db;
  const b = req.body || {};
  const code = (b.code || '').toUpperCase().trim();
  if (!code) return res.redirect('/admin/coupons/new');
  const discount_type = b.discount_type || 'percent';
  const discount_value = parseFloat(b.discount_value) || 0;
  const min_order = parseFloat(b.min_order) || 0;
  const max_uses = parseInt(b.max_uses, 10) || 0;
  const expires_at = b.expires_at || null;
  db.prepare('INSERT INTO coupons (code, discount_type, discount_value, min_order, max_uses, expires_at, is_active) VALUES (?, ?, ?, ?, ?, ?, ?)').run(code, discount_type, discount_value, min_order, max_uses, expires_at || null, b.is_active !== '0' ? 1 : 0);
  logActivity(db, req.session.adminId, req.session.adminUsername, 'إضافة كوبون', code);
  res.redirect('/admin/coupons');
});

router.post('/update/:id', (req, res) => {
  const db = req.db;
  const b = req.body || {};
  const id = req.params.id;
  const discount_type = b.discount_type || 'percent';
  const discount_value = parseFloat(b.discount_value) || 0;
  const min_order = parseFloat(b.min_order) || 0;
  const max_uses = parseInt(b.max_uses, 10) || 0;
  const expires_at = b.expires_at || null;
  db.prepare('UPDATE coupons SET discount_type = ?, discount_value = ?, min_order = ?, max_uses = ?, expires_at = ?, is_active = ? WHERE id = ?').run(discount_type, discount_value, min_order, max_uses, expires_at || null, b.is_active !== '0' ? 1 : 0, id);
  logActivity(db, req.session.adminId, req.session.adminUsername, 'تعديل كوبون', b.code || id);
  res.redirect('/admin/coupons');
});

router.post('/delete/:id', (req, res) => {
  const db = req.db;
  const id = req.params.id;
  const c = db.prepare('SELECT code FROM coupons WHERE id = ?').get(id);
  db.prepare('DELETE FROM coupons WHERE id = ?').run(id);
  if (c) logActivity(db, req.session.adminId, req.session.adminUsername, 'حذف كوبون', c.code);
  res.redirect('/admin/coupons');
});

module.exports = router;
