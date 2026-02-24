const express = require('express');
const path = require('path');
const session = require('express-session');

const app = express();
const PORT = process.env.PORT || 3000;
const isProduction = process.env.NODE_ENV === 'production';
if (isProduction) app.set('trust proxy', 1);

app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

app.use(express.urlencoded({ extended: true }));
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

app.use(session({
  secret: process.env.SESSION_SECRET || 'your-secret-key-change-in-production',
  resave: false,
  saveUninitialized: false,
  cookie: { maxAge: 24 * 60 * 60 * 1000 }
}));

// قاعدة البيانات تُحمّل لاحقاً؛ التطبيق يبدأ الاستماع فوراً
app.locals.db = null;

// فحص التوصيل — يعمل حتى قبل تحميل قاعدة البيانات
app.get('/health', (req, res) => res.type('text').send('ok'));

app.get('/api/status', (req, res) => {
  const db = app.locals.db;
  let dbStatus = 'جاري التحميل...';
  let dbOk = false;
  if (db) {
    try {
      db.prepare('SELECT 1').get();
      dbStatus = 'متصل';
      dbOk = true;
    } catch (e) {
      dbStatus = 'خطأ: ' + (e.message || 'غير متصل');
    }
  }
  res.json({
    ok: true,
    server: 'يعمل',
    database: dbStatus,
    databaseOk: dbOk,
    port: PORT,
    node: process.version,
    env: process.env.NODE_ENV || 'development'
  });
});

app.get('/status', (req, res) => {
  const db = app.locals.db;
  let dbStatus = 'جاري التحميل...';
  let dbOk = false;
  if (db) {
    try {
      db.prepare('SELECT 1').get();
      dbStatus = 'متصل ✓';
      dbOk = true;
    } catch (e) {
      dbStatus = 'خطأ: ' + (e.message || 'غير متصل');
    }
  }
  res.type('text/html').send(`
<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head><meta charset="utf-8"><title>فحص التوصيل</title>
<style>body{font-family:system-ui;max-width:500px;margin:2rem auto;padding:1rem;background:#f5f5f5;}
h1{color:#333;} .box{background:#fff;padding:1rem;margin:0.5rem 0;border-radius:8px;box-shadow:0 1px 3px rgba(0,0,0,0.1);}
.ok{color:#0a0;} .fail{color:#c00;} .wait{color:#888;}
a{color:#06c;}</style></head>
<body>
<h1>فحص التوصيل</h1>
<div class="box"><strong>السيرفر:</strong> <span class="ok">يعمل ✓</span></div>
<div class="box"><strong>قاعدة البيانات:</strong> <span class="${dbOk ? 'ok' : (db ? 'fail' : 'wait')}">${dbStatus}</span></div>
<div class="box"><strong>المنفذ:</strong> ${PORT} | <strong>Node:</strong> ${process.version}</div>
<div class="box"><a href="/admin/login">لوحة التحكم ←</a></div>
</body>
</html>`);
});

app.use((req, res, next) => {
  if (req.path === '/') return res.redirect('/admin/login');
  req.db = app.locals.db;
  if (!req.db) return res.status(503).set('Content-Type', 'text/plain; charset=utf-8').send('جاري تحميل التطبيق...');
  next();
});

const { requireAuth } = require('./middleware/auth');

app.use('/admin', require('./routes/admin'));
app.use('/admin/dashboard', requireAuth, require('./routes/dashboard'));
app.use('/admin/products', requireAuth, require('./routes/products'));
app.use('/admin/orders', requireAuth, require('./routes/orders'));
app.use('/admin/customers', requireAuth, require('./routes/customers'));
app.use('/admin/sales', requireAuth, require('./routes/sales'));
app.use('/admin/categories', requireAuth, require('./routes/categories'));
app.use('/admin/settings', requireAuth, require('./routes/settings'));
app.use('/admin/cities', requireAuth, require('./routes/cities'));
app.use('/admin/activity', requireAuth, require('./routes/activity'));
app.use('/admin/cms', requireAuth, require('./routes/cms'));
app.use('/admin/coupons', requireAuth, require('./routes/coupons'));
app.use('/admin/merchants', requireAuth, require('./routes/merchants'));
app.use('/admin/inventory', requireAuth, require('./routes/inventory'));
app.use('/admin/api-docs', requireAuth, require('./routes/api-docs'));

app.use('/api/cities', require('./middleware/apiAuth').requireApiKey, require('./routes/api/cities'));
app.use('/api/cms', require('./middleware/apiAuth').requireApiKey, require('./routes/api/cms'));
const apiAuth = require('./middleware/apiAuth');
app.use('/api/orders', apiAuth.requireApiKey, apiAuth.requireWrite, require('./routes/api/orders'));

app.get('/admin', (req, res) => {
  if (req.session && req.session.adminId) return res.redirect('/admin/dashboard');
  res.redirect('/admin/login');
});

// بدء الاستماع فوراً (قبل تحميل قاعدة البيانات)
app.listen(PORT, '0.0.0.0', () => {
  console.log(`الخادم يعمل على المنفذ ${PORT} (0.0.0.0)`);
  console.log('لوحة التحكم: /admin/login');
});

// تحميل قاعدة البيانات في الخلفية
require('./db/init')
  .then((db) => {
    app.locals.db = db;
    console.log('قاعدة البيانات جاهزة');
  })
  .catch((err) => {
    console.error('خطأ في تحميل قاعدة البيانات:', err);
    console.error(err.stack);
    // لا نوقف العملية؛ /health يبقى يعمل للتأكد من أن السيرفر يعمل
  });
