const express = require('express');
const appAuth = require('../../middleware/appAuth');
const router = express.Router();

/** جميع مسارات التاجر تتطلب Bearer token و role === merchant */
router.use(appAuth.requireAppToken, appAuth.requireMerchant);

/** GET /api/merchant/orders — طلبات مدينة التاجر أو المعينة له
 *  توجيه حسب المدينة: التاجر يرى طلباته + الطلبات pending في مدينته فقط.
 *  استعلام: ?status=pending|confirmed|... — فلترة حسب الحالة. ?available=1 — الطلبات المتاحة للاستلام فقط (غير مستحوذ عليها في مدينته).
 */
router.get('/orders', async (req, res) => {
  const db = req.db;
  const merchantId = req.appUser.merchant_id;
  const statusFilter = (req.query.status || '').trim().toLowerCase();
  const availableOnly = req.query.available === '1' || req.query.available === 'true';
  try {
    const merchant = await db.prepare('SELECT city_id FROM merchants WHERE id = ?').get(merchantId);
    const cityId = merchant && merchant.city_id != null ? merchant.city_id : null;

    let sql;
    const params = [];

    if (availableOnly) {
      if (cityId == null) {
        return res.json({ ok: true, orders: [] });
      }
      // طلبات متاحة للاستلام فقط: في مدينتي وغير مستحوذ عليها
      sql = `
        SELECT o.id, o.order_number, o.merchant_id, o.customer_name, o.customer_phone, o.customer_address, o.city_id, o.status, o.total_amount, o.created_at,
          c.name as city_name
        FROM orders o
        LEFT JOIN cities c ON o.city_id = c.id
        WHERE o.merchant_id IS NULL AND o.city_id = ? AND o.status = ?
      `;
      params.push(cityId, 'pending');
    } else if (cityId != null) {
      // توجيه حسب المدينة: طلباتي أو الطلبات pending في مدينتي
      sql = `
        SELECT o.id, o.order_number, o.merchant_id, o.customer_name, o.customer_phone, o.customer_address, o.city_id, o.status, o.total_amount, o.created_at,
          c.name as city_name
        FROM orders o
        LEFT JOIN cities c ON o.city_id = c.id
        WHERE (o.merchant_id = ? OR (o.merchant_id IS NULL AND o.city_id = ?))
      `;
      params.push(merchantId, cityId);
    } else {
      // تاجر بدون مدينة: طلباته المعينة له فقط
      sql = `
        SELECT o.id, o.order_number, o.merchant_id, o.customer_name, o.customer_phone, o.customer_address, o.city_id, o.status, o.total_amount, o.created_at,
          c.name as city_name
        FROM orders o
        LEFT JOIN cities c ON o.city_id = c.id
        WHERE o.merchant_id = ?
      `;
      params.push(merchantId);
    }

    if (!availableOnly && statusFilter && ['pending', 'confirmed', 'shipped', 'delivered', 'cancelled'].includes(statusFilter)) {
      sql += ' AND o.status = ?';
      params.push(statusFilter);
    }
    sql += ' ORDER BY o.created_at DESC';

    const rows = await db.prepare(sql).all(...params);
    const orders = rows.map((o) => {
      const claimed = o.merchant_id != null && o.merchant_id === merchantId;
      return {
        id: o.id,
        order_number: o.order_number,
        merchant_id: o.merchant_id,
        city_id: o.city_id,
        city_name: o.city_name,
        status: o.status,
        total_amount: o.total_amount,
        created_at: o.created_at,
        customer_name: claimed ? o.customer_name : null,
        customer_phone: claimed ? o.customer_phone : null,
        customer_address: claimed ? o.customer_address : null,
      };
    });
    res.json({ ok: true, orders });
  } catch (e) {
    res.status(500).json({ ok: false, error: 'server_error', message: e.message });
  }
});

