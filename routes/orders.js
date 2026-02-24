const express = require('express');
const { getSettings, setSetting, logActivity } = require('../lib/settings');

const router = express.Router();

const STATUS_LABELS = { pending: 'قيد الانتظار', confirmed: 'مؤكد', shipped: 'تم الشحن', delivered: 'تم التوصيل', cancelled: 'ملغي' };

const PER_PAGE = 20;

function getOrdersWhere(filters) {
  const { q, status, date_from, date_to } = filters;
  let where = ' 1=1 ';
  const params = [];
  if (q && q.trim()) {
    const search = '%' + q.trim() + '%';
    where += ' AND (o.order_number LIKE ? OR o.customer_name LIKE ? OR o.customer_phone LIKE ? OR c.name LIKE ? OR c.phone LIKE ?)';
    params.push(search, search, search, search, search);
  }
  if (status && status.trim()) {
    where += ' AND o.status = ?';
    params.push(status.trim());
  }
  if (date_from && date_from.trim()) {
    where += ' AND date(o.created_at) >= ?';
    params.push(date_from.trim());
  }
  if (date_to && date_to.trim()) {
    where += ' AND date(o.created_at) <= ?';
    params.push(date_to.trim());
  }
  return { where, params };
}

function getNextOrderNumber(db) {
  const settings = getSettings(db);
  let next = parseInt(settings.next_order_number, 10);
  if (!Number.isFinite(next) || next < 1000) next = 1000;
  setSetting(db, 'next_order_number', String(next + 1));
  return next + '#';
}

router.get('/', (req, res) => {
  const db = req.db;
  const q = req.query.q || '';
  const status = req.query.status || '';
  const date_from = req.query.date_from || '';
  const date_to = req.query.date_to || '';
  const page = Math.max(1, parseInt(req.query.page, 10) || 1);
  const filters = { q, status, date_from, date_to };
  const { where, params } = getOrdersWhere(filters);

  const total = db.prepare(`
    SELECT COUNT(*) as c FROM orders o LEFT JOIN customers c ON o.customer_id = c.id WHERE ${where}
  `).get(...params).c;
  const totalPages = Math.max(1, Math.ceil(total / PER_PAGE));
  const offset = (page - 1) * PER_PAGE;

  const orders = db.prepare(`
    SELECT o.*,
      COALESCE(o.customer_name, c.name) as display_name,
      COALESCE(o.customer_phone, c.phone) as display_phone
    FROM orders o
    LEFT JOIN customers c ON o.customer_id = c.id
    WHERE ${where}
    ORDER BY o.created_at DESC
    LIMIT ? OFFSET ?
  `).all(...params, PER_PAGE, offset);

  res.render('orders/list', {
    orders,
    STATUS_LABELS,
    filters: { q, status, date_from, date_to },
    page,
    totalPages,
    total,
    queryString: [q && 'q=' + encodeURIComponent(q), status && 'status=' + encodeURIComponent(status), date_from && 'date_from=' + encodeURIComponent(date_from), date_to && 'date_to=' + encodeURIComponent(date_to)].filter(Boolean).join('&'),
    adminUsername: req.session.adminUsername
  });
});

router.get('/export', (req, res) => {
  const db = req.db;
  const filters = {
    q: req.query.q || '',
    status: req.query.status || '',
    date_from: req.query.date_from || '',
    date_to: req.query.date_to || ''
  };
  const { where, params } = getOrdersWhere(filters);
  const orders = db.prepare(`
    SELECT o.*,
      COALESCE(o.customer_name, c.name) as display_name,
      COALESCE(o.customer_phone, c.phone) as display_phone
    FROM orders o
    LEFT JOIN customers c ON o.customer_id = c.id
    WHERE ${where}
    ORDER BY o.created_at DESC
  `).all(...params);

  const BOM = '\uFEFF';
  const header = 'رقم الطلب;العميل;الهاتف;المبلغ;الحالة;التاريخ';
  const rows = orders.map(o => [
    o.order_number,
    (o.display_name || '').replace(/;/g, ','),
    (o.display_phone || '').replace(/;/g, ','),
    Number(o.total_amount).toFixed(2),
    STATUS_LABELS[o.status] || o.status,
    new Date(o.created_at).toLocaleDateString('ar-LY')
  ].join(';'));
  const csv = BOM + header + '\n' + rows.join('\n');
  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  res.setHeader('Content-Disposition', 'attachment; filename=orders.csv');
  res.send(csv);
});

