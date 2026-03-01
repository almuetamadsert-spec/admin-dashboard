const express = require('express');
const path = require('path');
const fs = require('fs');
const { uploadBanner } = require('../config/multerBanners');
const { uploadLogo } = require('../config/multerLogos');
const { setSetting, getSettings, logActivity } = require('../lib/settings');

const router = express.Router({ strict: false });

const LOGO_POSITIONS = [
  { value: 'left', label: 'يسار' },
  { value: 'right', label: 'يمين' },
  { value: 'top', label: 'فوق' },
  { value: 'bottom', label: 'تحت' }
];

const CORNER_STYLES = [
  // ... (lines 9-33 remain mostly same, I'll update the listPage below)
  { value: 'sharp', label: 'حادة' },
  { value: 'rounded', label: 'دائرية' },
  { value: 'medium', label: 'متوسطة' }
];

const CARD_POSITIONS = [
  { value: 'left', label: 'يسار' },
  { value: 'right', label: 'يمين' },
  { value: 'top', label: 'فوق' },
  { value: 'bottom', label: 'تحت' }
];

const CARD_ALIGNS = [
  { value: 'left', label: 'يسار' },
  { value: 'center', label: 'وسط' },
  { value: 'right', label: 'يمين' }
];

const ADD_BTN_STYLES = [
  { value: 'small_rounded', label: 'زر صغير زوايا دائرية' },
  { value: 'full_rounded', label: 'زر كامل دائري' },
  { value: 'sharp', label: 'زر زوايا حادة' }
];

async function listPage(req, res) {
  const db = req.db;
  const [slides, settings] = await Promise.all([
    db.prepare('SELECT * FROM store_slides ORDER BY sort_order ASC, id ASC').all(),
    getSettings(db)
  ]);

  // Stats for the header
  const stats = {
    totalSlides: slides.length,
    activeInterval: settings.store_slider_interval || '5',
    hasLogo: !!settings.store_logo_url,
    layoutType: settings.store_product_layout || 'grid_2'
  };

  const interval = settings.store_slider_interval || '5';
  const productLayout = settings.store_product_layout || 'grid_2';
  const cardBg = settings.store_product_card_bg || '#ffffff';
  const cardRadius = settings.store_product_card_radius || 'rounded';
  const showAddToCart = settings.store_product_card_show_add_to_cart !== '0';
  const showBuyNow = settings.store_product_card_show_buy_now !== '0';
  const cardBrandPos = settings.store_card_brand_position || 'left';
  const cardBrandAlign = settings.store_card_brand_align || 'right';
  const cardNameAlign = settings.store_card_name_align || 'right';
  const cardPriceAlign = settings.store_card_price_align || 'right';
  const stockStyle = settings.store_product_card_stock_style || 'none';
  const stockColorAv = settings.store_product_card_stock_color_av || '#4caf50';
  const stockColorOut = settings.store_product_card_stock_color_out || '#f44336';
  const priceColor = settings.store_product_card_price_color || '#0ea5e9';
  const cardAddBtnStyle = settings.store_card_add_btn_style || 'small_rounded';
  const cardAddBtnPosition = settings.store_card_add_btn_position || 'right';
  const cardAddBtnColor = settings.store_card_add_btn_color || '#06A3E7';
  const cardBuyNowColor = settings.store_card_buy_now_color || '#ff9800';
  const merchantCardBg = settings.merchant_product_card_bg || '#ffffff';
  const merchantCardRadius = settings.merchant_product_card_radius || 'rounded';

  const logoUrl = settings.store_logo_url || '';
  const logoSize = settings.store_logo_size || '100';
  const logoPosition = settings.store_logo_position || 'right';
  const logoMarginTop = settings.store_logo_margin_top || '0';
  const logoMarginBottom = settings.store_logo_margin_bottom || '0';
  const logoMarginLeft = settings.store_logo_margin_left || '0';
  const logoMarginRight = settings.store_logo_margin_right || '0';

  res.render('store_ui/list', {
    slides,
    stats,
    interval,
    productLayout,
    cardBg,
    cardRadius,
    showAddToCart,
    showBuyNow,
    stockStyle,
    stockColorAv,
    stockColorOut,
    priceColor,
    cardBrandPos,
    cardBrandAlign,
    cardNameAlign,
    cardPriceAlign,
    cardAddBtnStyle,
    cardAddBtnPosition,
    cardAddBtnColor,
    cardBuyNowColor,
    logoUrl,
    logoSize,
    logoPosition,
    logoMarginTop,
    logoMarginBottom,
    logoMarginLeft,
    logoMarginRight,
    cornerStyles: CORNER_STYLES,
    cardPositions: CARD_POSITIONS,
    cardAligns: CARD_ALIGNS,
    logoPositions: LOGO_POSITIONS,
    addBtnStyles: ADD_BTN_STYLES,
    merchantCardBg,
    merchantCardRadius,
    query: req.query,
    adminUsername: req.session.adminUsername
  });
}

router.get('/', listPage);
router.get('', listPage);