/** GET /api/merchant/orders/:id — تفاصيل طلب واحد */
router.get('/orders/:id', async (req, res) => {
  const db = req.db;
  const merchantId = req.appUser.merchant_id;
  const orderId = req.params.id;

  const merchant = await db.prepare('SELECT city_id FROM merchants WHERE id = ?').get(merchantId);
  const cityId = merchant && merchant.city_id != null ? merchant.city_id : null;

  const order = cityId != null
    ? await db.prepare(`
        SELECT o.*, c.name as city_name
        FROM orders o LEFT JOIN cities c ON o.city_id = c.id
        WHERE o.id = ? AND (o.merchant_id = ? OR (o.merchant_id IS NULL AND o.city_id = ?))
      `).get(orderId, merchantId, cityId)
    : await db.prepare(`
        SELECT o.*, c.name as city_name
        FROM orders o LEFT JOIN cities c ON o.city_id = c.id
        WHERE o.id = ? AND o.merchant_id = ?
      `).get(orderId, merchantId);

  if (!order) {
    return res.status(404).json({ ok: false, error: 'not_found', message: 'الطلب غير موجود أو غير مسموح لك بعرضه' });
  }

  const items = await db.prepare(`
    SELECT oi.id, oi.product_id, oi.product_name, oi.quantity, oi.unit_price, oi.total_price, p.image_path
    FROM order_items oi
    LEFT JOIN products p ON oi.product_id = p.id
    WHERE oi.order_id = ?
  `).all(orderId);

  res.json({
    ok: true,
    order: {
      id: order.id,
      order_number: order.order_number,
      customer_name: order.customer_name,
      customer_phone: order.customer_phone,
      customer_phone_alt: order.customer_phone_alt,
      customer_email: order.customer_email,
      customer_address: order.customer_address,
      city_id: order.city_id,
      city_name: order.city_name,
      status: order.status,
      total_amount: order.total_amount,
      notes: order.notes,
      created_at: order.created_at,
      merchant_contacted_at: order.merchant_contacted_at || null
    },
    items: items.map(row => ({
      id: row.id,
      product_id: row.product_id,
      product_name: row.product_name,
      quantity: row.quantity,
      unit_price: row.unit_price,
      total_price: row.total_price,
      image_path: row.image_path
    }))
  });
});

/** POST /api/merchant/orders/:id/contacted — تسجيل أن التاجر اتصل بالعميل (يُخفى زر الاتصال ويُظهر زر تم التسليم) */
router.post('/orders/:id/contacted', async (req, res) => {
  const db = req.db;
  const merchantId = req.appUser.merchant_id;
  const orderId = req.params.id;
  const order = await db.prepare('SELECT id FROM orders WHERE id = ? AND merchant_id = ?').get(orderId, merchantId);
  if (!order) {
    return res.status(404).json({ ok: false, error: 'not_found', message: 'الطلب غير موجود' });
  }
  try {
    await db.prepare('UPDATE orders SET merchant_contacted_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND merchant_id = ?').run(orderId, merchantId);
    return res.json({ ok: true, message: 'تم التسجيل' });
  } catch (e) {
    return res.status(500).json({ ok: false, error: 'server_error', message: e.message });
  }
});

/** POST /api/merchant/orders/:id/claim — استحواذ التاجر على الطلب (ذري: طلب واحد فقط يستحوذ) */
router.post('/orders/:id/claim', async (req, res) => {
  const db = req.db;
  const merchantId = req.appUser.merchant_id;
  const orderId = req.params.id;
  const orderIdNum = parseInt(orderId, 10);
  if (!Number.isFinite(orderIdNum)) {
    return res.status(400).json({ ok: false, error: 'invalid_id', message: 'معرف الطلب غير صالح' });
  }

  const merchant = await db.prepare('SELECT city_id FROM merchants WHERE id = ?').get(merchantId);
  const cityId = merchant && merchant.city_id != null ? merchant.city_id : null;

  try {
    // تحديث ذري: فقط إن كان الطلب pending ولم يستحوذ عليه أحد (ومطابق لمدينة التاجر إن وُجدت)
    let updateSql = 'UPDATE orders SET merchant_id = ?, status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND status = ? AND merchant_id IS NULL';
    const updateParams = [merchantId, 'confirmed', orderIdNum, 'pending'];
    if (cityId != null) {
      updateSql += ' AND city_id = ?';
      updateParams.push(cityId);
    }
    await db.prepare(updateSql).run(...updateParams);

    const after = await db.prepare('SELECT id, merchant_id, status FROM orders WHERE id = ?').get(orderIdNum);
    if (!after) {
      return res.status(404).json({ ok: false, error: 'not_found', message: 'الطلب غير موجود' });
    }
    if (after.merchant_id === merchantId && after.status === 'confirmed') {
      // إشعار فوري لباقي التجار في المدينة أن الطلب تم استلامه
      const io = req.app.locals.io;
      if (io && cityId != null) {
        io.to('city:' + cityId).emit('order_claimed', {
          order_id: orderIdNum,
          claimed_by_merchant_id: merchantId
        });
      }
      return res.json({ ok: true, message: 'تم استلام الطلب' });
    }
    // استحوذ عليه تاجر آخر أو لم يعد قابلاً للاستحواذ
    return res.status(409).json({
      ok: false,
      error: 'already_claimed',
      message: 'عذراً، تم استلام الطلب من قبل تاجر آخر'
    });
  } catch (e) {
    res.status(500).json({ ok: false, error: 'server_error', message: e.message });
  }
});

