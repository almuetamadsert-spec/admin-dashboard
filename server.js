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

app.use((req, res, next) => {
  if (req.path === '/health') return res.type('text').send('ok');
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
