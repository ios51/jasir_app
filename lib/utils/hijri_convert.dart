/// تحويل التاريخ الهجري ↔ الميلادي (التقويم الهجري الجدولي).
///
/// ملاحظة: التقويم الجدولي حسابي وقد يختلف عن أم القرى بيوم واحد في
/// بعض التواريخ — لذلك الحقلان يبقيان قابلين للتعديل اليدوي للتصحيح.
class HijriConvert {
  HijriConvert._();

  // ── يوم جوليان من ميلادي ──
  static int _g2jdn(int y, int m, int d) {
    final a = (14 - m) ~/ 12;
    final y2 = y + 4800 - a;
    final m2 = m + 12 * a - 3;
    return d + (153 * m2 + 2) ~/ 5 + 365 * y2 + y2 ~/ 4 - y2 ~/ 100 + y2 ~/ 400 - 32045;
  }

  // ── ميلادي من يوم جوليان ──
  static DateTime _jdn2g(int j) {
    final a = j + 32044;
    final b = (4 * a + 3) ~/ 146097;
    final c = a - 146097 * b ~/ 4;
    final d2 = (4 * c + 3) ~/ 1461;
    final e = c - 1461 * d2 ~/ 4;
    final m2 = (5 * e + 2) ~/ 153;
    return DateTime(
      100 * b + d2 - 4800 + m2 ~/ 10,
      m2 + 3 - 12 * (m2 ~/ 10),
      e - (153 * m2 + 2) ~/ 5 + 1,
    );
  }

  // ── يوم جوليان من هجري ──
  static int _h2jdn(int y, int m, int d) {
    return d + ((29.5 * (m - 1)).ceil()) + (y - 1) * 354 + (3 + 11 * y) ~/ 30 + 1948440 - 1;
  }

  // ── هجري من يوم جوليان ──
  static List<int> _jdn2h(int j) {
    var l = j - 1948440 + 10632;
    final n = (l - 1) ~/ 10631;
    l = l - 10631 * n + 354;
    final jj = ((10985 - l) ~/ 5316) * (50 * l ~/ 17719) + (l ~/ 5670) * (43 * l ~/ 15238);
    l = l - ((30 - jj) ~/ 15) * (17719 * jj ~/ 50) - (jj ~/ 16) * (15238 * jj ~/ 43) + 29;
    final m = 24 * l ~/ 709;
    final d = l - 709 * m ~/ 24;
    final y = 30 * n + jj - 30;
    return [y, m, d];
  }

  static String _pad(int v) => v.toString().padLeft(2, '0');

  /// ميلادي → هجري كنص "yyyy-mm-dd" (مثال: 1401-09-13).
  static String gregorianToHijri(DateTime g) {
    final h = _jdn2h(_g2jdn(g.year, g.month, g.day));
    return '${h[0]}-${_pad(h[1])}-${_pad(h[2])}';
  }

  /// هجري (نص "yyyy-mm-dd" أو "yyyy/mm/dd") → ميلادي، أو null لو الصيغة غير صالحة.
  static DateTime? hijriToGregorian(String hijri) {
    final m = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$').firstMatch(hijri.trim());
    if (m == null) return null;
    final y = int.parse(m.group(1)!), mo = int.parse(m.group(2)!), d = int.parse(m.group(3)!);
    if (mo < 1 || mo > 12 || d < 1 || d > 30) return null;
    if (y < 1300 || y > 1500) return null; // نطاق منطقي لتواريخ الميلاد
    return _jdn2g(_h2jdn(y, mo, d));
  }

  /// ميلادي كنص "yyyy-mm-dd".
  static String fmtGreg(DateTime g) => '${g.year.toString().padLeft(4, '0')}-${_pad(g.month)}-${_pad(g.day)}';
}
