import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// جدول عام للتصدير: عناوين وصفوف نصية.
class ExportTable {
  final String title;
  final List<String> heads;
  final List<List<String>> rows;
  const ExportTable(this.title, this.heads, this.rows);

  /// يعيد جدولاً بالأعمدة المحددة فقط.
  ExportTable pick(List<int> cols) => ExportTable(
      title,
      [for (final c in cols) heads[c]],
      [for (final r in rows) [for (final c in cols) r[c]]]);
}

// ================= CSV =================
String toCsv(List<List<String>> rows) {
  String esc(String s) => (s.contains(',') ||
          s.contains('"') ||
          s.contains('\n') ||
          s.contains(';'))
      ? '"${s.replaceAll('"', '""')}"'
      : s;
  return rows.map((r) => r.map(esc).join(',')).join('\r\n');
}

List<List<String>> parseCsv(String text) {
  if (text.startsWith('\uFEFF')) text = text.substring(1);
  final firstLine = text.split('\n').first;
  final delim = (firstLine.contains(';') && !firstLine.contains(',')) ? ';' : ',';
  final rows = <List<String>>[];
  var row = <String>[];
  final cur = StringBuffer();
  var inQ = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (inQ) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cur.write('"');
          i++;
        } else {
          inQ = false;
        }
      } else {
        cur.write(c);
      }
    } else if (c == '"') {
      inQ = true;
    } else if (c == delim) {
      row.add(cur.toString());
      cur.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(cur.toString());
      cur.clear();
      if (row.any((e) => e.trim().isNotEmpty)) rows.add(row);
      row = <String>[];
    } else {
      cur.write(c);
    }
  }
  row.add(cur.toString());
  if (row.any((e) => e.trim().isNotEmpty)) rows.add(row);
  return rows;
}

Uint8List csvBytes(List<List<String>> rows) =>
    Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(toCsv(rows))]);

// ================= XLSX (كتابة وقراءة داخلية) =================
String _xml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String colLetter(int i) {
  var s = '';
  var n = i + 1;
  while (n > 0) {
    final r = (n - 1) % 26;
    s = String.fromCharCode(65 + r) + s;
    n = (n - 1) ~/ 26;
  }
  return s;
}

int _colIndex(String letters) {
  var n = 0;
  for (final c in letters.codeUnits) {
    n = n * 26 + (c - 64);
  }
  return n - 1;
}

/// خلية في ورقة xlsx غنية: نص أو رقم أو معادلة (مع قيمة مخزّنة للعرض).
class XCell {
  final String? t, f, str;
  final double? n;
  final int s;
  const XCell.text(this.t, [this.s = 3])
      : n = null, f = null, str = null;
  const XCell.num(this.n, [this.s = 3])
      : t = null, f = null, str = null;
  const XCell.formula(this.f, {this.n, this.str, this.s = 3}) : t = null;
}

