const express = require('express');

const router = express.Router();

router.get('/', async (req, res) => {
  const db = req.db;
  const [lowStock, outOfStock] = await Promise.all([
    db.prepare(`
      SELECT p.*, c.name_ar as category_name FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE p.low_stock_alert > 0 AND p.stock <= p.low_stock_alert AND p.is_active = 1
      ORDER BY p.stock ASC
    `).all(),
    db.prepare(`
      SELECT p.*, c.name_ar as category_name FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE p.stock <= 0
      ORDER BY p.name_ar
    `).all()
  ]);
  res.render('inventory/alerts', { lowStock, outOfStock, adminUsername: req.session.adminUsername });
});

module.exports = router;
