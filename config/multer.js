const multer = require('multer');
const path = require('path');
const fs = require('fs');

const uploadDir = path.join(__dirname, '..', 'uploads', 'products');
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const ext = (path.extname(file.originalname) || '.jpg').toLowerCase();
    cb(null, `product_${Date.now()}_${Math.random().toString(36).slice(2)}${ext}`);
  }
});

const upload = multer({
  storage,
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const allowed = /\.(jpe?g|png|gif|webp)$/i.test(file.originalname);
    if (allowed) cb(null, true);
    else cb(new Error('نوع الملف غير مدعوم. استخدم صورة (jpg, png, gif, webp)'));
  }
});

// CSV Upload configuration
const csvDir = path.join(__dirname, '..', 'uploads', 'csv');
if (!fs.existsSync(csvDir)) fs.mkdirSync(csvDir, { recursive: true });

const storageCsv = multer.diskStorage({
  destination: (req, file, cb) => cb(null, csvDir),
  filename: (req, file, cb) => {
    cb(null, `import_${Date.now()}_${file.originalname}`);
  }
});

const uploadCsv = multer({
  storage: storageCsv,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB limit for CSV
  fileFilter: (req, file, cb) => {
    const allowed = /\.(csv)$/i.test(file.originalname);
    if (allowed) cb(null, true);
    else cb(new Error('الرجاء رفع ملف بصيغة CSV فقط.'));
  }
});

module.exports = { upload, uploadCsv, uploadMultiple: upload.array('images', 10) };
