import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/form_schema.dart';
import '../models/record.dart';
import '../state/app_state.dart';

class PdfBuildResult {
  const PdfBuildResult(this.bytes, this.pageCount);
  final Uint8List bytes;
  final int pageCount;
}

/// 按《呼吸治疗教程》附录Ⅱ版式生成 PDF。
///
/// - 病历首页：A4 纵向，按教程分组逐行排（分组行 + 字段行）
/// - 通气记录表：A4 横向，**行 = 监测项目，列 = 记录时间点**（每页最多 5 列），
///   分组行与教程同名，超出 5 列自动续页
Future<PdfBuildResult> buildRtPdf({
  required AppState state,
  required List<PatientForm> forms,
  required String title,
  required bool includePatientForm,
  required bool includeVentTables,
}) async {
  final fontData = await rootBundle.load('assets/fonts/SimHei.ttf');
  final font = pw.Font.ttf(fontData);
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: font, bold: font),
    title: title,
  );

  var pageCount = 0;

  for (final form in forms) {
    // ---------- 一、呼吸治疗病历首页 ----------
    if (includePatientForm) {
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('一、呼吸治疗病历首页',
                style: const pw.TextStyle(
                    fontSize: 15, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 3),
            pw.Text(
              '姓名：${form.name}　床号：${form.bedNo}　病历号：${form.mrn}　'
              '记录日期：${form.date}',
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('第 ${ctx.pageNumber} 页',
              style: const pw.TextStyle(fontSize: 8)),
        ),
        build: (ctx) => kPatientGroups
            .map((g) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  child: _patientGroupTable(g, form.data),
                ))
            .toList(),
      ));
      pageCount++;
    }

    if (!includeVentTables) continue;

    // ---------- 二/三、通气工作记录表 ----------
    for (final type in [kTypeInvasive, kTypeNiv]) {
      final meta = state.metaFor(form.id, form.date, type);
      final points = state.pointsFor(form.id, form.date, type);
      if (meta == null && points.isEmpty) continue;

      final metaText = meta == null
          ? ''
          : metaGroups(type)
              .expand((g) => g.fields)
              .where((f) => displayValue(f, meta.data).isNotEmpty)
              .map((f) => '${f.displayLabel}：${displayValue(f, meta.data)}')
              .join('　');

      // 教程表格的"行"清单：分组行 + 字段行，供横向分页用
      final descriptors = <_RowDesc>[];
      for (final g in pointGroups(type)) {
        descriptors.add(_RowDesc(groupName: g.name));
        for (final f in g.fields) {
          descriptors.add(_RowDesc(field: f));
        }
      }

      const perPage = 5; // 每页 5 个时间点（5 列）
      const rowsPerPage = 26; // 每页最多 26 个项目行，超出自动续页
      final colChunks = points.isEmpty ? 1 : (points.length / perPage).ceil();
      final rowChunks = (descriptors.length / rowsPerPage).ceil();
      final totalPages = colChunks * rowChunks;
      var pageNo = 0;

      for (var c = 0; c < colChunks; c++) {
        final from = c * perPage;
        final to = from + perPage > points.length
            ? points.length
            : from + perPage;
        final chunk = from >= points.length
            ? <VentPoint>[]
            : points.sublist(from, to);
        for (var r = 0; r < rowChunks; r++) {
          final rFrom = r * rowsPerPage;
          final rTo = rFrom + rowsPerPage > descriptors.length
              ? descriptors.length
              : rFrom + rowsPerPage;
          pageNo++;
          pageCount++;
          doc.addPage(_ventTablePage(
            form: form,
            type: type,
            metaText: metaText,
            points: chunk,
            descriptors: descriptors.sublist(rFrom, rTo),
            pageNo: pageNo,
            totalPages: totalPages,
          ));
        }
      }
    }
  }

  return PdfBuildResult(
    Uint8List.fromList(await doc.save()),
    pageCount,
  );
}

