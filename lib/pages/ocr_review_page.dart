import 'dart:io';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../services/ocr_service.dart';

/// 识别结果核对页。
///
/// 临床数值不能盲信文字识别：本页把识别到的值逐项列出，治疗师核对、可改，
/// 点「确认填入」后才真正写回表格。返回 Map<字段key, 值>；点返回则为 null。
class OcrReviewPage extends StatefulWidget {
  const OcrReviewPage({
    super.key,
    required this.title,
    required this.imagePath,
    required this.candidates,
    required this.rawText,
  });

  final String title;
  final String imagePath;
  final List<OcrCandidate> candidates;
  final String rawText;

  @override
  State<OcrReviewPage> createState() => _OcrReviewPageState();
}

class _OcrReviewPageState extends State<OcrReviewPage> {
  late final List<TextEditingController> _controllers;
  bool _showRaw = false;

  @override
  void initState() {
    super.initState();
    _controllers = widget.candidates
        .map((c) => TextEditingController(text: c.value))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final result = <String, String>{};
    for (var i = 0; i < widget.candidates.length; i++) {
      final v = _controllers[i].text.trim();
      if (v.isNotEmpty) result[widget.candidates[i].key] = v;
    }
    Navigator.of(context).pop(result);
  }

  Future<void> _viewImage() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 6,
                child: Center(
                  child: Image.file(File(widget.imagePath), fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned(
              right: 4,
              top: 4,
              child: IconButton(
                tooltip: '关闭',
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final found = widget.candidates.where((c) => c.value.isNotEmpty).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(onPressed: _submit, child: const Text('确认填入')),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF0C987)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_outlined,
                          size: 18, color: Color(0xFFB26A00)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '照片识别可能出错。请对照下方的原件逐项核对，'
                          '不对就直接改，确认无误后再填入表格。',
                          style: TextStyle(
                              fontSize: 12,
                              height: 1.6,
                              color: Color(0xFF7A4A00)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _viewImage,
                  child: Container(
                    height: 110,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kDivider),
                      image: DecorationImage(
                        image: FileImage(File(widget.imagePath)),
                        fit: BoxFit.cover,
                        onError: (_, __) {},
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Container(
                        margin: const EdgeInsets.all(6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('点开放大看原件',
                            style: TextStyle(
                                fontSize: 11, color: Colors.white)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      '识别到 $found / ${widget.candidates.length} 项',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: kInk),
                    ),
                    const Spacer(),
                    const Text('留空表示不填入',
                        style: TextStyle(fontSize: 11, color: kInkSoft)),
                  ],
                ),
                const SizedBox(height: 10),
                LayoutBuilder(builder: (context, constraints) {
                  final cols = constraints.maxWidth >= 560 ? 3 : 2;
                  final w = (constraints.maxWidth - (cols - 1) * 8) / cols;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 10,
                    children: List.generate(widget.candidates.length, (i) {
                      final c = widget.candidates[i];
                      final hit = c.value.isNotEmpty;
                      return SizedBox(
                        width: w,
                        child: TextField(
                          controller: _controllers[i],
                          keyboardType: TextInputType.text,
                          style: TextStyle(
                              fontSize: 13,
                              color: kInk,
                              fontWeight: hit
                                  ? FontWeight.w600
                                  : FontWeight.normal),
                          decoration: InputDecoration(
                            labelText: c.label,
                            hintText: hit ? null : '未识别到',
                            suffixIcon: hit
                                ? const Icon(Icons.check_circle_outline,
                                    size: 16, color: kNiv)
                                : null,
                          ),
                        ),
                      );
                    }),
                  );
                }),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => setState(() => _showRaw = !_showRaw),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          _showRaw
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 18,
                          color: kPrimary,
                        ),
                        const SizedBox(width: 6),
                        const Text('查看识别到的全部文字',
                            style: TextStyle(fontSize: 12.5, color: kPrimary)),
                      ],
                    ),
                  ),
                ),
                if (_showRaw)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kDivider),
                    ),
                    child: SelectableText(
                      widget.rawText.trim().isEmpty
                          ? '（这张照片里没有识别出文字，请检查照片是否清晰、是否拍到报告单）'
                          : widget.rawText,
                      style: const TextStyle(fontSize: 11.5, height: 1.6),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.input_outlined, size: 18),
                  label: const Text('核对无误，填入表格'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
