import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as excel_package;
import 'package:file_picker/file_picker.dart';

import '../models/equipment.dart';

class InventoryImportRow {
  final int index;
  final Map<String, String> raw;

  InventoryImportRow({required this.index, required this.raw});

  String? get name => _get('name');
  String? get description => _get('description');
  String? get category => _get('category');
  String? get brand => _get('brand');
  String? get model => _get('model');
  String? get serialNumber => _get('serialNumber');
  String? get assetTag => _get('assetTag');
  String? get assetCode => _get('assetCode');
  String? get accountingPeriod => _get('accountingPeriod');
  String? get location => _get('location');
  String? get status => _get('status');
  String? get condition => _get('condition');
  String? get purchasePrice => _get('purchasePrice');
  String? get purchaseDate => _get('purchaseDate');
  String? get purchaseYear => _get('purchaseYear');
  String? get supplier => _get('supplier');
  String? get warrantyExpiry => _get('warrantyExpiry');
  String? get notes => _get('notes');
  String? get assignedToId => _get('assignedToId');
  String? get assignedToName => _get('assignedToName');
  String? get currentHolderId => _get('currentHolderId');
  String? get currentHolderName => _get('currentHolderName');
  String? get quantity => _get('quantity');
  String? get unitCost => _get('unitCost');
  String? get depreciationPercentage => _get('depreciationPercentage');
  String? get monthsDepreciated => _get('monthsDepreciated');

