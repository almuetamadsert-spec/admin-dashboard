const express = require('express');

const router = express.Router();

router.get('/:slug', async (req, res) => {
  const db = req.db;
  const page = await db.prepare('SELECT slug, title_ar, title_en, content_ar, content_en, updated_at FROM cms_pages WHERE slug = ?').get(req.params.slug);
  if (!page) return res.status(404).json({ ok: false, error: 'not_found' });
  res.json({ ok: true, page });
});

module.exports = router;
