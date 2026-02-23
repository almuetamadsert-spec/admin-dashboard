const express = require('express');

const router = express.Router();

router.get('/', (req, res) => {
  const db = req.db;
  const list = db.prepare('SELECT * FROM categories ORDER BY name_ar').all();
  res.json(list);
});

router.get('/page', (req, res) => {
  const db = req.db;
  const list = db.prepare('SELECT * FROM categories ORDER BY name_ar').all();
  res.render('categories/list', { categories: list, adminUsername: req.session.adminUsername });
});

router.post('/', (req, res) => {
  const db = req.db;
  const { name_ar, name_en } = req.body || {};
  if (!name_ar) return res.status(400).json({ error: 'اسم التصنيف مطلوب' });
  const r = db.prepare('INSERT INTO categories (name_ar, name_en) VALUES (?, ?)').run(name_ar || '', name_en || '');
  res.json({ id: r.lastInsertRowid });
});

router.put('/:id', (req, res) => {
  const db = req.db;
  const { name_ar, name_en } = req.body || {};
  db.prepare('UPDATE categories SET name_ar = ?, name_en = ? WHERE id = ?').run(name_ar || '', name_en || '', req.params.id);
  res.json({ ok: true });
});

router.delete('/:id', (req, res) => {
  const db = req.db;
  db.prepare('DELETE FROM categories WHERE id = ?').run(req.params.id);
  res.json({ ok: true });
});

module.exports = router;
