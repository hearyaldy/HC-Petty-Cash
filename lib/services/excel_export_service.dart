import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/petty_cash_report.dart';
import '../models/enums.dart';
import '../utils/constants.dart';
import 'firestore_service.dart';

class ExcelExportService {
  Future<String> exportReport(PettyCashReport report) async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['Petty Cash Report'];

    // Remove default sheet if it exists
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final dateFormat = DateFormat('MMM dd, yyyy');
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    int currentRow = 0;

    // Header Section
    _setCellValue(sheet, 0, currentRow, AppConstants.organizationName);
    _mergeCells(sheet, currentRow, 0, currentRow, 8);
    _styleCell(sheet, 0, currentRow, bold: true, fontSize: 14);
    currentRow++;

    _setCellValue(sheet, 0, currentRow, AppConstants.organizationAddress);
    _mergeCells(sheet, currentRow, 0, currentRow, 8);
    _styleCell(sheet, 0, currentRow, bold: false, fontSize: 11);
    currentRow++;

    currentRow++; // Empty row for spacing

    currentRow++; // Empty row

    _setCellValue(sheet, 0, currentRow, 'PETTY CASH REPORT');
    _mergeCells(sheet, currentRow, 0, currentRow, 8);
    _styleCell(sheet, 0, currentRow, bold: true, fontSize: 14);
    currentRow++;

    currentRow++; // Empty row

    // Report Info
    _setCellValue(sheet, 0, currentRow, 'Report Number:');
    _setCellValue(sheet, 1, currentRow, report.reportNumber);
    _styleCell(sheet, 0, currentRow, bold: true);
    currentRow++;

    _setCellValue(sheet, 0, currentRow, 'Period:');
    _setCellValue(
      sheet,
      1,
      currentRow,
      '${dateFormat.format(report.periodStart)} - ${dateFormat.format(report.periodEnd)}',
    );
    _styleCell(sheet, 0, currentRow, bold: true);
    currentRow++;

    _setCellValue(sheet, 0, currentRow, 'Department:');
    _setCellValue(sheet, 1, currentRow, report.department);
    _styleCell(sheet, 0, currentRow, bold: true);
    currentRow++;

    _setCellValue(sheet, 0, currentRow, 'Custodian:');
    _setCellValue(sheet, 1, currentRow, report.custodianName);
    _styleCell(sheet, 0, currentRow, bold: true);
    currentRow++;

    _setCellValue(sheet, 0, currentRow, 'Status:');
    _setCellValue(sheet, 1, currentRow, report.statusEnum.displayName);
    _styleCell(sheet, 0, currentRow, bold: true);
    currentRow++;

    currentRow++; // Empty row

    // Opening Balance
    _setCellValue(sheet, 0, currentRow, 'Opening Balance:');
    _setCellValue(
      sheet,
      1,
      currentRow,
      currencyFormat.format(report.openingBalance),
    );
    _styleCell(sheet, 0, currentRow, bold: true);
    _styleCell(sheet, 1, currentRow, bold: true);
    currentRow++;

    currentRow++; // Empty row

    // Transactions Table Header
    final headers = [
      'Date',
      'Receipt No',
      'Description',
      'Category',
      'Payment Method',
      'Requestor',
      'Approver',
      'Status',
      'Amount',
    ];

    for (int i = 0; i < headers.length; i++) {
      _setCellValue(sheet, i, currentRow, headers[i]);
      _styleCell(sheet, i, currentRow, bold: true, backgroundColor: 'FF4A148C');
      _setTextColor(sheet, i, currentRow, 'FFFFFFFF');
    }
    currentRow++;

    // Get transactions
    final firestoreService = FirestoreService();
    final transactions = await firestoreService.getTransactionsByReportId(
      report.id,
    );

