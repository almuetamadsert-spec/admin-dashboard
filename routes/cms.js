const express = require('express');

const router = express.Router();

const SLUGS = [
  { slug: 'about_us', title_ar: 'من نحن', title_en: 'About Us' },
  { slug: 'privacy_policy', title_ar: 'سياسة الخصوصية', title_en: 'Privacy Policy' },
  { slug: 'terms', title_ar: 'شروط الاستخدام', title_en: 'Terms of Use' }
];

router.get('/', async (req, res) => {
  const db = req.db;
  const pages = [];
  let updatedCount = 0;

  for (const s of SLUGS) {
    const row = await db.prepare('SELECT * FROM cms_pages WHERE slug = ?').get(s.slug);
    if (row && row.updated_at) updatedCount++;
    pages.push(row ? { ...s, ...row } : { ...s, id: null, content_ar: '', content_en: '', updated_at: null });
  }

  const stats = {
    totalPages: SLUGS.length,
    updatedPages: updatedCount
  };

  res.render('cms/list', { pages, stats, adminUsername: req.session.adminUsername, title: 'إدارة المحتوى' });
});

router.get('/edit/:slug', async (req, res) => {
  const db = req.db;
  const slug = req.params.slug;
  const page = await db.prepare('SELECT * FROM cms_pages WHERE slug = ?').get(slug);
  const def = SLUGS.find(s => s.slug === slug) || { slug, title_ar: slug, title_en: slug };
  res.render('cms/form', { page: page || { slug, title_ar: def.title_ar, title_en: def.title_en, content_ar: '', content_en: '' }, adminUsername: req.session.adminUsername });
});

router.post('/save/:slug', async (req, res) => {
  const db = req.db;
  const slug = req.params.slug;
  const { title_ar, title_en, content_ar, content_en } = req.body || {};
  const exists = await db.prepare('SELECT id FROM cms_pages WHERE slug = ?').get(slug);
  if (exists) {
    await db.prepare('UPDATE cms_pages SET title_ar = ?, title_en = ?, content_ar = ?, content_en = ?, updated_at = CURRENT_TIMESTAMP WHERE slug = ?').run(title_ar || '', title_en || '', content_ar || '', content_en || '', slug);
  } else {
    await db.prepare('INSERT INTO cms_pages (slug, title_ar, title_en, content_ar, content_en) VALUES (?, ?, ?, ?, ?)').run(slug, title_ar || '', title_en || '', content_ar || '', content_en || '');
  }
  res.redirect('/admin/cms');
});

module.exports = router;