// ------------------------------------------------------------------
// 病历首页：一个分组 = 一张两列表
// ------------------------------------------------------------------
pw.Widget _patientGroupTable(FormGroup group, Map<String, dynamic> data) {
  pw.Widget cell(String text, {bool bold = false, bool grey = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: grey ? PdfColors.grey700 : PdfColors.black,
          ),
        ),
      );

  return pw.Table(
    border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey500),
    columnWidths: {0: const pw.FixedColumnWidth(120)},
    defaultColumnWidth: const pw.FlexColumnWidth(),
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          cell(group.name, bold: true),
          cell(''),
        ],
      ),
      ...group.fields.map((f) => pw.TableRow(children: [
            cell(f.displayLabel, grey: true),
            cell(displayValue(f, data)),
          ])),
    ],
  );
}

// ------------------------------------------------------------------
// 通气记录表：A4 横向，行 = 项目，列 = 时间点
// ------------------------------------------------------------------
pw.Page _ventTablePage({
  required PatientForm form,
  required String type,
  required String metaText,
  required List<VentPoint> points,
  required List<_RowDesc> descriptors,
  required int pageNo,
  required int totalPages,
}) {
  const colCount = 5; // 固定 5 列，不足留空列，方便现场手写补录
  final displayPoints = points.take(colCount).toList();

  pw.Widget cell(String text,
          {bool bold = false, bool grey = false, bool center = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        child: pw.Text(
          text.isEmpty ? '' : text,
          maxLines: 2,
          textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
          style: pw.TextStyle(
            fontSize: 7,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: grey ? PdfColors.grey800 : PdfColors.black,
          ),
        ),
      );

  final rows = <pw.TableRow>[];

  // 表头：姓名 / 性别 / 年龄 / 床号 / 病历号 / 日期 / 主要诊断
  rows.add(pw.TableRow(
    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
    children: [
      cell('姓名 / 日期', bold: true),
      cell(form.name, bold: true),
      cell('性别', grey: true),
      cell(displayValue(_patientField('sex'), form.data)),
      cell('年龄', grey: true),
      cell(displayValue(_patientField('age'), form.data)),
    ],
  ));
  rows.add(pw.TableRow(children: [
    cell('床号 / 病历号', grey: true),
    cell('${form.bedNo} / ${form.mrn}'),
    cell('日期', grey: true),
    cell(form.date),
    cell('主要诊断', grey: true),
    cell(displayValue(_patientField('diagnosis'), form.data)),
  ]));
  rows.add(pw.TableRow(
    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
    children: [
      cell('监测项目', bold: true),
      ...List.generate(colCount, (i) => cell(
            i < displayPoints.length ? displayPoints[i].columnTitle : '',
            bold: true,
            center: true,
          )),
    ],
  ));

  for (final d in descriptors) {
    if (d.isGroup) {
      // 分组行（教程里的"心电监护 / 机械通气监测 / …"）
      rows.add(pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          cell(d.groupName!, bold: true),
          ...List.generate(colCount, (_) => cell('')),
        ],
      ));
    } else {
      final f = d.field!;
      rows.add(pw.TableRow(children: [
        cell(f.displayLabel, grey: true),
        ...List.generate(colCount, (i) => cell(
              i < displayPoints.length
                  ? displayValue(f, displayPoints[i].data)
                  : '',
              center: true,
            )),
      ]));
    }
  }

  return pw.Page(
    pageFormat: PdfPageFormat.a4.landscape,
    margin: const pw.EdgeInsets.all(20),
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(formTitle(type),
                style: const pw.TextStyle(
                    fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.Text('第 $pageNo / $totalPages 页',
                style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
        pw.SizedBox(height: 4),
        if (metaText.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text(metaText,
                style: const pw.TextStyle(fontSize: 8), maxLines: 3),
          ),
        pw.Table(
          border: pw.TableBorder.all(width: 0.4, color: PdfColors.grey600),
          columnWidths: {0: const pw.FixedColumnWidth(150)},
          defaultColumnWidth: const pw.FlexColumnWidth(),
          children: rows,
        ),
      ],
    ),
  );
}

/// 表格行描述：分组标题行或字段数据行
class _RowDesc {
  _RowDesc({this.groupName, this.field});
  final String? groupName;
  final FormField? field;
  bool get isGroup => groupName != null;
}

FormField _patientField(String key) {
  for (final g in kPatientGroups) {
    for (final f in g.fields) {
      if (f.key == key) return f;
    }
  }
  return FormField(key, key);
}
