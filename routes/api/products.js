const express = require('express');
const router = express.Router();

/**
 * GET /api/products — قائمة المنتجات النشطة (للمتجر/التطبيق).
 */
router.get('/', (req, res) => {
  const db = req.db;
  const products = db.prepare(`
    SELECT id, name_ar, name_en, price, discount_percent, image_path, stock
    FROM products
    WHERE is_active = 1
    ORDER BY name_ar
  `).all();
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
      stock: p.stock != null ? Number(p.stock) : 0
    };
  });
  res.json({ ok: true, products: list });
});

module.exports = router;
