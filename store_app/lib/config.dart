/// إعدادات الاتصال بالـ API — غيّر القيم حسب السيرفر والمفتاح من لوحة التحكم.
import 'package:flutter/foundation.dart' show kIsWeb;

class Config {
  /// رابط السيرفر: على الويب يُستخدم localhost، وعلى أندرويد 10.0.2.2 (محاكي).
  /// للهاتف الحقيقي: ضع هنا IP الكمبيوتر على نفس الـ Wi‑Fi، مثل: 'http://192.168.1.5:3000'
  static const String? baseUrlOverride = null; // للهاتف: 'http://IP_الكمبيوتر:3000'
  static const String baseUrlWeb = 'http://localhost:3000';
  static const String baseUrlAndroid = 'http://10.0.2.2:3000';
  static String get baseUrl {
    if (baseUrlOverride != null && baseUrlOverride!.isNotEmpty) return baseUrlOverride!.replaceAll(RegExp(r'/$'), '');
    return kIsWeb ? baseUrlWeb : baseUrlAndroid;
  }

  /// Consumer Key من لوحة التحكم → الإعدادات → مفاتيح API (صلاحية قراءة وكتابة).
  /// تأكد أنه يبدأ بـ ck_ بدون مسافة أو تاب قبله.
  static const String consumerKey = 'ck_7406e875f6b39c44e347960e95a711c942ad76b455fe0b03';

  /// Consumer Secret من نفس المفتاح (يُعرض مرة واحدة عند الإنشاء أو تجديد السر).
  static const String consumerSecret = 'cs_dd26ccc21d27aa75f8b294fc5ca9d1a6142b52444949fce0b0d8050fdf52ad26';
}
