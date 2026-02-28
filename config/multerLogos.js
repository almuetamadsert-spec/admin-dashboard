const multer = require('multer');
const path = require('path');
const fs = require('fs');

const uploadDir = path.join(__dirname, '..', 'uploads', 'logos');
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });

const storage = multer.diskStorage({
    destination: (req, file, cb) => cb(null, uploadDir),
    filename: (req, file, cb) => {
        const ext = (path.extname(file.originalname) || '.png').toLowerCase();
        cb(null, `logo_${Date.now()}_${Math.random().toString(36).slice(2)}${ext}`);
    }
});

const uploadLogo = multer({
    storage,
    limits: { fileSize: 2 * 1024 * 1024 }, // 2MB is enough for a logo
    fileFilter: (req, file, cb) => {
        const allowed = /\.(jpe?g|png|gif|webp|svg)$/i.test(file.originalname);
        if (allowed) cb(null, true);
        else cb(new Error('نوع الملف غير مدعوم. استخدم صورة (jpg, png, gif, webp, svg)'));
    }
}).single('logo');

module.exports = { uploadLogo };
