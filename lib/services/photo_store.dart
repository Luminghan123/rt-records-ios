import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 照片文件的统一管理。
///
/// 关键设计：数据库里只存「文件名」（不是绝对路径），并且写进记录已有的
/// JSON data 中，键名一律以下划线开头，避开 form_schema.dart 里的字段 key。
/// 因此 SQLite 三张表完全不用改，手机上 V1 已有的老记录也不会受影响。
class PhotoStore {
  PhotoStore._();

  static const String folderName = 'rt_photos';

  /// 病历首页：病历资料 / 化验单照片
  static const String keyForm = '_photos_form';

  /// 通气记录页某个时间点：血气报告单照片
  static const String keyAbg = '_photos_abg';

  static Future<Directory> _folder() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, folderName));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// 从记录的 data 里读出照片文件名列表
  static List<String> readList(Map<String, dynamic> values, String key) {
    final raw = values[key];
    if (raw is List) return raw.whereType<String>().toList();
    return <String>[];
  }

  /// 写回记录的 data（空列表就删掉这个键，保持 JSON 干净）
  static void writeList(
      Map<String, dynamic> values, String key, List<String> names) {
    if (names.isEmpty) {
      values.remove(key);
    } else {
      values[key] = names;
    }
  }

  /// 相机/相册给的是临时文件，可能被系统随时清掉，
  /// 所以复制一份到 App 私有目录，返回稳定文件名。
  static Future<String> saveFrom(XFile source) async {
    final dir = await _folder();
    var ext = p.extension(source.path).toLowerCase();
    if (ext.isEmpty || ext.length > 5) ext = '.jpg';
    final name = 'p${DateTime.now().microsecondsSinceEpoch}$ext';
    await File(source.path).copy(p.join(dir.path, name));
    return name;
  }

  /// 文件名 -> 当前设备上的真实路径
  static Future<String> pathOf(String name) async {
    final dir = await _folder();
    return p.join(dir.path, p.basename(name));
  }

  static Future<void> delete(String name) async {
    try {
      final f = File(await pathOf(name));
      if (await f.exists()) await f.delete();
    } catch (_) {
      // 文件已经不存在时忽略即可
    }
  }

  /// 设置里「清空所有数据」时把照片文件一并删掉，避免残留占空间
  static Future<void> deleteAll() async {
    try {
      final dir = await _folder();
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }
}
