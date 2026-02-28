const express = require('express');
const path = require('path');
const { upload, uploadMultiple, uploadCsv } = require('../config/multer');
const fs = require('fs');
const csv = require('csv-parser');
const xlsx = require('xlsx');
const { downloadImage } = require('../lib/image_downloader');

const router = express.Router();

router.get('/', async (req, res) => {
  const db = req.db;
  const page = parseInt(req.query.page) || 1;
  const limit = 30;
  const offset = (page - 1) * limit;

  const [categories, products, totalCountResult] = await Promise.all([
    db.prepare('SELECT * FROM categories ORDER BY name_ar').all(),
    db.prepare(`
      SELECT p.*, c.name_ar as category_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      ORDER BY p.created_at DESC
      LIMIT ? OFFSET ?
    `).all(limit, offset),
    db.prepare('SELECT COUNT(*) as total FROM products').get()
  ]);

  const totalPages = Math.ceil(totalCountResult.total / limit);

  res.render('products/list', {
    products,
    categories,
    adminUsername: req.session.adminUsername,
    currentPage: page,
    totalPages,
    totalProducts: totalCountResult.total
  });
});

router.post('/bulk-delete', async (req, res) => {
  const db = req.db;
  const ids = req.body.ids; // Array of IDs
  if (!ids || !Array.isArray(ids) || ids.length === 0) {
    return res.status(400).json({ success: false, message: 'لم يتم اختيار أي منتجات' });
  }

  try {
    const placeholders = ids.map(() => '?').join(',');
    await db.prepare(`DELETE FROM products WHERE id IN (${placeholders})`).run(...ids);
    res.json({ success: true, message: `تم حذف ${ids.length} منتج بنجاح.` });
  } catch (err) {
    console.error('Bulk Delete Error:', err);
    res.status(500).json({ success: false, message: 'حدث خطأ أثناء الحذف الجماعي' });
  }
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

// Import WooCommerce CSV or Excel
router.post('/import', (req, res, next) => {
  uploadCsv.single('csv_file')(req, res, err => {
    if (err) return res.status(400).json({ success: false, message: err.message });
    next();
  });
}, async (req, res) => {
  if (!req.file) return res.status(400).json({ success: false, message: 'لم يتم إرفاق ملف' });
  const db = req.db;
  const filePath = req.file.path;

  try {
    const workbook = xlsx.readFile(filePath);
    const sheetName = workbook.SheetNames[0];
    const results = xlsx.utils.sheet_to_json(workbook.Sheets[sheetName], { defval: '' });

    db.exec('BEGIN TRANSACTION');

    let insertedCount = 0;
    for (const row of results) {
      // Normalize column names (sometimes WooCommerce uses "Name", "Regular price" etc)
      const name = row['Name'] || row['Title'] || row['اسم المنتج'] || row['الاسم'] || '';
      if (!name) continue; // skip empty rows

      const desc = row['Description'] || row['وصف'] || row['الوصف'] || '';
      const shortDesc = row['Short description'] || row['نبذة'] || row['وصف قصير'] || '';
      const regPrice = parseFloat(row['Regular price'] || row['السعر الافتراضي'] || row['السعر العادي'] || row['السعر'] || 0);
      const salePrice = parseFloat(row['Sale price'] || row['سعر التخفيض'] || 0);
      const stockStr = String(row['Stock'] || row['In stock?'] || row['المخزون'] || '1').toLowerCase().trim();
      let stock = parseInt(stockStr, 10);
      if (isNaN(stock)) {
        if (stockStr === 'instock' || stockStr === 'في المخزن' || stockStr === '1') stock = 99;
        else stock = 0;
      }

      const categoriesStr = row['Categories'] || row['تصنيفات'] || row['التصنيفات'] || '';
      const imagesStr = row['Images'] || row['الصور'] || '';

      // Try to get Brand/Company
      let company = row['Brand'] || row['Manufacturer'] || row['العلامة التجارية'] || row['الشركة'] || '';
      if (!company && categoriesStr) {
        // Fallback: use the last category as brand if company is missing
        const cats = String(categoriesStr).split(',').map(c => c.trim());
        if (cats.length > 1) company = cats[cats.length - 1];
      }

      // Try to get Attributes (Options)
      let colors = row['Attribute 1 value(s)'] || row['اللون'] || '';
      let sizes = row['Attribute 2 value(s)'] || row['المقاس'] || '';
      let storage = row['Attribute 3 value(s)'] || row['السعة'] || '';

      let price = salePrice > 0 ? salePrice : regPrice;
      let discount_percent = 0;
      if (salePrice > 0 && regPrice > salePrice) {
        discount_percent = Math.round(((regPrice - salePrice) / regPrice) * 100);
        price = regPrice; // base price is regular, discount is applied
      }

      let categoryId = null;
      if (categoriesStr) {
        const firstCat = String(categoriesStr).split(',')[0].trim();
        if (firstCat) {
          let cat = await db.prepare('SELECT id FROM categories WHERE name_ar = ? OR name_en = ?').get(firstCat, firstCat);
          if (!cat) {
            const info = await db.prepare('INSERT INTO categories (name_ar, name_en, icon_path) VALUES (?, ?, ?)').run(firstCat, firstCat, '');
            categoryId = info.lastInsertRowid;
          } else {
            categoryId = cat.id;
          }
        }
      }

      // Handle Image Downloads
      let image_path = '';
      let image_paths = '';
      if (imagesStr) {
        const imageUrls = String(imagesStr).split(',').map(u => u.trim()).filter(Boolean);
        const productsUploadDir = path.join(__dirname, '..', 'uploads', 'products');

        const downloadedNames = [];
        for (const url of imageUrls) {
          const filename = await downloadImage(url, productsUploadDir);
          if (filename) downloadedNames.push('products/' + filename);
        }

        if (downloadedNames.length > 0) {
          image_path = downloadedNames[0];
          image_paths = downloadedNames.join(',');
        }
      }

      await db.prepare(`
        INSERT INTO products 
        (name_ar, name_en, short_description, long_description, price, discount_percent, company, category_id, image_path, image_paths, stock, is_active, low_stock_alert, hide_when_out_of_stock, colors, sizes, storage_capacities, battery_capacities)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `).run(
        name, // name_ar
        name, // name_en
        shortDesc,
        desc,
        price,
        discount_percent,
        company, // company
        categoryId,
        image_path,
        image_paths,
        stock,
        1, // is_active
        0, // low_stock_alert
        1, // hide_when_out_of_stock
        colors, sizes, storage, ''
      );
      insertedCount++;
    }

    db.exec('COMMIT');

    if (fs.existsSync(filePath)) fs.unlinkSync(filePath); // Cleanup
    res.json({ success: true, message: `تم استيراد ${insertedCount} منتج بنجاح.` });
  } catch (err) {
    try { db.exec('ROLLBACK'); } catch (e) { }
    if (fs.existsSync(filePath)) fs.unlinkSync(filePath);
    console.error('CSV/Excel Import Error:', err);
    res.status(500).json({ success: false, message: 'حدث خطأ أثناء الاستيراد: ' + err.message });
  }
});

module.exports = router;
