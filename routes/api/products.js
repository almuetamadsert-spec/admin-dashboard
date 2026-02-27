const express = require('express');
const router = express.Router();

/**
 * GET /api/products — قائمة المنتجات النشطة.
 * Query: category_id (اختياري), company (فلتر بالبراند), q (بحث بالاسم أو الكود), sort (price_asc | price_desc | date_asc | date_desc)
 */
router.get('/', async (req, res) => {
  const db = req.db;
  const categoryId = req.query.category_id ? parseInt(req.query.category_id, 10) : null;
  const company = (req.query.company || '').trim();
  const q = (req.query.q || '').trim();
  const sort = req.query.sort || '';

  let sql = `
    SELECT id, name_ar, name_en, price, discount_percent, image_path, stock, company, category_id, created_at,
           colors, sizes, storage_capacities, battery_capacities, long_description, short_description
    FROM products
    WHERE is_active = 1
  `;
  const params = [];

  if (categoryId && Number.isFinite(categoryId)) {
    sql += ' AND category_id = ?';
    params.push(categoryId);
  }
  if (company) {
    sql += " AND LOWER(TRIM(COALESCE(company, ''))) = LOWER(?)";
    params.push(company);
  }
  if (q) {
    const like = '%' + q + '%';
    const numQ = parseInt(q, 10);
    if (Number.isFinite(numQ)) {
      sql += ' AND (name_ar LIKE ? OR name_en LIKE ? OR id = ?)';
      params.push(like, like, numQ);
    } else {
      sql += ' AND (name_ar LIKE ? OR name_en LIKE ?)';
      params.push(like, like);
    }
  }

  switch (sort) {
    case 'price_asc': sql += ' ORDER BY price ASC'; break;
    case 'price_desc': sql += ' ORDER BY price DESC'; break;
    case 'date_desc': sql += ' ORDER BY created_at DESC'; break;
    case 'date_asc': sql += ' ORDER BY created_at ASC'; break;
    default: sql += ' ORDER BY name_ar'; break;
  }

  const products = params.length ? await db.prepare(sql).all(...params) : await db.prepare(sql).all();
  const list = products.map((p) => {
    const price = Number(p.price) || 0;
    const discount = Number(p.discount_percent) || 0;
    const finalPrice = price * (1 - discount / 100);
    return {
      id: p.id,
      name_ar: p.name_ar,
      name_en: p.name_en,
      price,
      discount_percent: discount,
      final_price: Math.round(finalPrice * 100) / 100,
      image_path: p.image_path || null,
      stock: p.stock != null ? Number(p.stock) : 0,
      company: p.company || null,
      colors: p.colors || null,
      sizes: p.sizes || null,
      storage_capacities: p.storage_capacities || null,
      battery_capacities: p.battery_capacities || null,
      description: p.long_description || null,
      short_description: p.short_description || null
    };
  });
  res.json({ ok: true, products: list });
});

module.exports = router;