/** POST /api/merchant/orders/:id/transfer — تحويل الطلب لتاجر آخر */
router.post('/orders/:id/transfer', async (req, res) => {
  const db = req.db;
  const merchantId = req.appUser.merchant_id;
  const orderId = req.params.id;
  const targetMerchantId = req.body && req.body.target_merchant_id != null ? parseInt(req.body.target_merchant_id, 10) : null;

  if (!targetMerchantId || !Number.isFinite(targetMerchantId)) {
    return res.status(400).json({ ok: false, error: 'target_required', message: 'حدد التاجر المستهدف (target_merchant_id)' });
  }

  const merchant = await db.prepare('SELECT city_id FROM merchants WHERE id = ?').get(merchantId);
  const cityId = merchant && merchant.city_id != null ? merchant.city_id : null;

  const order = cityId != null
    ? await db.prepare('SELECT id FROM orders WHERE id = ? AND (merchant_id = ? OR (merchant_id IS NULL AND city_id = ?))').get(orderId, merchantId, cityId)
    : await db.prepare('SELECT id FROM orders WHERE id = ? AND merchant_id = ?').get(orderId, merchantId);

  if (!order) {
    return res.status(404).json({ ok: false, error: 'not_found', message: 'الطلب غير موجود أو غير مسموح لك بتحويله' });
  }

  const target = await db.prepare('SELECT id FROM merchants WHERE id = ? AND is_active = 1').get(targetMerchantId);
  if (!target) {
    return res.status(400).json({ ok: false, error: 'invalid_merchant', message: 'التاجر المستهدف غير موجود أو غير نشط' });
  }

  try {
    await db.prepare('UPDATE orders SET merchant_id = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?').run(targetMerchantId, orderId);
    res.json({ ok: true, message: 'تم تحويل الطلب' });
  } catch (e) {
    res.status(500).json({ ok: false, error: 'server_error', message: e.message });
  }
});

/** POST /api/merchant/orders/:id/delivered — تم التسليم */
router.post('/orders/:id/delivered', async (req, res) => {
  const db = req.db;
  const merchantId = req.appUser.merchant_id;
  const orderId = req.params.id;
  const order = await db.prepare('SELECT id FROM orders WHERE id = ? AND merchant_id = ?').get(orderId, merchantId);
  if (!order) return res.status(404).json({ ok: false, error: 'not_found', message: 'الطلب غير موجود' });
  try {
    await db.prepare('UPDATE orders SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?').run('delivered', orderId);
    res.json({ ok: true, message: 'تم تسجيل التسليم' });
  } catch (e) {
    res.status(500).json({ ok: false, error: 'server_error', message: e.message });
  }
});

/** POST /api/merchant/orders/:id/unavailable — غير متوفر */
router.post('/orders/:id/unavailable', async (req, res) => {
  const db = req.db;
  const merchantId = req.appUser.merchant_id;
  const orderId = req.params.id;
  const order = await db.prepare('SELECT id FROM orders WHERE id = ? AND merchant_id = ?').get(orderId, merchantId);
  if (!order) return res.status(404).json({ ok: false, error: 'not_found', message: 'الطلب غير موجود' });
  try {
    const note = (req.body && req.body.reason) || 'نفاد الكمية';
    await db.prepare('UPDATE orders SET status = ?, notes = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?').run('cancelled', note, orderId);
    res.json({ ok: true, message: 'تم إلغاء الطلب' });
  } catch (e) {
    res.status(500).json({ ok: false, error: 'server_error', message: e.message });
  }
});

