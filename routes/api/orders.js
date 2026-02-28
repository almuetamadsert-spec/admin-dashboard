const express = require('express');
const { getSettings, setSetting, getNextOrderNumber } = require('../../lib/settings');
const { notifyMerchantsNewOrder } = require('../../lib/onesignal');
const { emitNewOrder } = require('../../lib/socket');

const router = express.Router();

/**
 * GET /api/orders?phone=xxx — طلبات العميل حسب رقم الهاتف (للتطبيق: طلباتي).
 * يرجع الطلبات مع العناصر وصورة المنتج الأول لكل طلب.
 */
router.get('/', async (req, res) => {
  const phone = (req.query.phone || '').trim().replace(/\s+/g, '');
  if (!phone) {
    return res.status(400).json({ ok: false, message: 'رقم الهاتف مطلوب' });
  }
  const db = req.db;
  try {
    const orders = await db.prepare(`
      SELECT o.id, o.order_number, o.status, o.total_amount, o.created_at, o.updated_at
      FROM orders o
      WHERE TRIM(REPLACE(o.customer_phone, ' ', '')) = ?
      ORDER BY o.created_at DESC
    `).all(phone);

    if (orders.length === 0) {
      res.setHeader('Cache-Control', 'no-store');
      return res.json({ ok: true, orders: [] });
    }

    // استعلام واحد لجميع items بدلاً من N+1
    const orderIds = orders.map(o => o.id);
    const placeholders = orderIds.map(() => '?').join(', ');
    const allItems = await db.prepare(`
      SELECT oi.id, oi.order_id, oi.product_id, oi.product_name, oi.quantity, oi.unit_price, oi.total_price, p.image_path
      FROM order_items oi
      LEFT JOIN products p ON oi.product_id = p.id
      WHERE oi.order_id IN (${placeholders})
    `).all(...orderIds);

    // تجميع items حسب order_id
    const itemsByOrder = {};
    for (const row of allItems) {
      if (!itemsByOrder[row.order_id]) itemsByOrder[row.order_id] = [];
      itemsByOrder[row.order_id].push({
        id: row.id,
        product_id: row.product_id,
        product_name: row.product_name,
        quantity: row.quantity,
        unit_price: row.unit_price,
        total_price: row.total_price,
        image_path: row.image_path || null,
      });
    }

    const list = orders.map(o => ({
      id: o.id,
      order_number: o.order_number,
      status: o.status || 'pending',
      total_amount: Number(o.total_amount) || 0,
      created_at: o.created_at,
      updated_at: o.updated_at,
      items: itemsByOrder[o.id] || [],
    }));

    res.setHeader('Cache-Control', 'no-store');
    res.json({ ok: true, orders: list });
  } catch (e) {
    res.status(500).json({ ok: false, message: e.message });
  }
});

/**
 * POST /api/orders — إنشاء طلب من التطبيق.
 * Body (JSON): city_id (مطلوب), customer_name, customer_phone, customer_address?, customer_email?, items: [{ product_id, quantity }], notes?
 * الإشعار يُرسل للتجار في نفس مدينة العميل فقط، ويتضمن بيانات العميل.
 */
router.post('/', async (req, res) => {
  const db = req.db;
  const body = req.body || {};
  const cityId = body.city_id != null ? parseInt(body.city_id, 10) : null;
  const customerName = (body.customer_name || '').trim();
  const customerPhone = (body.customer_phone || '').trim();
  const customerAddress = (body.customer_address || '').trim();
  const customerEmail = (body.customer_email || '').trim();
  const customerPhoneAlt = (body.customer_phone_alt || '').trim();
  const notes = (body.notes || '').trim();

  if (!cityId || !Number.isFinite(cityId)) {
    return res.status(400).json({ ok: false, error: 'city_id_required', message: 'مدينة العميل مطلوبة' });
  }
  const city = await db.prepare('SELECT id FROM cities WHERE id = ? AND is_active = 1').get(cityId);
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
  const productIds = [];
  const quantities = [];
  const optionsArr = [];

  for (const item of rawItems) {
    if (item && item.product_id != null) {
      const pid = parseInt(item.product_id, 10);
      if (Number.isFinite(pid)) {
        productIds.push(pid);
        quantities.push(parseInt(item.quantity, 10) || 1);
        optionsArr.push(item.options ? String(item.options).trim() : '');
      }
    }
  }

  if (productIds.length === 0) {
    return res.status(400).json({ ok: false, error: 'items_required', message: 'يجب إضافة منتج واحد على الأقل' });
  }

  const fetchProduct = db.prepare('SELECT id, name_ar, price, discount_percent FROM products WHERE id = ?');
  // تحميل بيانات المنتجات مرة واحدة لكل معرف فريد
  const productCache = new Map();
  for (const pid of new Set(productIds)) {
    const p = await fetchProduct.get(pid);
    if (p) productCache.set(String(pid), p);
  }

  let totalAmount = 0;
  for (let i = 0; i < productIds.length; i++) {
    const p = productCache.get(String(productIds[i]));
    if (p) {
      const qty = quantities[i] || 1;
      const unitPrice = p.price * (1 - (p.discount_percent || 0) / 100);
      totalAmount += unitPrice * qty;
    }
  }

  const orderNumber = await getNextOrderNumber(db);
  const r = await db.prepare(`
    INSERT INTO orders (order_number, customer_name, customer_phone, customer_phone_alt, customer_email, customer_address, city_id, status, total_amount, notes)
    VALUES (?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?)
  `).run(orderNumber, customerName, customerPhone, customerPhoneAlt || null, customerEmail, customerAddress, cityId, totalAmount, notes);

  const orderId = r.lastInsertRowid;
  const insertItem = db.prepare(`
    INSERT INTO order_items (order_id, product_id, product_name, quantity, unit_price, total_price)
    VALUES (?, ?, ?, ?, ?, ?)
  `);

  for (let i = 0; i < productIds.length; i++) {
    const p = productCache.get(String(productIds[i]));
    const qty = quantities[i] || 1;
    const opts = optionsArr[i] || '';
    if (p) {
      const unitPrice = p.price * (1 - (p.discount_percent || 0) / 100);
      const finalName = opts ? `${p.name_ar} (${opts})` : p.name_ar;
      await insertItem.run(orderId, productIds[i], finalName, qty, unitPrice, unitPrice * qty);
    }
  }

  notifyMerchantsNewOrder(db, orderNumber, totalAmount, {
    cityId,
    customerName,
    customerPhone
  }).catch((err) => console.warn('[OneSignal] فشل إرسال إشعار طلب جديد:', err.message));

  const io = req.app.locals.io;
  if (io) {
    emitNewOrder(io, cityId, {
      order_id: orderId,
      order_number: orderNumber,
      total_amount: totalAmount,
      city_id: cityId
    });
  }

  res.status(201).json({
    ok: true,
    order_id: orderId,
    order_number: orderNumber,
    total_amount: totalAmount
  });
});

module.exports = router;
