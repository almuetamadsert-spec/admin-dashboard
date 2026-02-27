# فصل ملفات التطبيق عن ملفات اللوحة

بعد تشغيل السكربت يصبح هيكل المشروع كالتالي:

```
nodjs/
├── backend/          ← السيرفر + لوحة التحكم (Node.js)
│   ├── server.js
│   ├── package.json
│   ├── routes/
│   ├── views/
│   ├── db/
│   ├── middleware/
│   ├── lib/
│   ├── config/
│   ├── public/
│   ├── uploads/
│   └── ...
│
├── app/              ← تطبيق فلاتر (أندرويد / آيفون)
│   ├── lib/
│   ├── pubspec.yaml
│   └── ...
│
└── scripts/
    └── separate-app-from-backend.js
```

## تشغيل السكربت

من **جذر المشروع** (المجلد الذي فيه `server.js` و `store_app`):

```bash
node scripts/separate-app-from-backend.js
```

سيتم:
1. إنشاء مجلد **backend** ونقل كل ملفات السيرفر واللوحة إليه.
2. إعادة تسمية **store_app** إلى **app**.

## بعد الفصل

- **تشغيل السيرفر واللوحة:**  
  `cd backend && npm install && npm start`

- **تشغيل تطبيق فلاتر:**  
  `cd app && flutter pub get && flutter run`

- **رابط لوحة التحكم:** كما هو (مثلاً `http://localhost:3000/admin/login`).
- **إعداد التطبيق:** في `app/lib/config.dart` ضع رابط السيرفر ومفاتيح API.
