import 'package:flutter/material.dart';
import '../../services/module_service.dart';
import 'field_def.dart';

/// نموذج عام لإضافة/تعديل عنصر في أي موديول، مبني من قائمة FieldDef.
class GenericFormScreen extends StatefulWidget {
  final ModuleDef def;
  final Map<String, dynamic>? existing;
  const GenericFormScreen({super.key, required this.def, this.existing});

  @override
  State<GenericFormScreen> createState() => _GenericFormScreenState();
}

class _GenericFormScreenState extends State<GenericFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, dynamic> _values;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _values = {};
    for (final f in widget.def.fields) {
      final v = widget.existing?[f.key] ?? widget.existing?[_snake(f.key)];
      if (f.type == FieldType.toggle) {
        _values[f.key] = (v == 1 || v == true);
      } else if (v != null) {
        _values[f.key] = v.toString();
      }
    }
  }

  String _snake(String s) => s.replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

  Future<void> _pickDate(FieldDef f) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) {
      setState(() => _values[f.key] =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _pickTime(FieldDef f) async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) {
      setState(() => _values[f.key] =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _saving = true);
    try {
      final svc = ModuleService(widget.def.path);
      final body = <String, dynamic>{};
      _values.forEach((k, v) {
        if (v is bool) {
          body[k] = v;
        } else if (v != null && v.toString().isNotEmpty) {
          body[k] = v;
        }
      });
      if (widget.existing != null && widget.existing!['id'] != null) {
        await svc.update(widget.existing!['id'] as int, body);
      } else {
        await svc.create(body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الحفظ: $e')));
      }
    }
  }

  Widget _buildField(FieldDef f) {
    switch (f.type) {
      case FieldType.toggle:
        return SwitchListTile(
          title: Text(f.label),
          value: _values[f.key] == true,
          onChanged: (v) => setState(() => _values[f.key] = v),
        );
      case FieldType.dropdown:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: DropdownButtonFormField<String>(
            value: _values[f.key] as String?,
            decoration: InputDecoration(labelText: f.label, border: const OutlineInputBorder()),
            items: (f.options ?? [])
                .map((o) => DropdownMenuItem(value: o.value, child: Text(o.label)))
                .toList(),
            validator: (v) => (f.required && (v == null || v.isEmpty)) ? 'مطلوب' : null,
            onChanged: (v) => setState(() => _values[f.key] = v),
          ),
        );
      case FieldType.date:
      case FieldType.time:
        final isDate = f.type == FieldType.date;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: InkWell(
            onTap: () => isDate ? _pickDate(f) : _pickTime(f),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: f.label,
                border: const OutlineInputBorder(),
                suffixIcon: Icon(isDate ? Icons.calendar_today : Icons.access_time),
              ),
              child: Text(_values[f.key]?.toString() ?? 'اختر...'),
            ),
          ),
        );
      default:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: TextFormField(
            initialValue: _values[f.key] as String?,
            maxLines: f.type == FieldType.multiline ? 3 : 1,
            keyboardType: f.type == FieldType.number ? TextInputType.number : TextInputType.text,
            decoration: InputDecoration(
              labelText: f.label,
              hintText: f.hint,
              border: const OutlineInputBorder(),
            ),
            validator: (v) => (f.required && (v == null || v.trim().isEmpty)) ? 'مطلوب' : null,
            onSaved: (v) => _values[f.key] = v?.trim(),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null && widget.existing!['id'] != null;
    return Scaffold(
      appBar: AppBar(title: Text('${editing ? 'تعديل' : 'إضافة'} — ${widget.def.title}')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ...widget.def.fields.map(_buildField),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(_saving ? 'جاري الحفظ...' : 'حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}