router.get('/new', (req, res) => {
  const db = req.db;
  const customers = db.prepare('SELECT * FROM customers ORDER BY name').all();
  const products = db.prepare('SELECT id, name_ar, name_en, price, discount_percent FROM products WHERE is_active = 1').all();
  const cities = db.prepare('SELECT id, name FROM cities WHERE is_active = 1 ORDER BY name').all();
  res.render('orders/form', { order: null, items: [], customers, products, cities, adminUsername: req.session.adminUsername });
});

router.get('/view/:id', (req, res) => {
  const db = req.db;
  const order = db.prepare('SELECT * FROM orders WHERE id = ?').get(req.params.id);
  if (!order) return res.redirect('/admin/orders');
  const items = db.prepare('SELECT * FROM order_items WHERE order_id = ?').all(req.params.id);
  const customer = order.customer_id ? db.prepare('SELECT * FROM customers WHERE id = ?').get(order.customer_id) : null;
  res.render('orders/view', { order, items, customer, adminUsername: req.session.adminUsername });
});

router.post('/', (req, res) => {
  const db = req.db;
  const body = req.body || {};
  const orderNumber = getNextOrderNumber(db);
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
    INSERT INTO orders (order_number, customer_id, customer_name, customer_phone, customer_email, customer_address, city_id, status, total_amount, notes)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).run(orderNumber, customerId, customerName, customerPhone, customerEmail, customerAddress, body.city_id ? parseInt(body.city_id, 10) : null, status, totalAmount, notes);

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

  const { notifyMerchantsNewOrder } = require('../lib/onesignal');
  notifyMerchantsNewOrder(db, orderNumber, totalAmount, {
    cityId: body.city_id ? parseInt(body.city_id, 10) : undefined,
    customerName: customerName || undefined,
    customerPhone: customerPhone || undefined
  }).catch(() => {});

  res.redirect('/admin/orders');
});

router.get('/edit/:id', (req, res) => {
  const db = req.db;
  const order = db.prepare('SELECT * FROM orders WHERE id = ?').get(req.params.id);
  if (!order) return res.redirect('/admin/orders');
  const items = db.prepare('SELECT * FROM order_items WHERE order_id = ?').all(req.params.id);
  const customers = db.prepare('SELECT * FROM customers ORDER BY name').all();
  const products = db.prepare('SELECT id, name_ar, name_en, price, discount_percent FROM products WHERE is_active = 1').all();
  const cities = db.prepare('SELECT id, name FROM cities WHERE is_active = 1 ORDER BY name').all();
  res.render('orders/form', { order, items, customers, products, cities, adminUsername: req.session.adminUsername });
});

router.post('/edit/:id', (req, res) => {
  const db = req.db;
  const orderId = req.params.id;
  const order = db.prepare('SELECT * FROM orders WHERE id = ?').get(orderId);
  if (!order) return res.redirect('/admin/orders');
  const body = req.body || {};
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

  db.prepare(`
    UPDATE orders SET customer_id = ?, customer_name = ?, customer_phone = ?, customer_email = ?, customer_address = ?,
      city_id = ?, status = ?, total_amount = ?, notes = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?
  `).run(customerId, customerName, customerPhone, customerEmail, customerAddress, body.city_id ? parseInt(body.city_id, 10) : null, status, totalAmount, notes, orderId);

  db.prepare('DELETE FROM order_items WHERE order_id = ?').run(orderId);
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
  logActivity(db, req.session.adminId, req.session.adminUsername, 'تعديل الطلب', 'طلب ' + order.order_number);
  res.redirect('/admin/orders');
});

router.post('/delete/:id', (req, res) => {
  const db = req.db;
  const order = db.prepare('SELECT order_number FROM orders WHERE id = ?').get(req.params.id);
  if (!order) return res.redirect('/admin/orders');
  db.prepare('DELETE FROM order_items WHERE order_id = ?').run(req.params.id);
  db.prepare('DELETE FROM orders WHERE id = ?').run(req.params.id);
  logActivity(db, req.session.adminId, req.session.adminUsername, 'حذف الطلب', order.order_number);
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

module.exports = router;
