/**
 * اتصال MariaDB — واجهة متوافقة مع استدعاءات db.prepare().get/all/run
 * يُفعّل عند وجود MARIADB_HOST أو DATABASE_URL في البيئة.
 */
const mysql = require('mysql2/promise');

function rowToLower(obj) {
  if (obj == null || typeof obj !== 'object') return obj;
  const out = {};
  for (const k of Object.keys(obj)) out[k.toLowerCase()] = obj[k];
  return out;
}

async function init() {
  const host = process.env.MARIADB_HOST || process.env.MYSQL_HOST || 'localhost';
  const user = process.env.MARIADB_USER || process.env.MYSQL_USER || 'root';
  const password = process.env.MARIADB_PASSWORD || process.env.MYSQL_PASSWORD || '';
  const database = process.env.MARIADB_DATABASE || process.env.MYSQL_DATABASE || 'shop';
  const port = parseInt(process.env.MARIADB_PORT || process.env.MYSQL_PORT || '3306', 10);

  const pool = mysql.createPool({
    host,
    port,
    user,
    password,
    database,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0,
    timezone: '+00:00',
    ssl: process.env.MARIADB_SSL === 'true' ? { rejectUnauthorized: true } : undefined,
  });

  const wrapper = {
    driver: 'mariadb',
    _pool: pool,
    exec(sql) {
      return pool.execute(sql).then(() => { });
    },
    prepare(sql) {
      return {
        async get(...params) {
          const [rows] = await pool.execute(sql, params);
          const row = Array.isArray(rows) && rows.length ? rows[0] : undefined;
          return row ? rowToLower(row) : undefined;
        },
        async all(...params) {
          const [rows] = await pool.execute(sql, params);
          return (Array.isArray(rows) ? rows : []).map(rowToLower);
        },
        async run(...params) {
          const [result] = await pool.execute(sql, params);
          const lastInsertRowid = result && result.insertId != null ? result.insertId : 0;
          return { lastInsertRowid };
        },
      };
    },
  };

  // التحقق من الاتصال
  const conn = await pool.getConnection();
  conn.release();

  console.log('اتصال MariaDB جاهز:', database);
  return wrapper;
}

module.exports = { init };
