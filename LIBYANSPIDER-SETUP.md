# إعداد النشر على LibyanSpider — تحقق من هذه النقاط

المشروع مربوط بـ Git لكن الموقع لا يفتح؟ راجع الإعدادات التالية **في لوحة LibyanSpider**.

---

## 1. خطوة البناء (ضرورية)

على السيرفر **لا يوجد** مجلد `node_modules` لأنّه غير مرفوع مع Git. يجب تثبيت الحزم **على السيرفر** بعد سحب الكود.

- في إعدادات **Deployments** أو **Build** أو **Application Server**:
  - ابحث عن حقل مثل: **Build command** / **Install command** / **Pre-start** / **Build step**.
  - ضع فيه: **`npm install`** أو **`npm run build`**.
- إذا لم تجد حقل "Build"، ابحث في **Hooks** (في نافذة Edit Project) عن **Post-deploy** أو **After deploy** وأضف تنفيذ: **`npm install`**.

بدون تشغيل `npm install` على السيرفر التطبيق **لن يعمل** (خطأ مثل Cannot find module 'express').

---

## 2. أمر التشغيل (Start)

- في إعدادات الـ **Application Server (Node.js)** أو **Deployments**:
  - ابحث عن: **Start command** / **Run command** / **Command** / **Start script**.
  - ضع: **`npm start`** أو **`node server.js`**.
- يجب أن يكون هناك أمر تشغيل واضح؛ إذا كان الحقل فارغاً أو يحتوي أمراً آخر، غيّره إلى أحد الاثنين أعلاه.

---

## 3. المسار (Context / Document root)

- تأكد أن **جذر التطبيق** هو المجلد الذي فيه ملفات المشروع (`package.json`, `server.js`).
- إذا كانت المنصة تطلب **Context** أو **Application root** أو **Path**، اتركه **فارغاً** أو **`/`** أو **`.`** إذا المشروع في جذر المستودع.

---

## 4. المنفذ (PORT)

- التطبيق يقرأ المنفذ من **`process.env.PORT`**.
- عادة LibyanSpider يضبط **PORT** تلقائياً؛ **لا تحتاج** تعيينه إلا إذا كانت الوثائق أو الدعم يطلب ذلك.

---

## 5. بعد تعديل الإعدادات

1. احفظ التغييرات.
2. نفّذ **Deploy** مرة أخرى (أو انتظر النشر التلقائي).
3. انتظر 1–2 دقيقة ثم جرّب **فحص التوصيل**:
   - **https://env-6069530.tip2.libyanspider.cloud/health** — يظهر **ok** إذا السيرفر يعمل.
   - **https://env-6069530.tip2.libyanspider.cloud/status** — صفحة توضح: السيرفر + قاعدة البيانات (متصل أم لا).
   - **https://env-6069530.tip2.libyanspider.cloud/api/status** — نفس المعلومات بصيغة JSON.
   - **https://env-6069530.tip2.libyanspider.cloud/admin/login** — لوحة التحكم.

---

## 6. إذا استمرت المشكلة — أرسل من الـ Logs

من لوحة LibyanSpider:

1. ادخل إلى **Application Servers** → اختر خادم **Node.js**.
2. افتح **Logs** أو **Console** أو **Error log**.
3. بعد عملية النشر وتشغيل التطبيق، انسخ **آخر 20–30 سطراً** (خصوصاً أي سطر فيه `Error` أو `error` أو `Cannot find module` أو `خطأ`).
4. أرسلها مع ذكر إن كنت تصل إلى `/health` وتظهر **ok** أم لا.

هذه المعلومات ضرورية لمعرفة إن كانت المشكلة من البناء أو أمر التشغيل أو المنصة.
