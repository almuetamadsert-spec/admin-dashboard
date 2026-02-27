/**
 * تحميل قاعدة البيانات: MariaDB عند وجود متغيرات الاتصال، وإلا SQLite.
 */
function loadDb() {
  const useMariaDB = !!(
    process.env.MARIADB_HOST ||
    process.env.MYSQL_HOST ||
    (process.env.DATABASE_URL && process.env.DATABASE_URL.startsWith('mysql'))
  );
  if (useMariaDB) {
    return require('./mariadb').init();
  }
  return require('./init');
}

module.exports = loadDb();
