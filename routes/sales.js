const express = require('express');

const router = express.Router();

router.get('/', (req, res) => {
  const db = req.db;
  const daily = db.prepare(`
    SELECT date(created_at) as day, SUM(total_amount) as total, COUNT(*) as count
    FROM orders WHERE status != 'cancelled'
    GROUP BY date(created_at) ORDER BY day DESC LIMIT 31
  `).all();
  const monthly = db.prepare(`
    SELECT strftime('%Y-%m', created_at) as month, SUM(total_amount) as total, COUNT(*) as count
    FROM orders WHERE status != 'cancelled'
    GROUP BY strftime('%Y-%m', created_at) ORDER BY month DESC LIMIT 12
  `).all();
  const yearly = db.prepare(`
    SELECT strftime('%Y', created_at) as year, SUM(total_amount) as total, COUNT(*) as count
    FROM orders WHERE status != 'cancelled'
    GROUP BY strftime('%Y', created_at) ORDER BY year DESC LIMIT 5
  `).all();
  const todayTotal = db.prepare(`
    SELECT COALESCE(SUM(total_amount), 0) as total FROM orders
    WHERE date(created_at) = date('now', 'localtime') AND status != 'cancelled'
  `).get().total;
  const monthTotal = db.prepare(`
    SELECT COALESCE(SUM(total_amount), 0) as total FROM orders
    WHERE strftime('%Y-%m', created_at) = strftime('%Y-%m', 'now', 'localtime') AND status != 'cancelled'
  `).get().total;
  const yearTotal = db.prepare(`
    SELECT COALESCE(SUM(total_amount), 0) as total FROM orders
    WHERE strftime('%Y', created_at) = strftime('%Y', 'now', 'localtime') AND status != 'cancelled'
  `).get().total;

  res.render('sales/index', {
    daily,
    monthly,
    yearly,
    todayTotal,
    monthTotal,
    yearTotal,
    adminUsername: req.session.adminUsername
  });
});

module.exports = router;