  String? _get(String key) {
    final value = raw[key];
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class InventoryImportResult {
  final List<InventoryImportRow> rows;
  final List<String> warnings;

  InventoryImportResult({required this.rows, required this.warnings});
}

class InventoryImportService {
  static const List<String> allowedExtensions = ['csv', 'xlsx'];

  Future<InventoryImportResult> parseFile(
    PlatformFile file, {
    String? sheetName,
  }) async {
    final extension = (file.extension ?? '').toLowerCase();
    if (!allowedExtensions.contains(extension)) {
      throw Exception('Unsupported file type: .$extension');
    }

    final bytes = file.bytes;
    if (bytes == null) {
      throw Exception('Unable to read file contents. Please reselect the file.');
    }

    if (extension == 'csv') {
      return _parseCsv(bytes);
    }
    return _parseXlsx(bytes, sheetName: sheetName);
  }

  /// Sheet names in file order — an .xlsx with more than one sheet (e.g. a
  /// combined "Depreciation Table" + "Uncapitalization" export) needs the
  /// caller to ask which one to import, since silently taking the first
  /// sheet can import the wrong asset list entirely.
  List<String> listXlsxSheets(Uint8List bytes) {
    final excel = excel_package.Excel.decodeBytes(_sanitizeXlsxStyles(bytes));
    return excel.tables.keys.toList();
  }

  /// The `excel` package's style parser hard-throws
  /// ("custom numFmtId starts at 164 but found a value of N") if
  /// `xl/styles.xml` has a `<numFmt>` entry with an id under 164 — the
  /// range OOXML reserves for custom formats. Some export tools (this
  /// happens on real files, not just crafted ones) redundantly redefine a
  /// *built-in* format id (e.g. 43, the standard accounting format) as a
  /// custom entry anyway; harmless to Excel itself, fatal to this parser.
  /// Strips those specific entries before decoding — the built-in format
  /// is already known internally, so nothing is lost, only the pointless
  /// redefinition. Best-effort: falls back to the original bytes if the
  /// archive can't be read or has no such entries, so a file that isn't
  /// hitting this bug is unaffected.
  Uint8List _sanitizeXlsxStyles(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final stylesFile = archive.findFile('xl/styles.xml');
      if (stylesFile == null) return bytes;

      final xml = utf8.decode(stylesFile.content as List<int>);
      final fixed = xml.replaceAllMapped(
        RegExp(r'<numFmt\s+numFmtId="(\d+)"[^>]*/>'),
        (match) {
          final id = int.tryParse(match.group(1)!) ?? 164;
          return id < 164 ? '' : match.group(0)!;
        },
      );
      if (fixed == xml) return bytes;

      final rebuilt = Archive();
      for (final file in archive.files) {
        if (!file.isFile) continue;
        if (file.name == 'xl/styles.xml') {
          final content = utf8.encode(fixed);
          rebuilt.addFile(ArchiveFile('xl/styles.xml', content.length, content));
        } else {
          rebuilt.addFile(ArchiveFile(file.name, file.size, file.content));
        }
      }
      final rezipped = ZipEncoder().encode(rebuilt);
      return rezipped != null ? Uint8List.fromList(rezipped) : bytes;
    } catch (_) {
      return bytes;
    }
  }

  Future<InventoryImportResult> _parseCsv(Uint8List bytes) async {
    final content = utf8.decode(bytes);
    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(content);

    if (rows.isEmpty) {
      return InventoryImportResult(rows: [], warnings: ['Empty CSV file.']);
    }

    final stringRows = rows
        .map((row) => row.map((e) => e?.toString() ?? '').toList())
        .toList();
    final headerIndex = _findHeaderRowIndex(stringRows);
    final headers = stringRows[headerIndex];
    final normalized = headers.map(_normalizeHeader).toList();
    final warnings = _validateHeaders(headers);

    final parsedRows = <InventoryImportRow>[];
    for (var i = headerIndex + 1; i < stringRows.length; i++) {
      final row = stringRows[i];
      if (row.every((cell) => cell.trim().isEmpty)) {
        continue;
      }
      final map = _rowToMap(normalized, row);
      parsedRows.add(InventoryImportRow(index: i + 1, raw: map));
    }

    return InventoryImportResult(rows: parsedRows, warnings: warnings);
  }

  /// Finds the row that actually holds column headers, scanning the first
  /// 20 rows for the one where at least 2 cells match a recognized column
  /// name. Formatted exports (like an accounting system's asset register)
  /// often put a title block — org name, campus, report title, a blank
  /// row — above the real header row, and assuming row 1 is always the
  /// header misreads that title text as columns, so every field would fail
  /// to map and the actual header row above would be misparsed as a data
  /// row instead.
  int _findHeaderRowIndex(List<List<String>> rows) {
    final scanLimit = rows.length < 20 ? rows.length : 20;
    for (var i = 0; i < scanLimit; i++) {
      final normalized = rows[i].map(_normalizeHeader).toList();
      final mappedCount = normalized.where((h) => _mapHeader(h) != null).length;
      if (mappedCount >= 2) return i;
    }
    return 0;
  }

  Future<InventoryImportResult> _parseXlsx(
    Uint8List bytes, {
    String? sheetName,
  }) async {
    final excel = excel_package.Excel.decodeBytes(_sanitizeXlsxStyles(bytes));
    if (excel.tables.isEmpty) {
      return InventoryImportResult(rows: [], warnings: ['Empty Excel file.']);
    }

    final sheet = sheetName != null
        ? excel.tables[sheetName]
        : excel.tables.values.first;
    if (sheet == null) {
      return InventoryImportResult(
        rows: [],
        warnings: ['Sheet "$sheetName" not found in this file.'],
      );
    }
    if (sheet.rows.isEmpty) {
      return InventoryImportResult(rows: [], warnings: ['Empty Excel sheet.']);
    }

    final stringRows = sheet.rows
        .map((row) => row.map((cell) => cell?.value?.toString() ?? '').toList())
        .toList();
    final headerIndex = _findHeaderRowIndex(stringRows);
    final headers = stringRows[headerIndex];
    final normalized = headers.map(_normalizeHeader).toList();
    final warnings = _validateHeaders(headers);

    final parsedRows = <InventoryImportRow>[];
    for (var i = headerIndex + 1; i < stringRows.length; i++) {
      final row = stringRows[i];
      if (row.every((cell) => cell.trim().isEmpty)) {
        continue;
      }
      final map = _rowToMap(normalized, row);
      parsedRows.add(InventoryImportRow(index: i + 1, raw: map));
    }

    return InventoryImportResult(rows: parsedRows, warnings: warnings);
  }

  Map<String, String> _rowToMap(List<String> normalizedHeaders, List<dynamic> row) {
    final map = <String, String>{};
    for (var i = 0; i < normalizedHeaders.length; i++) {
      final key = _mapHeader(normalizedHeaders[i]);
      if (key == null) continue;
      final value = i < row.length ? row[i]?.toString() ?? '' : '';
      // First occurrence wins. A bilingual header pair like "Description"
      // + "Description/คำอธิบาย" both normalize to the same key once
      // non-Latin characters are stripped — without this, the Thai column
      // (whichever export happens to put later) would silently clobber the
      // English one already captured from the first column.
      if (value.isNotEmpty && (map[key] == null || map[key]!.isEmpty)) {
        map[key] = value;
      } else {
        map.putIfAbsent(key, () => value);
      }
    }
    return map;
  }

  List<String> _validateHeaders(List<String> headers) {
    final normalized = headers.map(_normalizeHeader).toSet();
    if (!normalized.contains('name') && !normalized.contains('assetcode')) {
      return [
        'Missing recommended column: `name` or `assetCode`.',
      ];
    }
    return [];
  }

  String _normalizeHeader(String header) {
    return header.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String? _mapHeader(String normalized) {
    const map = {
      'name': 'name',
      'assetname': 'name',
      'description': 'description',
      'category': 'category',
      'brand': 'brand',
      'model': 'model',
      'serialnumber': 'serialNumber',
      'serialno': 'serialNumber',
      'serial': 'serialNumber',
      'assettag': 'assetTag',
      'assetcode': 'assetCode',
      // The organization's own accounting exports (e.g. the yearly
      // "Uncapitalization" / "Depreciation Table" asset register) use
      // "Account Code" / "Period" / "Date" / "QTY" / "Base Amount" rather
      // than this app's own field names.
      'accountcode': 'assetCode',
      'accountingperiod': 'accountingPeriod',
      'period': 'accountingPeriod',
      'location': 'location',
      'status': 'status',
      'condition': 'condition',
      'purchaseprice': 'purchasePrice',
      'baseamount': 'purchasePrice',
      'purchasedate': 'purchaseDate',
      'date': 'purchaseDate',
      'purchaseyear': 'purchaseYear',
      'supplier': 'supplier',
      'warrantyexpiry': 'warrantyExpiry',
      'warrantyexpiration': 'warrantyExpiry',
      'notes': 'notes',
      'assignedtoid': 'assignedToId',
      'assignedtoname': 'assignedToName',
      'currentholderid': 'currentHolderId',
      'currentholdername': 'currentHolderName',
      'quantity': 'quantity',
      'qty': 'quantity',
      'unitcost': 'unitCost',
      'depreciationpercentage': 'depreciationPercentage',
      'monthsdepreciated': 'monthsDepreciated',
    };
    return map[normalized];
  }
}

EquipmentStatus? parseStatus(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return EquipmentStatus.fromString(value);
}

EquipmentCondition? parseCondition(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return EquipmentCondition.fromString(value);
}

DateTime? parseDate(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final direct = DateTime.tryParse(value);
  if (direct != null) return direct;

  final slash = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{2,4})$');
  final match = slash.firstMatch(value.trim());
  if (match != null) {
    final month = int.tryParse(match.group(1)!);
    final day = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);
    if (month != null && day != null && year != null) {
      final fullYear = year < 100 ? 2000 + year : year;
      return DateTime(fullYear, month, day);
    }
  }
  return null;
}

int? parseInt(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return int.tryParse(value.replaceAll(',', ''));
}

double? parseDouble(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return double.tryParse(value.replaceAll(',', ''));
}
