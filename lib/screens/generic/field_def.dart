import 'package:flutter/material.dart';

/// تعريف حقل في نموذج عام (يُستخدم في شاشة الإضافة/التعديل العامة).
class FieldDef {
  final String key;         // اسم الحقل في JSON المرسل للـ API
  final String label;       // العنوان الظاهر للمستخدم
  final FieldType type;
  final bool required;
  final List<FieldOption>? options; // للقوائم المنسدلة
  final String? hint;

  const FieldDef(
    this.key,
    this.label, {
    this.type = FieldType.text,
    this.required = false,
    this.options,
    this.hint,
  });
}

class FieldOption {
  final String value;
  final String label;
  const FieldOption(this.value, this.label);
}

enum FieldType { text, multiline, number, date, time, dropdown, toggle }

/// تعريف موديول كامل: عنوان، أيقونة، مسار API، حقول النموذج،
/// وكيف يُعرض كل عنصر في القائمة.
class ModuleDef {
  final String title;
  final IconData icon;
  final String path; // '/api/v1/meds'
  final List<FieldDef> fields;
  final String Function(Map<String, dynamic> item) titleOf;
  final String Function(Map<String, dynamic> item)? subtitleOf;
  final bool canAdd;
  final bool canDelete;
  final String emptyText;
  // أفعال إضافية على العنصر (زر) مثل "أخذت الجرعة" / "سدد"
  final List<ModuleAction> actions;
  // شاشة فرعية للعنصر (مثل سجل صيانة السيارة) — يظهر زر يفتحها
  final Widget Function(BuildContext context, Map<String, dynamic> item)? itemScreen;
  final IconData? itemScreenIcon;
  final String? itemScreenTooltip;

  const ModuleDef({
    required this.title,
    required this.icon,
    required this.path,
    required this.fields,
    required this.titleOf,
    this.subtitleOf,
    this.canAdd = true,
    this.canDelete = true,
    this.emptyText = 'لا توجد عناصر — اضغط + للإضافة',
    this.actions = const [],
    this.itemScreen,
    this.itemScreenIcon,
    this.itemScreenTooltip,
  });
}

class ModuleAction {
  final String label;
  final IconData icon;
  final String verb; // POST /path/:id/<verb>
  final String successMsg;
  const ModuleAction(this.label, this.icon, this.verb, this.successMsg);
}