// أنماط الخلايا: 0 عادي، 1 عريض، 2 ترويسة، 3 جسم، 4 عنوان، 5 اسم،
// 6 مجموعة، 7 توقيع، 8 معلومات، 9 صف الإجمالي.
const _stylesXml =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
    '<fonts count="6">'
    '<font><sz val="11"/><name val="Arial"/></font>'
    '<font><b/><sz val="11"/><name val="Arial"/></font>'
    '<font><b/><sz val="9"/><name val="Arial"/></font>'
    '<font><sz val="9"/><name val="Arial"/></font>'
    '<font><b/><sz val="13"/><name val="Arial"/></font>'
    '<font><b/><sz val="10"/><name val="Arial"/></font>'
    '</fonts>'
    '<fills count="4">'
    '<fill><patternFill patternType="none"/></fill>'
    '<fill><patternFill patternType="gray125"/></fill>'
    '<fill><patternFill patternType="solid"><fgColor rgb="FFF3F4F6"/><bgColor indexed="64"/></patternFill></fill>'
    '<fill><patternFill patternType="solid"><fgColor rgb="FFDBEAFE"/><bgColor indexed="64"/></patternFill></fill>'
    '</fills>'
    '<borders count="2">'
    '<border><left/><right/><top/><bottom/><diagonal/></border>'
    '<border><left style="thin"><color rgb="FF9CA3AF"/></left><right style="thin"><color rgb="FF9CA3AF"/></right>'
    '<top style="thin"><color rgb="FF9CA3AF"/></top><bottom style="thin"><color rgb="FF9CA3AF"/></bottom><diagonal/></border>'
    '</borders>'
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
    '<cellXfs count="10">'
    '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
    '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
    '<xf numFmtId="0" fontId="2" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf>'
    '<xf numFmtId="0" fontId="3" fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf>'
    '<xf numFmtId="0" fontId="4" fillId="0" borderId="0" xfId="0" applyFont="1" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf>'
    '<xf numFmtId="0" fontId="3" fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1" applyAlignment="1"><alignment horizontal="right" vertical="center" wrapText="1"/></xf>'
    '<xf numFmtId="0" fontId="2" fillId="3" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf>'
    '<xf numFmtId="0" fontId="3" fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1" applyAlignment="1"><alignment horizontal="right" vertical="top" wrapText="1"/></xf>'
    '<xf numFmtId="0" fontId="5" fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf>'
    '<xf numFmtId="0" fontId="2" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf>'
    '</cellXfs>'
    '</styleSheet>';

Uint8List _packXlsx(String sheetName, String sheetXml) {
  const ns = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
  final name = sheetName.length > 31 ? sheetName.substring(0, 31) : sheetName;
  final files = <String, String>{
    '[Content_Types].xml':
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
            '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
            '<Default Extension="xml" ContentType="application/xml"/>'
            '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
            '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
            '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
            '</Types>',
    '_rels/.rels':
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
            '</Relationships>',
    'xl/workbook.xml':
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<workbook xmlns="$ns" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
            '<sheets><sheet name="${_xml(name)}" sheetId="1" r:id="rId1"/></sheets>'
            '</workbook>',
    'xl/_rels/workbook.xml.rels':
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
            '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
            '</Relationships>',
    'xl/styles.xml': _stylesXml,
    'xl/worksheets/sheet1.xml': sheetXml,
  };
  final arc = Archive();
  files.forEach((n, content) {
    final b = utf8.encode(content);
    arc.addFile(ArchiveFile(n, b.length, b));
  });
  final out = ZipEncoder().encode(arc);
  return Uint8List.fromList(out ?? <int>[]);
}

/// ينشئ ملف xlsx باتجاه RTL؛ الصف الأول بخط عريض عند [boldFirstRow].
Uint8List buildXlsx(String sheetName, List<List<String>> rows,
    {bool boldFirstRow = true}) {
  final sb = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<sheetViews><sheetView workbookViewId="0" rightToLeft="1"/></sheetViews>'
      '<sheetData>');
  for (var r = 0; r < rows.length; r++) {
    sb.write('<row r="${r + 1}">');
    for (var c = 0; c < rows[r].length; c++) {
      final v = rows[r][c];
      final ref = '${colLetter(c)}${r + 1}';
      final style = (boldFirstRow && r == 0) ? ' s="1"' : '';
      final n = double.tryParse(v);
      if (n != null &&
          v.trim().isNotEmpty &&
          (!v.startsWith('0') || v == '0' || v.startsWith('0.'))) {
        sb.write('<c r="$ref"$style><v>$v</v></c>');
      } else {
        sb.write('<c r="$ref" t="inlineStr"$style><is>'
            '<t xml:space="preserve">${_xml(v)}</t></is></c>');
      }
    }
    sb.write('</row>');
  }
  sb.write('</sheetData></worksheet>');
  return _packXlsx(sheetName, sb.toString());
}

