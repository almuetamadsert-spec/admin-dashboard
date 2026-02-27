const express = require('express');

const router = express.Router();

const isMaria = (db) => (db.driver === 'mariadb');

router.get('/', async (req, res) => {
  const db = req.db;
  const maria = isMaria(db);

  const sqlDaily = maria
    ? `SELECT DATE(created_at) as day, SUM(total_amount) as total, COUNT(*) as count FROM orders WHERE status != 'cancelled' GROUP BY DATE(created_at) ORDER BY day DESC LIMIT 31`
    : `SELECT date(created_at) as day, SUM(total_amount) as total, COUNT(*) as count FROM orders WHERE status != 'cancelled' GROUP BY date(created_at) ORDER BY day DESC LIMIT 31`;
  const sqlMonthly = maria
    ? `SELECT DATE_FORMAT(created_at, '%Y-%m') as month, SUM(total_amount) as total, COUNT(*) as count FROM orders WHERE status != 'cancelled' GROUP BY DATE_FORMAT(created_at, '%Y-%m') ORDER BY month DESC LIMIT 12`
    : `SELECT strftime('%Y-%m', created_at) as month, SUM(total_amount) as total, COUNT(*) as count FROM orders WHERE status != 'cancelled' GROUP BY strftime('%Y-%m', created_at) ORDER BY month DESC LIMIT 12`;
  const sqlYearly = maria
    ? `SELECT DATE_FORMAT(created_at, '%Y') as year, SUM(total_amount) as total, COUNT(*) as count FROM orders WHERE status != 'cancelled' GROUP BY DATE_FORMAT(created_at, '%Y') ORDER BY year DESC LIMIT 5`
    : `SELECT strftime('%Y', created_at) as year, SUM(total_amount) as total, COUNT(*) as count FROM orders WHERE status != 'cancelled' GROUP BY strftime('%Y', created_at) ORDER BY year DESC LIMIT 5`;
  const sqlToday = maria
    ? `SELECT COALESCE(SUM(total_amount), 0) as total FROM orders WHERE DATE(created_at) = CURDATE() AND status != 'cancelled'`
    : `SELECT COALESCE(SUM(total_amount), 0) as total FROM orders WHERE date(created_at) = date('now', 'localtime') AND status != 'cancelled'`;
  const sqlWeek = maria
    ? `SELECT COALESCE(SUM(total_amount), 0) as total, COUNT(*) as count FROM orders WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY) AND status != 'cancelled'`
    : `SELECT COALESCE(SUM(total_amount), 0) as total, COUNT(*) as count FROM orders WHERE created_at >= datetime('now', 'localtime', '-7 days') AND status != 'cancelled'`;
  const sqlMonth = maria
    ? `SELECT COALESCE(SUM(total_amount), 0) as total FROM orders WHERE DATE_FORMAT(created_at, '%Y-%m') = DATE_FORMAT(NOW(), '%Y-%m') AND status != 'cancelled'`
    : `SELECT COALESCE(SUM(total_amount), 0) as total FROM orders WHERE strftime('%Y-%m', created_at) = strftime('%Y-%m', 'now', 'localtime') AND status != 'cancelled'`;
  const sqlYear = maria
    ? `SELECT COALESCE(SUM(total_amount), 0) as total FROM orders WHERE YEAR(created_at) = YEAR(NOW()) AND status != 'cancelled'`
    : `SELECT COALESCE(SUM(total_amount), 0) as total FROM orders WHERE strftime('%Y', created_at) = strftime('%Y', 'now', 'localtime') AND status != 'cancelled'`;

  const [daily, monthly, yearly, todayRow, weekRow, monthRow, yearRow, ordersByStatus, topProducts] = await Promise.all([
    db.prepare(sqlDaily).all(),
    db.prepare(sqlMonthly).all(),
    db.prepare(sqlYearly).all(),
    db.prepare(sqlToday).get(),
    db.prepare(sqlWeek).get(),
    db.prepare(sqlMonth).get(),
    db.prepare(sqlYear).get(),
    db.prepare(`SELECT status, COUNT(*) as count FROM orders GROUP BY status ORDER BY count DESC`).all(),
    db.prepare(`
      SELECT oi.product_name, SUM(oi.quantity) as total_qty, SUM(oi.total_price) as total_sales
      FROM order_items oi
      JOIN orders o ON o.id = oi.order_id AND o.status != 'cancelled'
      GROUP BY oi.product_id ORDER BY total_qty DESC LIMIT 15
    `).all()
  ]);
  const todayTotal = (todayRow && todayRow.total != null) ? Number(todayRow.total) : 0;
  const weekTotal = (weekRow && weekRow.total != null) ? Number(weekRow.total) : 0;
  const weekCount = (weekRow && weekRow.count != null) ? Number(weekRow.count) : 0;
  const monthTotal = (monthRow && monthRow.total != null) ? Number(monthRow.total) : 0;
  const yearTotal = (yearRow && yearRow.total != null) ? Number(yearRow.total) : 0;
  const STATUS_LABELS = { pending: 'قيد الانتظار', confirmed: 'مؤكد', shipped: 'تم الشحن', delivered: 'تم التوصيل', cancelled: 'ملغي' };

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
