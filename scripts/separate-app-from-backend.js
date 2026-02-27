/**
 * يفصل ملفات التطبيق (فلاتر) عن ملفات اللوحة والسيرفر.
 * النتيجة: مجلد backend/ (سيرفر + لوحة تحكم) ومجلد app/ (تطبيق فلاتر).
 * شغّل من جذر المشروع: node scripts/separate-app-from-backend.js
 */

const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');

const TO_BACKEND = [
  'server.js',
  'package.json',
  'package-lock.json',
  'Procfile',
  'routes',
  'views',
  'db',
  'middleware',
  'lib',
  'config',
  'public',
  'uploads',
  'data',
  'test-api.js',
  'test-local.js',
  'test-api-keys.example.json',
  'TEST.md',
  'خطوات-الاستضافة.md',
  'التحقق-من-لوحة-السيرفر.md',
  'LIBYANSPIDER-SETUP.md',
  'ما-ناقص.md',
  '.gitignore',
  'gitignore',
];

const APP_SOURCE = 'store_app';
const APP_TARGET = 'app';

function moveItem(srcPath, destPath) {
  if (!fs.existsSync(srcPath)) return;
  if (fs.existsSync(destPath)) {
    console.warn('موجود مسبقاً، تخطي:', path.relative(root, destPath));
    return;
  }
  fs.renameSync(srcPath, destPath);
  console.log('نقل:', path.relative(root, srcPath), '->', path.relative(root, destPath));
}

function main() {
  console.log('جذر المشروع:', root);
  const backendDir = path.join(root, 'backend');
  if (!fs.existsSync(backendDir)) {
    fs.mkdirSync(backendDir, { recursive: true });
    console.log('تم إنشاء مجلد backend');
  }

  for (const name of TO_BACKEND) {
    const src = path.join(root, name);
    const dest = path.join(backendDir, name);
    if (fs.existsSync(src)) {
      moveItem(src, dest);
    }
  }

  const appSrc = path.join(root, APP_SOURCE);
  const appDest = path.join(root, APP_TARGET);
  if (fs.existsSync(appSrc) && !fs.existsSync(appDest)) {
    fs.renameSync(appSrc, appDest);
    console.log('إعادة تسمية:', APP_SOURCE, '->', APP_TARGET);
  } else if (fs.existsSync(appSrc)) {
    console.warn('مجلد app موجود مسبقاً، لم يتم إعادة تسمية store_app');
  }

  console.log('\nانتهى. التشغيل:');
  console.log('  السيرفر واللوحة: cd backend && npm install && npm start');
  console.log('  التطبيق:         cd app && flutter pub get && flutter run');
}

main();
