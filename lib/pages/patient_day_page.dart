import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../models/form_schema.dart';
import '../models/record.dart';
import '../state/app_state.dart';
import '../utils/date_fmt.dart';
import 'export_page.dart';
import 'patient_form_page.dart';
import 'vent_page.dart';

/// 患者当天的工作台：编辑病历首页 / 进入有创或无创记录 / 导出全疗程 PDF
class PatientDayPage extends StatelessWidget {
  const PatientDayPage({super.key, required this.formId});

  final int formId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    PatientForm? form;
    for (final f in state.forms) {
      if (f.id == formId) {
        form = f;
        break;
      }
    }
    if (form == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('这份记录已被删除')),
      );
    }

    final inv = state.pointCount(form.id, form.date, kTypeInvasive);
    final niv = state.pointCount(form.id, form.date, kTypeNiv);

    return Scaffold(
      appBar: AppBar(title: const Text('患者记录')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        children: [
          Card(
            color: kCard,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: kDivider),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    form.displayName,
                    style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w700, color: kInk,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${formatCnDate(parseDateKey(form.date))}　'
                    '床号 ${form.bedNo.isEmpty ? '—' : form.bedNo}　'
                    '病历号 ${form.mrn.isEmpty ? '—' : form.mrn}',
                    style: const TextStyle(fontSize: 12.5, color: kInkSoft),
                  ),
                  if (form.data['diagnosis'] != null &&
                      form.data['diagnosis'].toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('主要诊断：${form.data['diagnosis']}',
                        style: const TextStyle(fontSize: 12.5, color: kInkSoft)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const _Section('第一步 · 患者基本信息'),
          _ActionTile(
            icon: Icons.description_outlined,
            color: kPrimary,
            title: '呼吸治疗病历首页',
            subtitle: '查看 / 修改基本信息、查体、辅助检查、诊断、呼吸支持',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PatientFormPage(
                  date: parseDateKey(form!.date),
                  formId: form.id,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const _Section('第二步 · 选择通气记录表'),
          _ActionTile(
            icon: Icons.air,
            color: kInvasive,
            title: '有创通气记录表',
            subtitle: inv == 0 ? '尚未录入 · 点此新建' : '已录入 $inv 个时间点',
            trailing: inv == 0 ? '新建' : '$inv 次',
            onTap: () => _openVent(context, form!, kTypeInvasive),
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.airline_seat_recline_normal,
            color: kNiv,
            title: '无创通气记录表',
            subtitle: niv == 0 ? '尚未录入 · 点此新建' : '已录入 $niv 个时间点',
            trailing: niv == 0 ? '新建' : '$niv 次',
            onTap: () => _openVent(context, form!, kTypeNiv),
          ),
          const SizedBox(height: 18),
          const _Section('导出'),
          _ActionTile(
            icon: Icons.picture_as_pdf_outlined,
            color: kPrimary,
            title: '导出该患者全疗程 PDF',
            subtitle: '从首次记录到最近一次，按教程表格排版',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ExportPage(patientKey: form!.patientKey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openVent(BuildContext context, PatientForm form, String type) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VentPage(formId: form.id!, type: type),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12, letterSpacing: 1, color: kInkSoft,
                fontWeight: FontWeight.w500)),
      );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: kCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: kDivider),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withAlpha(24),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        title: Text(title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle,
              style: const TextStyle(fontSize: 12, color: kInkSoft, height: 1.5)),
        ),
        trailing: trailing == null
            ? const Icon(Icons.chevron_right, size: 18, color: kInkSoft)
            : Text(trailing!, style: TextStyle(fontSize: 12, color: color)),
        onTap: onTap,
      ),
    );
  }
}
