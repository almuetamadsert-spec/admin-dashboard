const express = require('express');
const multer = require('multer');
const { logActivity } = require('../lib/settings');
const { DEFAULT_RATE_TIERS, DEFAULT_FIXED_TIERS } = require('../lib/commission');

function parseTiersFromMerchant(merchant, key) {
  if (!merchant || !merchant[key]) return null;
  try {
    const val = typeof merchant[key] === 'string' ? merchant[key] : JSON.stringify(merchant[key]);
    const arr = JSON.parse(val);
    return Array.isArray(arr) ? arr : null;
  } catch (e) {
    return null;
  }
}

const router = express.Router();
const uploadCsv = multer({ storage: multer.memoryStorage(), limits: { fileSize: 2 * 1024 * 1024 } }).single('csv_file');

/** ألوان البطاقات (نفس نظام المعتمد — لون يمين البطاقة في لوحة المتاجر) */
const CARD_COLORS = [
  { value: '', label: 'افتراضي (أخضر هادئ)' },
  { value: '#7b9eb5', label: 'أزرق هادئ' },
  { value: '#6b9b8a', label: 'تركواز هادئ' },
  { value: '#7d9a7d', label: 'أخضر هادئ' },
  { value: '#c4a35c', label: 'ذهبي باهت' },
  { value: '#c98a7a', label: 'مرجاني هادئ' },
  { value: '#5a6570', label: 'رمادي داكن' },
  { value: '#8a9199', label: 'رمادي فاتح' },
  { value: '#9a8ab5', label: 'بنفسجي هادئ' },
  { value: '#9a8575', label: 'بني باهت' },
  { value: '#a67b7b', label: 'وردي داكن هادئ' },
  { value: '#6b8a9e', label: 'أزرق رمادي' },
  { value: '#8b9a6b', label: 'زيتوني باهت' },
  { value: '#a89b7a', label: 'رملي' },
  { value: '#7a8a9b', label: 'أزرق فضي' },
  { value: '#b59a8a', label: 'بيج وردي' },
  { value: '#6b7a8a', label: 'أزرق فولاذي' },
  { value: '#9a9a7a', label: 'طحلب هادئ' },
  { value: '#6b9a9a', label: 'سماوي باهت' },
  { value: '#c9b59a', label: 'كريمي' },
  { value: '#8a7a9b', label: 'خزامى باهت' },
];

/** قائمة التجار مع بحث وفلترة */
router.get('/stats', (req, res) => res.redirect('/admin/merchant-stats'));

router.get('/', async (req, res) => {
  const db = req.db;
  const q = (req.query.q || '').trim();
  const cityFilter = req.query.city_id || '';
  const statusFilter = req.query.status || '';

  let where = '1=1';
  const params = [];
  if (q) {
    const like = '%' + q + '%';
    where += ' AND (m.name LIKE ? OR m.store_name LIKE ? OR m.email LIKE ? OR m.phone LIKE ?)';
    params.push(like, like, like, like);
  }
  if (cityFilter) {
    where += ' AND m.city_id = ?';
    params.push(cityFilter);
  }
  if (statusFilter === 'active') { where += ' AND m.is_active = 1'; }
  else if (statusFilter === 'inactive') { where += ' AND m.is_active = 0'; }

  const [merchants, cities] = await Promise.all([
    db.prepare(`
      SELECT m.*, c.name as city_name FROM merchants m
      LEFT JOIN cities c ON m.city_id = c.id
      WHERE ${where}
      ORDER BY m.name
    `).all(...params),
    db.prepare('SELECT * FROM cities WHERE is_active = 1 ORDER BY name').all()
  ]);
  res.render('merchants/list', { merchants, cities, cardColors: CARD_COLORS, query: req.query || {}, adminUsername: req.session.adminUsername });
});

/** صفحة إضافة تاجر جديد */
router.get('/new', async (req, res) => {
  const db = req.db;
  const cities = await db.prepare('SELECT * FROM cities WHERE is_active = 1 ORDER BY name').all();
  const rateTiers = DEFAULT_RATE_TIERS;
  const fixedTiers = DEFAULT_FIXED_TIERS;
  res.render('merchants/form', { merchant: null, cities, cardColors: CARD_COLORS, rateTiers, fixedTiers, adminUsername: req.session.adminUsername, isEdit: false });
});

