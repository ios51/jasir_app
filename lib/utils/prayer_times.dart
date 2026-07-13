import 'dart:math' as math;

/// حساب مواقيت الصلاة فلكياً (بلا إنترنت) — طريقة أم القرى الرسمية
/// المعتمدة في السعودية: زاوية الفجر 18.5°، والعشاء = المغرب + 90 دقيقة
/// (120 دقيقة في رمضان). العصر على مذهب الجمهور (ظل المثل).
///
/// المصدر الخوارزمي: معادلات الموقع الشمسي القياسية (خط الطول/العرض
/// وزمن المعادلة والميل)، وهي نفس ما تعتمده تطبيقات المواقيت المعروفة.
class PrayerTimes {
  final DateTime fajr, sunrise, dhuhr, asr, maghrib, isha;
  PrayerTimes({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  static double _dtr(double d) => d * math.pi / 180.0;
  static double _rtd(double r) => r * 180.0 / math.pi;
  static double _sin(double d) => math.sin(_dtr(d));
  static double _cos(double d) => math.cos(_dtr(d));
  static double _tan(double d) => math.tan(_dtr(d));
  static double _fixHour(double h) => _fix(h, 24);
  static double _fix360(double a) => _fix(a, 360);
  static double _fix(double a, double b) {
    a = a - b * (a / b).floor();
    return a < 0 ? a + b : a;
  }

  /// ضبط دقائق يدوي لكل صلاة (يعالج فروق مسجد الحي عن الحساب الفلكي).
  /// القيم بالدقائق، تُضاف/تُطرح من الناتج.
  static Map<String, int> offsets = {
    'fajr': 0, 'sunrise': 0, 'dhuhr': 0, 'asr': 0, 'maghrib': 0, 'isha': 0,
  };

  /// يحسب مواقيت [date] لموقع [lat]/[lng] وفارق التوقيت [tz] (بالساعات).
  /// [ramadan] يمدّ العشاء إلى 120 دقيقة بعد المغرب.
  /// منفذ أمين لخوارزمية PrayTimes (متحقَّق منه مقابل مواقيت أم القرى).
  static PrayerTimes forDate(
    DateTime date,
    double lat,
    double lng,
    double tz, {
    bool ramadan = false,
  }) {
    final jDate = _julian(date.year, date.month, date.day) - lng / (15.0 * 24.0);

    // القيم الشمسية (ميل الشمس وزمن المعادلة) عند كسر يوم t
    List<double> sun(double t) {
      final d = jDate + t - 2451545.0;
      final g = _fix360(357.529 + 0.98560028 * d);
      final q = _fix360(280.459 + 0.98564736 * d);
      final l = _fix360(q + 1.915 * _sin(g) + 0.020 * _sin(2 * g));
      final e = 23.439 - 0.00000036 * d;
      final ra = _fixHour(_rtd(math.atan2(_cos(e) * _sin(l), _cos(l))) / 15.0);
      final eqt = q / 15.0 - ra;
      final decl = _rtd(math.asin(_sin(e) * _sin(l)));
      return [decl, eqt];
    }

    double midDay(double t) => _fixHour(12.0 - sun(t)[1]);

    double sunAngleTime(double angle, double t, bool ccw) {
      final decl = sun(t)[0];
      final noon = midDay(t);
      final x = (-_sin(angle) - _sin(decl) * _sin(lat)) / (_cos(decl) * _cos(lat));
      final tt = (1.0 / 15.0) * _rtd(math.acos(x.clamp(-1.0, 1.0)));
      return noon + (ccw ? -tt : tt);
    }

    double asrTime(double t) {
      final decl = sun(t)[0];
      final angle = -_rtd(math.atan(1.0 / (1.0 + _tan((lat - decl).abs()))));
      return sunAngleTime(angle, t, false);
    }

    // تقديرات ابتدائية بكسور اليوم
    final fajrH = sunAngleTime(18.5, 5.0 / 24.0, true);
    final sunriseH = sunAngleTime(0.833, 6.0 / 24.0, true);
    final noonH = midDay(12.0 / 24.0);
    final asrH = asrTime(13.0 / 24.0);
    final maghribH = sunAngleTime(0.833, 18.0 / 24.0, false);
    final ishaH = maghribH + (ramadan ? 120 : 90) / 60.0;

    // تحويل للتوقيت المحلي
    double conv(double x) => _fixHour(x + tz - lng / 15.0);

    DateTime at(double h, String key) {
      final totalMin = (conv(h) * 60).round() + (offsets[key] ?? 0);
      final m = ((totalMin % 1440) + 1440) % 1440;
      return DateTime(date.year, date.month, date.day, m ~/ 60, m % 60);
    }

    return PrayerTimes(
      fajr: at(fajrH, 'fajr'),
      sunrise: at(sunriseH, 'sunrise'),
      dhuhr: at(noonH, 'dhuhr'),
      asr: at(asrH, 'asr'),
      maghrib: at(maghribH, 'maghrib'),
      isha: at(ishaH, 'isha'),
    );
  }

  static double _julian(int year, int month, int day) {
    if (month <= 2) {
      year -= 1;
      month += 12;
    }
    final a = (year / 100).floor();
    final b = 2 - a + (a / 4).floor();
    return (365.25 * (year + 4716)).floor() +
        (30.6001 * (month + 1)).floor() +
        day +
        b -
        1524.5;
  }
}

/// مدن سعودية رئيسية (خط العرض/الطول) — التوقيت +3 موحّد.
class SaudiCity {
  final String name;
  final double lat, lng;
  const SaudiCity(this.name, this.lat, this.lng);
}

const List<SaudiCity> saudiCities = [
  SaudiCity('الرياض', 24.7136, 46.6753),
  SaudiCity('مكة المكرمة', 21.3891, 39.8579),
  SaudiCity('المدينة المنورة', 24.5247, 39.5692),
  SaudiCity('جدة', 21.4858, 39.1925),
  SaudiCity('الدمام', 26.4207, 50.0888),
  SaudiCity('الخبر', 26.2794, 50.2083),
  SaudiCity('الأحساء', 25.3833, 49.5833),
  SaudiCity('الطائف', 21.2703, 40.4158),
  SaudiCity('بريدة', 26.3260, 43.9750),
  SaudiCity('تبوك', 28.3838, 36.5550),
  SaudiCity('أبها', 18.2164, 42.5053),
  SaudiCity('خميس مشيط', 18.3000, 42.7300),
  SaudiCity('حائل', 27.5114, 41.7208),
  SaudiCity('نجران', 17.4917, 44.1322),
  SaudiCity('جازان', 16.8892, 42.5511),
  SaudiCity('الجبيل', 27.0174, 49.6225),
  SaudiCity('ينبع', 24.0895, 38.0618),
  SaudiCity('عرعر', 30.9753, 41.0381),
  SaudiCity('سكاكا', 29.9697, 40.2064),
  SaudiCity('الباحة', 20.0129, 41.4677),
];