router.post('/settings', async (req, res) => {
  const db = req.db;
  const interval = (req.body && req.body.interval !== undefined) ? String(req.body.interval).trim() : '5';
  const num = parseInt(interval, 10);
  const val = (num >= 2 && num <= 60) ? String(num) : '5';
  await setSetting(db, 'store_slider_interval', val);

  const layout = (req.body && req.body.product_layout) ? String(req.body.product_layout).trim() : '';
  if (['grid_2', 'grid_3', 'slider'].includes(layout)) {
    await setSetting(db, 'store_product_layout', layout);
  }

  const cardBg = (req.body && req.body.product_card_bg) ? String(req.body.product_card_bg).trim() : '';
  if (cardBg) await setSetting(db, 'store_product_card_bg', cardBg);
  const cardRadius = (req.body && req.body.product_card_radius) ? String(req.body.product_card_radius).trim() : '';
  if (['sharp', 'rounded', 'medium'].includes(cardRadius)) await setSetting(db, 'store_product_card_radius', cardRadius);
  const showAdd = (req.body && req.body.product_card_show_add_to_cart === '1') ? '1' : '0';
  await setSetting(db, 'store_product_card_show_add_to_cart', showAdd);

  const showBuyNow = (req.body && req.body.product_card_show_buy_now === '1') ? '1' : '0';
  await setSetting(db, 'store_product_card_show_buy_now', showBuyNow);

  const brandPos = (req.body && req.body.card_brand_position) ? String(req.body.card_brand_position).trim() : '';
  if (['left', 'right', 'top', 'bottom'].includes(brandPos)) await setSetting(db, 'store_card_brand_position', brandPos);

  const brandAlign = (req.body && req.body.card_brand_align) ? String(req.body.card_brand_align).trim() : '';
  if (['left', 'center', 'right'].includes(brandAlign)) await setSetting(db, 'store_card_brand_align', brandAlign);

  const nameAlign = (req.body && req.body.card_name_align) ? String(req.body.card_name_align).trim() : '';
  if (['left', 'center', 'right'].includes(nameAlign)) await setSetting(db, 'store_card_name_align', nameAlign);
  const priceAlign = (req.body && req.body.card_price_align) ? String(req.body.card_price_align).trim() : '';
  if (['left', 'center', 'right'].includes(priceAlign)) await setSetting(db, 'store_card_price_align', priceAlign);

  const stockStyle = (req.body && req.body.product_card_stock_style) ? String(req.body.product_card_stock_style).trim() : '';
  if (['none', 'number', 'text'].includes(stockStyle)) await setSetting(db, 'store_product_card_stock_style', stockStyle);

  const stockColorAv = (req.body && req.body.product_card_stock_color_av) ? String(req.body.product_card_stock_color_av).trim() : '';
  if (stockColorAv) await setSetting(db, 'store_product_card_stock_color_av', stockColorAv);

  const stockColorOut = (req.body && req.body.product_card_stock_color_out) ? String(req.body.product_card_stock_color_out).trim() : '';
  if (stockColorOut) await setSetting(db, 'store_product_card_stock_color_out', stockColorOut);

  const priceColor = (req.body && req.body.product_card_price_color) ? String(req.body.product_card_price_color).trim() : '';
  if (priceColor) await setSetting(db, 'store_product_card_price_color', priceColor);

  // Remove legacy setting just in case, or leave it.
  await setSetting(db, 'store_product_card_show_stock', '0');

  const addBtnStyle = (req.body && req.body.card_add_btn_style) ? String(req.body.card_add_btn_style).trim() : '';
  if (['small_rounded', 'full_rounded', 'sharp'].includes(addBtnStyle)) await setSetting(db, 'store_card_add_btn_style', addBtnStyle);
  const addBtnPos = (req.body && req.body.card_add_btn_position) ? String(req.body.card_add_btn_position).trim() : '';
  if (['left', 'right'].includes(addBtnPos)) await setSetting(db, 'store_card_add_btn_position', addBtnPos);
  const addBtnColor = (req.body && req.body.card_add_btn_color) ? String(req.body.card_add_btn_color).trim() : '';
  if (addBtnColor) await setSetting(db, 'store_card_add_btn_color', addBtnColor);
  const buyNowColor = (req.body && req.body.card_buy_now_color) ? String(req.body.card_buy_now_color).trim() : '';
  if (buyNowColor) await setSetting(db, 'store_card_buy_now_color', buyNowColor);

  const merchantCardBg = (req.body && req.body.merchant_product_card_bg) ? String(req.body.merchant_product_card_bg).trim() : '';
  if (merchantCardBg) await setSetting(db, 'merchant_product_card_bg', merchantCardBg);
  const merchantCardRadius = (req.body && req.body.merchant_product_card_radius) ? String(req.body.merchant_product_card_radius).trim() : '';
  if (['sharp', 'rounded', 'medium'].includes(merchantCardRadius)) await setSetting(db, 'merchant_product_card_radius', merchantCardRadius);

  await logActivity(db, req.session.adminId, req.session.adminUsername, 'تعديل واجهة المتجر', 'وقت السلايدر وعرض البطاقات');
  res.redirect('/admin/store-ui');
});

