const express = require('express');

const router = express.Router();

router.get('/', (req, res) => {
  const db = req.db;
  const productsCount = db.prepare('SELECT COUNT(*) as c FROM products').get().c;
  const ordersCount = db.prepare('SELECT COUNT(*) as c FROM orders').get().c;
  const customersCount = db.prepare('SELECT COUNT(*) as c FROM customers').get().c;
  const todaySales = db.prepare(`
    SELECT COALESCE(SUM(total_amount), 0) as total FROM orders
    WHERE date(created_at) = date('now', 'localtime') AND status != 'cancelled'
  `).get().total;

  res.render('dashboard/index', {
    productsCount,
    ordersCount,
    customersCount,
    todaySales,
    adminUsername: req.session.adminUsername
  });
});

module.exports = router;
