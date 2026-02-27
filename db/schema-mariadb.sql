-- هيكل قاعدة البيانات لـ MariaDB/MySQL — مطابق لمشروع المعتمد
-- التشغيل: من لوحة MariaDB أو: mysql -u user -p shop < db/schema-mariadb.sql
-- أو إنشاء قاعدة أولاً: CREATE DATABASE IF NOT EXISTS shop CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- الأدمن
CREATE TABLE IF NOT EXISTS admins (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(255) UNIQUE NOT NULL,
  password VARCHAR(255) NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- التصنيفات
CREATE TABLE IF NOT EXISTS categories (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name_ar VARCHAR(500) NOT NULL,
  name_en VARCHAR(500),
  icon_type VARCHAR(50) DEFAULT 'circle',
  icon_name VARCHAR(100),
  icon_color VARCHAR(50) DEFAULT '#06A3E7',
  icon_symbol_color VARCHAR(50),
  icon_opacity INT DEFAULT 100,
  icon_path VARCHAR(500),
  sort_order INT DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- المدن
CREATE TABLE IF NOT EXISTS cities (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  delivery_fee DOUBLE NOT NULL DEFAULT 0,
  is_active INT DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- المنتجات
CREATE TABLE IF NOT EXISTS products (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name_ar VARCHAR(500) NOT NULL,
  name_en VARCHAR(500),
  short_description TEXT,
  long_description TEXT,
  price DOUBLE NOT NULL DEFAULT 0,
  discount_percent DOUBLE DEFAULT 0,
  company VARCHAR(255),
  category_id INT,
  image_path VARCHAR(500),
  image_paths TEXT,
  stock INT DEFAULT 0,
  is_active INT DEFAULT 1,
  low_stock_alert INT DEFAULT 0,
  hide_when_out_of_stock INT DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (category_id) REFERENCES categories(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- العملاء
CREATE TABLE IF NOT EXISTS customers (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  phone VARCHAR(100),
  email VARCHAR(255),
  address TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- التجار (مع city_id للتوجيه الجغرافي — منطق نظام المعتمد: لون البطاقة، حد الطلبات)
CREATE TABLE IF NOT EXISTS merchants (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  city_id INT,
  phone VARCHAR(100),
  email VARCHAR(255),
  store_name VARCHAR(255),
  onesignal_player_id VARCHAR(255),
  card_color VARCHAR(20) DEFAULT NULL,
  order_limit INT UNSIGNED DEFAULT 20,
  commission_rate_tiers TEXT,
  fixed_commission_tiers TEXT,
  is_active INT DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (city_id) REFERENCES cities(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
-- إن كان جدول merchants موجوداً مسبقاً، شغّل مرة واحدة:
-- ALTER TABLE merchants ADD COLUMN card_color VARCHAR(20) DEFAULT NULL;
-- ALTER TABLE merchants ADD COLUMN order_limit INT UNSIGNED DEFAULT 20;
-- ALTER TABLE merchants ADD COLUMN commission_rate_tiers TEXT;
-- ALTER TABLE merchants ADD COLUMN fixed_commission_tiers TEXT;

-- الطلبات (city_id و merchant_id لاستيلاء التاجر)
CREATE TABLE IF NOT EXISTS orders (
  id INT AUTO_INCREMENT PRIMARY KEY,
  order_number VARCHAR(100) UNIQUE,
  customer_id INT,
  customer_name VARCHAR(255),
  customer_phone VARCHAR(100),
  customer_phone_alt VARCHAR(100),
  customer_email VARCHAR(255),
  customer_address TEXT,
  status VARCHAR(50) DEFAULT 'pending',
  total_amount DOUBLE DEFAULT 0,
  notes TEXT,
  city_id INT,
  merchant_id INT,
  merchant_contacted_at DATETIME NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (customer_id) REFERENCES customers(id),
  FOREIGN KEY (city_id) REFERENCES cities(id),
  FOREIGN KEY (merchant_id) REFERENCES merchants(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- إن كان جدول orders موجوداً مسبقاً بدون العمود، شغّل مرة واحدة:
-- ALTER TABLE orders ADD COLUMN merchant_contacted_at DATETIME NULL;

-- عناصر الطلب
CREATE TABLE IF NOT EXISTS order_items (
  id INT AUTO_INCREMENT PRIMARY KEY,
  order_id INT NOT NULL,
  product_id INT,
  product_name VARCHAR(500),
  quantity INT NOT NULL DEFAULT 1,
  unit_price DOUBLE NOT NULL,
  total_price DOUBLE NOT NULL,
  FOREIGN KEY (order_id) REFERENCES orders(id),
  FOREIGN KEY (product_id) REFERENCES products(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- الإعدادات
CREATE TABLE IF NOT EXISTS settings (
  id INT AUTO_INCREMENT PRIMARY KEY,
  setting_key VARCHAR(255) UNIQUE NOT NULL,
  setting_value TEXT,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- سجل النشاط
CREATE TABLE IF NOT EXISTS activity_log (
  id INT AUTO_INCREMENT PRIMARY KEY,
  admin_id INT,
  admin_name VARCHAR(255),
  action VARCHAR(255) NOT NULL,
  details TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (admin_id) REFERENCES admins(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- صفحات المحتوى (من نحن، خصوصية، شروط)
CREATE TABLE IF NOT EXISTS cms_pages (
  id INT AUTO_INCREMENT PRIMARY KEY,
  slug VARCHAR(100) UNIQUE NOT NULL,
  title_ar VARCHAR(255),
  title_en VARCHAR(255),
  content_ar LONGTEXT,
  content_en LONGTEXT,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- الكوبونات
CREATE TABLE IF NOT EXISTS coupons (
  id INT AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(100) UNIQUE NOT NULL,
  discount_type VARCHAR(50) NOT NULL DEFAULT 'percent',
  discount_value DOUBLE NOT NULL DEFAULT 0,
  min_order DOUBLE DEFAULT 0,
  max_uses INT DEFAULT 0,
  used_count INT DEFAULT 0,
  expires_at DATETIME,
  is_active INT DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- مفاتيح API
CREATE TABLE IF NOT EXISTS api_keys (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  consumer_key VARCHAR(255) UNIQUE NOT NULL,
  consumer_secret VARCHAR(255) NOT NULL,
  permission VARCHAR(50) NOT NULL DEFAULT 'read_only',
  is_active INT DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- مستخدمو التطبيق (عميل / تاجر)
CREATE TABLE IF NOT EXISTS app_users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255),
  role VARCHAR(50) NOT NULL DEFAULT 'customer',
  merchant_id INT,
  google_id VARCHAR(255),
  apple_id VARCHAR(255),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (merchant_id) REFERENCES merchants(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- جلسات التطبيق
CREATE TABLE IF NOT EXISTS app_sessions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  token VARCHAR(255) UNIQUE NOT NULL,
  expires_at DATETIME NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES app_users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- شرائح السلايدر
CREATE TABLE IF NOT EXISTS store_slides (
  id INT AUTO_INCREMENT PRIMARY KEY,
  image_path VARCHAR(500) NOT NULL,
  corner_style VARCHAR(50) NOT NULL DEFAULT 'rounded',
  sort_order INT NOT NULL DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- مخزون التاجر (كمية كل منتج متوفرة لدى التاجر)
CREATE TABLE IF NOT EXISTS merchant_stock (
  merchant_id INT NOT NULL,
  product_id INT NOT NULL,
  quantity INT NOT NULL DEFAULT 0,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (merchant_id, product_id),
  FOREIGN KEY (merchant_id) REFERENCES merchants(id),
  FOREIGN KEY (product_id) REFERENCES products(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- تصنيفات البراندات
CREATE TABLE IF NOT EXISTS brand_categories (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name_ar VARCHAR(255) NOT NULL,
  icon_path VARCHAR(500),
  icon_size VARCHAR(50) DEFAULT 'medium',
  icon_corner VARCHAR(50) DEFAULT 'rounded',
  icon_shape VARCHAR(50) DEFAULT 'square',
  icon_color VARCHAR(50) DEFAULT '#06A3E7',
  sort_order INT DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- فهارس
CREATE INDEX IF NOT EXISTS idx_orders_created ON orders(created_at);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_city ON orders(city_id);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id);

SET FOREIGN_KEY_CHECKS = 1;

-- إعداد رقم الطلب التالي (إن لم يكن موجوداً في settings)
INSERT IGNORE INTO settings (setting_key, setting_value) VALUES ('next_order_number', '1000');

-- حساب أدمن افتراضي (كلمة المرور: admin123 — غيّرها فوراً)
-- INSERT INTO admins (username, password) SELECT 'admin', '$2a$10$...' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM admins LIMIT 1);
-- يفضّل إنشاء الأدمن من لوحة التحكم أو تشفير bcrypt يدوياً.
