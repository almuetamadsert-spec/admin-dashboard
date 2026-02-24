/**
 * اختبار محلي: يبدأ السيرفر ويختبر /health و /api/status ثم يوقف السيرفر.
 * استخدم: node test-local.js   أو  npm run test
 */
const { spawn } = require('child_process');
const http = require('http');

const TEST_PORT = 3333;
const BASE = `http://127.0.0.1:${TEST_PORT}`;

function request(url) {
  return new Promise((resolve, reject) => {
    const req = http.get(url, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => resolve({ status: res.statusCode, data }));
    });
    req.on('error', reject);
    req.setTimeout(5000, () => { req.destroy(); reject(new Error('timeout')); });
  });
}

async function run() {
  const env = { ...process.env, PORT: String(TEST_PORT), NODE_ENV: 'test' };
  const child = spawn(process.execPath, ['server.js'], { env, stdio: 'pipe', cwd: __dirname });

  let resolved = false;
  child.on('error', (err) => { if (!resolved) { resolved = true; console.error('خطأ تشغيل السيرفر:', err.message); process.exit(1); } });
  child.stderr.on('data', (d) => process.stderr.write(d));

  // انتظار بدء السيرفر
  await new Promise((r) => setTimeout(r, 4000));

  try {
    const health = await request(`${BASE}/health`);
    if (health.status !== 200 || health.data.trim() !== 'ok') {
      console.error('فشل /health:', health.status, health.data);
      process.exit(1);
    }
    console.log('✓ /health يعمل');

    const status = await request(`${BASE}/api/status`);
    if (status.status !== 200) {
      console.error('فشل /api/status:', status.status);
      process.exit(1);
    }
    let obj;
    try { obj = JSON.parse(status.data); } catch (e) { console.error('استجابة /api/status غير صحيحة'); process.exit(1); }
    if (!obj.server || !obj.database) {
      console.error('استجابة /api/status ناقصة:', obj);
      process.exit(1);
    }
    console.log('✓ /api/status يعمل — السيرفر:', obj.server, '| قاعدة البيانات:', obj.database);

    console.log('\nجميع الفحوصات نجحت.');
    resolved = true;
    child.kill('SIGTERM');
    process.exit(0);
  } catch (err) {
    console.error('خطأ أثناء الاختبار:', err.message);
    child.kill('SIGTERM');
    process.exit(1);
  }
}

run();
