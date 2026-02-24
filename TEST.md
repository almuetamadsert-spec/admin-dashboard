# اختبار المشروع — على الكمبيوتر وعلى Git

## 1. اختبار على الكمبيوتر (محلي)

### الطريقة الأولى — تشغيل يدوي

```powershell
cd c:\Users\Prof\Desktop\nodjs
npm install
npm start
```

ثم في المتصفح:

- **http://localhost:3000/health** — يجب أن تظهر كلمة **ok**
- **http://localhost:3000/status** — صفحة فحص التوصيل (السيرفر + قاعدة البيانات)
- **http://localhost:3000/admin/login** — لوحة التحكم (admin / admin123)

إذا الثلاثة يعملون، المشروع على الكمبيوتر سليم.

---

### الطريقة الثانية — سكربت اختبار تلقائي

```powershell
cd c:\Users\Prof\Desktop\nodjs
npm install
npm run test
```

السكربت يشغّل السيرفر على المنفذ 3333، يختبر **/health** و **/api/status**، ثم يوقفه. إذا ظهرت رسالة **"جميع الفحوصات نجحت"** فالمشروع يعمل محلياً.

---

## 2. اختبار مثل السيرفر (مجلد نظيف — مثل Git)

هذا يقلّد ما يحدث عند سحب المشروع من Git ثم تشغيله (بدون وجود `node_modules` أو `data` مسبقاً).

### على الكمبيوتر

```powershell
cd c:\Users\Prof\Desktop
mkdir nodjs-test
xcopy /E /I nodjs nodjs-test
cd nodjs-test
rd /s /q node_modules 2>nul
del data\shop.db 2>nul
npm install
npm run test
```

أو باستخدام PowerShell:

```powershell
cd c:\Users\Prof\Desktop
Copy-Item -Path nodjs -Destination nodjs-test -Recurse -Force
cd nodjs-test
Remove-Item -Recurse -Force node_modules -ErrorAction SilentlyContinue
Remove-Item -Force data\shop.db -ErrorAction SilentlyContinue
npm install
npm run test
```

إذا **npm run test** ينتهي برسالة **"جميع الفحوصات نجحت"**، فالمشروع يشتغل من مجلد نظيف كما لو كان سحبه من Git وتشغيله.

---

## 3. ماذا نستنتج؟

| الاختبار | النتيجة | المعنى |
|----------|---------|--------|
| **محلي (npm start + فتح /status)** | يعمل | المشروع نفسه سليم على جهازك. |
| **npm run test** | نجح | السيرفر + /health + /api/status يعملون. |
| **مجلد نظيف → npm install → npm run test** | نجح | المشروع يشتغل بعد سحب من Git وتثبيت الحزم فقط. |
| **على LibyanSpider** | 502 أو خطأ | المشكلة من إعدادات المنصة (مسار التشغيل، أمر Post، منفذ، إلخ). |

---

## 4. ملخص أوامر سريعة

```powershell
# اختبار عادي
npm install && npm run test

# تشغيل وفتح المتصفح
npm start
# ثم افتح: http://localhost:3000/status
```

إذا كل شيء ينجح محلياً ومجلد نظيف، يمكننا حصر المشكلة في إعدادات النشر على المنصة (مسار ROOT، Post-deploy، أمر Start).
