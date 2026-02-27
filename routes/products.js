const express = require('express');
const path = require('path');
const { upload, uploadMultiple } = require('../config/multer');

const router = express.Router();

router.get('/', async (req, res) => {
  const db = req.db;
  const [categories, products] = await Promise.all([
    db.prepare('SELECT * FROM categories ORDER BY name_ar').all(),
    db.prepare(`
      SELECT p.*, c.name_ar as category_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      ORDER BY p.created_at DESC
    `).all()
  ]);
  res.render('products/list', { products, categories, adminUsername: req.session.adminUsername });
});

router.get('/new', async (req, res) => {
  const db = req.db;
  const categories = await db.prepare('SELECT * FROM categories ORDER BY name_ar').all();
  res.render('products/form', { product: null, categories, adminUsername: req.session.adminUsername });
});

router.get('/edit/:id', async (req, res) => {
  const db = req.db;
  const product = await db.prepare('SELECT * FROM products WHERE id = ?').get(req.params.id);
  if (!product) return res.redirect('/admin/products');
  const categories = await db.prepare('SELECT * FROM categories ORDER BY name_ar').all();
  res.render('products/form', { product, categories, adminUsername: req.session.adminUsername });
});

router.post('/', upload.fields([{ name: 'image', maxCount: 1 }, { name: 'images', maxCount: 10 }]), async (req, res) => {
  const db = req.db;
  const body = req.body || {};
  const mainImg = req.files && req.files.image && req.files.image[0];
  const extraImgs = req.files && req.files.images ? req.files.images : [];
  const image_path = mainImg ? path.join('products', mainImg.filename).replace(/\\/g, '/') : '';
  const image_paths = extraImgs.length ? extraImgs.map(f => path.join('products', f.filename).replace(/\\/g, '/')).join('|') : '';

  const price = parseFloat(body.price) || 0;
  const discount = parseFloat(body.discount_percent) || 0;
  const stock = parseInt(body.stock, 10) || 0;
  const low_stock_alert = parseInt(body.low_stock_alert, 10) || 0;
  const hide_when_out = body.hide_when_out_of_stock === '1' ? 1 : 0;

  const colors = body.colors ? body.colors.trim() : '';
  const sizes = body.sizes ? body.sizes.trim() : '';
  const storage_capacities = body.storage_capacities ? body.storage_capacities.trim() : '';
  const battery_capacities = body.battery_capacities ? body.battery_capacities.trim() : '';

  await db.prepare(`
    INSERT INTO products (name_ar, name_en, short_description, long_description, price, discount_percent, company, category_id, image_path, image_paths, stock, is_active, low_stock_alert, hide_when_out_of_stock, colors, sizes, storage_capacities, battery_capacities)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).run(
    body.name_ar || '',
    body.name_en || '',
    body.short_description || '',
    body.long_description || '',
    price,
    discount,
    body.company || '',
    body.category_id || null,
    image_path,
    image_paths,
    stock,
    body.is_active !== '0' ? 1 : 0,
    low_stock_alert,
    hide_when_out,
    colors,
    sizes,
    storage_capacities,
    battery_capacities
  );
  res.redirect('/admin/products');
});

router.post('/edit/:id', upload.fields([{ name: 'image', maxCount: 1 }, { name: 'images', maxCount: 10 }]), async (req, res) => {
  const db = req.db;
  const body = req.body || {};
  const id = req.params.id;
  const product = await db.prepare('SELECT * FROM products WHERE id = ?').get(id);
  if (!product) return res.redirect('/admin/products');

  let image_path = product.image_path;
  let image_paths = product.image_paths || '';
  const mainImg = req.files && req.files.image && req.files.image[0];
  const extraImgs = req.files && req.files.images ? req.files.images : [];
  if (mainImg) image_path = path.join('products', mainImg.filename).replace(/\\/g, '/');
  if (extraImgs.length) image_paths = extraImgs.map(f => path.join('products', f.filename).replace(/\\/g, '/')).join('|');

  const price = parseFloat(body.price) || 0;
  const discount = parseFloat(body.discount_percent) || 0;
  const stock = parseInt(body.stock, 10) || 0;
  const low_stock_alert = parseInt(body.low_stock_alert, 10) || 0;
  const hide_when_out = body.hide_when_out_of_stock === '1' ? 1 : 0;

  const colors = body.colors ? body.colors.trim() : '';
  const sizes = body.sizes ? body.sizes.trim() : '';
  const storage_capacities = body.storage_capacities ? body.storage_capacities.trim() : '';
  const battery_capacities = body.battery_capacities ? body.battery_capacities.trim() : '';

  await db.prepare(`
    UPDATE products SET
      name_ar = ?, name_en = ?, short_description = ?, long_description = ?,
      price = ?, discount_percent = ?, company = ?, category_id = ?,
      image_path = ?, image_paths = ?, stock = ?, is_active = ?,
      low_stock_alert = ?, hide_when_out_of_stock = ?,
      colors = ?, sizes = ?, storage_capacities = ?, battery_capacities = ?,
      updated_at = CURRENT_TIMESTAMP
    WHERE id = ?
  `).run(
    body.name_ar || '',
    body.name_en || '',
    body.short_description || '',
    body.long_description || '',
    price,
    discount,
    body.company || '',
    body.category_id || null,
    image_path,
    image_paths,
    stock,
    body.is_active !== '0' ? 1 : 0,
    low_stock_alert,
    hide_when_out,
    colors,
    sizes,
    storage_capacities,
    battery_capacities,
    id
  );
  res.redirect('/admin/products');
});

router.post('/delete/:id', async (req, res) => {
  const db = req.db;
  await db.prepare('DELETE FROM products WHERE id = ?').run(req.params.id);
  res.redirect('/admin/products');
});

module.exports = router;
