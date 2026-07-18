import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'field_def.dart';
import '../../services/api_client.dart';
import '../cars/car_service_log_screen.dart';
import '../family/medical_files_screen.dart';
import '../meds/meds_form_screen.dart';

/// سجل كل موديولات جاسر — كل تعريف يولّد شاشة قائمة + نموذج تلقائياً.
class ModuleRegistry {
  static final ModuleDef meds = ModuleDef(
    title: 'الأدوية',
    icon: Icons.medication_outlined,
    path: '/api/v1/meds',
    titleOf: (m) => '${m['name'] ?? 'دواء'}${m['dose'] != null ? ' — ${m['dose']}' : ''}',
    subtitleOf: (m) {
      final slots = m['time_slots'];
      final remain = m['remaining_pills'];
      final parts = <String>[];
      if (slots != null && slots.toString().isNotEmpty) parts.add('المواعيد: $slots');
      if (remain != null) parts.add('المتبقي: $remain حبة');
      return parts.join('  •  ');
    },
    actions: const [ModuleAction('أخذت الجرعة', Icons.check_circle_outline, 'taken', 'تم تسجيل الجرعة ✅')],
    // نموذج مخصّص للأدوية (قائمة ساعات/أيام بحقل متغيّر)
    formBuilder: (ctx, existing) => MedsFormScreen(existing: existing),
    fields: const [
      FieldDef('name', 'اسم الدواء', required: true),
    ],
    itemActionIcon: Icons.vpn_key_outlined,
    itemActionTooltip: 'دعوة متابِع',
    itemAction: (ctx, m) async {
      try {
        final res = await ApiClient.instance.dio.post('/api/v1/meds/${m['id']}/caregiver-invite');
        final code = res.data['code']?.toString() ?? '';
        if (!ctx.mounted) return;
        showDialog(
          context: ctx,
          builder: (_) => AlertDialog(
            title: const Text('دعوة متابِع للدواء'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('أعطِ هذا الكود للمتابِع — يدخله في جاسر (المحادثة: "متابع [الكود]") ليتابع الدواء ويوصله تنبيه لو ما تأكّدت الجرعة:',
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              SelectableText(code, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 3)),
            ]),
            actions: [
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('نُسخ الكود: $code')));
                },
                child: const Text('نسخ'),
              ),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
            ],
          ),
        );
      } catch (e) {
        if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('تعذّرت الدعوة')));
      }
    },
  );

  static final ModuleDef measurements = ModuleDef(
    title: 'القياسات الصحية',
    icon: Icons.monitor_heart_outlined,
    path: '/api/v1/measurements',
    titleOf: (m) => '${m['type'] ?? 'قياس'}: ${m['value'] ?? ''}',
    subtitleOf: (m) => m['measured_at']?.toString() ?? '',
    fields: const [
      FieldDef('type', 'نوع القياس', type: FieldType.dropdown, required: true, options: [
        FieldOption('ضغط', 'ضغط'),
        FieldOption('سكر', 'سكر'),
        FieldOption('وزن', 'وزن'),
        FieldOption('حرارة', 'حرارة'),
        FieldOption('نبض', 'نبض'),
      ]),
      FieldDef('value', 'القيمة', required: true, hint: '120/80، 5.6...'),
      FieldDef('notes', 'ملاحظات', type: FieldType.multiline),
    ],
  );

  static final ModuleDef documents = ModuleDef(
    title: 'وثائقي',
    icon: Icons.description_outlined,
    path: '/api/v1/documents',
    titleOf: (m) => '${m['name'] ?? m['type'] ?? 'وثيقة'}',
    subtitleOf: (m) {
      final parts = <String>[];
      if (m['person_name'] != null) parts.add('${m['person_name']}');
      if (m['doc_number'] != null) parts.add('رقم: ${m['doc_number']}');
      if (m['expiry_date'] != null) parts.add('تنتهي: ${m['expiry_date']}');
      return parts.join('  •  ');
    },
    fields: const [
      FieldDef('type', 'نوع الوثيقة', hint: 'إقامة، هوية، جواز...'),
      FieldDef('name', 'الاسم/الجهة'),
      FieldDef('personName', 'صاحب الوثيقة'),
      FieldDef('docNumber', 'رقم الوثيقة'),
      FieldDef('issueDate', 'تاريخ الإصدار', type: FieldType.date),
      FieldDef('expiryDate', 'تاريخ الانتهاء', type: FieldType.date),
      FieldDef('remindBefore', 'التذكير قبل (أيام)', type: FieldType.number),
    ],
  );

  static final ModuleDef family = ModuleDef(
    title: 'العائلة',
    icon: Icons.family_restroom_outlined,
    path: '/api/v1/family',
    titleOf: (m) => '${m['nickname'] ?? m['first_name'] ?? m['name'] ?? 'فرد'}',
    subtitleOf: (m) {
      final parts = <String>[];
      if (m['relation'] != null) parts.add('${m['relation']}');
      if (m['national_id'] != null) parts.add('🆔 ${m['national_id']}');
      return parts.join('  •  ');
    },
    fields: const [
      FieldDef('firstName', 'الاسم الأول', required: true),
      FieldDef('secondName', 'الاسم الثاني'),
      FieldDef('thirdName', 'الاسم الثالث'),
      FieldDef('nickname', 'اللقب'),
      FieldDef('relation', 'صلة القرابة', hint: 'ابن، أخ، والدة...'),
      FieldDef('nationalId', 'رقم الهوية', type: FieldType.number),
      FieldDef('nameEn', 'الاسم بالإنجليزي', hint: 'Jaber Ali'),
      FieldDef('dobGreg', 'تاريخ الميلاد (ميلادي)', type: FieldType.date),
      FieldDef('dobHijri', 'تاريخ الميلاد (هجري)', hint: '1436-07-14'),
      FieldDef('passportNo', 'رقم الجواز'),
    ],
    itemScreen: (ctx, m) => MedicalFilesScreen(
      memberId: m['id'] as int,
      memberName: (m['nickname'] ?? m['first_name'] ?? 'فرد').toString(),
    ),
    itemScreenIcon: Icons.folder_shared_outlined,
    itemScreenTooltip: 'الملفات الطبية',
  );

  static final ModuleDef contacts = ModuleDef(
    title: 'أطباء ومستشفيات',
    icon: Icons.local_hospital_outlined,
    path: '/api/v1/contacts',
    titleOf: (m) => '${m['nickname'] ?? m['real_name'] ?? 'جهة'}',
    subtitleOf: (m) {
      final parts = <String>[];
      if (m['relationship'] != null) parts.add('${m['relationship']}');
      if (m['whatsapp'] != null) parts.add('واتساب');
      return parts.join('  •  ');
    },
    fields: const [
      FieldDef('nickname', 'الاسم', required: true, hint: 'د. خالد، مستشفى الملك فهد...'),
      FieldDef('realName', 'الاسم الكامل / الجهة'),
      FieldDef('relationship', 'النوع', hint: 'طبيب، مستشفى، صيدلية، مزوّد خدمة'),
      FieldDef('whatsapp', 'رقم واتساب/جوال', type: FieldType.number),
      FieldDef('telegram', 'وسيلة أخرى'),
    ],
  );

  static final ModuleDef cars = ModuleDef(
    title: 'سياراتي',
    icon: Icons.directions_car_outlined,
    path: '/api/v1/cars',
    titleOf: (m) => '${m['name'] ?? m['make'] ?? 'سيارة'}${m['model'] != null ? ' ${m['model']}' : ''}',
    subtitleOf: (m) {
      final parts = <String>[];
      if (m['plate'] != null) parts.add('لوحة: ${m['plate']}');
      if (m['last_odometer'] != null) parts.add('العداد: ${m['last_odometer']}');
      return parts.join('  •  ');
    },
    fields: const [
      FieldDef('name', 'اسم/نوع السيارة', required: true),
      FieldDef('make', 'الصانع', hint: 'تويوتا، فورد...'),
      FieldDef('model', 'الموديل'),
      FieldDef('year', 'سنة الصنع', type: FieldType.number),
      FieldDef('color', 'اللون'),
      FieldDef('plate', 'رقم اللوحة'),
      FieldDef('chassisNumber', 'رقم الشاصي (الهيكل)'),
      FieldDef('vin', 'الرقم التسلسلي (VIN)'),
      FieldDef('odometer', 'قراءة العداد', type: FieldType.number),
      FieldDef('registrationExpiry', 'انتهاء الاستمارة', type: FieldType.date),
      FieldDef('inspectionExpiry', 'انتهاء الفحص', type: FieldType.date),
      FieldDef('insuranceExpiry', 'انتهاء التأمين', type: FieldType.date),
    ],
    itemScreen: (ctx, m) => CarServiceLogScreen(
      carId: m['id'] as int,
      carName: (m['name'] ?? m['make'] ?? 'سيارة').toString(),
    ),
    itemScreenIcon: Icons.build_outlined,
    itemScreenTooltip: 'سجل الصيانة',
  );

  static final ModuleDef debts = ModuleDef(
    title: 'الديون',
    icon: Icons.account_balance_wallet_outlined,
    path: '/api/v1/debts',
    titleOf: (m) => '${m['person_name'] ?? ''} — ${m['remaining'] ?? m['amount']} ريال',
    subtitleOf: (m) => '${m['direction'] == 'لي' ? 'لي عند' : 'علي لـ'} ${m['person_name'] ?? ''}'
        '${m['due_date'] != null ? '  •  يستحق: ${m['due_date']}' : ''}',
    actions: const [ModuleAction('سداد كامل', Icons.paid_outlined, 'pay', 'تم تسجيل السداد ✅')],
    fields: const [
      FieldDef('direction', 'النوع', type: FieldType.dropdown, required: true, options: [
        FieldOption('علي', 'علي (دين عليّ)'),
        FieldOption('لي', 'لي (دين لي عند غيري)'),
      ]),
      FieldDef('personName', 'اسم الشخص', required: true),
      FieldDef('amount', 'المبلغ', type: FieldType.number, required: true),
      FieldDef('dueDate', 'تاريخ الاستحقاق', type: FieldType.date),
      FieldDef('notes', 'ملاحظات', type: FieldType.multiline),
    ],
  );

  static final ModuleDef shopping = ModuleDef(
    title: 'مشترياتي',
    icon: Icons.shopping_cart_outlined,
    path: '/api/v1/shopping',
    titleOf: (m) => '${m['name'] ?? m['ingredient_name'] ?? 'عنصر'}',
    subtitleOf: (m) {
      final parts = <String>[];
      if (m['quantity'] != null) parts.add('الكمية: ${m['quantity']}');
      if (m['category'] != null) parts.add('${m['category']}');
      return parts.join('  •  ');
    },
    actions: const [ModuleAction('تم الشراء', Icons.check_circle_outline, 'done', 'تم التأشير ✅')],
    fields: const [
      FieldDef('name', 'اسم المنتج', required: true),
      FieldDef('quantity', 'الكمية'),
      FieldDef('category', 'التصنيف', hint: 'خضار، ألبان...'),
      FieldDef('notes', 'ملاحظات'),
    ],
  );

  static final ModuleDef workers = ModuleDef(
    title: 'عمالتي',
    icon: Icons.engineering_outlined,
    path: '/api/v1/workers',
    titleOf: (m) => '${m['name'] ?? 'عامل'}',
    subtitleOf: (m) {
      final parts = <String>[];
      if (m['job_title'] != null) parts.add('${m['job_title']}');
      if (m['iqama_expiry'] != null) parts.add('إقامة تنتهي: ${m['iqama_expiry']}');
      return parts.join('  •  ');
    },
    fields: const [
      FieldDef('name', 'الاسم', required: true),
      FieldDef('nationality', 'الجنسية'),
      FieldDef('jobTitle', 'المهنة'),
      FieldDef('birthDate', 'تاريخ الميلاد', type: FieldType.date),
      FieldDef('iqamaNumber', 'رقم الإقامة', type: FieldType.number),
      FieldDef('iqamaExpiry', 'انتهاء الإقامة', type: FieldType.date),
      FieldDef('passportNumber', 'رقم الجواز'),
      FieldDef('passportExpiry', 'انتهاء الجواز', type: FieldType.date),
      FieldDef('passportSource', 'مصدر الجواز', hint: 'مثال: الرياض'),
      FieldDef('passportMrz', 'الرقم أسفل الجواز', hint: 'آخر سطر في الجواز — ٨ أو ١٠ رموز'),
      FieldDef('notes', 'ملاحظات', type: FieldType.multiline),
    ],
  );

  static final ModuleDef sizes = ModuleDef(
    title: 'مقاساتي',
    icon: Icons.straighten_outlined,
    path: '/api/v1/sizes',
    titleOf: (m) => '${m['label'] ?? m['category'] ?? 'مقاس'}',
    subtitleOf: (m) {
      final parts = <String>[];
      if (m['size_value'] != null) parts.add('المقاس: ${m['size_value']}');
      if (m['category'] != null) parts.add('${m['category']}');
      return parts.join('  •  ');
    },
    fields: const [
      FieldDef('category', 'التصنيف', type: FieldType.dropdown, required: true, options: [
        FieldOption('ملابس', 'ملابس'),
        FieldOption('أحذية', 'أحذية'),
        FieldOption('أبعاد', 'أبعاد (غرفة/أثاث)'),
        FieldOption('أخرى', 'أخرى'),
      ]),
      FieldDef('label', 'لمن/ماذا؟', hint: 'الجوري، غرفة النوم...', required: true),
      FieldDef('sizeValue', 'القيمة/المقاس', hint: 'L، 42، 3×4م...'),
      FieldDef('notes', 'ملاحظات'),
    ],
  );

  static final ModuleDef schedule = ModuleDef(
    title: 'جدولي والمحاضرات',
    icon: Icons.calendar_view_week_outlined,
    path: '/api/v1/schedule',
    titleOf: (m) => '${m['title'] ?? 'عنصر'}',
    subtitleOf: (m) {
      final parts = <String>[];
      if (m['start_time'] != null) parts.add('${m['start_time']}${m['end_time'] != null ? '-${m['end_time']}' : ''}');
      if (m['location'] != null) parts.add('${m['location']}');
      return parts.join('  •  ');
    },
    actions: const [ModuleAction('تم', Icons.check_circle_outline, 'complete', 'تم التأشير ✅')],
    fields: const [
      FieldDef('title', 'العنوان', required: true),
      FieldDef('itemType', 'النوع', type: FieldType.dropdown, options: [
        FieldOption('lecture', 'محاضرة'),
        FieldOption('meeting', 'اجتماع'),
        FieldOption('task', 'مهمة'),
      ]),
      FieldDef('recurrenceDays', 'أيام التكرار', hint: '1,3,5 (الأحد=0)'),
      FieldDef('startTime', 'وقت البدء', type: FieldType.time),
      FieldDef('endTime', 'وقت الانتهاء', type: FieldType.time),
      FieldDef('location', 'المكان'),
      FieldDef('buildingNo', 'المبنى/القاعة'),
    ],
  );

  static final ModuleDef links = ModuleDef(
    title: 'روابطي',
    icon: Icons.link_outlined,
    path: '/api/v1/links',
    titleOf: (m) => '${m['title'] ?? m['url'] ?? 'رابط'}',
    subtitleOf: (m) => '${m['url'] ?? ''}',
    fields: const [
      FieldDef('url', 'الرابط', required: true, hint: 'https://...'),
      FieldDef('title', 'العنوان'),
      FieldDef('category', 'التصنيف'),
      FieldDef('description', 'وصف', type: FieldType.multiline),
    ],
    itemActionIcon: Icons.open_in_new,
    itemActionTooltip: 'فتح الرابط',
    itemAction: (ctx, m) async {
      final raw = (m['url'] ?? '').toString().trim();
      if (raw.isEmpty) return;
      final uri = Uri.parse(raw.startsWith('http') ? raw : 'https://$raw');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('تعذر فتح الرابط')));
      }
    },
  );

  /// كل الموديولات العامة القابلة للعرض عبر شاشة "الخدمات".
  static final List<ModuleDef> all = [
    meds, measurements, documents, family, contacts,
    cars, debts, shopping, workers, sizes, schedule, links,
  ];
}