router.post('/logo', uploadLogo, async (req, res) => {
  const db = req.db;
  if (req.file && req.file.filename) {
    const relativePath = path.join('logos', req.file.filename).replace(/\\/g, '/');
    await setSetting(db, 'store_logo_url', relativePath);
  }

  if (req.body && req.body.logo_size) {
    await setSetting(db, 'store_logo_size', String(req.body.logo_size));
  }
  if (req.body && req.body.logo_position) {
    await setSetting(db, 'store_logo_position', String(req.body.logo_position));
  }

  // Margin Settings
  if (req.body && req.body.logo_margin_top !== undefined) {
    await setSetting(db, 'store_logo_margin_top', String(req.body.logo_margin_top));
  }
  if (req.body && req.body.logo_margin_bottom !== undefined) {
    await setSetting(db, 'store_logo_margin_bottom', String(req.body.logo_margin_bottom));
  }
  if (req.body && req.body.logo_margin_left !== undefined) {
    await setSetting(db, 'store_logo_margin_left', String(req.body.logo_margin_left));
  }
  if (req.body && req.body.logo_margin_right !== undefined) {
    await setSetting(db, 'store_logo_margin_right', String(req.body.logo_margin_right));
  }

  await logActivity(db, req.session.adminId, req.session.adminUsername, 'تعديل شعار المتجر', 'الشعار والحجم والموقع والهوامش');
  res.redirect('/admin/store-ui');
});

router.post('/slide', uploadBanner, async (req, res) => {
  const db = req.db;
  if (!req.file || !req.file.filename) {
    return res.redirect('/admin/store-ui?error=no_image');
  }
  const relativePath = path.join('banners', req.file.filename).replace(/\\/g, '/');
  const cornerStyle = (req.body && req.body.corner_style) || 'rounded';
  const validStyle = CORNER_STYLES.some(s => s.value === cornerStyle) ? cornerStyle : 'rounded';
  const maxOrder = await db.prepare('SELECT COALESCE(MAX(sort_order), -1) + 1 AS next_order FROM store_slides').get();
  const sortOrder = (maxOrder && maxOrder.next_order != null) ? maxOrder.next_order : 0;
  await db.prepare('INSERT INTO store_slides (image_path, corner_style, sort_order) VALUES (?, ?, ?)').run(relativePath, validStyle, sortOrder);
  await logActivity(db, req.session.adminId, req.session.adminUsername, 'إضافة شريحة إعلان', relativePath);
  res.redirect('/admin/store-ui');
});

router.get('/slide/edit/:id', async (req, res) => {
  const db = req.db;
  const slide = await db.prepare('SELECT * FROM store_slides WHERE id = ?').get(req.params.id);
  if (!slide) return res.redirect('/admin/store-ui');
  res.render('store_ui/edit', {
    slide,
    cornerStyles: CORNER_STYLES,
    adminUsername: req.session.adminUsername
  });
});

router.post('/slide/edit/:id', uploadBanner, async (req, res) => {
  const db = req.db;
  const id = req.params.id;
  const slide = await db.prepare('SELECT * FROM store_slides WHERE id = ?').get(id);
  if (!slide) return res.redirect('/admin/store-ui');
  let imagePath = slide.image_path;
  if (req.file && req.file.filename) {
    const fullOld = path.join(__dirname, '..', 'uploads', slide.image_path);
    if (fs.existsSync(fullOld)) try { fs.unlinkSync(fullOld); } catch (e) { /* ignore */ }
    imagePath = path.join('banners', req.file.filename).replace(/\\/g, '/');
  }
  const cornerStyle = (req.body && req.body.corner_style) || 'rounded';
  const validStyle = CORNER_STYLES.some(s => s.value === cornerStyle) ? cornerStyle : 'rounded';
  await db.prepare('UPDATE store_slides SET image_path = ?, corner_style = ? WHERE id = ?').run(imagePath, validStyle, id);
  await logActivity(db, req.session.adminId, req.session.adminUsername, 'تعديل شريحة إعلان', String(id));
  res.redirect('/admin/store-ui');
});

router.post('/slide/delete/:id', async (req, res) => {
  const db = req.db;
  const id = req.params.id;
  const slide = await db.prepare('SELECT * FROM store_slides WHERE id = ?').get(id);
  if (slide) {
    const fullPath = path.join(__dirname, '..', 'uploads', slide.image_path);
    if (fs.existsSync(fullPath)) try { fs.unlinkSync(fullPath); } catch (e) { /* ignore */ }
    await db.prepare('DELETE FROM store_slides WHERE id = ?').run(id);
    await logActivity(db, req.session.adminId, req.session.adminUsername, 'حذف شريحة إعلان', String(id));
  }
  res.redirect('/admin/store-ui');
});

router.post('/slide/reorder', async (req, res) => {
  const db = req.db;
  const order = req.body && req.body.order;
  if (order && Array.isArray(order)) {
    for (let index = 0; index < order.length; index++) {
      const n = parseInt(order[index], 10);
      if (Number.isFinite(n)) await db.prepare('UPDATE store_slides SET sort_order = ? WHERE id = ?').run(index, n);
    }
  }
  res.redirect('/admin/store-ui');
});

module.exports = router;
