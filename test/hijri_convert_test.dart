// اختبارات وحدة لتحويل التاريخ الهجري ↔ الميلادي (تقويم أم القرى الرسمي).
// الحالات المرجعية رؤوس سنوات هجرية معروفة رسميًا في أم القرى، ومتحقَّق
// منها مقابل تطبيق HijriConvert نفسه (ذهابًا وإيابًا بلا فرق يوم).
import 'package:flutter_test/flutter_test.dart';
import 'package:jasir_app/utils/hijri_convert.dart';

void main() {
  group('HijriConvert — ميلادي ← هجري (أم القرى)', () {
    // 1 محرّم لأربع سنوات هجرية موثّقة في تقويم أم القرى.
    final cases = <String, DateTime>{
      '1445-01-01': _d(2023, 7, 19),
      '1440-01-01': _d(2018, 9, 11),
      '1446-01-01': _d(2024, 7, 7),
      '1421-01-01': _d(2000, 4, 6),
    };

    cases.forEach((hijri, greg) {
      test('$hijri هـ ← ${HijriConvert.fmtGreg(greg)} م', () {
        final g = HijriConvert.hijriToGregorian(hijri)!;
        expect(g.year, greg.year);
        expect(g.month, greg.month);
        expect(g.day, greg.day);
      });
    });
  });

  group('HijriConvert — هجري ← ميلادي (أم القرى)', () {
    test('2023-07-19 م → 1445-01-01 هـ', () {
      expect(HijriConvert.gregorianToHijri(_d(2023, 7, 19)), '1445-01-01');
    });
    test('2018-09-11 م → 1440-01-01 هـ', () {
      expect(HijriConvert.gregorianToHijri(_d(2018, 9, 11)), '1440-01-01');
    });
    test('2024-07-07 م → 1446-01-01 هـ', () {
      expect(HijriConvert.gregorianToHijri(_d(2024, 7, 7)), '1446-01-01');
    });
  });

  group('HijriConvert — ذهاب وإياب (round-trip)', () {
    for (final g in <DateTime>[
      _d(2023, 7, 19),
      _d(2000, 4, 6),
      _d(2024, 7, 7),
    ]) {
      test('${HijriConvert.fmtGreg(g)} م ← → هجري ← ميلادي', () {
        final hijri = HijriConvert.gregorianToHijri(g);
        final back = HijriConvert.hijriToGregorian(hijri)!;
        expect(HijriConvert.fmtGreg(back), HijriConvert.fmtGreg(g));
      });
    }
  });

  group('HijriConvert — مدخلات غير صالحة', () {
    test('صيغة خاطئة ترجع null', () {
      expect(HijriConvert.hijriToGregorian('غير صالح'), isNull);
    });
    test('شهر خارج المدى (13) يرجع null', () {
      expect(HijriConvert.hijriToGregorian('1445-13-01'), isNull);
    });
  });
}

/// اختصار لبناء تاريخ ميلادي عند منتصف الليل المحلي.
DateTime _d(int y, int m, int d) => DateTime(y, m, d);
