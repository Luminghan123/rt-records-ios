import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../models/record.dart';
import '../state/app_state.dart';
import '../utils/date_fmt.dart';
import '../pdf/rt_pdf.dart';

/// 设置 → 导出 PDF：按日期段（全部患者）或单个患者全疗程导出
class ExportPage extends StatefulWidget {
  const ExportPage({super.key, this.patientKey});

  /// 从"患者当天工作台"进入时，自动切到该患者的全疗程模式
  final String? patientKey;

  @override
  State<ExportPage> createState() => _ExportPageState();
}

enum _ExportMode { range, patient }

class _ExportPageState extends State<ExportPage> {
  late _ExportMode _mode;
  late DateTime _from;
  late DateTime _to;
  String? _patientKey;
  bool _includeHome = true;
  bool _includeVent = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _to = DateTime(now.year, now.month, now.day);
    _from = _to.subtract(const Duration(days: 30));
    if (widget.patientKey != null) {
      _mode = _ExportMode.patient;
      _patientKey = widget.patientKey;
    } else {
      _mode = _ExportMode.range;
    }
  }

  List<PatientForm> _targetForms(AppState state) {
    if (_mode == _ExportMode.patient) {
      return _patientKey == null
          ? const []
          : state.allFormsForPatient(_patientKey!);
    }
    return state.formsInRange(_from, _to);
  }

  Future<void> _pickDate(bool isFrom) async {
    final initial = isFrom ? _from : _to;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 2),
      helpText: isFrom ? '开始日期' : '结束日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked;
        if (_from.isAfter(_to)) _from = _to;
      }
    });
  }

  Future<void> _generate({required bool share}) async {
    if (_busy) return;
    final state = context.read<AppState>();
    final forms = _targetForms(state);
    if (forms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('所选范围内没有记录')),
      );
      return;
    }
    if (!_includeHome && !_includeVent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少勾选一类表格')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final title = _mode == _ExportMode.patient
          ? '呼吸治疗记录_${forms.first.name}_全疗程'
          : '呼吸治疗记录_${formatIso(_from)}_${formatIso(_to)}';
      final result = await buildRtPdf(
        state: state,
        forms: forms,
        title: title,
        includePatientForm: _includeHome,
        includeVentTables: _includeVent,
      );
      if (!mounted) return;
      final filename = '$title.pdf';
      if (share) {
        await Printing.sharePdf(bytes: result.bytes, filename: filename);
      } else {
        // 系统打印/预览界面里可以选择「另存为 PDF」
        await Printing.layoutPdf(
          onLayout: (_) async => result.bytes,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已生成 ${result.pageCount} 页 PDF')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('生成失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final forms = _targetForms(state);
    final history = state.patientHistory();
    var pointCount = 0;
    for (final f in forms) {
      pointCount += state.pointsFor(f.id, f.date, 'invasive').length;
      pointCount += state.pointsFor(f.id, f.date, 'niv').length;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('导出 PDF')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
        children: [
          const Text(
            '按《呼吸治疗教程》附录Ⅱ的表格版式排版：病历首页 A4 纵向；'
            '有创/无创工作记录表 A4 横向（行=监测项目，列=记录时间点）。',
            style: TextStyle(fontSize: 12.5, color: kInkSoft, height: 1.7),
          ),
          const SizedBox(height: 16),
          _card(
            title: '导出范围',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<_ExportMode>(
                  segments: const [
                    ButtonSegment(
                        value: _ExportMode.range,
                        label: Text('按日期段（全部患者）')),
                    ButtonSegment(
                        value: _ExportMode.patient,
                        label: Text('单患者全疗程')),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) =>
                      setState(() => _mode = s.first),
                ),
                const SizedBox(height: 12),
                if (_mode == _ExportMode.range)
                  Row(
                    children: [
                      Expanded(
                          child: _dateButton('开始 ${formatIso(_from)}',
                              () => _pickDate(true))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _dateButton('结束 ${formatIso(_to)}',
                              () => _pickDate(false))),
                    ],
                  )
                else
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: _patientKey,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: '选择患者'),
                    hint: const Text('请选择患者', style: TextStyle(fontSize: 13)),
                    items: history
                        .map((f) => DropdownMenuItem<String>(
                              value: f.patientKey,
                              child: Text(
                                '${f.displayName}　病历号 ${f.mrn}　'
                                '(${f.date} 起)',
                                style: const TextStyle(fontSize: 12.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _patientKey = v),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            title: '包含内容',
            child: Column(
              children: [
                CheckboxListTile(
                  value: _includeHome,
                  title: const Text('一、呼吸治疗病历首页',
                      style: TextStyle(fontSize: 13.5)),
                  subtitle: const Text('A4 纵向，按分组逐行排版',
                      style: TextStyle(fontSize: 11.5)),
                  onChanged: (v) => setState(() => _includeHome = v ?? true),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  value: _includeVent,
                  title: const Text('二 / 三、有创与无创通气工作记录表',
                      style: TextStyle(fontSize: 13.5)),
                  subtitle: const Text('A4 横向，每页 5 个时间点，超出自动续页',
                      style: TextStyle(fontSize: 11.5)),
                  onChanged: (v) => setState(() => _includeVent = v ?? true),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            title: '将要导出',
            child: Text(
              '${forms.length} 份病历首页 · ${forms.length} 位患者日记录 · '
              '$pointCount 个通气时间点',
              style: const TextStyle(fontSize: 13, color: kInk, height: 1.6),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : () => _generate(share: false),
            icon: const Icon(Icons.print_outlined, size: 18),
            label: Text(_busy ? '生成中…' : '预览 / 打印（可另存为 PDF）'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _generate(share: true),
            icon: const Icon(Icons.share_outlined, size: 18),
            label: const Text('生成并分享 / 保存 PDF 文件'),
          ),
          const SizedBox(height: 14),
          const Text(
            '提示：安卓系统打印界面里选「保存为 PDF」即可把文件存到手机；'
            '「分享」可直接发送到微信、邮箱或文件管理器。',
            style: TextStyle(fontSize: 11.5, color: kInkSoft, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _dateButton(String text, VoidCallback onTap) => OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.event_outlined, size: 16),
        label: Text(text, style: const TextStyle(fontSize: 12)),
      );

  Widget _card({required String title, required Widget child}) => Card(
        color: kCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: kDivider),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kPrimary)),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      );
}
