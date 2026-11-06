import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../state/app_state.dart';
import 'export_page.dart';

/// 设置：导出 PDF / 字段依据 / 清空数据 / 关于
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        children: [
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.storage_outlined, size: 18, color: kPrimary),
                    const SizedBox(width: 8),
                    Text(
                      '本机共 ${state.forms.length} 份病历首页',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '全部数据（含拍照的照片）只保存在这台手机的本地数据库里，App 不联网、不上传。\n'
                  '卸载 App 会连同记录一起删除，重要资料请及时导出 PDF 归档。\n'
                  '照片识别在本机离线完成，识别结果需人工核对后才填入表格。',
                  style: TextStyle(fontSize: 12.5, height: 1.7, color: kInkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _Section('导出'),
          _tile(
            icon: Icons.picture_as_pdf_outlined,
            title: '导出 PDF 表格',
            subtitle: '按日期段或单患者全疗程，教程版式排版',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ExportPage()),
            ),
          ),
          const SizedBox(height: 18),
          const _Section('依据'),
          _tile(
            icon: Icons.menu_book_outlined,
            title: '字段与表格来源',
            subtitle: '《呼吸治疗教程》附录Ⅱ（印刷 253–255 页）',
            onTap: () => showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('字段依据'),
                content: const Text(
                  '一、呼吸治疗病历首页（印刷 253 页）\n'
                  '二、呼吸治疗工作记录表（有创通气）（印刷 254 页）\n'
                  '三、呼吸治疗工作记录表（无创通气）（印刷 255 页）\n\n'
                  '已按你的纠正采用：Rinsp（吸气时间）、High Ppeak（气道高压报警）、'
                  '是否通过 RTW（具备撤机条件）。',
                  style: TextStyle(fontSize: 13, height: 1.7),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('知道了')),
                ],
              ),
            ),
          ),
          _tile(
            icon: Icons.info_outline,
            title: '版本',
            subtitle: '呼吸治疗工作记录 1.1.0（V1.1 · 支持拍照识别）',
            onTap: () {},
          ),
          const SizedBox(height: 26),
          Center(
            child: TextButton(
              onPressed: () => _clearAll(context),
              child: const Text('清空所有数据', style: TextStyle(color: kDanger)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAll(BuildContext context) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空所有数据'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('所有病历首页与通气记录都会被删除，不可恢复。\n请输入「删除」确认。'),
            const SizedBox(height: 12),
            SizedBox(
              width: 220,
              child: TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '删除',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, controller.text.trim() == '删除'),
              child: const Text('确认清空', style: TextStyle(color: kDanger))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await context.read<AppState>().clearAll();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已清空全部数据')),
    );
  }

  Widget _card({required Widget child}) => Card(
        color: kCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: kDivider),
        ),
        child: Padding(padding: const EdgeInsets.all(14), child: child),
      );

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      Card(
        color: kCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: kDivider),
        ),
        child: ListTile(
          leading: Icon(icon, size: 20, color: kPrimary),
          title: Text(title, style: const TextStyle(fontSize: 14)),
          subtitle: Text(subtitle,
              style: const TextStyle(fontSize: 11.5, color: kInkSoft)),
          trailing: const Icon(Icons.chevron_right, size: 18, color: kInkSoft),
          onTap: onTap,
        ),
      );
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
