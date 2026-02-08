import 'dart:convert';
import 'dart:typed_data';

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

  Future<InventoryImportResult> parseFile(PlatformFile file) async {
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
    return _parseXlsx(bytes);
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

    final headers = rows.first.map((e) => e?.toString() ?? '').toList();
    final normalized = headers.map(_normalizeHeader).toList();
    final warnings = _validateHeaders(headers);

    final parsedRows = <InventoryImportRow>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.every((cell) => (cell?.toString() ?? '').trim().isEmpty)) {
        continue;
      }
      final map = _rowToMap(normalized, row);
      parsedRows.add(InventoryImportRow(index: i + 1, raw: map));
    }

    return InventoryImportResult(rows: parsedRows, warnings: warnings);
  }

  Future<InventoryImportResult> _parseXlsx(Uint8List bytes) async {
    final excel = excel_package.Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      return InventoryImportResult(rows: [], warnings: ['Empty Excel file.']);
    }

    final sheet = excel.tables.values.first;
    if (sheet.rows.isEmpty) {
      return InventoryImportResult(rows: [], warnings: ['Empty Excel sheet.']);
    }

    final headerRow = sheet.rows.first;
    final headers = headerRow.map((cell) => cell?.value?.toString() ?? '').toList();
    final normalized = headers.map(_normalizeHeader).toList();
    final warnings = _validateHeaders(headers);

    final parsedRows = <InventoryImportRow>[];
    for (var i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (row.every((cell) => (cell?.value?.toString() ?? '').trim().isEmpty)) {
        continue;
      }
      final rowValues = row.map((cell) => cell?.value?.toString() ?? '').toList();
      final map = _rowToMap(normalized, rowValues);
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
      map[key] = value;
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
      'accountingperiod': 'accountingPeriod',
      'location': 'location',
      'status': 'status',
      'condition': 'condition',
      'purchaseprice': 'purchasePrice',
      'purchasedate': 'purchaseDate',
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
