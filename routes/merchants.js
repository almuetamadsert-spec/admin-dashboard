const express = require('express');
const { logActivity } = require('../lib/settings');

const router = express.Router();

router.get('/', (req, res) => {
  const db = req.db;
  const merchants = db.prepare(`
    SELECT m.*, c.name as city_name FROM merchants m
    LEFT JOIN cities c ON m.city_id = c.id
    ORDER BY m.name
  `).all();
  const cities = db.prepare('SELECT * FROM cities WHERE is_active = 1 ORDER BY name').all();
  res.render('merchants/list', { merchants, cities, adminUsername: req.session.adminUsername });
});

router.post('/', (req, res) => {
  const db = req.db;
  const { name, store_name, city_id, phone, email, is_active } = req.body || {};
  if (!name) return res.redirect('/admin/merchants');
  db.prepare('INSERT INTO merchants (name, store_name, city_id, phone, email, is_active) VALUES (?, ?, ?, ?, ?, ?)').run(name.trim(), (store_name || '').trim() || null, city_id || null, phone || '', email || '', is_active !== '0' ? 1 : 0);
  logActivity(db, req.session.adminId, req.session.adminUsername, 'إضافة تاجر', name.trim());
  res.redirect('/admin/merchants');
});

router.post('/edit/:id', (req, res) => {
  const db = req.db;
  const { name, store_name, city_id, phone, email, is_active } = req.body || {};
  db.prepare('UPDATE merchants SET name = ?, store_name = ?, city_id = ?, phone = ?, email = ?, is_active = ? WHERE id = ?').run(name || '', (store_name || '').trim() || null, city_id || null, phone || '', email || '', is_active !== '0' ? 1 : 0, req.params.id);
  logActivity(db, req.session.adminId, req.session.adminUsername, 'تعديل تاجر', name);
  res.redirect('/admin/merchants');
});

router.post('/delete/:id', (req, res) => {
  const db = req.db;
  const id = req.params.id;
  const m = db.prepare('SELECT name FROM merchants WHERE id = ?').get(id);
  db.prepare('DELETE FROM merchants WHERE id = ?').run(id);
  if (m) logActivity(db, req.session.adminId, req.session.adminUsername, 'حذف تاجر', m.name);
  res.redirect('/admin/merchants');
});

module.exports = router;
