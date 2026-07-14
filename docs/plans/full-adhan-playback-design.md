# تصميم: تشغيل الأذان الكامل (Full Adhan Playback)

الحالة: معتمد من المستخدم — نُفِّذ. النسخة: 0.1.6+32
التاريخ: 2026-07-14

## المشكلة
عند دخول وقت الصلاة، يصل إشعار محلي بصوت أذان قصير (adhan.caf / raw adhan).
المطلوب: تشغيل **الأذان الكامل** (ملف `assets/sounds/adhan_full.m4a` — مدة 4:52)
داخل التطبيق عند فتحه/العودة إليه قرب وقت الصلاة، وعند الضغط على إشعار الصلاة،
مع إمكانية إيقافه، ومرة واحدة فقط لكل صلاة.

## القرارات المعمارية

### 1) خدمة مفردة `AdhanPlayer`
`lib/services/adhan_player.dart` — غلاف مفرد (singleton) حول `AudioPlayer`
من حزمة `audioplayers: ^6.8.0`:
- `playFullAdhan()` — يشغّل `AssetSource('sounds/adhan_full.m4a')` مع حارس ضد
  التشغيل المزدوج (`_isPlaying`).
- `stop()` — يوقف ويصفّر الحالة.
- `isPlaying` + `ValueNotifier<bool> playing` — لتحديث الواجهة (شريط الإيقاف).
- يُصفّى تلقائياً عند اكتمال التشغيل عبر `onPlayerComplete` (اشتراك واحد في
  المُنشئ، بلا تسريب).
- `ReleaseMode.release` الافتراضي كافٍ لتشغيل واحد (لا حاجة لضبط).

### 2) حارس «مرة واحدة لكل صلاة» — `AdhanGuard`
يُخزَّن آخر مفتاح صلاة شُغّل بصيغة `YYYY-MM-DD|اسم_الصلاة` (مثل `2026-07-14|المغرب`).
- التخزين عبر `FlutterSecureStorage` **بنفس أسلوب `worship_prefs.dart`** (المشروع
  لا يستخدم `shared_preferences` ولا يعتمدها في pubspec — انظر «انحرافات» أدناه).
- قبل التشغيل: إن كان المفتاح الحالي == آخر مفتاح مخزَّن → تجاهُل. وإلا نخزّنه ثم نشغّل.
- المفتاح مبني على «اليوم» فيمنع تكرار نفس الصلاة في نفس اليوم من مسارَي الفتح والضغط معاً.

### 3) مسار فتح/عودة التطبيق (app-open / resume)
يحاكي نمط `openChatIfPendingMed()` الموجود:
- دالة عليا `maybePlayAdhan({String? prayerName})` في `main.dart`.
- تُستدعى في `_StartupGate.initState` (بعد تأكيد الدخول) وفي `didChangeAppLifecycleState`
  عند `resumed` — بجوار `openChatIfPendingMed()` تماماً.
- الشروط (مسار الفتح، بلا `prayerName`):
  1. `WorshipPrefs.adhanEnabled == true`.
  2. `WorshipPrefs.sound == 'adhan'` (نحترم اختيار المستخدم: الأذان الكامل فقط لو
     اختار «صوت الأذان»).
  3. الآن يقع ضمن **10 دقائق بعد** وقت إحدى الصلوات الخمس (تُحسب محلياً عبر
     `PrayerTimes.forDate` ومدينة `WorshipPrefs.cityIndex`، فرق توقيت +3).
  4. لم تُشغَّل هذه الصلاة اليوم (حارس `AdhanGuard`).

### 4) مسار الضغط على الإشعار (notification-tap)
- إشعار الأذان كان يحمل `payload: 'worship'` (يتشاركه مع الإقامة والذكر المتكرر —
  غامض). غيّرناه إلى **`payload: 'prayer|<اسم الصلاة>'`** في `notification_sync.dart`
  (سطر جدولة الأذان فقط؛ الإقامة والذكر يبقيان `'worship'`). هذا يمنع تشغيل الأذان
  خطأً عند الضغط على إشعار إقامة أو ذكر.
