const express = require('express');
const bcrypt = require('bcryptjs');

const router = express.Router();

router.get('/login', (req, res) => {
  if (req.session && req.session.adminId) return res.redirect('/admin/dashboard');
  res.render('admin/login', { error: null });
});

router.post('/login', async (req, res) => {
  const db = req.db;
  const { username, password } = req.body || {};
  if (!username || !password) {
    return res.render('admin/login', { error: 'أدخل اسم المستخدم وكلمة المرور' });
  }
  const admin = await db.prepare('SELECT * FROM admins WHERE username = ?').get(username);
  if (!admin || !bcrypt.compareSync(password, admin.password)) {
    return res.render('admin/login', { error: 'اسم المستخدم أو كلمة المرور غير صحيحة' });
  }
  req.session.adminId = admin.id;
  req.session.adminUsername = admin.username;
  res.redirect('/admin/dashboard');
});

router.get('/logout', (req, res) => {
  req.session.destroy();
  res.redirect('/admin/login');
});

module.exports = router;
