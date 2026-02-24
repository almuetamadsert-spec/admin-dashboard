const express = require('express');

const router = express.Router();

function generateOrderNumber(db) {
  const n = db.prepare('SELECT COUNT(*) as c FROM orders').get().c + 1;
  return 'ORD-' + Date.now().toString(36).toUpperCase() + '-' + n;
}

router.get('/', (req, res) => {
  const db = req.db;
  const orders = db.prepare(`
    SELECT o.*, c.name as customer_name, c.phone as customer_phone, c.email as customer_email
    FROM orders o
    LEFT JOIN customers c ON o.customer_id = c.id
    ORDER BY o.created_at DESC
  `).all();
  res.render('orders/list', { orders, adminUsername: req.session.adminUsername });
});

router.get('/new', (req, res) => {
  const db = req.db;
  const customers = db.prepare('SELECT * FROM customers ORDER BY name').all();
  const products = db.prepare('SELECT id, name_ar, name_en, price, discount_percent FROM products WHERE is_active = 1').all();
  res.render('orders/form', { order: null, customers, products, adminUsername: req.session.adminUsername });
});

router.get('/view/:id', (req, res) => {
  const db = req.db;
  const order = db.prepare('SELECT * FROM orders WHERE id = ?').get(req.params.id);
  if (!order) return res.redirect('/admin/orders');
  const items = db.prepare('SELECT * FROM order_items WHERE order_id = ?').all(req.params.id);
  const customer = order.customer_id ? db.prepare('SELECT * FROM customers WHERE id = ?').get(order.customer_id) : null;
  const merchants = db.prepare('SELECT m.*, c.name as city_name FROM merchants m LEFT JOIN cities c ON m.city_id = c.id WHERE m.is_active = 1 ORDER BY m.name').all();
  res.render('orders/view', { order, items, customer, merchants, adminUsername: req.session.adminUsername });
});

router.post('/', (req, res) => {
  const db = req.db;
  const body = req.body || {};
  const orderNumber = generateOrderNumber(db);
  const customerId = body.customer_id || null;
  const customerName = body.customer_name || '';
  const customerPhone = body.customer_phone || '';
  const customerEmail = body.customer_email || '';
  const customerAddress = body.customer_address || '';
  const notes = body.notes || '';
  const status = body.status || 'pending';

  let totalAmount = 0;
  const productIds = Array.isArray(body.product_id) ? body.product_id : (body.product_id ? [body.product_id] : []);
  const quantities = Array.isArray(body.quantity) ? body.quantity : (body.quantity ? [body.quantity] : []);
  const products = db.prepare('SELECT id, name_ar, price, discount_percent FROM products WHERE id = ?');

  for (let i = 0; i < productIds.length; i++) {
    const pid = productIds[i];
    const qty = parseInt(quantities[i], 10) || 1;
    const p = products.get(pid);
    if (p) {
      const unitPrice = p.price * (1 - (p.discount_percent || 0) / 100);
      totalAmount += unitPrice * qty;
    }
  }

  const r = db.prepare(`
    INSERT INTO orders (order_number, customer_id, customer_name, customer_phone, customer_email, customer_address, status, total_amount, notes)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).run(orderNumber, customerId, customerName, customerPhone, customerEmail, customerAddress, status, totalAmount, notes);

  const orderId = r.lastInsertRowid;
  const insertItem = db.prepare(`
    INSERT INTO order_items (order_id, product_id, product_name, quantity, unit_price, total_price)
    VALUES (?, ?, ?, ?, ?, ?)
  `);

  for (let i = 0; i < productIds.length; i++) {
    const pid = productIds[i];
    const qty = parseInt(quantities[i], 10) || 1;
    const p = products.get(pid);
    if (p) {
      const unitPrice = p.price * (1 - (p.discount_percent || 0) / 100);
      insertItem.run(orderId, pid, p.name_ar, qty, unitPrice, unitPrice * qty);
    }
  }

  res.redirect('/admin/orders');
});

router.post('/status/:id', (req, res) => {
  const db = req.db;
  const { status } = req.body || {};
  if (['pending', 'confirmed', 'shipped', 'delivered', 'cancelled'].includes(status)) {
    db.prepare('UPDATE orders SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?').run(status, req.params.id);
  }
  res.redirect('/admin/orders/view/' + req.params.id);
});

router.post('/transfer/:id', (req, res) => {
  const db = req.db;
  const merchantId = req.body.merchant_id || null;
  const orderId = req.params.id;
  db.prepare('UPDATE orders SET merchant_id = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?').run(merchantId ? parseInt(merchantId, 10) : null, orderId);
  const { logActivity } = require('../lib/settings');
  logActivity(db, req.session.adminId, req.session.adminUsername, 'تحويل الطلب', 'طلب #' + orderId + ' → تاجر ' + merchantId);
  res.redirect('/admin/orders/view/' + orderId);
});

module.exports = router;
