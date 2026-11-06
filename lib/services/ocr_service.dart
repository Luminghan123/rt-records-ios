import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../utils/date_fmt.dart';

/// 一条可填进表格的识别结果（value 为空表示这一项没识别到）。
class OcrCandidate {
  OcrCandidate({required this.key, required this.label, this.value = ''});

  final String key;
  final String label;
  String value;
}

/// 一个字段的匹配规则：标签别名 + 合理数值范围。
/// 范围外的值基本可以断定是识别错误或串到了别的字段，直接丢弃。
class OcrSpec {
  const OcrSpec(this.key, this.label, this.patterns, this.min, this.max);

  final String key;
  final String label;
  final List<String> patterns;
  final double min;
  final double max;
}

// ------------------------------------------------------------------
// 标签别名。OCR 常把字母 O 认成数字 0、把下标 ₂ 认成 z 之类，
// 所以别名里同时写 [O0] 两种写法，并在归一化时把下标统一成数字。
// ------------------------------------------------------------------
const _pH = <String>[
  r'(?:\bpH\b|酸碱度)[^\d+\-]{0,12}(-?\d{1,2}[.,]\d{1,3})'
];
const _pao2 = <String>[
  r'(?:Pa[O0]2|P[O0]2|氧分压)[^\d+\-]{0,12}(\d{1,3}(?:[.,]\d{1,2})?)'
];
const _paco2 = <String>[
  r'(?:PaC[O0]2|PC[O0]2|二氧化碳分压)[^\d+\-]{0,12}(\d{1,3}(?:[.,]\d{1,2})?)'
];
const _hco3 = <String>[
  r'(?:HC[O0]3|碳酸氢根|实际碳酸氢根|\bAB\b)[^\d+\-]{0,12}(-?\d{1,2}(?:[.,]\d{1,2})?)'
];
const _be = <String>[
  r'(?:\bSBE\b|\bBE\b|碱剩余|剩余碱)[^\d+\-]{0,12}(-?\d{1,2}(?:[.,]\d{1,2})?)'
];
const _fio2 = <String>[
  r'(?:FI[O0]2|吸入氧浓度|氧浓度)[^\d+\-]{0,12}(\d{1,3}(?:[.,]\d{1,2})?)'
];
const _wbc = <String>[
  r'(?:\bWBC\b|白细胞)[^\d+\-]{0,12}(\d{1,2}(?:[.,]\d{1,2})?)'
];
const _hb = <String>[
  r'(?:\bHB\b|\bHb\b|血红蛋白)[^\d+\-]{0,12}(\d{1,3}(?:[.,]\d{1,2})?)'
];
const _rbc = <String>[
  r'(?:\bRBC\b|红细胞计数)[^\d+\-]{0,12}(\d{1,2}(?:[.,]\d{1,3})?)'
];
const _plt = <String>[
  r'(?:\bPLT\b|血小板)[^\d+\-]{0,12}(\d{1,4}(?:[.,]\d{1,2})?)'
];
const _na = <String>[
  r'(?:\bNa\b|钠)[^\d+\-]{0,12}(\d{1,3}(?:[.,]\d{1,2})?)'
];
const _k = <String>[
  r'(?:\bK\b|血钾|钾离子)[^\d+\-]{0,12}(\d{1,2}(?:[.,]\d{1,2})?)'
];
const _cl = <String>[
  r'(?:\bCl\b|血氯|氯离子)[^\d+\-]{0,12}(\d{1,3}(?:[.,]\d{1,2})?)'
];
const _ca = <String>[
  r'(?:\bCa\b|血钙|钙离子)[^\d+\-]{0,12}(\d{1,2}(?:[.,]\d{1,3})?)'
];
const _ast = <String>[r'(?:\bAST\b)[^\d+\-]{0,12}(\d{1,4}(?:[.,]\d{1,2})?)'];
const _alt = <String>[r'(?:\bALT\b)[^\d+\-]{0,12}(\d{1,4}(?:[.,]\d{1,2})?)'];
const _bun = <String>[
  r'(?:\bBUN\b|尿素氮)[^\d+\-]{0,12}(\d{1,3}(?:[.,]\d{1,2})?)'
];
const _crea = <String>[
  r'(?:\bCrea\b|\bCre\b|肌酐)[^\d+\-]{0,12}(\d{1,4}(?:[.,]\d{1,2})?)'
];
const _tp = <String>[
  r'(?:\bTP\b|总蛋白)[^\d+\-]{0,12}(\d{1,3}(?:[.,]\d{1,2})?)'
];
const _n = <String>[
  r'(?:\bN\b|中性粒|中性粒细胞)[^\d+\-]{0,12}(\d{1,3}(?:[.,]\d{1,2})?)'
];