/** POST /api/merchant/orders/:id/refused — رفض العميل */
router.post('/orders/:id/refused', async (req, res) => {
  const db = req.db;
  const merchantId = req.appUser.merchant_id;
  const orderId = req.params.id;
  const order = await db.prepare('SELECT id FROM orders WHERE id = ? AND merchant_id = ?').get(orderId, merchantId);
  if (!order) return res.status(404).json({ ok: false, error: 'not_found', message: 'الطلب غير موجود' });
  try {
    await db.prepare('UPDATE orders SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?').run('customer_refused', orderId);
    res.json({ ok: true, message: 'تم تسجيل الرفض' });
  } catch (e) {
    res.status(500).json({ ok: false, error: 'server_error', message: e.message });
  }
});

/** GET /api/merchant/categories — تصنيفات المتجر (لشاشة إضافة المخزون) */
router.get('/categories', async (req, res) => {
  const db = req.db;
  try {
    const rows = await db.prepare('SELECT id, name_ar, name_en, icon_type, icon_name, icon_color, icon_path FROM categories ORDER BY name_ar').all();
    res.json({ ok: true, categories: rows });
  } catch (e) {
    res.status(500).json({ ok: false, error: 'server_error', message: e.message });
  }
});

/** GET /api/merchant/brand-categories — تصنيفات البراند (لشاشة إضافة المخزون) */
router.get('/brand-categories', async (req, res) => {
  const db = req.db;
  try {
    const rows = await db.prepare('SELECT id, name_ar, icon_path FROM brand_categories ORDER BY sort_order, name_ar').all();
    res.json({ ok: true, brand_categories: rows });
  } catch (e) {
    res.status(500).json({ ok: false, error: 'server_error', message: e.message });
  }
});

/** GET /api/merchant/products — قائمة المنتجات (لشاشة إضافة المخزون: تصنيفات، بحث) */
router.get('/products', async (req, res) => {
  const db = req.db;
  const categoryId = req.query.category_id ? parseInt(req.query.category_id, 10) : null;
  const company = (req.query.company || '').trim();
  const q = (req.query.q || '').trim();
  let sql = `
    SELECT id, name_ar, name_en, price, discount_percent, image_path, stock, company, category_id, short_description, long_description
    FROM products WHERE is_active = 1
  `;
  const params = [];
  if (categoryId && Number.isFinite(categoryId)) { sql += ' AND category_id = ?'; params.push(categoryId); }
  if (company) { sql += " AND LOWER(TRIM(COALESCE(company, ''))) = LOWER(?)"; params.push(company); }
  if (q) {
    const like = '%' + q + '%';
    const numQ = parseInt(q, 10);
    if (Number.isFinite(numQ)) { sql += ' AND (name_ar LIKE ? OR name_en LIKE ? OR id = ?)'; params.push(like, like, numQ); }
    else { sql += ' AND (name_ar LIKE ? OR name_en LIKE ?)'; params.push(like, like); }
  }
  sql += ' ORDER BY name_ar';
  const products = params.length ? await db.prepare(sql).all(...params) : await db.prepare(sql).all();
  const list = products.map((p) => {
    const price = Number(p.price) || 0;
    const discount = Number(p.discount_percent) || 0;
    return {
      id: p.id,
      name_ar: p.name_ar,
      name_en: p.name_en,
      price,
      discount_percent: discount,
      final_price: Math.round(price * (1 - discount / 100) * 100) / 100,
      image_path: p.image_path || null,
      stock: Number(p.stock) || 0,
      company: p.company || null,
      category_id: p.category_id,
      short_description: p.short_description || null,
      long_description: p.long_description || null,
    };
  });
  res.json({ ok: true, products: list });
});

/** GET /api/merchant/inventory — مخزون التاجر (المنتجات والكميات) */
router.get('/inventory', async (req, res) => {
  const db = req.db;
  const merchantId = req.appUser.merchant_id;
  try {
    const rows = await db.prepare(`
      SELECT ms.product_id, ms.quantity, p.name_ar, p.image_path, p.short_description, p.long_description
      FROM merchant_stock ms
      JOIN products p ON p.id = ms.product_id
      WHERE ms.merchant_id = ? AND ms.quantity > 0
      ORDER BY p.name_ar
    `).all(merchantId);
    res.json({ ok: true, items: rows });
  } catch (e) {
    res.status(500).json({ ok: false, error: 'server_error', message: e.message });
  }
});

