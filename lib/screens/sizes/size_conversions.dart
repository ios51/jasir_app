/// تحويلات المقاسات (تقريبية — تختلف قليلاً حسب الماركة).
class SizeConvert {
  static String _f(double v) =>
      v <= 0 ? '—' : (v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1));

  /// حذاء: من المقاس الأوروبي (EU) إلى US و UK حسب الجنس.
  /// gender: men | women | kids
  static Map<String, String> shoe(double eu, String gender) {
    double us, uk;
    if (gender == 'women') {
      us = eu - 30;
      uk = eu - 32.5;
    } else if (gender == 'kids') {
      us = eu - 15.5;
      uk = eu - 16;
    } else {
      us = eu - 33;
      uk = eu - 33.5;
    }
    return {'EU': _f(eu), 'US': _f(us), 'UK': _f(uk)};
  }

  /// برا: من مقاس الحزام الأوروبي (سم) إلى الأمريكي (إنش)، الكوب يبقى تقريبياً.
  static Map<String, String> bra(double euBand, String cup) {
    double us = ((euBand + 10) / 2.5);
    us = (us / 2).round() * 2; // لأقرب رقم زوجي
    final c = cup.trim();
    return {'EU': '${euBand.toStringAsFixed(0)}$c', 'US': '${us.toStringAsFixed(0)}$c'};
  }

  /// طول بالسنتيمتر → قدم وإنش.
  static String cmToFtIn(double cm) {
    final inches = cm / 2.54;
    final ft = (inches / 12).floor();
    final inRem = (inches - ft * 12).round();
    if (ft <= 0) return '${inches.toStringAsFixed(1)} إنش';
    return '$ft قدم و$inRem إنش';
  }

  /// متر → قدم.
  static String mToFeet(double m) => '${(m * 3.28084).toStringAsFixed(2)} قدم';

  /// سنتيمتر → إنش.
  static String cmToInch(double cm) => '${(cm / 2.54).toStringAsFixed(1)} إنش';

  /// كجم → رطل.
  static String kgToLb(double kg) => '${(kg * 2.20462).toStringAsFixed(1)} رطل';

  /// يُنتج سطر التحويل المناسب لعنصر مقاس، أو null إن ما فيه تحويل.
  static String? line({
    required String type,
    String? value,
    String? unit,
    String? gender,
    double? width,
    double? height,
    double? depth,
  }) {
    double? v = double.tryParse((value ?? '').replaceAll(RegExp(r'[^0-9.]'), ''));
    switch (type) {
      case 'shoe':
        if (v == null) return null;
        final m = shoe(v, gender ?? 'men');
        return 'US ${m['US']}  •  UK ${m['UK']}';
      case 'bra':
        if (v == null) return null;
        final cup = RegExp(r'[A-Za-zأ-ي]+$').firstMatch(value ?? '')?.group(0) ?? '';
        final m = bra(v, cup);
        return 'US ${m['US']}';
      case 'height':
        if (v == null) return null;
        return (unit == 'م') ? mToFeet(v) : cmToFtIn(v);
      case 'waist':
      case 'length':
        if (v == null) return null;
        return (unit == 'م') ? mToFeet(v) : cmToInch(v);
      case 'weight':
        if (v == null) return null;
        return kgToLb(v);
      case 'dimensions':
        final parts = <String>[];
        for (final d in [width, height, depth]) {
          if (d != null && d > 0) parts.add((unit == 'م') ? mToFeet(d) : cmToInch(d));
        }
        return parts.isEmpty ? null : parts.join('  ×  ');
      default:
        return null;
    }
  }
}