/// 有创 / 无创记录页「血气分析」分组的字段
const List<OcrSpec> kAbgSpecs = [
  OcrSpec('ph', 'pH', _pH, 6.5, 7.9),
  OcrSpec('pao2', 'PaO₂ (mmHg)', _pao2, 10, 700),
  OcrSpec('paco2', 'PaCO₂ (mmHg)', _paco2, 10, 150),
  OcrSpec('hco3', 'HCO₃⁻ (mmol/L)', _hco3, 1, 60),
  OcrSpec('be', 'BE (mmol/L)', _be, -30, 30),
  OcrSpec('fio2', 'FiO₂ (%)', _fio2, 0, 100),
];

/// 病历首页「辅助检查」分组的字段
const List<OcrSpec> kLabSpecs = [
  OcrSpec('wbc', 'WBC', _wbc, 0, 100),
  OcrSpec('n', 'N (%)', _n, 0, 100),
  OcrSpec('hb', 'Hb', _hb, 1, 250),
  OcrSpec('rbc', 'RBC', _rbc, 0, 10),
  OcrSpec('plt', 'PLT', _plt, 1, 1000),
  OcrSpec('abg_ph', 'pH', _pH, 6.5, 7.9),
  OcrSpec('abg_pao2', 'PaO₂', _pao2, 10, 700),
  OcrSpec('abg_paco2', 'PaCO₂', _paco2, 10, 150),
  OcrSpec('abg_hco3', 'HCO₃⁻', _hco3, 1, 60),
  OcrSpec('abg_be', 'BE', _be, -30, 30),
  OcrSpec('abg_fio2', 'FiO₂', _fio2, 0, 100),
  OcrSpec('bio_na', 'Na⁺', _na, 80, 200),
  OcrSpec('bio_k', 'K⁺', _k, 1, 10),
  OcrSpec('bio_cl', 'Cl⁻', _cl, 50, 150),
  OcrSpec('bio_ca', 'Ca²⁺', _ca, 0.5, 5),
  OcrSpec('bio_tp', 'TP', _tp, 10, 120),
  OcrSpec('bio_ast', 'AST', _ast, 1, 1000),
  OcrSpec('bio_alt', 'ALT', _alt, 1, 1000),
  OcrSpec('bio_bun', 'BUN', _bun, 1, 100),
  OcrSpec('bio_crea', 'Crea', _crea, 10, 2000),
];

/// 本机离线文字识别。模型随 App 打包，识别过程不联网、不上传任何照片。
class OcrService {
  OcrService._();

  static Future<String> recognize(String imagePath) async {
    final recognizer =
        TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer
          .processImage(InputImage.fromFilePath(imagePath));
      return result.text;
    } finally {
      await recognizer.close();
    }
  }

  /// 解析成「血气分析」字段候选（含血气时间）
  static List<OcrCandidate> parseAbg(String rawText) {
    final list = _parse(rawText, kAbgSpecs);
    list.insert(
      0,
      OcrCandidate(
        key: 'abg_time',
        label: '血气时间',
        value: _time(rawText) ?? '',
      ),
    );
    return list;
  }

  /// 解析成病历首页「辅助检查」字段候选
  static List<OcrCandidate> parseLab(String rawText) =>
      _parse(rawText, kLabSpecs);

  static List<OcrCandidate> _parse(String rawText, List<OcrSpec> specs) {
    final text = _normalize(rawText);
    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    // 有些报告单把「标签」和「数值」拆成上下两行，拼起来再兜底找一次
    final joined = lines.join('  ');
    final scopes = <String>[...lines, joined];
    return specs.map((s) {
      String? hit;
      for (final scope in scopes) {
        hit = _match(scope, s);
        if (hit != null) break;
      }
      return OcrCandidate(key: s.key, label: s.label, value: hit ?? '');
    }).toList();
  }

  static String? _match(String scope, OcrSpec spec) {
    for (final pattern in spec.patterns) {
      final re = RegExp(pattern, caseSensitive: false);
      for (final m in re.allMatches(scope)) {
        final raw = m.group(1);
        if (raw == null) continue;
        final value = raw.replaceAll(',', '.').trim();
        final n = double.tryParse(value);
        if (n == null) continue;
        if (n < spec.min || n > spec.max) continue;
        return value;
      }
    }
    return null;
  }

  static String _normalize(String text) => text
      .replaceAll('：', ':')
      .replaceAll('＝', '=')
      .replaceAll('₂', '2')
      .replaceAll('₃', '3')
      .replaceAll('⁻', '-')
      .replaceAll('⁺', '+')
      .replaceAll('·', '.')
      .replaceAll('　', ' ')
      .replaceAllMapped(RegExp(r'(\d),(\d)'), (m) => '${m[1]}.${m[2]}');

  /// 报告单上的时间；只有时分时补上今天的日期，符合表格里的时间格式
  static String? _time(String rawText) {
    final full = RegExp(r'(\d{4}-\d{1,2}-\d{1,2}[ T]\d{1,2}:\d{2})')
        .firstMatch(rawText);
    if (full != null) return full.group(1)!.replaceAll('T', ' ');
    final hm = RegExp(r'\b(\d{1,2}:\d{2})(?::\d{2})?\b').firstMatch(rawText);
    if (hm == null) return null;
    return '${formatIso(DateTime.now())} ${hm.group(1)}';
  }
}
