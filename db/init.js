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
      low_stock_alert INTEGER DEFAULT 0,
      hide_when_out_of_stock INTEGER DEFAULT 0,
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
      city_id INTEGER,
      merchant_id INTEGER,
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
    CREATE INDEX IF NOT EXISTS idx_orders_city ON orders(city_id);
    CREATE INDEX IF NOT EXISTS idx_orders_merchant ON orders(merchant_id);
    CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id);
  `);

  try {
    const ti = db.exec("PRAGMA table_info(orders)");
    const names = (ti[0] && ti[0].values) ? ti[0].values.map((row) => row[1]) : [];
    if (names.indexOf('merchant_contacted_at') === -1) {
      db.exec('ALTER TABLE orders ADD COLUMN merchant_contacted_at DATETIME');
      save();
    }
  } catch (e) { /* عمود موجود مسبقاً أو خطأ غير متوقع */ }

  db.exec(`
    CREATE TABLE IF NOT EXISTS settings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      setting_key TEXT UNIQUE NOT NULL,
      setting_value TEXT,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
    CREATE TABLE IF NOT EXISTS cities (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      delivery_fee REAL NOT NULL DEFAULT 0,
      is_active INTEGER DEFAULT 1,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
    CREATE TABLE IF NOT EXISTS activity_log (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      admin_id INTEGER,
      admin_name TEXT,
      action TEXT NOT NULL,
      details TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (admin_id) REFERENCES admins(id)
    );
    CREATE TABLE IF NOT EXISTS cms_pages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      slug TEXT UNIQUE NOT NULL,
      title_ar TEXT NOT NULL,
      title_en TEXT,
      content_ar TEXT,
      content_en TEXT,
      is_active INTEGER DEFAULT 1,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
    CREATE TABLE IF NOT EXISTS home_sections (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title_ar TEXT NOT NULL,
      title_en TEXT,
      section_type TEXT NOT NULL, -- 'slider', 'list', 'grid', 'categories'
      content_source TEXT NOT NULL, -- 'latest', 'sale', 'best_sellers', 'category', 'manual'
      category_id INTEGER,
      items_limit INTEGER DEFAULT 10,
      sort_order INTEGER DEFAULT 0,
      is_active INTEGER DEFAULT 1,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (category_id) REFERENCES categories(id)
    );
    CREATE TABLE IF NOT EXISTS home_section_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      section_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      sort_order INTEGER DEFAULT 0,
      FOREIGN KEY (section_id) REFERENCES home_sections(id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
    );
    CREATE TABLE IF NOT EXISTS coupons(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT UNIQUE NOT NULL,
            discount_type TEXT NOT NULL DEFAULT 'percent',
            discount_value REAL NOT NULL DEFAULT 0,
            min_order REAL DEFAULT 0,
            max_uses INTEGER DEFAULT 0,
            used_count INTEGER DEFAULT 0,
            expires_at DATETIME,
            is_active INTEGER DEFAULT 1,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
          );
    CREATE TABLE IF NOT EXISTS merchants(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            city_id INTEGER,
            phone TEXT,
            email TEXT,
            is_active INTEGER DEFAULT 1,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(city_id) REFERENCES cities(id)
          );
    CREATE TABLE IF NOT EXISTS api_keys(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            consumer_key TEXT UNIQUE NOT NULL,
            consumer_secret TEXT NOT NULL,
            permission TEXT NOT NULL DEFAULT 'read_only',
            is_active INTEGER DEFAULT 1,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
          );
    CREATE TABLE IF NOT EXISTS app_users(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT UNIQUE NOT NULL,
            password_hash TEXT,
            role TEXT NOT NULL DEFAULT 'customer',
            merchant_id INTEGER,
            google_id TEXT,
            apple_id TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(merchant_id) REFERENCES merchants(id)
          );
    CREATE TABLE IF NOT EXISTS app_sessions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            token TEXT UNIQUE NOT NULL,
            expires_at DATETIME NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(user_id) REFERENCES app_users(id)
          );
    CREATE TABLE IF NOT EXISTS store_slides(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            image_path TEXT NOT NULL,
            corner_style TEXT NOT NULL DEFAULT 'rounded',
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
          );
  `);

  try {
    const info = db.exec("PRAGMA table_info(orders)");
    const cols = info[0] && info[0].values ? info[0].values.map(r => r[1]) : [];
    if (!cols.includes('city_id')) db.run("ALTER TABLE orders ADD COLUMN city_id INTEGER");
    if (!cols.includes('merchant_id')) db.run("ALTER TABLE orders ADD COLUMN merchant_id INTEGER");
    if (!cols.includes('customer_phone_alt')) db.run("ALTER TABLE orders ADD COLUMN customer_phone_alt TEXT");
  } catch (e) { /* ignore */ }

  try {
    const minfo = db.exec("PRAGMA table_info(merchants)");
    const mcols = minfo[0] && minfo[0].values ? minfo[0].values.map(r => r[1]) : [];
    if (!mcols.includes('onesignal_player_id')) db.run("ALTER TABLE merchants ADD COLUMN onesignal_player_id TEXT");
    if (!mcols.includes('store_name')) db.run("ALTER TABLE merchants ADD COLUMN store_name TEXT");
    if (!mcols.includes('card_color')) db.run("ALTER TABLE merchants ADD COLUMN card_color TEXT");
    if (!mcols.includes('order_limit')) db.run("ALTER TABLE merchants ADD COLUMN order_limit INTEGER DEFAULT 20");
    if (!mcols.includes('commission_rate_tiers')) db.run("ALTER TABLE merchants ADD COLUMN commission_rate_tiers TEXT");
    if (!mcols.includes('fixed_commission_tiers')) db.run("ALTER TABLE merchants ADD COLUMN fixed_commission_tiers TEXT");
  } catch (e) { /* ignore */ }

  try {
    const pinfo = db.exec("PRAGMA table_info(products)");
    const pcols = pinfo[0] && pinfo[0].values ? pinfo[0].values.map(r => r[1]) : [];
    if (!pcols.includes('hide_when_out_of_stock')) db.run("ALTER TABLE products ADD COLUMN hide_when_out_of_stock INTEGER DEFAULT 0");
    if (!pcols.includes('low_stock_alert')) db.run("ALTER TABLE products ADD COLUMN low_stock_alert INTEGER DEFAULT 0");
    if (!pcols.includes('colors')) db.run("ALTER TABLE products ADD COLUMN colors TEXT");
    if (!pcols.includes('sizes')) db.run("ALTER TABLE products ADD COLUMN sizes TEXT");
    if (!pcols.includes('storage_capacities')) db.run("ALTER TABLE products ADD COLUMN storage_capacities TEXT");
    if (!pcols.includes('battery_capacities')) db.run("ALTER TABLE products ADD COLUMN battery_capacities TEXT");
    if (!pcols.includes('short_description')) db.run("ALTER TABLE products ADD COLUMN short_description TEXT");
    if (!pcols.includes('long_description')) db.run("ALTER TABLE products ADD COLUMN long_description TEXT");
    save();
  } catch (e) { /* ignore */ }

  try {
    const cinfo = db.exec("PRAGMA table_info(categories)");
    const ccols = cinfo[0] && cinfo[0].values ? cinfo[0].values.map(r => r[1]) : [];
    if (!ccols.includes('icon_type')) db.run("ALTER TABLE categories ADD COLUMN icon_type TEXT DEFAULT 'circle'");
    if (!ccols.includes('icon_name')) db.run("ALTER TABLE categories ADD COLUMN icon_name TEXT");
    if (!ccols.includes('icon_color')) db.run("ALTER TABLE categories ADD COLUMN icon_color TEXT DEFAULT '#06A3E7'");
    if (!ccols.includes('icon_symbol_color')) db.run("ALTER TABLE categories ADD COLUMN icon_symbol_color TEXT");
    if (!ccols.includes('icon_opacity')) db.run("ALTER TABLE categories ADD COLUMN icon_opacity INTEGER DEFAULT 100");
    if (!ccols.includes('icon_path')) db.run("ALTER TABLE categories ADD COLUMN icon_path TEXT");
    if (!ccols.includes('sort_order')) db.run("ALTER TABLE categories ADD COLUMN sort_order INTEGER DEFAULT 0");
  } catch (e) { /* ignore */ }

  try {
    db.run(`
      CREATE TABLE IF NOT EXISTS brand_categories(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name_ar TEXT NOT NULL,
    icon_path TEXT,
    icon_size TEXT DEFAULT 'medium',
    icon_corner TEXT DEFAULT 'rounded',
    icon_shape TEXT DEFAULT 'square',
    icon_color TEXT DEFAULT '#06A3E7',
    sort_order INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )
    `);
  } catch (e) { /* ignore */ }
  try {
    db.run(`
      CREATE TABLE IF NOT EXISTS merchant_stock(
      merchant_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      quantity INTEGER NOT NULL DEFAULT 0,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY(merchant_id, product_id),
      FOREIGN KEY(merchant_id) REFERENCES merchants(id),
      FOREIGN KEY(product_id) REFERENCES products(id)
    )
    `);
  } catch (e) { /* ignore */ }
  save();

  const res = db.exec("SELECT id FROM admins LIMIT 1");
  if (!res.length || !res[0].values.length) {
    const bcrypt = require('bcryptjs');
    const hash = bcrypt.hashSync('admin123', 10);
    const sql = "INSERT INTO admins (username, password) VALUES ($1, $2)";
    const stmt = db.prepare(sql);
    stmt.bind(['admin', hash]);
    stmt.step();
    stmt.free();
    save();
    console.log('تم إنشاء حساب الأدمن: admin / admin123');
  }

  const bcrypt = require('bcryptjs');
  const appUsersCheck = db.exec("SELECT id FROM app_users LIMIT 1");
  if (!appUsersCheck.length || !appUsersCheck[0].values.length) {
    const passHash = bcrypt.hashSync('123456', 10);
    const ins = db.prepare("INSERT INTO app_users (email, password_hash, role, merchant_id) VALUES (?, ?, 'customer', NULL)");
    ins.bind(['customer@test.com', passHash]);
    ins.step();
    ins.free();
    const firstMerchant = db.prepare("SELECT id FROM merchants LIMIT 1");
    let merchantId = null;
    if (firstMerchant.step()) {
      const row = firstMerchant.getAsObject();
      merchantId = row.id;
    }
    firstMerchant.free();
    const ins2 = db.prepare("INSERT INTO app_users (email, password_hash, role, merchant_id) VALUES (?, ?, 'merchant', ?)");
    ins2.bind(['merchant@test.com', passHash, merchantId]);
    ins2.step();
    ins2.free();
    save();
    console.log('تم إنشاء مستخدمي التطبيق: customer@test.com و merchant@test.com / 123456');
  }

  function rowToLower(obj) {
    if (obj == null || typeof obj !== 'object') return obj;
    const out = {};
    for (const k of Object.keys(obj)) out[k.toLowerCase()] = obj[k];
    return out;
  }

  const wrapper = {
    driver: 'sqlite',
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
          return Promise.resolve(out ? rowToLower(out) : out);
        },
        all(...params) {
          const stmt = db.prepare(named);
          stmt.bind(params);
          const rows = [];
          while (stmt.step()) rows.push(rowToLower(stmt.getAsObject()));
          stmt.free();
          return Promise.resolve(rows);
        },
        run(...params) {
          const stmt = db.prepare(named);
          stmt.bind(params);
          stmt.step();
          stmt.free();
          const r = db.exec("SELECT last_insert_rowid() AS id");
          const lastInsertRowid = r.length && r[0].values.length ? r[0].values[0][0] : 0;
          save();
          return Promise.resolve({ lastInsertRowid });
        }
      };
    }
  };

  return wrapper;
}

module.exports = initDb();
