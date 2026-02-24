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
  const todayTotal = (db.prepare(`
    SELECT COALESCE(SUM(total_amount), 0) as total FROM orders
    WHERE date(created_at) = date('now', 'localtime') AND status != 'cancelled'
  `).get() || {}).total || 0;
  const weekRow = db.prepare(`
    SELECT COALESCE(SUM(total_amount), 0) as total, COUNT(*) as count FROM orders
    WHERE created_at >= datetime('now', 'localtime', '-7 days') AND status != 'cancelled'
  `).get();
  const weekTotal = (weekRow && (weekRow.total !== undefined && weekRow.total !== null)) ? Number(weekRow.total) : 0;
  const weekCount = (weekRow && (weekRow.count !== undefined && weekRow.count !== null)) ? Number(weekRow.count) : 0;
  const monthTotal = (db.prepare(`
    SELECT COALESCE(SUM(total_amount), 0) as total FROM orders
    WHERE strftime('%Y-%m', created_at) = strftime('%Y-%m', 'now', 'localtime') AND status != 'cancelled'
  `).get() || {}).total || 0;
  const yearTotal = (db.prepare(`
    SELECT COALESCE(SUM(total_amount), 0) as total FROM orders
    WHERE strftime('%Y', created_at) = strftime('%Y', 'now', 'localtime') AND status != 'cancelled'
  `).get() || {}).total || 0;

  const ordersByStatus = db.prepare(`
    SELECT status, COUNT(*) as count FROM orders GROUP BY status ORDER BY count DESC
  `).all();
  const STATUS_LABELS = { pending: 'قيد الانتظار', confirmed: 'مؤكد', shipped: 'تم الشحن', delivered: 'تم التوصيل', cancelled: 'ملغي' };

  const topProducts = db.prepare(`
    SELECT oi.product_name, SUM(oi.quantity) as total_qty, SUM(oi.total_price) as total_sales
    FROM order_items oi
    JOIN orders o ON o.id = oi.order_id AND o.status != 'cancelled'
    GROUP BY oi.product_id ORDER BY total_qty DESC LIMIT 15
  `).all();

  res.render('sales/index', {
    daily,
    monthly,
    yearly,
    todayTotal,
    weekTotal,
    weekCount,
    monthTotal,
    yearTotal,
    ordersByStatus,
    STATUS_LABELS,
    topProducts,
    adminUsername: req.session.adminUsername
  });
});

module.exports = router;
