const express = require('express');
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

router.get('/', (req, res) => {
  const db = req.db;
  const settings = getSettings(db);
  KEYS.forEach(k => { if (!(k in settings)) settings[k] = ''; });
  res.render('settings/index', { settings, adminUsername: req.session.adminUsername });
});

router.post('/', (req, res) => {
  const db = req.db;
  const body = req.body || {};
  KEYS.forEach(k => setSetting(db, k, body[k]));
  logActivity(db, req.session.adminId, req.session.adminUsername, 'تحديث الإعدادات', 'تم حفظ إعدادات اللوحة');
  res.redirect('/admin/settings');
});

module.exports = router;
