const initSqlJs = require('sql.js');
const path = require('path');
const fs = require('fs');

const dataDir = path.join(__dirname, '..', 'data');
if (!fs.existsSync(dataDir)) fs.mkdirSync(dataDir, { recursive: true });
const dbPath = path.join(dataDir, 'shop.db');

// تحويل ? إلى $1, $2 ... لاستخدام مع sql.js
function toNamedParams(sql) {
  let i = 0;
  return sql.replace(/\?/g, () => '$' + (++i));
}

async function initDb() {
  // مسار ملف wasm يعمل محلياً وعلى السيرفر
  let wasmDir = path.join(__dirname, '..', 'node_modules', 'sql.js', 'dist');
  try {
    const pkgDir = path.dirname(require.resolve('sql.js'));
    if (fs.existsSync(path.join(pkgDir, 'dist', 'sql-wasm.wasm'))) wasmDir = path.join(pkgDir, 'dist');
  } catch (e) { /* استخدم wasmDir الافتراضي */ }
  const SQL = await initSqlJs({
    locateFile: (file) => path.join(wasmDir, file)
  });
  let db;
  if (fs.existsSync(dbPath)) {
    const buf = fs.readFileSync(dbPath);
    db = new SQL.Database(new Uint8Array(buf));
  } else {
    db = new SQL.Database();
  }

  function save() {
    try {
      const data = db.export();
      fs.writeFileSync(dbPath, Buffer.from(data));
    } catch (e) { /* ignore */ }
  }

  db.exec(`
    CREATE TABLE IF NOT EXISTS admins (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT UNIQUE NOT NULL,
      password TEXT NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
    CREATE TABLE IF NOT EXISTS categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name_ar TEXT NOT NULL,
      name_en TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
    CREATE TABLE IF NOT EXISTS products (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name_ar TEXT NOT NULL,
      name_en TEXT,
      short_description TEXT,
      long_description TEXT,
      price REAL NOT NULL DEFAULT 0,
      discount_percent REAL DEFAULT 0,
      company TEXT,
      category_id INTEGER,
      image_path TEXT,
      image_paths TEXT,
      stock INTEGER DEFAULT 0,
      is_active INTEGER DEFAULT 1,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (category_id) REFERENCES categories(id)
    );
    CREATE TABLE IF NOT EXISTS customers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      phone TEXT,
      email TEXT,
      address TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
    CREATE TABLE IF NOT EXISTS orders (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      order_number TEXT UNIQUE,
      customer_id INTEGER,
      customer_name TEXT,
      customer_phone TEXT,
      customer_email TEXT,
      customer_address TEXT,
      status TEXT DEFAULT 'pending',
      total_amount REAL DEFAULT 0,
      notes TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (customer_id) REFERENCES customers(id)
    );
    CREATE TABLE IF NOT EXISTS order_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      order_id INTEGER NOT NULL,
      product_id INTEGER,
      product_name TEXT,
      quantity INTEGER NOT NULL DEFAULT 1,
      unit_price REAL NOT NULL,
      total_price REAL NOT NULL,
      FOREIGN KEY (order_id) REFERENCES orders(id),
      FOREIGN KEY (product_id) REFERENCES products(id)
    );
    CREATE INDEX IF NOT EXISTS idx_orders_created ON orders(created_at);
    CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
    CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id);
  `);
  save();

  const res = db.exec("SELECT id FROM admins LIMIT 1");
  if (!res.length || !res[0].values.length) {
    const bcrypt = require('bcryptjs');
    const hash = bcrypt.hashSync('admin123', 10);
    const sql = "INSERT INTO admins (username, password) VALUES ($1, $2)";
    const stmt = db.prepare(sql);
    stmt.bind([ 'admin', hash ]);
    stmt.step();
    stmt.free();
    save();
    console.log('تم إنشاء حساب الأدمن: admin / admin123');
  }

  const wrapper = {
    exec(sql) {
      db.exec(sql);
      save();
    },
    prepare(sql) {
      const named = toNamedParams(sql);
      return {
        get(...params) {
          const stmt = db.prepare(named);
          stmt.bind(params);
          const out = stmt.step() ? stmt.getAsObject() : undefined;
          stmt.free();
          return out;
        },
        all(...params) {
          const stmt = db.prepare(named);
          stmt.bind(params);
          const rows = [];
          while (stmt.step()) rows.push(stmt.getAsObject());
          stmt.free();
          return rows;
        },
        run(...params) {
          const stmt = db.prepare(named);
          stmt.bind(params);
          stmt.step();
          stmt.free();
          const r = db.exec("SELECT last_insert_rowid() AS id");
          const lastInsertRowid = r.length && r[0].values.length ? r[0].values[0][0] : 0;
          save();
          return { lastInsertRowid };
        }
      };
    }
  };

  return wrapper;
}

module.exports = initDb();