/// ورقة منسّقة: خلايا بأنماط، ودمج، ومعادلات حية، وعرض أعمدة، وطباعة أفقية.
Uint8List buildXlsxSheet(String sheetName, List<List<XCell?>> rows,
    {List<String> merges = const [],
    Map<int, double> colWidths = const {},
    Map<int, double> rowHeights = const {}}) {
  final sb = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<sheetPr><pageSetUpPr fitToPage="1"/></sheetPr>'
      '<sheetViews><sheetView workbookViewId="0" rightToLeft="1"/></sheetViews>');
  if (colWidths.isNotEmpty) {
    sb.write('<cols>');
    final keys = colWidths.keys.toList()..sort();
    for (final k in keys) {
      sb.write('<col min="${k + 1}" max="${k + 1}" width="${colWidths[k]}" customWidth="1"/>');
    }
    sb.write('</cols>');
  }
  sb.write('<sheetData>');
  for (var r = 0; r < rows.length; r++) {
    final ht = rowHeights[r];
    sb.write('<row r="${r + 1}"${ht == null ? '' : ' ht="$ht" customHeight="1"'}>');
    for (var c = 0; c < rows[r].length; c++) {
      final cell = rows[r][c];
      if (cell == null) continue;
      final ref = '${colLetter(c)}${r + 1}';
      if (cell.f != null) {
        if (cell.str != null) {
          sb.write('<c r="$ref" s="${cell.s}" t="str"><f>${_xml(cell.f!)}</f><v>${_xml(cell.str!)}</v></c>');
        } else {
          sb.write('<c r="$ref" s="${cell.s}"><f>${_xml(cell.f!)}</f><v>${cell.n ?? 0}</v></c>');
        }
      } else if (cell.n != null) {
        sb.write('<c r="$ref" s="${cell.s}"><v>${cell.n}</v></c>');
      } else {
        sb.write('<c r="$ref" s="${cell.s}" t="inlineStr"><is>'
            '<t xml:space="preserve">${_xml(cell.t ?? '')}</t></is></c>');
      }
    }
    sb.write('</row>');
  }
  sb.write('</sheetData>');
  if (merges.isNotEmpty) {
    sb.write('<mergeCells count="${merges.length}">');
    for (final m in merges) {
      sb.write('<mergeCell ref="$m"/>');
    }
    sb.write('</mergeCells>');
  }
  sb.write('<pageMargins left="0.3" right="0.3" top="0.4" bottom="0.4" header="0.2" footer="0.2"/>'
      '<pageSetup paperSize="9" orientation="landscape" fitToWidth="1" fitToHeight="0"/>'
      '</worksheet>');
  return _packXlsx(sheetName, sb.toString());
}

String _unxml(String s) => s
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&');

/// يقرأ أول ورقة من ملف xlsx ويعيدها كجدول نصي.
List<List<String>> readXlsx(Uint8List bytes) {
  final arc = ZipDecoder().decodeBytes(bytes);
  ArchiveFile? find(bool Function(String) test) {
    for (final f in arc) {
      if (f.isFile && test(f.name)) return f;
    }
    return null;
  }

  String text(ArchiveFile? f) =>
      f == null ? '' : utf8.decode(f.content as List<int>, allowMalformed: true);

  final shared = <String>[];
  final sst = text(find((n) => n == 'xl/sharedStrings.xml'));
  for (final m in RegExp(r'<si>(.*?)</si>', dotAll: true).allMatches(sst)) {
    final inner = m.group(1) ?? '';
    final sbuf = StringBuffer();
    for (final t in RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true).allMatches(inner)) {
      sbuf.write(_unxml(t.group(1) ?? ''));
    }
    shared.add(sbuf.toString());
  }
  final sheet = text(find((n) =>
      n == 'xl/worksheets/sheet1.xml' ||
      (n.startsWith('xl/worksheets/sheet') && n.endsWith('.xml'))));
  final rows = <List<String>>[];
  for (final rm in RegExp(r'<row[^>]*>(.*?)</row>', dotAll: true).allMatches(sheet)) {
    final cells = <int, String>{};
    for (final cm in RegExp(r'<c\s+([^>]*?)(?:/>|>(.*?)</c>)', dotAll: true)
        .allMatches(rm.group(1) ?? '')) {
      final attrs = cm.group(1) ?? '';
      final body = cm.group(2) ?? '';
      final ref = RegExp(r'r="([A-Z]+)\d+"').firstMatch(attrs)?.group(1);
      if (ref == null) continue;
      final type = RegExp(r't="(\w+)"').firstMatch(attrs)?.group(1);
      String v = '';
      if (type == 's') {
        final i = int.tryParse(
            RegExp(r'<v>(.*?)</v>', dotAll: true).firstMatch(body)?.group(1) ?? '');
        if (i != null && i < shared.length) v = shared[i];
      } else if (type == 'inlineStr') {
        final sbuf = StringBuffer();
        for (final t in RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true).allMatches(body)) {
          sbuf.write(_unxml(t.group(1) ?? ''));
        }
        v = sbuf.toString();
      } else {
        v = _unxml(RegExp(r'<v>(.*?)</v>', dotAll: true).firstMatch(body)?.group(1) ?? '');
        if (v.endsWith('.0')) v = v.substring(0, v.length - 2);
      }
      cells[_colIndex(ref)] = v;
    }
    if (cells.isEmpty) continue;
    final maxC = cells.keys.reduce((a, b) => a > b ? a : b);
    final row = [for (var i = 0; i <= maxC; i++) cells[i] ?? ''];
    if (row.any((e) => e.trim().isNotEmpty)) rows.add(row);
  }
  return rows;
}