    // Transactions Data
    for (var transaction in transactions) {
      final requestor = await firestoreService.getUser(transaction.requestorId);
      final approver = transaction.approverId != null
          ? await firestoreService.getUser(transaction.approverId!)
          : null;

      _setCellValue(sheet, 0, currentRow, dateFormat.format(transaction.date));
      _setCellValue(sheet, 1, currentRow, transaction.receiptNo);
      _setCellValue(sheet, 2, currentRow, transaction.description);
      _setCellValue(
        sheet,
        3,
        currentRow,
        transaction.category.expenseCategoryDisplayName,
      );
      _setCellValue(
        sheet,
        4,
        currentRow,
        transaction.paymentMethod.paymentMethodDisplayName,
      );
      _setCellValue(sheet, 5, currentRow, requestor?.name ?? 'Unknown');
      _setCellValue(sheet, 6, currentRow, approver?.name ?? '-');
      _setCellValue(
        sheet,
        7,
        currentRow,
        transaction.status.transactionStatusDisplayName,
      );
      _setCellValue(
        sheet,
        8,
        currentRow,
        currencyFormat.format(transaction.amount),
      );

      currentRow++;
    }

    currentRow++; // Empty row

    // Summary Section
    _setCellValue(sheet, 7, currentRow, 'Total Disbursements:');
    _setCellValue(
      sheet,
      8,
      currentRow,
      currencyFormat.format(report.totalDisbursements),
    );
    _styleCell(sheet, 7, currentRow, bold: true);
    _styleCell(sheet, 8, currentRow, bold: true);
    currentRow++;

    _setCellValue(sheet, 7, currentRow, 'Cash on Hand:');
    _setCellValue(
      sheet,
      8,
      currentRow,
      currencyFormat.format(report.cashOnHand),
    );
    _styleCell(sheet, 7, currentRow, bold: true);
    _styleCell(sheet, 8, currentRow, bold: true);
    currentRow++;

    _setCellValue(sheet, 7, currentRow, 'Closing Balance:');
    _setCellValue(
      sheet,
      8,
      currentRow,
      currencyFormat.format(report.closingBalance),
    );
    _styleCell(sheet, 7, currentRow, bold: true);
    _styleCell(sheet, 8, currentRow, bold: true);
    currentRow++;

    _setCellValue(sheet, 7, currentRow, 'Variance:');
    _setCellValue(sheet, 8, currentRow, currencyFormat.format(report.variance));
    _styleCell(sheet, 7, currentRow, bold: true);
    _styleCell(sheet, 8, currentRow, bold: true);

    // Set column widths
    for (int i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, 20);
    }

    // Save file
    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Failed to encode Excel file');
    }

    final directory = await getApplicationDocumentsDirectory();
    final fileName =
        '${report.reportNumber}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final filePath = '${directory.path}/$fileName';

    final file = File(filePath);
    await file.writeAsBytes(bytes);

    return filePath;
  }

  void _setCellValue(Sheet sheet, int col, int row, dynamic value) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    cell.value = TextCellValue(value.toString());
  }

  void _styleCell(
    Sheet sheet,
    int col,
    int row, {
    bool bold = false,
    int fontSize = 11,
    String? backgroundColor,
  }) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    if (backgroundColor != null) {
      cell.cellStyle = CellStyle(
        bold: bold,
        fontSize: fontSize,
        backgroundColorHex: ExcelColor.fromHexString(backgroundColor),
      );
    } else {
      cell.cellStyle = CellStyle(bold: bold, fontSize: fontSize);
    }
  }

  void _setTextColor(Sheet sheet, int col, int row, String colorHex) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    cell.cellStyle = CellStyle(
      bold: true,
      fontSize: 11,
      backgroundColorHex: ExcelColor.fromHexString('FF4A148C'),
      fontColorHex: ExcelColor.fromHexString(colorHex),
    );
  }

  void _mergeCells(
    Sheet sheet,
    int startRow,
    int startCol,
    int endRow,
    int endCol,
  ) {
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: startRow),
      CellIndex.indexByColumnRow(columnIndex: endCol, rowIndex: endRow),
    );
  }
}
