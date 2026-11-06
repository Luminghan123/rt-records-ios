import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_theme.dart';
import '../services/photo_store.dart';

/// 通用「照片附件」区：拍照 / 相册选图 / 缩略图 / 全屏放大 / 删除。
///
/// 照片路径直接写进调用方传入的 [values] 里，保存记录时随 JSON 一起入库。
/// [onPhotoAdded] 用于「拍完照立刻做本机识别」的场景，由页面决定后续动作。
class PhotoAttachments extends StatefulWidget {
  const PhotoAttachments({
    super.key,
    required this.values,
    required this.photoKey,
    required this.title,
    this.hint,
    this.accent = kPrimary,
    this.onPhotoAdded,
  });

  final Map<String, dynamic> values;
  final String photoKey;
  final String title;
  final String? hint;
  final Color accent;

  /// 参数是照片在本机上的完整路径
  final Future<void> Function(String imagePath)? onPhotoAdded;

  @override
  State<PhotoAttachments> createState() => _PhotoAttachmentsState();
}

class _PhotoAttachmentsState extends State<PhotoAttachments> {
  final ImagePicker _picker = ImagePicker();
  bool _busy = false;

  List<String> get _names =>
      PhotoStore.readList(widget.values, widget.photoKey);

  Future<void> _pick(ImageSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 2400,
        maxHeight: 2400,
      );
      if (picked == null) return;
      final name = await PhotoStore.saveFrom(picked);
      final names = _names..add(name);
      PhotoStore.writeList(widget.values, widget.photoKey, names);
      if (mounted) setState(() {});
      final path = await PhotoStore.pathOf(name);
      // 无论识别成功与否，照片本身已经保存好了
      if (widget.onPhotoAdded != null && mounted) {
        await widget.onPhotoAdded!(path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加照片失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这张照片？'),
        content: const Text('照片会从本机删除，已填入表格的数值不受影响。'),
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
    await PhotoStore.delete(name);
    final names = _names..remove(name);
    PhotoStore.writeList(widget.values, widget.photoKey, names);
    if (mounted) setState(() {});
  }

  Future<void> _view(String name) async {
    final path = await PhotoStore.pathOf(name);
    if (!mounted) return;
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
                  child: Image.file(File(path), fit: BoxFit.contain),
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

  Widget _thumb(String name) {
    return FutureBuilder<String>(
      future: PhotoStore.pathOf(name),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Container(
            width: 78,
            height: 78,
            color: kPrimarySoft,
          );
        }
        final file = File(snap.data!);
        return GestureDetector(
          onTap: () => _view(name),
          child: Stack(
            children: [
              Container(
                width: 78,
                height: 78,
                margin: const EdgeInsets.only(top: 6, right: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kDivider),
                  image: DecorationImage(
                    image: FileImage(file),
                    fit: BoxFit.cover,
                    onError: (_, __) {},
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: GestureDetector(
                  onTap: () => _remove(name),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: kDanger,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final names = _names;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.accent.withAlpha(12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: widget.accent.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo_camera_outlined, size: 17, color: widget.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${widget.title}（${names.length}）',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: widget.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.hint ?? '照片只保存在本机，导出 PDF 时不附带。',
            style: const TextStyle(fontSize: 11, color: kInkSoft, height: 1.5),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined, size: 16),
                  label: const Text('拍照', style: TextStyle(fontSize: 12.5)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 16),
                  label: const Text('从相册选', style: TextStyle(fontSize: 12.5)),
                ),
              ),
            ],
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (names.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 2,
              runSpacing: 2,
              children: names.map(_thumb).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
