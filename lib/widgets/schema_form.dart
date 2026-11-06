import 'package:flutter/material.dart' hide FormField;

import '../app_theme.dart';
import '../models/form_schema.dart';
import '../utils/date_fmt.dart';

/// 通用表单渲染器：把 [FormGroup] 定义直接变成录入界面。
///
/// 值直接写进传入的 [values]（调用方持有），保存时读这个 Map 即可。
/// 如果外部整体替换了 values（例如"复用历史患者"），请给本组件换一个
/// 新的 ValueKey，让文本框重新初始化读取新值。
class SchemaForm extends StatefulWidget {
  const SchemaForm({
    super.key,
    required this.groups,
    required this.values,
    this.initiallyExpanded = true,
    this.groupFooters,
  });

  final List<FormGroup> groups;
  final Map<String, dynamic> values;
  final bool initiallyExpanded;

  /// 按分组名插入的自定义区域，例如「血气分析」分组下面的照片附件区。
  /// 这些 key 不会进入 form_schema 的字段清单，PDF 表格也不会读到。
  final Map<String, Widget>? groupFooters;

  @override
  State<SchemaForm> createState() => _SchemaFormState();
}

class _SchemaFormState extends State<SchemaForm> {
  Future<void> _pickDateTime(FormField f) async {
    final current = parseStamp(widget.values[f.key]?.toString()) ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 2),
      helpText: f.label,
      cancelText: '取消',
      confirmText: '确定',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      helpText: f.label,
      cancelText: '取消',
      confirmText: '确定',
    );
    if (!mounted) return;
    final t = time ?? TimeOfDay.fromDateTime(current);
    setState(() {
      widget.values[f.key] =
          formatStamp(DateTime(date.year, date.month, date.day, t.hour, t.minute));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: widget.groups.map((group) {
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: kCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: kDivider),
          ),
          child: ExpansionTile(
            initiallyExpanded: widget.initiallyExpanded,
            tilePadding: const EdgeInsets.symmetric(horizontal: 14),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            title: Text(
              group.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kPrimary,
              ),
            ),
            children: [
              LayoutBuilder(builder: (context, constraints) {
                final cols = constraints.maxWidth >= 560 ? 3 : 2;
                final w = (constraints.maxWidth - (cols - 1) * 8) / cols;
                return Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  children: group.fields.map((f) {
                    final full = f.kind == FieldKind.longText ||
                        f.kind == FieldKind.multi;
                    return SizedBox(
                      width: full ? constraints.maxWidth : w,
                      child: _buildField(f),
                    );
                  }).toList(),
                );
              }),
              if (widget.groupFooters?[group.name] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: widget.groupFooters![group.name]!,
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildField(FormField f) {
    switch (f.kind) {
      case FieldKind.text:
      case FieldKind.number:
      case FieldKind.longText:
        return TextFormField(
          initialValue: widget.values[f.key]?.toString() ?? '',
          maxLines: f.kind == FieldKind.longText ? 3 : 1,
          keyboardType: f.kind == FieldKind.number
              ? TextInputType.number
              : (f.kind == FieldKind.longText
                  ? TextInputType.multiline
                  : TextInputType.text),
          style: const TextStyle(fontSize: 13, color: kInk),
          decoration: InputDecoration(
            labelText: f.displayLabel,
            hintText: f.hint,
            alignLabelWithHint: f.kind == FieldKind.longText,
          ),
          onChanged: (v) => widget.values[f.key] = v,
        );

      case FieldKind.choice:
      case FieldKind.yesNo:
        final options = f.kind == FieldKind.yesNo
            ? <String>['', '是', '否']
            : <String>['', ...?f.options];
        final raw = widget.values[f.key]?.toString() ?? '';
        return DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: options.contains(raw) ? raw : '',
          isExpanded: true,
          style: const TextStyle(fontSize: 13, color: kInk),
          decoration: InputDecoration(labelText: f.displayLabel),
          items: options
              .map((o) => DropdownMenuItem<String>(
                    value: o,
                    child: Text(
                      o.isEmpty ? '未填' : o,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: (v) => setState(() {
            if (v == null || v.isEmpty) {
              widget.values.remove(f.key);
            } else {
              widget.values[f.key] = v;
            }
          }),
        );

      case FieldKind.multi:
        final selected = (widget.values[f.key] is List)
            ? List<String>.from(widget.values[f.key] as List)
            : <String>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(f.displayLabel,
                style: const TextStyle(fontSize: 12, color: kInkSoft)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 0,
              children: (f.options ?? []).map((o) {
                return FilterChip(
                  label: Text(o, style: const TextStyle(fontSize: 12)),
                  selected: selected.contains(o),
                  onSelected: (on) => setState(() {
                    if (on) {
                      selected.add(o);
                    } else {
                      selected.remove(o);
                    }
                    if (selected.isEmpty) {
                      widget.values.remove(f.key);
                    } else {
                      widget.values[f.key] = selected;
                    }
                  }),
                );
              }).toList(),
            ),
          ],
        );

      case FieldKind.dateTime:
        final text = widget.values[f.key]?.toString() ?? '';
        return InkWell(
          onTap: () => _pickDateTime(f),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: f.displayLabel,
              suffixIcon: const Icon(Icons.event_outlined, size: 17),
            ),
            child: Text(
              text.isEmpty ? '点此选择' : text,
              style: TextStyle(
                fontSize: 13,
                color: text.isEmpty ? const Color(0xFFA9B6C4) : kInk,
              ),
            ),
          ),
        );
    }
  }
}
