const express = require('express');

const router = express.Router();

router.get('/', (req, res) => {
  const db = req.db;
  const productsCount = db.prepare('SELECT COUNT(*) as c FROM products').get().c;
  const ordersCount = db.prepare('SELECT COUNT(*) as c FROM orders').get().c;
  const customersCount = db.prepare('SELECT COUNT(*) as c FROM customers').get().c;

  const ordersToday = db.prepare(`
    SELECT COUNT(*) as c FROM orders WHERE date(created_at) = date('now', 'localtime')
  `).get().c;
  const ordersThisWeek = db.prepare(`
    SELECT COUNT(*) as c FROM orders WHERE created_at >= datetime('now', 'localtime', '-7 days')
  `).get().c;
  const todaySales = db.prepare(`
    SELECT COALESCE(SUM(total_amount), 0) as total FROM orders
    WHERE date(created_at) = date('now', 'localtime') AND status != 'cancelled'
  `).get().total;
  const totalSales = db.prepare(`
    SELECT COALESCE(SUM(total_amount), 0) as total FROM orders WHERE status != 'cancelled'
  `).get().total;

  const lowStockProducts = db.prepare(`
    SELECT id, name_ar, stock, low_stock_alert FROM products
    WHERE is_active = 1 AND low_stock_alert > 0 AND stock <= low_stock_alert
    ORDER BY stock ASC LIMIT 10
  `).all();

  const lastOrders = db.prepare(`
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
