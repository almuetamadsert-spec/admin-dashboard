const express = require('express');
const crypto = require('crypto');
const { getSettings, setSetting, logActivity } = require('../lib/settings');

const router = express.Router();

const KEYS = [
  'api_key',
  'onesignal_app_id',
  'onesignal_rest_api_key',
  'google_client_id',
  'google_client_secret',
  'apple_service_id',
  'default_currency',
  'exchange_rate'
];

function generateApiKey() {
  return 'sk_' + crypto.randomBytes(32).toString('hex');
}

router.get('/', (req, res) => {
  const db = req.db;
  const settings = getSettings(db);
  KEYS.forEach(k => { if (!(k in settings)) settings[k] = ''; });
  if (!settings.api_key) {
    settings.api_key = generateApiKey();
    setSetting(db, 'api_key', settings.api_key);
  }
  res.render('settings/index', { settings, adminUsername: req.session.adminUsername });
});

router.post('/generate-api-key', (req, res) => {
  const db = req.db;
  const newKey = generateApiKey();
  setSetting(db, 'api_key', newKey);
  logActivity(db, req.session.adminId, req.session.adminUsername, 'توليد مفتاح API جديد', '');
  res.redirect('/admin/settings');
});

router.post('/', (req, res) => {
  const db = req.db;
  const body = req.body || {};
  KEYS.forEach(k => setSetting(db, k, body[k]));
  logActivity(db, req.session.adminId, req.session.adminUsername, 'تحديث الإعدادات', 'تم حفظ إعدادات اللوحة');
  res.redirect('/admin/settings');
});

module.exports = router;
