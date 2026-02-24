const express = require('express');
const { getSettings, setSetting } = require('../../lib/settings');
const { notifyMerchantsNewOrder } = require('../../lib/onesignal');

const router = express.Router();

function getNextOrderNumber(db) {
  const settings = getSettings(db);
  let next = parseInt(settings.next_order_number, 10);
  if (!Number.isFinite(next) || next < 1000) next = 1000;
  setSetting(db, 'next_order_number', String(next + 1));
  return next + '#';
}

/**
 * POST /api/orders — إنشاء طلب من التطبيق.
 * Body (JSON): city_id (مطلوب), customer_name, customer_phone, customer_address?, customer_email?, items: [{ product_id, quantity }], notes?
 * الإشعار يُرسل للتجار في نفس مدينة العميل فقط، ويتضمن بيانات العميل.
 */
router.post('/', (req, res) => {
  const db = req.db;
  const body = req.body || {};
  const cityId = body.city_id != null ? parseInt(body.city_id, 10) : null;
  const customerName = (body.customer_name || '').trim();
  const customerPhone = (body.customer_phone || '').trim();
  const customerAddress = (body.customer_address || '').trim();
  const customerEmail = (body.customer_email || '').trim();
  const notes = (body.notes || '').trim();

  if (!cityId || !Number.isFinite(cityId)) {
    return res.status(400).json({ ok: false, error: 'city_id_required', message: 'مدينة العميل مطلوبة' });
  }
  const city = db.prepare('SELECT id FROM cities WHERE id = ? AND is_active = 1').get(cityId);
  if (!city) {
    return res.status(400).json({ ok: false, error: 'invalid_city', message: 'مدينة غير صالحة' });
  }
  if (!customerName) {
    return res.status(400).json({ ok: false, error: 'customer_name_required', message: 'اسم العميل مطلوب' });
  }
  if (!customerPhone) {
    return res.status(400).json({ ok: false, error: 'customer_phone_required', message: 'هاتف العميل مطلوب' });
  }

  const rawItems = Array.isArray(body.items) ? body.items : (body.items ? [body.items] : []);
  const productIds = rawItems.map((i) => i && i.product_id != null ? parseInt(i.product_id, 10) : null).filter(Number.isFinite);
  const quantities = rawItems.map((i) => i && i.quantity != null ? parseInt(i.quantity, 10) || 1 : 1);
  while (quantities.length < productIds.length) quantities.push(1);

  if (productIds.length === 0) {
    return res.status(400).json({ ok: false, error: 'items_required', message: 'يجب إضافة منتج واحد على الأقل' });
  }

  const products = db.prepare('SELECT id, name_ar, price, discount_percent FROM products WHERE id = ?');
  let totalAmount = 0;
  for (let i = 0; i < productIds.length; i++) {
    const p = products.get(productIds[i]);
    if (p) {
      const qty = quantities[i] || 1;
      const unitPrice = p.price * (1 - (p.discount_percent || 0) / 100);
      totalAmount += unitPrice * qty;
    }
  }

  const orderNumber = getNextOrderNumber(db);
  const r = db.prepare(`
    INSERT INTO orders (order_number, customer_name, customer_phone, customer_email, customer_address, city_id, status, total_amount, notes)
    VALUES (?, ?, ?, ?, ?, ?, 'pending', ?, ?)
  `).run(orderNumber, customerName, customerPhone, customerEmail, customerAddress, cityId, totalAmount, notes);

  const orderId = r.lastInsertRowid;
  const insertItem = db.prepare(`
    INSERT INTO order_items (order_id, product_id, product_name, quantity, unit_price, total_price)
    VALUES (?, ?, ?, ?, ?, ?)
  `);

  for (let i = 0; i < productIds.length; i++) {
    const pid = productIds[i];
    const qty = quantities[i] || 1;
    const p = products.get(pid);
    if (p) {
      const unitPrice = p.price * (1 - (p.discount_percent || 0) / 100);
      insertItem.run(orderId, pid, p.name_ar, qty, unitPrice, unitPrice * qty);
    }
  }

  notifyMerchantsNewOrder(db, orderNumber, totalAmount, {
    cityId,
    customerName,
    customerPhone
  }).catch(() => {});

  res.status(201).json({
    ok: true,
    order_id: orderId,
    order_number: orderNumber,
    total_amount: totalAmount
  });
});

module.exports = router;
