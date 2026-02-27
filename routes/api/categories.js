const express = require('express');
const router = express.Router();

/** GET /api/categories — قائمة التصنيفات للتطبيق (مع أيقونة، شكل، لون) */
router.get('/', async (req, res) => {
  res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate');
  const db = req.db;
  try {
    const list = await db.prepare(`
      SELECT id, name_ar, name_en, icon_type, icon_name, icon_color, icon_symbol_color, icon_opacity, icon_path, sort_order
      FROM categories
      ORDER BY sort_order ASC, name_ar ASC
    `).all();
    res.json({
      ok: true,
      categories: list.map((c) => ({
        id: c.id,
        name_ar: c.name_ar || '',
        name_en: c.name_en || null,
        icon_type: c.icon_type || 'circle',
        icon_name: c.icon_name || null,
        icon_color: c.icon_color || '#06A3E7',
        icon_symbol_color: c.icon_symbol_color || null,
        icon_opacity: c.icon_opacity != null ? Math.min(100, Math.max(0, c.icon_opacity)) : 100,
        icon_path: c.icon_path || null,
        sort_order: c.sort_order != null ? c.sort_order : 0,
      })),
    });
  } catch (e) {
    res.status(500).json({ ok: false, message: e.message });
  }
});

module.exports = router;
