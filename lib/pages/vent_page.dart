import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../models/form_schema.dart';
import '../models/record.dart';
import '../services/ocr_service.dart';
import '../services/photo_store.dart';
import '../state/app_state.dart';
import '../utils/date_fmt.dart';
import '../widgets/photo_attachments.dart';
import '../widgets/schema_form.dart';
import 'ocr_review_page.dart';

/// 有创 / 无创通气记录页（共用此页，按 [type] 加载不同字段定义）。
///
/// 一个"时间点"= 教程表格里的一列。表头信息（入气道/连接方式）整页一份。
class VentPage extends StatefulWidget {
  const VentPage({super.key, required this.formId, required this.type});

  final int formId;
  final String type;

  @override
  State<VentPage> createState() => _VentPageState();
}

class _PointItem {
  _PointItem(this.key, this.data);

  final int key;
  final Map<String, dynamic> data;

  /// 识别结果回填后自增，用来让这一列的表单重建、显示新值
  int revision = 0;
}

class _VentPageState extends State<VentPage> {
  late PatientForm _form;
  late Map<String, dynamic> _meta;
  final List<_PointItem> _items = [];
  int _nextKey = 1;
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _form = state.forms.firstWhere((f) => f.id == widget.formId);
    final savedMeta = state.metaFor(_form.id, _form.date, widget.type);
    _meta = savedMeta != null
        ? Map<String, dynamic>.from(savedMeta.data)
        : <String, dynamic>{
            // 主要诊断从病历首页带出，少抄一遍
            'main_diagnosis': _form.data['diagnosis'] ?? '',
          };
    for (final p in state.pointsFor(_form.id, _form.date, widget.type)) {
      _items.add(_PointItem(_nextKey++, Map<String, dynamic>.from(p.data)));
    }
  }

  Color get _accent => widget.type == kTypeInvasive ? kInvasive : kNiv;

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  void _addPoint() {
    setState(() {
      _items.add(_PointItem(
        _nextKey++,
        <String, dynamic>{'time': formatStamp(DateTime.now())},
      ));
      _dirty = true;
    });
  }

  void _removePoint(int key) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这个时间点？'),
        content: const Text('该列的全部监测数据会被删除。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除', style: TextStyle(color: kDanger))),
        ],
      ),
    );
    if (ok != true) return;
    // 照片文件由 AppState 在「保存成功」后按前后差集统一清理，
    // 这里不动文件，避免删了时间点又选「不保存」时把原照片误删。
    setState(() {
      _items.removeWhere((e) => e.key == key);
      _dirty = true;
    });
  }

  /// 「血气分析」分组下面的照片附件区（每个时间点各存各的）
  Widget _abgPhotoSection(_PointItem item) {
    return PhotoAttachments(
      values: item.data,
      photoKey: PhotoStore.keyAbg,
      title: '血气报告单照片',
      hint: '拍照或选图后自动识别 pH / PaO₂ 等数值，核对后填入本次血气；'
          '照片只存本机，导出 PDF 不附带。',
      accent: _accent,
      onPhotoAdded: (path) => _recognizeAbg(path, item),
    );
  }

  /// 拍完血气报告单：本机离线识别 -> 人工核对 -> 填入这一列
  Future<void> _recognizeAbg(String imagePath, _PointItem item) async {
    try {
      final raw = await OcrService.recognize(imagePath);
      final candidates = OcrService.parseAbg(raw);
      if (!mounted) return;
      final picked = await Navigator.of(context).push<Map<String, String>>(
        MaterialPageRoute(
          builder: (_) => OcrReviewPage(
            title: '血气识别结果核对',
            imagePath: imagePath,
            candidates: candidates,
            rawText: raw,
          ),
        ),
      );
      if (picked == null || picked.isEmpty) return;
      setState(() {
        item.data.addAll(picked);
        item.revision++; // 换 key，让这一列的文本框重新读取刚填入的值
        _dirty = true;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已填入 ${picked.length} 项，请核对后保存')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('识别失败：$e\n照片已保存，可以手动填写')),
      );
    }
  }

  Future<void> _save({bool pop = true}) async {
    if (_saving) return;
    setState(() => _saving = true);
    final state = context.read<AppState>();
    await state.saveVent(
      form: _form,
      type: widget.type,
      metaData: _meta,
      points: _items.map((e) => e.data).toList(),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _dirty = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已保存')),
    );
    if (pop) Navigator.of(context).pop();
  }

  Future<void> _handleLeave() async {
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('还有未保存的内容'),
        content: const Text('离开前要保存吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'stay'),
              child: const Text('继续编辑')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'discard'),
              child: const Text('不保存', style: TextStyle(color: kDanger))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, 'save'),
              child: const Text('保存并返回')),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'save') {
      await _save();
    } else if (choice == 'discard') {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${typeTitle(widget.type)}记录表'),
          leading: IconButton(
            tooltip: '返回',
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleLeave,
          ),
          actions: [
            TextButton(
              onPressed: _saving ? null : () => _save(pop: false),
              child: Text(_saving ? '保存中…' : '保存'),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
          children: [
            _patientHeader(),
            const SizedBox(height: 8),
            // 表头信息（入气道 / 连接方式 / 呼吸机）
            Text(
              widget.type == kTypeInvasive
                  ? '表头信息 · 入气道 / 呼吸机'
                  : '表头信息 · 连接方式 / 呼吸机',
              style: const TextStyle(
                  fontSize: 12, color: kInkSoft, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            SchemaForm(
              groups: metaGroups(widget.type),
              values: _meta,
              initiallyExpanded: true,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '记录时间点（${_items.length}）',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: kInk),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _addPoint,
                  icon: const Icon(Icons.add, size: 17),
                  label: const Text('添加时间点'),
                  style: FilledButton.styleFrom(backgroundColor: _accent),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_items.isEmpty)
              Card(
                color: kCard,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: kDivider),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('点右上「添加时间点」开始录入第一列数据',
                        style: TextStyle(fontSize: 13, color: kInkSoft)),
                  ),
                ),
              ),
            ..._items.asMap().entries.map((entry) {
              final index = entry.key + 1;
              final item = entry.value;
              return Card(
                key: ValueKey<int>(item.key),
                margin: const EdgeInsets.only(bottom: 10),
                color: kCard,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: _accent.withAlpha(90)),
                ),
                child: ExpansionTile(
                  initiallyExpanded: _items.length == 1,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                  childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  leading: CircleAvatar(
                    radius: 13,
                    backgroundColor: _accent.withAlpha(28),
                    child: Text('$index',
                        style: TextStyle(fontSize: 12, color: _accent)),
                  ),
                  title: Text(
                    '第 $index 次 · ${item.data['time'] ?? '未填时间'}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  trailing: IconButton(
                    tooltip: '删除该时间点',
                    icon: const Icon(Icons.delete_outline,
                        size: 19, color: kDanger),
                    onPressed: () => _removePoint(item.key),
                  ),
                  children: [
                    // 文本框的 onChanged 直接写进 item.data，故此处不必监听
                    Listener(
                      onPointerDown: (_) => _markDirty(),
                      child: SchemaForm(
                        key: ValueKey<String>('${item.key}-${item.revision}'),
                        groups: pointGroups(widget.type),
                        values: item.data,
                        initiallyExpanded: true,
                        groupFooters: {
                          '血气分析': _abgPhotoSection(item),
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _saving ? null : () => _save(),
          backgroundColor: _accent,
          icon: const Icon(Icons.save_outlined, size: 18),
          label: const Text('保存并返回'),
        ),
      ),
    );
  }

  Widget _patientHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _accent.withAlpha(18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.person_outline, size: 18, color: _accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_form.displayName}　床号 ${_form.bedNo.isEmpty ? '—' : _form.bedNo}'
              '　病历号 ${_form.mrn.isEmpty ? '—' : _form.mrn}　${_form.date}',
              style: const TextStyle(fontSize: 12.5, color: kInk),
            ),
          ),
        ],
      ),
    );
  }
}
