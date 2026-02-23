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

const { requireAuth } = require('./middleware/auth');

(async () => {
  const db = await require('./db/init');
  app.use((req, res, next) => { req.db = db; next(); });

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

  app.get('/', (req, res) => res.redirect('/admin/login'));
  app.get('/health', (req, res) => res.type('text').send('ok'));

  app.listen(PORT, '0.0.0.0', () => {
    console.log(`الخادم يعمل على المنفذ ${PORT} (0.0.0.0)`);
    console.log('لوحة التحكم: /admin/login');
  });
})().catch((err) => {
  console.error('خطأ عند بدء التشغيل:', err);
  process.exit(1);
});
