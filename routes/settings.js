const express = require('express');
const crypto = require('crypto');
const { getSettings, setSetting, logActivity } = require('../lib/settings');

const router = express.Router();

const KEYS = [
  'onesignal_app_id',
  'onesignal_rest_api_key',
  'google_client_id',
  'google_client_secret',
  'apple_service_id',
  'default_currency',
  'exchange_rate'
];

function generateConsumerKey() {
  return 'ck_' + crypto.randomBytes(24).toString('hex');
}
function generateConsumerSecret() {
  return 'cs_' + crypto.randomBytes(32).toString('hex');
}

router.get('/', (req, res) => {
  const db = req.db;
  const settings = getSettings(db);
  KEYS.forEach(k => { if (!(k in settings)) settings[k] = ''; });
  const apiKeys = db.prepare('SELECT id, name, consumer_key, consumer_secret, permission, is_active, created_at FROM api_keys ORDER BY created_at DESC').all();
  const newApiKey = req.session._newApiKey || null;
  const regeneratedSecret = req.session._regeneratedSecret || null;
  const regeneratedKeyId = req.session._regeneratedKeyId || null;
  if (req.session._newApiKey) delete req.session._newApiKey;
  if (req.session._regeneratedSecret) delete req.session._regeneratedSecret;
  if (req.session._regeneratedKeyId) delete req.session._regeneratedKeyId;
  res.render('settings/index', { settings, apiKeys, newApiKey, regeneratedSecret, regeneratedKeyId, adminUsername: req.session.adminUsername });
});

router.post('/api-keys', (req, res) => {
  const db = req.db;
  const { name, permission } = req.body || {};
  if (!name || !name.trim()) return res.redirect('/admin/settings');
  const consumer_key = generateConsumerKey();
  const consumer_secret = generateConsumerSecret();
  db.prepare('INSERT INTO api_keys (name, consumer_key, consumer_secret, permission) VALUES (?, ?, ?, ?)').run(name.trim(), consumer_key, consumer_secret, permission === 'read_write' ? 'read_write' : 'read_only');
  logActivity(db, req.session.adminId, req.session.adminUsername, 'إنشاء مفتاح API', name.trim() + ' — ' + permission);
  req.session._newApiKey = { consumer_key, consumer_secret };
  res.redirect('/admin/settings#api-keys');
});

router.post('/api-keys/edit/:id', (req, res) => {
  const db = req.db;
  const { name, permission } = req.body || {};
  const id = req.params.id;
  db.prepare('UPDATE api_keys SET name = ?, permission = ? WHERE id = ?').run(name || '', permission === 'read_write' ? 'read_write' : 'read_only', id);
  logActivity(db, req.session.adminId, req.session.adminUsername, 'تعديل مفتاح API', name);
  res.redirect('/admin/settings#api-keys');
});

router.post('/api-keys/regenerate-secret/:id', (req, res) => {
  const db = req.db;
  const id = req.params.id;
  const newSecret = generateConsumerSecret();
  db.prepare('UPDATE api_keys SET consumer_secret = ? WHERE id = ?').run(newSecret, id);
  const row = db.prepare('SELECT name FROM api_keys WHERE id = ?').get(id);
  logActivity(db, req.session.adminId, req.session.adminUsername, 'تجديد Consumer Secret', row ? row.name : '');
  req.session._regeneratedSecret = newSecret;
  req.session._regeneratedKeyId = id;
  res.redirect('/admin/settings#api-keys');
});

router.post('/api-keys/delete/:id', (req, res) => {
  const db = req.db;
  const id = req.params.id;
  const row = db.prepare('SELECT name FROM api_keys WHERE id = ?').get(id);
  db.prepare('DELETE FROM api_keys WHERE id = ?').run(id);
  if (row) logActivity(db, req.session.adminId, req.session.adminUsername, 'حذف مفتاح API', row.name);
  res.redirect('/admin/settings#api-keys');
});

router.post('/', (req, res) => {
  const db = req.db;
  const body = req.body || {};
  KEYS.forEach(k => setSetting(db, k, body[k]));
  logActivity(db, req.session.adminId, req.session.adminUsername, 'تحديث الإعدادات', 'تم حفظ إعدادات اللوحة');
  res.redirect('/admin/settings');
});

module.exports = router;
