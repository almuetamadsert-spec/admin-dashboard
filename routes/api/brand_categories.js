const express = require('express');
const router = express.Router();

/** GET /api/brand-categories — قائمة تصنيفات البراندات للتطبيق */
router.get('/', async (req, res) => {
  res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate');
  const db = req.db;
  try {
    const list = await db.prepare(`
      SELECT id, name_ar, icon_path, icon_size, icon_corner, icon_shape, icon_color, sort_order
      FROM brand_categories
      ORDER BY sort_order ASC, name_ar ASC
    `).all();
    const baseUrl = (req.protocol || 'http') + '://' + (req.get('host') || 'localhost:3000');
    res.json({
      ok: true,
      brand_categories: list.map((b) => ({
        id: b.id,
        name_ar: b.name_ar || '',
        icon_path: b.icon_path || null,
        icon_url: b.icon_path ? baseUrl + '/uploads/' + (b.icon_path).replace(/^\/+/, '') : null,
        icon_size: b.icon_size || 'medium',
        icon_corner: b.icon_corner || 'rounded',
        icon_shape: b.icon_shape || 'square',
        icon_color: b.icon_color || '#06A3E7',
        sort_order: b.sort_order != null ? b.sort_order : 0,
      })),
    });
  } catch (e) {
    res.status(500).json({ ok: false, message: e.message });
  }
});

module.exports = router;
