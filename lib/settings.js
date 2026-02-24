function getSettings(db) {
  const rows = db.prepare('SELECT setting_key, setting_value FROM settings').all();
  const o = {};
  rows.forEach(r => { o[r.setting_key] = r.setting_value || ''; });
  return o;
}

function setSetting(db, key, value) {
  const exists = db.prepare('SELECT id FROM settings WHERE setting_key = ?').get(key);
  if (exists) {
    db.prepare('UPDATE settings SET setting_value = ?, updated_at = CURRENT_TIMESTAMP WHERE setting_key = ?').run(value || '', key);
  } else {
    db.prepare('INSERT INTO settings (setting_key, setting_value) VALUES (?, ?)').run(key, value || '');
  }
}

function logActivity(db, adminId, adminName, action, details) {
  db.prepare('INSERT INTO activity_log (admin_id, admin_name, action, details) VALUES (?, ?, ?, ?)').run(adminId || null, adminName || '', action, details || '');
}

module.exports = { getSettings, setSetting, logActivity };
