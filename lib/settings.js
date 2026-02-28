async function getSettings(db) {
  const rows = await db.prepare('SELECT setting_key, setting_value FROM settings').all();
  const o = {};
  rows.forEach(r => { o[r.setting_key] = r.setting_value || ''; });
  return o;
}

async function setSetting(db, key, value) {
  const exists = await db.prepare('SELECT id FROM settings WHERE setting_key = ?').get(key);
  if (exists) {
    await db.prepare('UPDATE settings SET setting_value = ?, updated_at = CURRENT_TIMESTAMP WHERE setting_key = ?').run(value || '', key);
  } else {
    await db.prepare('INSERT INTO settings (setting_key, setting_value) VALUES (?, ?)').run(key, value || '');
  }
}

async function logActivity(db, adminId, adminName, action, details) {
  await db.prepare('INSERT INTO activity_log (admin_id, admin_name, action, details) VALUES (?, ?, ?, ?)').run(adminId || null, adminName || '', action, details || '');
}

async function getNextOrderNumber(db) {
  const settings = await getSettings(db);
  let next = parseInt(settings.next_order_number, 10);
  if (!Number.isFinite(next) || next < 1000) next = 1000;
  await setSetting(db, 'next_order_number', String(next + 1));
  return '#' + next;
}

module.exports = { getSettings, setSetting, logActivity, getNextOrderNumber };
