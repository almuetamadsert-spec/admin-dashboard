const express = require('express');
const { logActivity } = require('../lib/settings');

const router = express.Router();

router.get('/', (req, res) => {
  const db = req.db;
  const cities = db.prepare('SELECT * FROM cities ORDER BY name').all();
  res.render('cities/list', { cities, adminUsername: req.session.adminUsername });
});

router.post('/', (req, res) => {
  const db = req.db;
  const { name, delivery_fee, is_active } = req.body || {};
  if (!name) return res.redirect('/admin/cities');
  const fee = parseFloat(delivery_fee) || 0;
  db.prepare('INSERT INTO cities (name, delivery_fee, is_active) VALUES (?, ?, ?)').run(name.trim(), fee, is_active !== '0' ? 1 : 0);
  logActivity(db, req.session.adminId, req.session.adminUsername, 'إضافة مدينة', name.trim() + ' - رسوم: ' + fee);
  res.redirect('/admin/cities');
});

router.post('/edit/:id', (req, res) => {
  const db = req.db;
  const { name, delivery_fee, is_active } = req.body || {};
  const id = req.params.id;
  const fee = parseFloat(delivery_fee) || 0;
  db.prepare('UPDATE cities SET name = ?, delivery_fee = ?, is_active = ? WHERE id = ?').run(name || '', fee, is_active !== '0' ? 1 : 0, id);
  logActivity(db, req.session.adminId, req.session.adminUsername, 'تعديل مدينة', name + ' - رسوم: ' + fee);
  res.redirect('/admin/cities');
});

router.post('/delete/:id', (req, res) => {
  const db = req.db;
  const id = req.params.id;
  const c = db.prepare('SELECT name FROM cities WHERE id = ?').get(id);
  db.prepare('DELETE FROM cities WHERE id = ?').run(id);
  if (c) logActivity(db, req.session.adminId, req.session.adminUsername, 'حذف مدينة', c.name);
  res.redirect('/admin/cities');
});

module.exports = router;