/** POST /api/merchant/inventory — حفظ/تحديث مخزون التاجر (items: [{ product_id, quantity }]) */
router.post('/inventory', async (req, res) => {
  const db = req.db;
  const merchantId = req.appUser.merchant_id;
  const items = req.body && Array.isArray(req.body.items) ? req.body.items : [];
  if (items.length === 0) {
    return res.status(400).json({ ok: false, error: 'items_required', message: 'أرسل مصفوفة items' });
  }
  try {
    const isMaria = db.driver === 'mariadb';
    for (const it of items) {
      const productId = parseInt(it.product_id, 10);
      const quantity = Math.max(0, parseInt(it.quantity, 10) || 0);
      if (!Number.isFinite(productId)) continue;
      if (isMaria) {
        await db.prepare(`
          INSERT INTO merchant_stock (merchant_id, product_id, quantity, updated_at)
          VALUES (?, ?, ?, CURRENT_TIMESTAMP)
          ON DUPLICATE KEY UPDATE quantity = VALUES(quantity), updated_at = CURRENT_TIMESTAMP
        `).run(merchantId, productId, quantity);
      } else {
        await db.prepare(`
          INSERT INTO merchant_stock (merchant_id, product_id, quantity, updated_at)
          VALUES (?, ?, ?, CURRENT_TIMESTAMP)
          ON CONFLICT (merchant_id, product_id) DO UPDATE SET quantity = excluded.quantity, updated_at = CURRENT_TIMESTAMP
        `).run(merchantId, productId, quantity);
      }
    }
    res.json({ ok: true, message: 'تم الحفظ' });
  } catch (e) {
    res.status(500).json({ ok: false, error: 'server_error', message: e.message });
  }
});

/** DELETE /api/merchant/inventory/:productId — حذف منتج من مخزون التاجر */
router.delete('/inventory/:productId', async (req, res) => {
  const db = req.db;
  const merchantId = req.appUser.merchant_id;
  const productId = parseInt(req.params.productId, 10);
  if (!Number.isFinite(productId)) {
    return res.status(400).json({ ok: false, error: 'invalid_id', message: 'معرف المنتج غير صالح' });
  }
  try {
    await db.prepare('DELETE FROM merchant_stock WHERE merchant_id = ? AND product_id = ?').run(merchantId, productId);
    res.json({ ok: true, message: 'تم الحذف' });
  } catch (e) {
    res.status(500).json({ ok: false, error: 'server_error', message: e.message });
  }
});

/** GET /api/merchant/merchants — قائمة التجار (لاختيار التحويل) */
router.get('/merchants', async (req, res) => {
  const db = req.db;
  const currentId = req.appUser.merchant_id;
  try {
    const list = await db.prepare('SELECT id, name, store_name, city_id FROM merchants WHERE is_active = 1 AND id != ? ORDER BY name').all(currentId);
    res.json({ ok: true, merchants: list });
  } catch (e) {
    res.status(500).json({ ok: false, error: 'server_error', message: e.message });
  }
});

/** GET /api/merchant/stats — إحصائيات التاجر (عدد الطلبات، مبيعات، سرعة رد تقريبية) */
router.get('/stats', async (req, res) => {
  const db = req.db;
  const merchantId = req.appUser.merchant_id;

  const merchant = await db.prepare('SELECT city_id FROM merchants WHERE id = ?').get(merchantId);
  const cityId = merchant && merchant.city_id != null ? merchant.city_id : null;

  const cond = cityId != null ? '(merchant_id = ? OR (merchant_id IS NULL AND city_id = ?))' : 'merchant_id = ?';
  const params = cityId != null ? [merchantId, cityId] : [merchantId];

  const orderCountRow = await db.prepare(`SELECT COUNT(*) as c FROM orders WHERE ${cond} AND status != 'cancelled'`).get(...params);
  const salesResult = await db.prepare(`SELECT COALESCE(SUM(total_amount), 0) as total FROM orders WHERE ${cond} AND status IN ('confirmed', 'shipped', 'delivered')`).get(...params);
  const orderCount = orderCountRow ? orderCountRow.c : 0;

  res.json({
    ok: true,
    stats: {
      orderCount: orderCount || 0,
      totalSales: Number(salesResult.total || 0)
    }
  });
});

module.exports = router;
