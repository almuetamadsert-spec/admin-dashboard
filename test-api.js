/**
 * اختبار واجهة API من الطرفية (بدون متصفح ولا متجر تجريبي).
 * السيرفر يجب أن يكون يعمل مسبقاً (مثلاً: node server.js).
 *
 * الاستخدام:
 *   node test-api.js
 *   (مع وجود ملف test-api-keys.json في نفس المجلد يحتوي consumerKey و consumerSecret)
 *   node test-api.js <Consumer_Key> <Consumer_Secret>
 *   أو: set CONSUMER_KEY=ck_xxx & set CONSUMER_SECRET=cs_xxx & node test-api.js
 */
const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 3000;
const BASE = `http://127.0.0.1:${PORT}`;

// قراءة من ملف إن وُجد (يتجنب اقتطاع المفتاح/السري عند النسخ في الطرفية)
let consumerKey = '';
let consumerSecret = '';
const keysFiles = ['test-api-keys.json', 'test-api-keys.example.json'];
for (const name of keysFiles) {
  const keysPath = path.join(__dirname, name);
  if (fs.existsSync(keysPath)) {
    try {
      const keys = JSON.parse(fs.readFileSync(keysPath, 'utf8'));
      consumerKey = (keys.consumerKey || keys.consumer_key || '').trim();
      consumerSecret = (keys.consumerSecret || keys.consumer_secret || '').trim();
      if (consumerKey && consumerSecret && !consumerKey.includes('xxx') && !consumerSecret.includes('xxx')) break;
    } catch (e) { /* تجاهل */ }
  }
}
if (!consumerKey || !consumerSecret) {
  const args = process.argv.slice(2).filter(a => a && a !== 'node' && !/test-api\.js$/i.test(a));
  consumerKey = consumerKey || args[0] || process.env.CONSUMER_KEY || '';
  consumerSecret = consumerSecret || args[1] || process.env.CONSUMER_SECRET || '';
}

const debug = process.argv.includes('--debug');

function request(method, path, body) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE);
    const opts = {
      hostname: url.hostname,
      port: url.port || PORT,
      path: url.pathname,
      method,
      headers: {
        'Content-Type': 'application/json',
        'X-Consumer-Key': consumerKey,
        'X-Consumer-Secret': consumerSecret
      }
    };
    const req = http.request(opts, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => resolve({ status: res.statusCode, data }));
    });
    req.on('error', reject);
    req.setTimeout(10000, () => { req.destroy(); reject(new Error('انتهت المهلة')); });
    if (body) req.write(typeof body === 'string' ? body : JSON.stringify(body));
    req.end();
  });
}

async function run() {
  console.log('--- اختبار API (من الطرفية، بدون متصفح) ---\n');
  console.log('الرابط:', BASE);
  if (!consumerKey || !consumerSecret) {
    console.log('\nاستخدم مفتاحاً من لوحة التحكم → الإعدادات → مفاتيح API (صلاحية قراءة وكتابة).');
    console.log('\nالاستخدام:');
    console.log('  1) ملف (موصى به، يتجنب اقتطاع المفتاح): أنشئ ملف test-api-keys.json في نفس مجلد المشروع:');
    console.log('     {"consumerKey":"ck_xxx","consumerSecret":"cs_xxx"}');
    console.log('     ثم نفّذ: node test-api.js');
    console.log('  2) أو: node test-api.js <Consumer_Key> <Consumer_Secret>');
    console.log('  3) أو: set CONSUMER_KEY=ck_xxx & set CONSUMER_SECRET=cs_xxx & node test-api.js');
    process.exit(1);
  }
  console.log('المفتاح:', consumerKey.substring(0, 10) + '...\n');
  if (debug) {
    console.log('[تتبع] طول Consumer Key:', consumerKey.length, '| طول Consumer Secret:', consumerSecret.length);
    console.log('[تتبع] إن كان الطول قصيراً أو السر مختلفاً عن لوحة التحكم سيظهر 401.\n');
  }

  try {
    const health = await request('GET', '/health');
    if (health.status !== 200) {
      console.error('السيرفر لا يستجيب. شغّل السيرفر أولاً: node server.js');
      process.exit(1);
    }
    console.log('✓ السيرفر يعمل');

    const products = await request('GET', '/api/products');
    if (products.status === 401) {
      const diag = await request('GET', '/api/debug-key-check').catch(() => ({ status: 0, data: '{}' }));
      let diagMsg = '';
      if (diag.status === 200) {
        try {
          const d = JSON.parse(diag.data);
          diagMsg = '\n  [تشخيص السيرفر] طول المفتاح: ' + d.keyLength + ' | طول السر: ' + d.secretLength + ' | المفتاح في DB: ' + (d.dbHasThisKey ? 'نعم' : 'لا') + ' | تطابق كامل: ' + (d.dbFullMatch ? 'نعم' : 'لا') + '\n  تلميح: ' + (d.hint || '');
        } catch (e) {}
      }
      console.error('✗ المفتاح أو السر غير صحيح (401). استخدم مفتاحاً يبدأ بـ ck_ و cs_ من لوحة التحكم.' + diagMsg);
      console.error('  • تأكد أن المفتاح من: لوحة التحكم → الإعدادات → مفاتيح API (صلاحية قراءة وكتابة).');
      console.error('  • انسخ Consumer Key و Consumer Secret كما هما بعد إنشاء المفتاح (أو بعد "تجديد السر").');
      console.error('  • إن جددت السر في اللوحة فاستخدم السر الجديد في الملف وليس القديم.');
      console.error('  • للتتبع: node test-api.js --debug');
      process.exit(1);
    }
    if (products.status !== 200) {
      console.error('✗ فشل تحميل المنتجات:', products.status, products.data);
      process.exit(1);
    }
    const productsData = JSON.parse(products.data);
    const list = productsData.products || [];
    console.log('✓ المنتجات:', list.length, 'منتج');
    if (list.length) console.log('  أول منتج:', (list[0].name_ar || list[0].name_en || '—').substring(0, 30));

    const cities = await request('GET', '/api/cities');
    if (cities.status === 401) {
      console.error('✗ المفتاح أو السر غير صحيح (401)');
      process.exit(1);
    }
    if (cities.status !== 200) {
      console.error('✗ فشل تحميل المدن:', cities.status);
      process.exit(1);
    }
    const citiesData = JSON.parse(cities.data);
    const cityList = citiesData.cities || [];
    console.log('✓ المدن:', cityList.length, 'مدينة');
    if (cityList.length) console.log('  أول مدينة:', cityList[0].name);

    console.log('\n--- انتهى الاختبار بنجاح. الـ API يعمل من الطرفية. ---');
    console.log('\nلإنشاء طلب تجريبي من الطرفية يمكنك استخدام برامج مثل:');
    console.log('  Postman, Insomnia, أو Thunder Client (إضافة في VS Code)');
    console.log('  الرابط: ' + BASE + '/api/orders');
    console.log('  الطريقة: POST، الهيدر: X-Consumer-Key, X-Consumer-Secret');
    console.log('  الجسم (JSON): city_id, customer_name, customer_phone, items: [{ product_id, quantity }]');
  } catch (err) {
    console.error('خطأ:', err.message);
    if (err.code === 'ECONNREFUSED') {
      console.error('السيرفر غير مشغّل. شغّله أولاً: node server.js');
    }
    process.exit(1);
  }
}

run();
