const express = require('express');

const router = express.Router();

const isMaria = (db) => (db.driver === 'mariadb');

router.get('/', async (req, res) => {
  const db = req.db;
  const maria = isMaria(db);

  const productsRow = await db.prepare('SELECT COUNT(*) as c FROM products').get();
  const ordersRow = await db.prepare('SELECT COUNT(*) as c FROM orders').get();
  const customersRow = await db.prepare('SELECT COUNT(*) as c FROM customers').get();
  const productsCount = productsRow ? productsRow.c : 0;
  const ordersCount = ordersRow ? ordersRow.c : 0;
  const customersCount = customersRow ? customersRow.c : 0;

  const sqlOrdersToday = maria
    ? `SELECT COUNT(*) as c FROM orders WHERE DATE(created_at) = CURDATE()`
    : `SELECT COUNT(*) as c FROM orders WHERE date(created_at) = date('now', 'localtime')`;
  const sqlOrdersWeek = maria
    ? `SELECT COUNT(*) as c FROM orders WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)`
    : `SELECT COUNT(*) as c FROM orders WHERE created_at >= datetime('now', 'localtime', '-7 days')`;
  const sqlTodaySales = maria
    ? `SELECT COALESCE(SUM(total_amount), 0) as total FROM orders WHERE DATE(created_at) = CURDATE() AND status != 'cancelled'`
    : `SELECT COALESCE(SUM(total_amount), 0) as total FROM orders WHERE date(created_at) = date('now', 'localtime') AND status != 'cancelled'`;

  const ordersTodayRow = await db.prepare(sqlOrdersToday).get();
  const ordersThisWeekRow = await db.prepare(sqlOrdersWeek).get();
  const todaySalesRow = await db.prepare(sqlTodaySales).get();
  const totalSalesRow = await db.prepare(`
    SELECT COALESCE(SUM(total_amount), 0) as total FROM orders WHERE status != 'cancelled'
  `).get();
  const ordersToday = ordersTodayRow ? ordersTodayRow.c : 0;
  const ordersThisWeek = ordersThisWeekRow ? ordersThisWeekRow.c : 0;
  const todaySales = todaySalesRow ? todaySalesRow.total : 0;
  const totalSales = totalSalesRow ? totalSalesRow.total : 0;

  const lowStockProducts = await db.prepare(`
    SELECT id, name_ar, stock, low_stock_alert FROM products
    WHERE is_active = 1 AND low_stock_alert > 0 AND stock <= low_stock_alert
    ORDER BY stock ASC LIMIT 10
  `).all();

  const lastOrders = await db.prepare(`
    SELECT o.id, o.order_number, o.total_amount, o.status, o.created_at,
      COALESCE(o.customer_name, c.name) as display_name,
      COALESCE(o.customer_phone, c.phone) as display_phone
    FROM orders o
    LEFT JOIN customers c ON o.customer_id = c.id
    ORDER BY o.created_at DESC LIMIT 10
  `).all();

  const STATUS_LABELS = { pending: 'قيد الانتظار', confirmed: 'مؤكد', shipped: 'تم الشحن', delivered: 'تم التوصيل', cancelled: 'ملغي' };

  res.render('dashboard/index', {
    productsCount,
    ordersCount,
    customersCount,
    ordersToday,
    ordersThisWeek,
    todaySales,
    totalSales,
    lowStockProducts,
    lastOrders,
    STATUS_LABELS,
    adminUsername: req.session.adminUsername
  });
});

module.exports = router;