- في `handleNotificationPayload` فرع جديد `prayer|`: يفتح `WorshipScreen` (يحافظ على
  السلوك السابق) **و** يستدعي `maybePlayAdhan(prayerName: name)` — يتجاوز نافذة الـ10
  دقائق (ضغط صريح من المستخدم) لكنه يحترم التفضيلات ونفس حارس «مرة لكل صلاة».
- يعمل أيضاً للإقلاع البارد من إشعار عبر `handleAppLaunch()` الذي يمرّ بنفس المُوجّه.

### 5) شريط الإيقاف (Stop affordance)
- أُضيف `rootMessengerKey` (GlobalKey<ScaffoldMessengerState>) إلى `MaterialApp`.
- يستمع `_JasirAppState` إلى `AdhanPlayer.instance.playing`:
  - عند التشغيل: `MaterialBanner` بنص عربي وزر **«إيقاف الأذان»** → `AdhanPlayer.stop()`.
  - عند الإيقاف/الاكتمال: `clearMaterialBanners()`.
- كل النصوص للمستخدم بالعربية.

### 6) pubspec
- إضافة `audioplayers: ^6.8.0`.
- إضافة `- assets/sounds/` إلى قائمة `flutter: assets:` (كانت تُصرّح `assets/icon/` فقط —
  بدونها يفشل `AssetSource` وقت التشغيل). **حرِج.**
- رفع الإصدار `0.1.5+31` → `0.1.6+32`.

## البدائل المرفوضة
- استخدام payload `'worship'` نفسه للتشغيل: مرفوض — يتشاركه الإقامة والذكر فيسبّب
  تشغيلاً خاطئاً.
- تشغيل الأذان من خلفية الإشعار مباشرة (بلا فتح التطبيق): خارج النطاق؛ iOS لا يسمح
  بتشغيل صوت طويل مخصّص من إشعار محلي دون فتح التطبيق. المطلوب هو التشغيل داخل التطبيق.
- `shared_preferences` للحارس: مرفوض — غير معتمد في المشروع؛ نستخدم `FlutterSecureStorage`.

## انحرافات عن المنهجية (مُوثّقة عمداً)
- **لا worktree/فرع git**: نعمل على نسخة عمل المستخدم مباشرة (طلب المستخدم؛ النشر يدوي).
- **لا اختبارات قابلة للتشغيل / لا `flutter analyze`**: Flutter/Dart غير متوفّرين في
  البيئة. التعويض: قراءة كل ملف كاملاً قبل التعديل، تعديلات جراحية دنيا، ومراجعة ذاتية
  نهائية لكل ملف. «التحقق» = مراجعة ذاتية مذكورة في التقرير النهائي.
- **الحارس عبر FlutterSecureStorage** لا SharedPreferences (المتطلب ذكر SharedPreferences،
  لكن أسلوب المشروع الفعلي هو FlutterSecureStorage — التزمنا بأسلوب المشروع).

## نقاط تحتاج انتباه المراجع البشري
- **Podfile**: لا يوجد Podfile مُدرَج في المستودع (Codemagic يولّده وقت البناء).
  هدف النشر في مشروع Xcode = **13.0** بالفعل (IPHONEOS_DEPLOYMENT_TARGET). تأكّد أن
  الـ Podfile المولَّد يفعّل `platform :ios, '13.0'` (يتطلبها audioplayers_darwin v6).
- ملف `assets/sounds/adhan_full.flac` (18MB) باقٍ في المجلد؛ التشغيل يستخدم `.m4a`
  فقط. بما أننا صرّحنا المجلد كاملاً، سيُحزَم الـ flac أيضاً ويكبّر التطبيق ~18MB —
  يُستحسن حذف الـ flac قبل البناء (قرار المستخدم).
