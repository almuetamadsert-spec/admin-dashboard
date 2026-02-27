const express = require('express');
const path = require('path');
const { uploadCategoryIcon } = require('../config/multerCategories');

const router = express.Router();

/** قائمة أيقونات احترافية (Bootstrap Icons) — يمكن تغيير لون الرمز عند الاختيار */
const ICON_PRESETS = [
  { value: 'case_cover', label: 'غطاء حماية (Case / Cover)', icon: 'bi-phone' },
  { value: 'screen_protector', label: 'لاصقة حماية الشاشة (Screen Protector)', icon: 'bi-phone-vibrate' },
  { value: 'camera_lens_protector', label: 'لاصقة حماية الكاميرا (Camera Lens Protector)', icon: 'bi-camera' },
  { value: 'phone_grip', label: 'مسكة هاتف (Phone Grip / PopSocket)', icon: 'bi-phone' },
  { value: 'phone_strap', label: 'ميدالية هاتف (Phone Strap)', icon: 'bi-phone' },
  { value: 'wall_charger', label: 'رأس شاحن (Wall Charger / Power Adapter)', icon: 'bi-plug' },
  { value: 'charging_cable', label: 'كابل شحن (Charging Cable - Type-C / Lightning)', icon: 'bi-lightning-charging' },
  { value: 'power_bank', label: 'شاحن متنقل (Power Bank)', icon: 'bi-battery-charging' },
  { value: 'wireless_charging_pad', label: 'قاعدة شحن لاسلكي (Wireless Charging Pad)', icon: 'bi-broadcast' },
  { value: 'car_charger', label: 'شاحن سيارة (Car Charger)', icon: 'bi-car-front' },
  { value: 'wired_earphones', label: 'سماعات أذن سلكية (Wired Earphones)', icon: 'bi-headphones' },
  { value: 'wireless_earbuds', label: 'سماعات بلوتوث (Wireless Earbuds)', icon: 'bi-headphones' },
  { value: 'bluetooth_speaker', label: 'مكبر صوت بلوتوث (Bluetooth Speaker)', icon: 'bi-speaker' },
  { value: 'audio_adapter', label: 'محول صوت (Audio Adapter - Type-C to 3.5mm)', icon: 'bi-usb-symbol' },
  { value: 'tripod', label: 'حامل ثلاثي (Tripod)', icon: 'bi-camera' },
  { value: 'selfie_stick', label: 'عصا سيلفي (Selfie Stick)', icon: 'bi-camera' },
  { value: 'gimbal', label: 'مانع اهتزاز (Gimbal)', icon: 'bi-camera-video' },
  { value: 'ring_light', label: 'إضاءة حلقية (Ring Light)', icon: 'bi-brightness-high' },
  { value: 'stylus_pen', label: 'قلم ذكي (Stylus Pen)', icon: 'bi-pencil' },
  { value: 'car_phone_holder', label: 'حامل هاتف للسيارة (Car Phone Holder)', icon: 'bi-phone' },
  { value: 'desktop_stand', label: 'حامل مكتب (Desktop Stand)', icon: 'bi-display' },
  { value: 'aux_cable', label: 'وصلة تشغيل الوسائط (AUX Cable)', icon: 'bi-music-note-beamed' },
  { value: 'power_bank_portable', label: 'باور بانك (Power Bank / Portable Charger)', icon: 'bi-battery-charging' },
  { value: 'solar_power_bank', label: 'شاحن طاقة شمسية (Solar Power Bank)', icon: 'bi-sun' },
  { value: 'portable_power_station', label: 'محطة طاقة محمولة (Portable Power Station)', icon: 'bi-lightning-charging' },
  { value: 'dslr_camera', label: 'كاميرا احترافية (DSLR / Mirrorless Camera)', icon: 'bi-camera' },
  { value: 'action_camera', label: 'كاميرا رياضية (Action Camera / GoPro)', icon: 'bi-camera-video' },
  { value: 'security_camera', label: 'كاميرا مراقبة ذكية (Smart Security Camera)', icon: 'bi-camera-video' },
  { value: 'external_phone_lenses', label: 'عدسات هاتف خارجية (External Phone Lenses)', icon: 'bi-camera' },
  { value: 'smartwatch', label: 'ساعة ذكية (Smartwatch)', icon: 'bi-smartwatch' },
];