/** تصدير قائمة التجار CSV — يجب أن يكون قبل /edit/:id */
router.get('/export', async (req, res) => {
  const db = req.db;
  const rows = await db.prepare(`
    SELECT m.email, c.name as city_name, m.store_name, m.name as owner_name, m.phone, m.card_color, m.order_limit, m.is_active
    FROM merchants m
    LEFT JOIN cities c ON m.city_id = c.id
    ORDER BY m.name
  `).all();
  const filename = 'merchants-' + new Date().toISOString().slice(0, 10) + '.csv';
  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  res.setHeader('Content-Disposition', 'attachment; filename="' + filename + '"');
  res.write('\uFEFF');
  const header = ['البريد', 'المدينة', 'اسم المتجر', 'اسم المالك', 'الهاتف', 'لون البطاقة', 'حد الطلبات', 'الحالة'];
  res.write(header.map(h => '"' + h + '"').join(',') + '\n');
  for (const r of rows) {
    const status = r.is_active ? 'active' : 'frozen';
    const row = [r.email || '', r.city_name || '', r.store_name || '', r.owner_name || r.name || '', r.phone || '', r.card_color || '', r.order_limit != null ? r.order_limit : 20, status];
    res.write(row.map(c => '"' + String(c).replace(/"/g, '""') + '"').join(',') + '\n');
  }
  res.end();
});

/** صفحة تعديل تاجر */
router.get('/edit/:id', async (req, res) => {
  const db = req.db;
  const merchant = await db.prepare('SELECT * FROM merchants WHERE id = ?').get(req.params.id);
  if (!merchant) return res.redirect('/admin/merchants');
  const cities = await db.prepare('SELECT * FROM cities WHERE is_active = 1 ORDER BY name').all();
  const rateTiers = parseTiersFromMerchant(merchant, 'commission_rate_tiers') || DEFAULT_RATE_TIERS;
  const fixedTiers = parseTiersFromMerchant(merchant, 'fixed_commission_tiers') || DEFAULT_FIXED_TIERS;
  res.render('merchants/form', { merchant, cities, cardColors: CARD_COLORS, rateTiers, fixedTiers, adminUsername: req.session.adminUsername, isEdit: true });
});

/** بناء شرائح النسبة والعمولة من مصفوفات النموذج (نفس منطق PHP) */
function buildTiersFromBody(body) {
  const toArr = (v) => (Array.isArray(v) ? v : (v !== undefined && v !== '' ? [v] : []));
  const rateFrom = toArr(body.rate_from);
  const rateTo = toArr(body.rate_to);
  const ratePct = toArr(body.rate_pct);
  const fixedFrom = toArr(body.fixed_from);
  const fixedTo = toArr(body.fixed_to);
  const fixedVal = toArr(body.fixed_val);
  const rateTiers = [];
  const rateCount = Math.max(rateFrom.length, rateTo.length, ratePct.length);
  for (let i = 0; i < rateCount; i++) {
    const from = parseFloat(rateFrom[i]) || 0;
    const to = parseFloat(rateTo[i]) || 0;
    const rate = parseFloat(ratePct[i]) || 0;
    if (rate > 0 || from > 0 || to > 0) rateTiers.push({ from, to, rate });
  }
  const fixedTiers = [];
  const fixedCount = Math.max(fixedFrom.length, fixedTo.length, fixedVal.length);
  for (let i = 0; i < fixedCount; i++) {
    const from = parseFloat(fixedFrom[i]) || 0;
    const to = parseFloat(fixedTo[i]) || 0;
    const fix = parseFloat(fixedVal[i]) || 0;
    if (fix > 0 || from > 0 || to > 0) fixedTiers.push({ from, to, fixed: fix });
  }
  return {
    rateTiers: rateTiers.length ? rateTiers : DEFAULT_RATE_TIERS,
    fixedTiers: fixedTiers.length ? fixedTiers : DEFAULT_FIXED_TIERS,
  };
}

router.post('/', async (req, res) => {
  const db = req.db;
  const body = req.body || {};
  const { name, store_name, city_id, phone, email, is_active, card_color, order_limit } = body;
  if (!name) return res.redirect('/admin/merchants/new');
  const limit = Math.max(0, parseInt(order_limit, 10) || 20);
  const cardVal = card_color && CARD_COLORS.some(c => c.value === card_color) ? card_color : '';
  const { rateTiers, fixedTiers } = buildTiersFromBody(body);
  await db.prepare('INSERT INTO merchants (name, store_name, city_id, phone, email, card_color, order_limit, commission_rate_tiers, fixed_commission_tiers, is_active) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)').run(
    name.trim(), (store_name || '').trim() || null, city_id || null, phone || '', email || '', cardVal, limit, JSON.stringify(rateTiers), JSON.stringify(fixedTiers), is_active !== '0' ? 1 : 0
  );
  await logActivity(db, req.session.adminId, req.session.adminUsername, 'إضافة تاجر', name.trim());
  res.redirect('/admin/merchants');
});

router.post('/edit/:id', async (req, res) => {
  const db = req.db;
  const body = req.body || {};
  const { name, store_name, city_id, phone, email, is_active, card_color, order_limit } = body;
  const limit = Math.max(0, parseInt(order_limit, 10) || 20);
  const cardVal = card_color && CARD_COLORS.some(c => c.value === card_color) ? card_color : '';
  const { rateTiers, fixedTiers } = buildTiersFromBody(body);
  await db.prepare('UPDATE merchants SET name = ?, store_name = ?, city_id = ?, phone = ?, email = ?, card_color = ?, order_limit = ?, commission_rate_tiers = ?, fixed_commission_tiers = ?, is_active = ? WHERE id = ?').run(
    name || '', (store_name || '').trim() || null, city_id || null, phone || '', email || '', cardVal, limit, JSON.stringify(rateTiers), JSON.stringify(fixedTiers), is_active !== '0' ? 1 : 0, req.params.id
  );
  await logActivity(db, req.session.adminId, req.session.adminUsername, 'تعديل تاجر', name);
  res.redirect('/admin/merchants');
});

router.post('/delete/:id', async (req, res) => {
  const db = req.db;
  const id = req.params.id;
  const m = await db.prepare('SELECT name FROM merchants WHERE id = ?').get(id);
  await db.prepare('DELETE FROM merchants WHERE id = ?').run(id);
  if (m) await logActivity(db, req.session.adminId, req.session.adminUsername, 'حذف تاجر', m.name);
  res.redirect('/admin/merchants');
});

/** استيراد تجار من CSV */
router.post('/import', uploadCsv, async (req, res) => {
  const db = req.db;
  if (!req.file || !req.file.buffer) {
    return res.redirect('/admin/merchants?import=no_file');
  }
  const cities = await db.prepare('SELECT id, name FROM cities').all();
  const cityByName = {};
  cities.forEach(c => { cityByName[(c.name || '').trim()] = c.id; });
  const allowedColors = CARD_COLORS.map(c => c.value).filter(Boolean);
  const buf = req.file.buffer.toString('utf8').replace(/\r\n/g, '\n').replace(/\r/g, '\n');
  const lines = buf.split('\n').filter(l => l.trim());
  let imported = 0;
  let skipped = 0;
  const rateTiersDefault = JSON.stringify(DEFAULT_RATE_TIERS);
  const fixedTiersDefault = JSON.stringify(DEFAULT_FIXED_TIERS);
  for (let i = 0; i < lines.length && imported + skipped < 5000; i++) {
    const line = lines[i];
    const row = [];
    let inQuotes = false;
    let cur = '';
    for (let j = 0; j < line.length; j++) {
      const ch = line[j];
      if (ch === '"') { inQuotes = !inQuotes; continue; }
      if (!inQuotes && ch === ',') { row.push(cur.trim()); cur = ''; continue; }
      cur += ch;
    }
    row.push(cur.trim());
    const raw0 = (row[0] || '').replace(/^\uFEFF/, '').trim();
    if (i === 0 && (raw0.includes('البريد') || raw0.toLowerCase().includes('email'))) continue;
    const email = raw0;
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) { skipped++; continue; }
    const cityName = (row[1] || '').trim();
    const cityId = cityByName[cityName] || null;
    const storeName = (row[2] || '').trim() || null;
    const ownerName = (row[3] || '').trim() || '';
    const phone = (row[4] || '').trim() || '';
    let cardColor = (row[5] || '').trim();
    if (cardColor && !allowedColors.includes(cardColor)) cardColor = '';
    const orderLimit = Math.max(0, parseInt(row[6], 10) || 20);
    const status = (row[7] || '').trim().toLowerCase();
    const isActive = (status === 'frozen' || status === 'معطل') ? 0 : 1;
    const existing = await db.prepare('SELECT id FROM merchants WHERE email = ?').get(email);
    if (existing) {
      await db.prepare('UPDATE merchants SET name = ?, store_name = ?, city_id = ?, phone = ?, card_color = ?, order_limit = ?, is_active = ? WHERE id = ?').run(
        ownerName, storeName, cityId, phone, cardColor || null, orderLimit, isActive, existing.id
      );
    } else {
      await db.prepare('INSERT INTO merchants (name, store_name, city_id, phone, email, card_color, order_limit, commission_rate_tiers, fixed_commission_tiers, is_active) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)').run(
        ownerName, storeName, cityId, phone, email, cardColor || null, orderLimit, rateTiersDefault, fixedTiersDefault, isActive
      );
    }
    imported++;
  }
  await logActivity(db, req.session.adminId, req.session.adminUsername, 'استيراد تجار', 'تم استيراد ' + imported + ' تاجر');
  res.redirect('/admin/merchants?import=ok&count=' + imported + '&skipped=' + skipped);
});

module.exports = router;
