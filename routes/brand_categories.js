const express = require('express');
const path = require('path');
const fs = require('fs');
const { uploadBrandIcon } = require('../config/multerBrandCategories');

const router = express.Router();

const ICON_SIZES = [
  { value: 'small', label: 'صغير' },
  { value: 'medium', label: 'وسط' },
  { value: 'large', label: 'كبير' },
];

const ICON_CORNERS = [
  { value: 'sharp', label: 'حادة' },
  { value: 'rounded', label: 'دائرية' },
  { value: 'medium', label: 'متوسطة' },
];

const ICON_SHAPES = [
  { value: 'square', label: 'مربع' },
  { value: 'rectangle', label: 'مستطيل' },
];

function normStr(v) {
  if (v == null) return '';
  if (Array.isArray(v)) v = v[0];
  return String(v).trim();
}

router.get('/', async (req, res) => {
  const db = req.db;
  const list = await db.prepare('SELECT * FROM brand_categories ORDER BY sort_order ASC, name_ar').all();
  res.render('brand_categories/list', {
    list,
    adminUsername: req.session.adminUsername,
    iconSizes: ICON_SIZES,
    iconCorners: ICON_CORNERS,
    iconShapes: ICON_SHAPES,
  });
});

router.post('/', uploadBrandIcon.single('icon'), async (req, res) => {
  const db = req.db;
  const body = req.body || {};
  const name_ar = normStr(body.name_ar);
  const icon_size = ['small', 'medium', 'large'].includes(normStr(body.icon_size)) ? normStr(body.icon_size) : 'medium';
  const icon_corner = ['sharp', 'rounded', 'medium'].includes(normStr(body.icon_corner)) ? normStr(body.icon_corner) : 'rounded';
  const icon_shape = ['square', 'rectangle'].includes(normStr(body.icon_shape)) ? normStr(body.icon_shape) : 'square';
  const icon_color = normStr(body.icon_color) || '#06A3E7';
  const sort_order = parseInt(body.sort_order, 10) || 0;
  let icon_path = null;
  if (req.file && req.file.filename) {
    icon_path = 'brand_categories/' + req.file.filename;
  }
  if (!name_ar) return res.status(400).json({ error: 'اسم البراند مطلوب' });
  const r = await db.prepare(
    'INSERT INTO brand_categories (name_ar, icon_path, icon_size, icon_corner, icon_shape, icon_color, sort_order) VALUES (?, ?, ?, ?, ?, ?, ?)'
  ).run(name_ar, icon_path, icon_size, icon_corner, icon_shape, icon_color, sort_order);
  res.json({ id: r.lastInsertRowid });
});

async function updateBrandCategory(req, res) {
  const db = req.db;
  const id = req.params.id;
  const body = req.body || {};
  const name_ar = normStr(body.name_ar);
  const icon_size = ['small', 'medium', 'large'].includes(normStr(body.icon_size)) ? normStr(body.icon_size) : 'medium';
  const icon_corner = ['sharp', 'rounded', 'medium'].includes(normStr(body.icon_corner)) ? normStr(body.icon_corner) : 'rounded';
  const icon_shape = ['square', 'rectangle'].includes(normStr(body.icon_shape)) ? normStr(body.icon_shape) : 'square';
  const icon_color = normStr(body.icon_color) || '#06A3E7';
  const sort_order = parseInt(body.sort_order, 10) || 0;
  const row = await db.prepare('SELECT icon_path FROM brand_categories WHERE id = ?').get(id);
  if (!row) return res.status(404).json({ error: 'غير موجود' });
  let icon_path = body.icon_path !== undefined ? (body.icon_path || null) : row.icon_path;
  if (req.file && req.file.filename) {
    if (row.icon_path) {
      const fullOld = path.join(__dirname, '..', 'uploads', row.icon_path);
      if (fs.existsSync(fullOld)) try { fs.unlinkSync(fullOld); } catch (e) { /* ignore */ }
    }
    icon_path = 'brand_categories/' + req.file.filename;
  }
  if (!name_ar) return res.status(400).json({ error: 'اسم البراند مطلوب' });
  await db.prepare(
    'UPDATE brand_categories SET name_ar = ?, icon_path = ?, icon_size = ?, icon_corner = ?, icon_shape = ?, icon_color = ?, sort_order = ? WHERE id = ?'
  ).run(name_ar, icon_path, icon_size, icon_corner, icon_shape, icon_color, sort_order, id);
  res.json({ ok: true });
}

router.put('/:id', uploadBrandIcon.single('icon'), updateBrandCategory);
router.post('/:id', uploadBrandIcon.single('icon'), updateBrandCategory);

router.delete('/:id', async (req, res) => {
  const db = req.db;
  const row = await db.prepare('SELECT icon_path FROM brand_categories WHERE id = ?').get(req.params.id);
  if (row && row.icon_path) {
    const fullPath = path.join(__dirname, '..', 'uploads', row.icon_path);
    if (fs.existsSync(fullPath)) try { fs.unlinkSync(fullPath); } catch (e) { /* ignore */ }
  }
  await db.prepare('DELETE FROM brand_categories WHERE id = ?').run(req.params.id);
  res.json({ ok: true });
});

module.exports = router;
