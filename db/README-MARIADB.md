# تشغيل هيكل MariaDB على السحابة

## 1. إنشاء قاعدة البيانات

من لوحة LibyanSpider أو عبر الاتصال بـ MariaDB:

```sql
CREATE DATABASE IF NOT EXISTS shop CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

## 2. تشغيل ملف الهيكل

**من جهازك (إذا كان لديك عميل mysql):**
```bash
mysql -h عنوان-الخادم -u المستخدم -p shop < db/schema-mariadb.sql
```

**من السيرفر (AlmaLinux) بعد رفع المشروع:**
```bash
cd /path/to/project
mysql -h localhost -u user -p shop < db/schema-mariadb.sql
```

**أو من داخل عميل MariaDB (mysql -u ... -p):**
```sql
USE shop;
SOURCE /path/to/project/db/schema-mariadb.sql;
```

## 3. إنشاء حساب الأدمن

بعد تشغيل الـ schema، أضف أدمن من لوحة التحكم أو من SQL (كلمة المرور يجب أن تكون مشفرة bcrypt):

```bash
node -e "const bcrypt=require('bcryptjs'); console.log(bcrypt.hashSync('admin123',10));"
```
انسخ الناتج ثم:
```sql
INSERT INTO admins (username, password) VALUES ('admin', 'الناتج_المنسوخ');
```

## 4. متغيرات البيئة على السيرفر

عيّن في البيئة (أو ملف `.env` إذا استخدمت dotenv):

- `MARIADB_HOST` = عنوان خادم MariaDB من لوحة السحابة  
- `MARIADB_USER`  
- `MARIADB_PASSWORD`  
- `MARIADB_DATABASE=shop`  
- `MARIADB_PORT=3306` (إن لزم)

**ملاحظة:** التطبيق حالياً يعمل على SQLite محلياً. تفعيل MariaDB يتطلب تعديل نقطة تحميل قاعدة البيانات لاستخدام `db/mariadb.js` عند وجود هذه المتغيرات (الخطوات اللاحقة).
