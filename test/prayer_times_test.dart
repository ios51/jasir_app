// اختبارات وحدة لحساب مواقيت الصلاة (طريقة أم القرى) — لمدينة الرياض
// وتاريخ ثابت. لا تعتمد على شبكة ولا secure storage. نتحقق من:
// (1) ترتيب الصلوات الطبيعي، (2) العشاء = المغرب + 90 دقيقة (120 في رمضان)،
// (3) وقوع الظهر قرب منتصف النهار.
import 'package:flutter_test/flutter_test.dart';
import 'package:jasir_app/utils/prayer_times.dart';

void main() {
  // الرياض: خط العرض/الطول من قائمة saudiCities، التوقيت +3.
  const riyadhLat = 24.7136;
  const riyadhLng = 46.6753;
  const tz = 3.0;

  // إعادة ضبط أي إزاحة يدوية قبل كل اختبار حتى تكون النتائج حتمية.
  setUp(() {
    PrayerTimes.offsets = {
      'fajr': 0, 'sunrise': 0, 'dhuhr': 0, 'asr': 0, 'maghrib': 0, 'isha': 0,
    };
  });

  int _min(DateTime a, DateTime b) => b.difference(a).inMinutes;

  group('PrayerTimes — ترتيب الصلوات في الرياض', () {
    final dates = <DateTime>[
      DateTime(2024, 6, 21), // الانقلاب الصيفي
      DateTime(2024, 1, 15), // شتاء
      DateTime(2025, 3, 21), // الاعتدال الربيعي
    ];

    for (final date in dates) {
      test('${date.year}-${date.month}-${date.day}: الفجر < الشروق < الظهر < العصر < المغرب < العشاء', () {
        final p = PrayerTimes.forDate(date, riyadhLat, riyadhLng, tz);
        expect(p.fajr.isBefore(p.sunrise), isTrue, reason: 'الفجر قبل الشروق');
        expect(p.sunrise.isBefore(p.dhuhr), isTrue, reason: 'الشروق قبل الظهر');
        expect(p.dhuhr.isBefore(p.asr), isTrue, reason: 'الظهر قبل العصر');
        expect(p.asr.isBefore(p.maghrib), isTrue, reason: 'العصر قبل المغرب');
        expect(p.maghrib.isBefore(p.isha), isTrue, reason: 'المغرب قبل العشاء');
      });
    }
  });

  test('العشاء = المغرب + 90 دقيقة (أم القرى)', () {
    final p = PrayerTimes.forDate(DateTime(2024, 6, 21), riyadhLat, riyadhLng, tz);
    expect(_min(p.maghrib, p.isha), 90);
  });

  test('في رمضان العشاء = المغرب + 120 دقيقة', () {
    final p = PrayerTimes.forDate(
        DateTime(2024, 3, 15), riyadhLat, riyadhLng, tz,
        ramadan: true);
    expect(_min(p.maghrib, p.isha), 120);
  });

  test('الظهر قرب منتصف النهار (بين 11:30 و 12:30)', () {
    final p = PrayerTimes.forDate(DateTime(2024, 6, 21), riyadhLat, riyadhLng, tz);
    final minutes = p.dhuhr.hour * 60 + p.dhuhr.minute;
    expect(minutes, greaterThanOrEqualTo(11 * 60 + 30));
    expect(minutes, lessThanOrEqualTo(12 * 60 + 30));
  });

  test('الإزاحة اليدوية تُطبَّق على وقت الصلاة', () {
    final base = PrayerTimes.forDate(DateTime(2024, 6, 21), riyadhLat, riyadhLng, tz);
    PrayerTimes.offsets['fajr'] = 5;
    final shifted = PrayerTimes.forDate(DateTime(2024, 6, 21), riyadhLat, riyadhLng, tz);
    expect(_min(base.fajr, shifted.fajr), 5);
  });
}
