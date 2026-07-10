import 'package:flutter/material.dart';
import '../../theme/theme_controller.dart';

/// إعدادات عامة: المظهر (فاتح/داكن/تلقائي) وحجم الخط.
class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final _tc = ThemeController.instance;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الإعدادات')),
        body: AnimatedBuilder(
          animation: _tc,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 8, 4, 8),
                child: Text('المظهر',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              RadioListTile<ThemeMode>(
                title: const Text('تلقائي (حسب الجهاز)'),
                value: ThemeMode.system,
                groupValue: _tc.mode,
                onChanged: (v) => _tc.setMode(v!),
              ),
              RadioListTile<ThemeMode>(
                title: const Text('فاتح'),
                value: ThemeMode.light,
                groupValue: _tc.mode,
                onChanged: (v) => _tc.setMode(v!),
              ),
              RadioListTile<ThemeMode>(
                title: const Text('داكن'),
                value: ThemeMode.dark,
                groupValue: _tc.mode,
                onChanged: (v) => _tc.setMode(v!),
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 12, 4, 4),
                child: Text('حجم الخط',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              Row(
                children: [
                  const Text('أ', style: TextStyle(fontSize: 14)),
                  Expanded(
                    child: Slider(
                      min: 0.85,
                      max: 1.4,
                      divisions: 11,
                      value: _tc.fontScale.clamp(0.85, 1.4),
                      label: '${(_tc.fontScale * 100).round()}%',
                      onChanged: (v) => _tc.setFontScale(v),
                    ),
                  ),
                  const Text('أ', style: TextStyle(fontSize: 26)),
                ],
              ),
              Center(
                child: Text('معاينة: صباح الخير، عندك موعد بكرة',
                    style: TextStyle(fontSize: 16 * _tc.fontScale)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
