import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../models/form_schema.dart';
import '../models/record.dart';
import '../state/app_state.dart';
import '../utils/date_fmt.dart';
import '../widgets/schema_form.dart';
import 'patient_day_page.dart';

/// 病历首页（教程附录Ⅱ 一、呼吸治疗病历首页）
class PatientFormPage extends StatefulWidget {
  const PatientFormPage({super.key, required this.date, this.formId});

  final DateTime date;
  final int? formId;

  @override
  State<PatientFormPage> createState() => _PatientFormPageState();
}

class _PatientFormPageState extends State<PatientFormPage> {
  late Map<String, dynamic> _values;
  late String _uuid;
  int _revision = 0;
  bool _saving = false;

  bool get _isEdit => widget.formId != null;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    PatientForm? existing;
    for (final f in state.forms) {
      if (f.id == widget.formId) {
        existing = f;
        break;
      }
    }
    _uuid = existing?.uuid ?? _newUuid();
    _values = existing != null
        ? Map<String, dynamic>.from(existing.data)
        : <String, dynamic>{
            'record_time': formatStamp(DateTime.now()),
          };
  }

  String _newUuid() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(0xFFFFFF)}';

  /// 跨天复用：选历史患者，自动带出上一次的全部基本信息
  Future<void> _reusePatient() async {
    final history = context.read<AppState>().patientHistory();
    if (history.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('还没有历史患者，先填一份病历首页吧')),
      );
      return;
    }
    final picked = await showDialog<PatientForm>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('复用历史患者'),
        children: history
            .map((f) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, f),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.displayName,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          '病历号 ${f.mrn} · 床号 ${f.bedNo} · 最近 ${f.date}',
                          style: const TextStyle(fontSize: 11, color: kInkSoft),
                        ),
                      ],
                    ),
                  ),
                ))
            .toList(),
      ),
    );
    if (picked == null) return;
    setState(() {
      _values = Map<String, dynamic>.from(picked.data);
      // 时间类字段不沿用，改成这次填写的时刻
      _values['record_time'] = formatStamp(DateTime.now());
      _values.remove('icu_in');
      _revision++; // 换 key，让文本框重新读值
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已带出 ${picked.displayName} 上次的病历内容')),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = (_values['name'] ?? '').toString().trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先填写患者姓名')),
      );
      return;
    }
    setState(() => _saving = true);

    final state = context.read<AppState>();
    final form = PatientForm(
      id: widget.formId,
      uuid: _uuid,
      date: dateKey(widget.date),
      name: name,
      mrn: (_values['mrn'] ?? '').toString().trim(),
      bedNo: (_values['bed_no'] ?? '').toString().trim(),
      data: Map<String, dynamic>.from(_values),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    final id = await state.saveForm(form);
    if (!mounted) return;

    // 保存后直接进入通气方式选择页
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => PatientDayPage(formId: id)),
    );
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这份病历？'),
        content: const Text('该患者当天的有创/无创记录会一并删除，且不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: kDanger)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<AppState>().deleteForm(widget.formId!);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '编辑病历首页' : '新建病历首页'),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: '删除',
              icon: const Icon(Icons.delete_outline, color: kDanger),
              onPressed: _delete,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: kPrimarySoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '记录日期 ${dateKey(widget.date)}',
                    style: const TextStyle(fontSize: 12, color: kPrimary),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _reusePatient,
                  icon: const Icon(Icons.person_search_outlined, size: 17),
                  label: const Text('复用历史患者'),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: SchemaForm(
                key: ValueKey<int>(_revision),
                groups: kPatientGroups,
                values: _values,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: Text(_saving ? '保存中…' : '保存并选择通气记录'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
