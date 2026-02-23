const express = require('express');

const router = express.Router();

router.get('/', (req, res) => {
  const db = req.db;
  const customers = db.prepare('SELECT * FROM customers ORDER BY name').all();
  res.render('customers/list', { customers, adminUsername: req.session.adminUsername });
});

router.post('/', (req, res) => {
  const db = req.db;
  const { name, phone, email, address } = req.body || {};
  if (!name) return res.redirect('/admin/customers');
  db.prepare('INSERT INTO customers (name, phone, email, address) VALUES (?, ?, ?, ?)').run(name || '', phone || '', email || '', address || '');
  res.redirect('/admin/customers');
});

router.post('/edit/:id', (req, res) => {
  const db = req.db;
  const { name, phone, email, address } = req.body || {};
  db.prepare('UPDATE customers SET name = ?, phone = ?, email = ?, address = ? WHERE id = ?').run(name || '', phone || '', email || '', address || '', req.params.id);
  res.redirect('/admin/customers');
});

router.post('/delete/:id', (req, res) => {
  const db = req.db;
  db.prepare('DELETE FROM customers WHERE id = ?').run(req.params.id);
  res.redirect('/admin/customers');
});

module.exports = router;