// ================= ملفات: اختيار ومشاركة =================
class PickedFile {
  final String name;
  final Uint8List bytes;
  PickedFile(this.name, this.bytes);
}

Future<PickedFile?> pickAnyFile() async {
  final r = await FilePicker.platform.pickFiles(withData: true);
  if (r == null || r.files.isEmpty) return null;
  final f = r.files.first;
  final b = f.bytes;
  if (b == null) return null;
  return PickedFile(f.name, b);
}

/// يقرأ ملف جدول (xlsx أو csv) ويعيد صفوفه.
List<List<String>> parseTableFile(PickedFile f) {
  final n = f.name.toLowerCase();
  if (n.endsWith('.xlsx')) return readXlsx(f.bytes);
  return parseCsv(utf8.decode(f.bytes, allowMalformed: true));
}

Future<void> shareBytes(String fileName, List<int> bytes, {String? mime}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  await Share.shareXFiles([XFile(file.path, mimeType: mime)], text: fileName);
}

Future<void> exportTable(ExportTable t,
    {required bool xlsx, bool withTitle = false, String school = '', String year = ''}) async {
  final rows = <List<String>>[
    if (withTitle) [t.title],
    if (withTitle) [[school, year].where((e) => e.isNotEmpty).join(' - ')],
    if (withTitle) <String>[],
    t.heads,
    ...t.rows,
  ];
  final safe = t.title.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
  if (xlsx) {
    await shareBytes('$safe.xlsx',
        buildXlsx(t.title, rows, boldFirstRow: !withTitle),
        mime: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  } else {
    await shareBytes('$safe.csv', csvBytes(rows), mime: 'text/csv');
  }
}

/// يختار صورة من المعرض، يصغّرها (حتى 1200 بكسل) ويحفظها في مجلد التطبيق ويعيد مسارها.
/// لا تُحمَّل الصورة كاملة عبر القناة (كان ذلك يسبب انهيار التطبيق مع الصور الكبيرة).
Future<String?> pickAndStoreImage(String prefix) async {
  final r = await FilePicker.platform.pickFiles(type: FileType.image, withData: false);
  if (r == null || r.files.isEmpty) return null;
  final src = r.files.first.path;
  if (src == null) return null;
  final dir = await getApplicationDocumentsDirectory();
  final folder = Directory('${dir.path}/images');
  if (!await folder.exists()) await folder.create(recursive: true);
  final base = '${folder.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}';
  try {
    final bytes = await File(src).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1200);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    if (data != null) {
      final out = File('$base.png');
      await out.writeAsBytes(data.buffer.asUint8List(), flush: true);
      return out.path;
    }
  } catch (_) {}
  // بديل: نسخ الملف كما هو
  final ext = src.contains('.') ? src.split('.').last.toLowerCase() : 'png';
  final out = File('$base.$ext');
  await File(src).copy(out.path);
  return out.path;
}
