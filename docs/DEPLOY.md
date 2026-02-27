# إعداد النشر على السحابة (LibyanSpider / AlmaLinux)

دليل نشر لوحة التحكم وتطبيق الـ API على سيرفر يعمل عليه Node.js و NGINX و (اختياري) MariaDB.

---

## 1. متطلبات السيرفر

- **Node.js** 18 أو أحدث (`node -v`)
- **NGINX** (وكيل عكسي وخدمة الملفات الثابتة إن رغبت)
- **PM2** (اختياري، لإدارة العملية وإعادة التشغيل التلقائي): `npm i -g pm2`
- عند استخدام **MariaDB**: خادم MariaDB متاح (من لوحة LibyanSpider أو نفس السيرفر)

---

## 2. متغيرات البيئة

انسخ `.env.example` إلى `.env` على السيرفر وعدّل القيم. التطبيق يقرأ `.env` عبر حزمة `dotenv`.

| المتغير | مطلوب | الوصف |
|--------|--------|--------|
| `NODE_ENV` | لا | `production` في الإنتاج |
| `PORT` | لا | منفذ التطبيق (افتراضي 3000) |
| `SESSION_SECRET` | نعم في الإنتاج | سلسلة عشوائية طويلة لجلسات لوحة التحكم |
| `MARIADB_HOST` | عند استخدام MariaDB | عنوان خادم MariaDB |
| `MARIADB_PORT` | لا | 3306 |
| `MARIADB_USER` | عند استخدام MariaDB | مستخدم قاعدة البيانات |
| `MARIADB_PASSWORD` | عند استخدام MariaDB | كلمة مرور المستخدم |
| `MARIADB_DATABASE` | لا | اسم القاعدة (افتراضي shop) |

**ملاحظة:** في حال عدم تعيين متغيرات MariaDB، التطبيق يستخدم **SQLite** (ملف `data/shop.db`). لاستخدام MariaDB على السحابة راجع `db/README-MARIADB.md` وتشغيل `db/schema-mariadb.sql`؛ تفعيل الاتصال بـ MariaDB من التطبيق يتطلب حالياً تعديل نقطة تحميل قاعدة البيانات لاستخدام `db/mariadb.js` (واجهة غير متزامنة).

---

## 3. خطوات النشر

```bash
# على السيرفر (مثال: AlmaLinux)
cd /var/www/store-backend   # أو المسار الذي تختاره
git clone <مستودع-المشروع> .
# أو ارفع الملفات عبر FTP/rsync

npm install --production
cp .env.example .env
# عدّل .env (SESSION_SECRET، وإذا استخدمت MariaDB أضف متغيراتها)
```

### المجلدات والصلاحيات

- **data/** — يُنشأ تلقائياً لملف SQLite؛ تأكد أن المستخدم الذي يشغّل التطبيق يملك صلاحية الكتابة.
- **uploads/** — رفع صور المنتجات والملفات؛ أنشئه إن لم يوجد وامنح صلاحية الكتابة:
  ```bash
  mkdir -p uploads data
  chown -R المستخدم:المجموعة uploads data
  ```

### تشغيل التطبيق

**تشغيل مباشر (للاختبار):**
```bash
PORT=3000 node server.js
```

**تشغيل دائم بـ PM2 (موصى به):**
```bash
pm2 start server.js --name store-api
pm2 save
pm2 startup   # لبدء PM2 مع التشغيل
```

يمكن استخدام ملف `ecosystem.config.js` (انظر القسم 5).

---

## 4. NGINX (وكيل عكسي)

ليستقبل NGINX الطلبات على المنفذ 80/443 ويمررها إلى التطبيق (مثلاً على المنفذ 3000)، واستخدام Socket.io بدون قطع الاتصال.

مثال إعداد (موجود أيضاً في `docs/nginx.example.conf`؛ استبدل `your-domain.com` ومسارات الشهادات حسب بيئتك):

```nginx
# مثال: /etc/nginx/conf.d/store.conf
upstream store_backend {
    server 127.0.0.1:3000;
    keepalive 64;
}

server {
    listen 80;
    server_name your-domain.com;

    # اختياري: إعادة توجيه HTTP إلى HTTPS
    # return 301 https://$server_name$request_uri;

    location / {
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_pass http://store_backend;
        proxy_buffering off;
    }

    # ضروري لـ Socket.io
    location /socket.io/ {
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_pass http://store_backend;
    }

    # اختياري: خدمة الملفات المرفوعة مباشرة من NGINX (أسرع)
    location /uploads/ {
        alias /var/www/store-backend/uploads/;
        expires 30d;
    }
}
```

لتفعيل HTTPS مع Let's Encrypt يمكن استخدام Certbot ثم إضافة `listen 443 ssl` و `ssl_certificate` و `ssl_certificate_key`.

بعد التعديل:
```bash
sudo nginx -t
sudo systemctl reload nginx
```

---

## 5. PM2 — ملف إعداد اختياري

أنشئ في جذر المشروع ملف `ecosystem.config.js`:

```javascript
module.exports = {
  apps: [{
    name: 'store-api',
    script: 'server.js',
    cwd: __dirname,
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '500M',
    env: { NODE_ENV: 'development' },
    env_production: { NODE_ENV: 'production' },
  }],
};
```

ثم:
```bash
pm2 start ecosystem.config.js --env production
pm2 save && pm2 startup
```

---

## 6. التخزين (Storage)

- **قاعدة البيانات:** محلياً SQLite (`data/shop.db`). على السحابة يمكن استخدام MariaDB بعد تنفيذ الهيكل وإعداد الاتصال كما في `db/README-MARIADB.md`.
- **الملفات المرفوعة:** مجلد `uploads/` في جذر المشروع. في النشر الموزع يُفضّل لاحقاً ربط تخزين موحد (مثل S3 أو مسار شبكة مشترك) وتوجيه الرفع إليه.

---

## 7. التحقق بعد النشر

- **صحة التطبيق:** `http://your-domain.com/health` — يجب أن يرجع `ok`.
- **حالة قاعدة البيانات:** `http://your-domain.com/api/status` — يرجع حالة السيرفر وقاعدة البيانات.
- **لوحة التحكم:** `http://your-domain.com/admin/login`.
- **Socket.io:** تأكد أن طلبات `/socket.io/` تمر عبر نفس الـ proxy (الكتلة `location /socket.io/` أعلاه).

---

## 8. مراجع في المشروع

- **MariaDB:** `db/README-MARIADB.md` — إنشاء القاعدة وتشغيل الهيكل ومتغيرات البيئة.
- **Socket.io للتجار:** `docs/SOCKET-IO.md` — ربط تطبيق التاجر بالإشعارات الفورية.