router.get('/', async (req, res) => {
  const db = req.db;
  const list = await db.prepare('SELECT * FROM categories ORDER BY sort_order ASC, name_ar').all();
  res.json(list);
});

router.get('/page', async (req, res) => {
  const db = req.db;
  const list = await db.prepare('SELECT * FROM categories ORDER BY sort_order ASC, name_ar').all();
  res.render('categories/list', {
    categories: list,
    adminUsername: req.session.adminUsername,
    iconPresets: ICON_PRESETS,
  });
});

function normStr(v) {
  if (v == null) return '';
  if (Array.isArray(v)) v = v[0];
  return String(v).trim();
}

router.post('/', uploadCategoryIcon.single('icon'), async (req, res) => {
  const db = req.db;
  const body = req.body || {};
  const name_ar = normStr(body.name_ar);
  const name_en = normStr(body.name_en);
  const icon_type = normStr(body.icon_type) || 'circle';
  const icon_name = normStr(body.icon_name) || '';
  const icon_color = normStr(body.icon_color) || '#06A3E7';
  const icon_symbol_color = normStr(body.icon_symbol_color) || '';
  const icon_opacity = Math.min(100, Math.max(0, parseInt(body.icon_opacity, 10) || 100));
  const sort_order = parseInt(body.sort_order, 10) || 0;
  let icon_path = null;
  if (req.file && req.file.filename) {
    icon_path = 'categories/' + req.file.filename;
  }
  if (!name_ar) return res.status(400).json({ error: 'اسم التصنيف مطلوب' });
  const r = await db.prepare(
    'INSERT INTO categories (name_ar, name_en, icon_type, icon_name, icon_color, icon_symbol_color, icon_opacity, icon_path, sort_order) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)'
  ).run(name_ar, name_en, icon_type, icon_name || null, icon_color, icon_symbol_color || null, icon_opacity, icon_path, sort_order);
  res.json({ id: r.lastInsertRowid });
});

router.put('/:id', uploadCategoryIcon.single('icon'), async (req, res) => {
  const db = req.db;
  const id = req.params.id;
  const body = req.body || {};
  const name_ar = normStr(body.name_ar);
  const name_en = normStr(body.name_en);
  const icon_type = normStr(body.icon_type) || 'circle';
  const icon_name = normStr(body.icon_name) || '';
  const icon_color = normStr(body.icon_color) || '#06A3E7';
  const icon_symbol_color = normStr(body.icon_symbol_color) || '';
  const icon_opacity = Math.min(100, Math.max(0, parseInt(body.icon_opacity, 10) || 100));
  const sort_order = parseInt(body.sort_order, 10) || 0;
  let icon_path = body.icon_path || null;
  if (req.file && req.file.filename) {
    icon_path = 'categories/' + req.file.filename;
  }
  if (!name_ar) return res.status(400).json({ error: 'اسم التصنيف مطلوب' });
  const row = await db.prepare('SELECT icon_path FROM categories WHERE id = ?').get(id);
  if (!row) return res.status(404).json({ error: 'التصنيف غير موجود' });
  const finalIconPath = (req.file && req.file.filename)
    ? 'categories/' + req.file.filename
    : (icon_path !== undefined && icon_path !== '' ? icon_path : row.icon_path);
  await db.prepare(
    'UPDATE categories SET name_ar = ?, name_en = ?, icon_type = ?, icon_name = ?, icon_color = ?, icon_symbol_color = ?, icon_opacity = ?, icon_path = ?, sort_order = ? WHERE id = ?'
  ).run(name_ar, name_en, icon_type, icon_name || null, icon_color, icon_symbol_color || null, icon_opacity, finalIconPath, sort_order, id);
  res.json({ ok: true });
});

router.delete('/:id', async (req, res) => {
  const db = req.db;
  await db.prepare('DELETE FROM categories WHERE id = ?').run(req.params.id);
  res.json({ ok: true });
});

module.exports = router;
