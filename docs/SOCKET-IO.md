# الإشعارات الفورية (Socket.io) للتجار

## الغرض
عند إنشاء طلب جديد من تطبيق العميل، يُرسل إشعار فوري للتجار في **نفس مدينة الطلب** فقط، ليمكنهم استلام الطلب فوراً.

## الاتصال من تطبيق التاجر (Flutter / ويب)

- **الرابط:** نفس عنوان الـ API، مثلاً `http://localhost:3000` أو `https://your-domain.com`
- **المسار:** Socket.io يستخدم المسار الافتراضي `/socket.io/`
- **المصادقة:** إرسال توكن تسجيل الدخول (نفس Bearer token المستخدم في `/api/merchant/*`) عند الاتصال:

```javascript
// مثال (JavaScript)
import { io } from 'socket.io-client';
const socket = io('http://localhost:3000', {
  auth: { token: 'YOUR_BEARER_TOKEN' }
});
socket.on('new_order', (data) => {
  // data: { order_id, order_number, total_amount, city_id }
  console.log('طلب جديد:', data);
});
```

في Flutter يمكن استخدام حزمة `socket_io_client` مع نفس الخيارات (`auth: { 'token': token }`).

## الأحداث

| الحدث        | الاتجاه   | الوصف |
|-------------|-----------|--------|
| `new_order` | سيرفر → عميل | يُرسل عند إنشاء طلب جديد. يُستقبل فقط من التجار المسجلين في مدينة الطلب. الحمولة: `{ order_id, order_number, total_amount, city_id }`. |

## ملاحظات
- التاجر يجب أن يكون له `city_id` في جدول `merchants` لاستقبال إشعارات طلبات مدينته.
- الإشعار يُرسل بالإضافة إلى إشعار OneSignal (إن وُجد) ولا يغني عنه في حال إغلاق التطبيق.
