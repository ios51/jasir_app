import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// رمز الريال السعودي الرسمي (SVG من ساما — sama.gov.sa/ar-sa/Currency/SRS).
/// نستخدم الأيقونة لا حرف اليونيكود U+20C0 لأن خطوط التطبيق لا تدعمه بعد.
class Riyal extends StatelessWidget {
  final double size;
  final Color? color;
  const Riyal({super.key, this.size = 14, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? DefaultTextStyle.of(context).style.color ?? Theme.of(context).colorScheme.onSurface;
    return SvgPicture.asset(
      'assets/riyal.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
    );
  }
}

/// مبلغ + رمز الريال في سطر واحد: «30 ⃀» — للاستخدام في أي مكان فيه مبلغ.
class RiyalAmount extends StatelessWidget {
  final num amount;
  final TextStyle? style;
  const RiyalAmount(this.amount, {super.key, this.style});

  String get _fmt =>
      amount % 1 == 0 ? amount.toInt().toString() : amount.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final s = style ?? DefaultTextStyle.of(context).style;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(_fmt, style: s),
        const SizedBox(width: 3),
        Riyal(size: (s.fontSize ?? 14) * 0.85, color: s.color),
      ],
    );
  }
}
