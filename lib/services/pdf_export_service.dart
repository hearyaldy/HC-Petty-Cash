import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:barcode/barcode.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../models/petty_cash_report.dart';
import '../models/transaction.dart';
import '../models/equipment.dart';
import '../models/income_report.dart';
import '../models/enums.dart';
import '../utils/constants.dart';
import 'firestore_service.dart';
import 'pdf_signature_helper.dart';

/// Enum for equipment fields that can be included in the print export
enum EquipmentPrintField {
  assetCode('Asset Code'),
  itemStickerTag('Item Sticker Tag'),
  name('Asset Name'),
  description('Description'),
  category('Category'),
  brand('Brand'),
  model('Model'),
  serialNumber('Serial Number'),
  assetTag('Asset Tag'),
  assetTagQr('Asset Tag QR'),
  assetTagBarcode('Asset Tag Barcode'),
  accountingPeriod('Accounting Period'),
  location('Location'),
  assignedTo('Assigned To'),
  status('Status'),
  condition('Condition'),
  purchaseYear('Purchase Year'),
  purchaseDate('Purchase Date'),
  purchasePrice('Purchase Price'),
  quantity('Quantity'),
  unitCost('Unit Cost'),
  depreciationPercentage('Depreciation %'),
  assetAge('Asset Age'),
  monthlyDepreciation('Monthly Depreciation'),
  totalDepreciation('Total Depreciation'),
  currentBookValue('Book Value'),
  supplier('Supplier'),
  warrantyExpiry('Warranty Expiry'),
  currentHolder('Current Holder'),
  notes('Notes');

  final String displayName;
  const EquipmentPrintField(this.displayName);

  /// Get default fields for quick print
  static List<EquipmentPrintField> get defaultFields => [
        EquipmentPrintField.assetCode,
        EquipmentPrintField.itemStickerTag,
        EquipmentPrintField.name,
        EquipmentPrintField.category,
        EquipmentPrintField.brand,
        EquipmentPrintField.model,
        EquipmentPrintField.status,
        EquipmentPrintField.condition,
        EquipmentPrintField.location,
        EquipmentPrintField.purchasePrice,
      ];

  /// Get all available fields
  static List<EquipmentPrintField> get allFields => EquipmentPrintField.values;
}

class PdfExportService {
  pw.Font? _regularFont;
  pw.Font? _boldFont;
  pw.ThemeData? _pdfTheme;

  /// Sorts transactions chronologically, breaking ties (same date) by the
  /// numeric portion of the receipt number so rows like 001, 002, 003
  /// print in order instead of following raw Firestore fetch order.
  static int _compareByDateAndReceipt(Transaction a, Transaction b) {
    // Compare calendar day only — `date` often carries a time-of-day
    // component (e.g. DateTime.now() at entry time), which made same-day
    // transactions rarely compare equal and skip the receiptNo tiebreak.
    final aDay = DateTime(a.date.year, a.date.month, a.date.day);
    final bDay = DateTime(b.date.year, b.date.month, b.date.day);
    final dateComparison = aDay.compareTo(bDay);
    if (dateComparison != 0) return dateComparison;

    final aNumber = int.tryParse(a.receiptNo.replaceAll(RegExp(r'[^0-9]'), ''));
    final bNumber = int.tryParse(b.receiptNo.replaceAll(RegExp(r'[^0-9]'), ''));
    if (aNumber != null && bNumber != null) return aNumber.compareTo(bNumber);
    return a.receiptNo.compareTo(b.receiptNo);
  }

  Future<pw.ThemeData> _getPdfTheme() async {
    if (_pdfTheme != null) return _pdfTheme!;
    pw.Font? regular;
    pw.Font? bold;
    try {
      regular = _regularFont ??
          pw.Font.ttf(
            await rootBundle.load('assets/fonts/NotoSansThai-Regular.ttf'),
          );
      bold = _boldFont ??
          pw.Font.ttf(
            await rootBundle.load('assets/fonts/NotoSansThai-Bold.ttf'),
          );
      _regularFont = regular;
      _boldFont = bold;
    } catch (e) {
      // Fall back to built-in fonts if custom fonts fail to load.
    }

    pw.Font? notoFallback;
    pw.Font? emojiFont;
    try {
      notoFallback = await PdfGoogleFonts.notoSansRegular();
    } catch (_) {}
    try {
      emojiFont = await PdfGoogleFonts.notoColorEmojiRegular();
    } catch (_) {}

    _pdfTheme = pw.ThemeData.withFont(
      base: regular ?? pw.Font.helvetica(),
      bold: bold ?? pw.Font.helveticaBold(),
      fontFallback: [?notoFallback, ?emojiFont],
    );
    return _pdfTheme!;
  }

  Future<pw.Document> _createPdfDocument() async {
    final theme = await _getPdfTheme();
    return pw.Document(theme: theme);
  }

  /// Export equipment sticker sheet to PDF bytes
  Future<List<int>> exportEquipmentStickerSheetBytes(
    List<Equipment> equipment,
    StickerPrintConfig config,
  ) async {
    final pdf = await _createPdfDocument();
    final stickerItems =
        equipment.where((e) => e.itemStickerTag != null).toList();
    final totalPerPage = config.rows * config.columns;
    if (totalPerPage <= 0) return await pdf.save();

    final pageContentWidthPt = config.stickerWidthPt * config.columns +
        config.horizontalGapPt * (config.columns - 1);
    final availableWidthPt = config.pageFormat.width - (2 * config.marginPt);
    final double extraLeftPaddingPt =
        (availableWidthPt - pageContentWidthPt) > 0
            ? (availableWidthPt - pageContentWidthPt) / 2
            : 0.0;

    // Calculate start position (convert 1-indexed to 0-indexed)
    final startRowIndex = (config.startRow - 1).clamp(0, config.rows - 1);
    final startColIndex = (config.startColumn - 1).clamp(0, config.columns - 1);
    final startSlotIndex = startRowIndex * config.columns + startColIndex;

    // Build a map of slot index -> equipment item
    final Map<int, Equipment> slotMap = {};
    int currentItemIndex = 0;
    int currentSlot = startSlotIndex; // Start from the user-specified position

    while (currentItemIndex < stickerItems.length) {
      slotMap[currentSlot] = stickerItems[currentItemIndex];
      currentItemIndex++;
      currentSlot++;
    }

    // Calculate how many pages we need
    final lastSlot = currentSlot - 1;
    final totalPages = (lastSlot ~/ totalPerPage) + 1;

    for (int pageNumber = 0; pageNumber < totalPages; pageNumber++) {
      final pageStartSlot = pageNumber * totalPerPage;

      pdf.addPage(
        pw.Page(
          pageFormat: config.pageFormat,
          margin: pw.EdgeInsets.all(config.marginPt),
          build: (context) {
            return pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.start,
              children: List.generate(config.rows, (rowIndex) {
                return pw.Padding(
                  padding: pw.EdgeInsets.only(
                    bottom: rowIndex == config.rows - 1
                        ? 0
                        : config.verticalGapPt,
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: List.generate(config.columns, (colIndex) {
                      final slotIndex =
                          pageStartSlot + rowIndex * config.columns + colIndex;
                      final item = slotMap[slotIndex];
                      return pw.Padding(
                        padding: pw.EdgeInsets.only(
                          left: colIndex == 0
                              ? (extraLeftPaddingPt +
                                  config.offsetLeftPt -
                                  config.offsetRightPt)
                              : 0.0,
                          right: colIndex == config.columns - 1
                              ? 0
                              : config.horizontalGapPt,
                        ),
                        child: _buildStickerCell(item, config),
                      );
                    }),
                  ),
                );
              }),
            );
          },
        ),
      );
    }

    return await pdf.save();
  }

  /// Export a receipt for a single income entry
  Future<List<int>> exportIncomeReceiptBytes(
    IncomeReport report,
    IncomeEntry entry,
    String receiptNumber,
  ) async {
    final pdf = await _createPdfDocument();
    final dateFormat = DateFormat('MMM dd, yyyy');
    final currencyFormat = NumberFormat.currency(
      symbol: '${AppConstants.currencySymbol} ',
      decimalDigits: 2,
    );

    pw.ImageProvider? logoImage;
    try {
      final logoData = await rootBundle.load(
        'assets/images/hope_channel_logo.png',
      );
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      // Logo loading failed, will use fallback
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (logoImage != null)
                    pw.Container(
                      width: 48,
                      height: 48,
                      child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                    )
                  else
                    pw.Container(
                      width: 48,
                      height: 48,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey300,
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          'H',
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ),
                    ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          AppConstants.organizationName,
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          AppConstants.organizationAddress,
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green100,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Text(
                      'RECEIPT',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Receipt No: $receiptNumber',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                  pw.Text(
                    'Date: ${dateFormat.format(entry.dateReceived)}',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
              pw.SizedBox(height: 14),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Amount Received',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.Text(
                      currencyFormat.format(entry.amount),
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green800,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildReceiptRow('Payer', entry.sourceName),
                    _buildReceiptRow(
                      'Report',
                      '${report.reportNumber} - ${report.reportName}',
                    ),
                    _buildReceiptRow(
                      'Category',
                      incomeCategoryFromString(entry.category).displayName,
                    ),
                    _buildReceiptRow(
                      'Payment Method',
                      paymentMethodFromString(entry.paymentMethod).displayName,
                    ),
                    if (entry.referenceNumber != null &&
                        entry.referenceNumber!.isNotEmpty)
                      _buildReceiptRow('Reference', entry.referenceNumber!),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Description',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(entry.description),
                  ],
                ),
              ),
              pw.Spacer(),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Received By',
                            style: const pw.TextStyle(fontSize: 9)),
                        pw.SizedBox(height: 24),
                        pw.Container(
                          height: 1,
                          width: 180,
                          color: PdfColors.grey400,
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Signature',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 24),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Payer',
                            style: const pw.TextStyle(fontSize: 9)),
                        pw.SizedBox(height: 24),
                        pw.Container(
                          height: 1,
                          width: 180,
                          color: PdfColors.grey400,
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Signature',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Text(
                'Issued on ${dateFormat.format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  pw.Widget _buildReceiptRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildStickerCell(Equipment? item, StickerPrintConfig config) {
    return pw.Container(
      width: config.stickerWidthPt,
      height: config.stickerHeightPt,
      padding: pw.EdgeInsets.only(
        left: 4 + config.stickerLeftPaddingPt,
        right: 4,
        top: 4,
        bottom: 4,
      ),
      child: item == null
          ? pw.SizedBox()
          : pw.Center(
              child: pw.Padding(
                padding: const pw.EdgeInsets.all(2),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (config.includeQr) ...[
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4),
                        child: pw.BarcodeWidget(
                          barcode: Barcode.qrCode(),
                          data: item.itemStickerTag!,
                          width: config.qrSizePt * 0.9,
                          height: config.qrSizePt * 0.9,
                          drawText: false,
                        ),
                      ),
                      pw.SizedBox(width: 4),
                    ],
                    pw.Expanded(
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Organization Name
                          if (item.organizationName != null &&
                              item.organizationName!.isNotEmpty)
                            pw.Text(
                              item.organizationName!,
                              style: pw.TextStyle(
                                fontSize: config.textSize - 2,
                                fontWeight: pw.FontWeight.bold,
                              ),
                              maxLines: 1,
                            ),
                          // Item Sticker Tag
                          pw.Text(
                            item.itemStickerTag!,
                            style: pw.TextStyle(
                              fontSize: config.textSize - 1,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            maxLines: 1,
                          ),
                          if (config.includeBarcode) ...[
                            pw.SizedBox(height: 2),
                            pw.BarcodeWidget(
                              barcode: Barcode.code128(),
                              data: item.itemStickerTag!,
                              width: config.barcodeWidthPt * 0.9,
                              height: config.barcodeHeightPt * 0.9,
                              drawText: false,
                            ),
                          ],
                          // Item Name under barcode
                          pw.SizedBox(height: 1),
                          pw.Text(
                            item.name,
                            style: pw.TextStyle(
                              fontSize: config.textSize - 3,
                            ),
                            maxLines: 1,
                            overflow: pw.TextOverflow.clip,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  /// Export equipment list to PDF with selected fields
  /// Returns the PDF bytes for web compatibility
  Future<List<int>> exportEquipmentListBytes(
    List<Equipment> equipment,
    List<EquipmentPrintField> selectedFields, {
    String? title,
  }) async {
    final pdf = await _createPdfDocument();
    final dateFormat = DateFormat('MMM dd, yyyy');
    final currencyFormat = NumberFormat.currency(symbol: 'THB ', decimalDigits: 2);

    // Load logo
    pw.ImageProvider? logoImage;
    try {
      final logoData = await rootBundle.load(
        'assets/images/hope_channel_logo.png',
      );
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      // Logo loading failed, will use fallback
    }

    final reportTitle = title ?? 'Equipment Inventory List';

    // Calculate column flex values based on field types
    final columnFlexes = _getColumnFlexes(selectedFields);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _buildEquipmentHeader(logoImage, reportTitle),
        footer: (context) => _buildEquipmentFooter(context, equipment.length),
        build: (context) => [
          // Summary info
          _buildEquipmentSummary(equipment),
          pw.SizedBox(height: 16),

          // Equipment table
          _buildEquipmentTable(
            equipment,
            selectedFields,
            columnFlexes,
            dateFormat,
            currencyFormat,
          ),
        ],
      ),
    );

    return await pdf.save();
  }

  /// Export equipment list to PDF file (for mobile/desktop)
  Future<String> exportEquipmentList(
    List<Equipment> equipment,
    List<EquipmentPrintField> selectedFields, {
    String? title,
  }) async {
    final pdfBytes = await exportEquipmentListBytes(
      equipment,
      selectedFields,
      title: title,
    );

    // Save file
    final directory = await getApplicationDocumentsDirectory();
    final fileName =
        'equipment_list_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final filePath = '${directory.path}/$fileName';

    final file = File(filePath);
    await file.writeAsBytes(pdfBytes);

    return filePath;
  }

  pw.Widget _buildEquipmentHeader(
    pw.ImageProvider? logoImage,
    String title,
  ) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Add logo
            if (logoImage != null)
              pw.Container(
                width: 40,
                height: 40,
                child: pw.Image(logoImage, fit: pw.BoxFit.contain),
              )
            else
              pw.Container(
                width: 40,
                height: 40,
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.DecoratedBox(
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey300,
                      borderRadius: pw.BorderRadius.circular(5),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'H',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            pw.SizedBox(width: 10),
            // Organization name and address
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    AppConstants.organizationName,
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.left,
                  ),
                  pw.Text(
                    AppConstants.organizationAddress,
                    style: const pw.TextStyle(fontSize: 9),
                    textAlign: pw.TextAlign.left,
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          title.toUpperCase(),
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.Divider(),
        pw.SizedBox(height: 8),
      ],
    );
  }

  pw.Widget _buildEquipmentFooter(pw.Context context, int totalItems) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated on: ${DateFormat('MMM dd, yyyy hh:mm a').format(DateTime.now())} | Total Items: $totalItems',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildEquipmentSummary(List<Equipment> equipment) {
    final stats = {
      'Total': equipment.length,
      'Available': equipment
          .where((e) => e.status == EquipmentStatus.available)
          .length,
      'Checked Out': equipment
          .where((e) => e.status == EquipmentStatus.checkedOut)
          .length,
      'Maintenance': equipment
          .where((e) => e.status == EquipmentStatus.maintenance)
          .length,
      'Retired': equipment
          .where((e) => e.status == EquipmentStatus.retired)
          .length,
    };

    // Calculate total value
    final totalValue = equipment.fold<double>(
      0,
      (sum, e) => sum + (e.purchasePrice ?? 0),
    );
    final currencyFormat =
        NumberFormat.currency(symbol: 'THB ', decimalDigits: 2);

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        color: PdfColors.grey100,
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          ...stats.entries.map((entry) => pw.Column(
                children: [
                  pw.Text(
                    entry.value.toString(),
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: entry.key == 'Total'
                          ? PdfColors.indigo
                          : PdfColors.grey800,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    entry.key,
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              )),
          pw.Column(
            children: [
              pw.Text(
                currencyFormat.format(totalValue),
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green800,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Total Value',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<int> _getColumnFlexes(List<EquipmentPrintField> fields) {
    return fields.map((field) {
      switch (field) {
        case EquipmentPrintField.description:
        case EquipmentPrintField.notes:
          return 20;
        case EquipmentPrintField.name:
        case EquipmentPrintField.location:
        case EquipmentPrintField.assignedTo:
        case EquipmentPrintField.currentHolder:
          return 15;
        case EquipmentPrintField.category:
        case EquipmentPrintField.brand:
        case EquipmentPrintField.model:
        case EquipmentPrintField.supplier:
          return 12;
        case EquipmentPrintField.serialNumber:
        case EquipmentPrintField.assetTag:
        case EquipmentPrintField.assetTagQr:
        case EquipmentPrintField.assetTagBarcode:
        case EquipmentPrintField.accountingPeriod:
        case EquipmentPrintField.itemStickerTag:
          return 12;
        case EquipmentPrintField.purchasePrice:
        case EquipmentPrintField.unitCost:
        case EquipmentPrintField.monthlyDepreciation:
        case EquipmentPrintField.totalDepreciation:
        case EquipmentPrintField.currentBookValue:
          return 12;
        default:
          return 10;
      }
    }).toList();
  }

  pw.Widget _buildEquipmentTable(
    List<Equipment> equipment,
    List<EquipmentPrintField> selectedFields,
    List<int> columnFlexes,
    DateFormat dateFormat,
    NumberFormat currencyFormat,
  ) {
    // Build header row
    final headerCells = selectedFields
        .map((field) => pw.Text(field.displayName))
        .toList();

    // Build data rows
    final rows = equipment.map((item) {
      return selectedFields.map((field) {
        return _buildFieldWidget(item, field, dateFormat, currencyFormat);
      }).toList();
    }).toList();

    return pw.ListView.builder(
      itemCount: rows.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildEquipmentTableRow(headerCells, columnFlexes, isHeader: true);
        }
        return _buildEquipmentTableRow(rows[index - 1], columnFlexes);
      },
    );
  }

  String _getFieldValue(
    Equipment item,
    EquipmentPrintField field,
    DateFormat dateFormat,
    NumberFormat currencyFormat,
  ) {
    switch (field) {
      case EquipmentPrintField.assetCode:
        return item.assetCode ?? '-';
      case EquipmentPrintField.itemStickerTag:
        return item.itemStickerTag ?? '-';
      case EquipmentPrintField.name:
        return item.name;
      case EquipmentPrintField.description:
        return item.description ?? '-';
      case EquipmentPrintField.category:
        return item.category;
      case EquipmentPrintField.brand:
        return item.brand ?? '-';
      case EquipmentPrintField.model:
        return item.model ?? '-';
      case EquipmentPrintField.serialNumber:
        return item.serialNumber ?? '-';
      case EquipmentPrintField.assetTag:
        return item.assetTag ?? '-';
      case EquipmentPrintField.assetTagQr:
      case EquipmentPrintField.assetTagBarcode:
        return item.assetTag ?? '-';
      case EquipmentPrintField.accountingPeriod:
        return item.accountingPeriod ?? '-';
      case EquipmentPrintField.location:
        return item.location ?? '-';
      case EquipmentPrintField.assignedTo:
        return item.assignedToName ?? '-';
      case EquipmentPrintField.status:
        return item.status.displayName;
      case EquipmentPrintField.condition:
        return item.condition.displayName;
      case EquipmentPrintField.purchaseYear:
        return item.purchaseYear?.toString() ?? '-';
      case EquipmentPrintField.purchaseDate:
        return item.purchaseDate != null
            ? dateFormat.format(item.purchaseDate!)
            : '-';
      case EquipmentPrintField.purchasePrice:
        return item.purchasePrice != null
            ? currencyFormat.format(item.purchasePrice)
            : '-';
      case EquipmentPrintField.quantity:
        return item.quantity.toString();
      case EquipmentPrintField.unitCost:
        return item.effectiveUnitCost != null
            ? currencyFormat.format(item.effectiveUnitCost)
            : '-';
      case EquipmentPrintField.depreciationPercentage:
        return item.depreciationPercentage != null
            ? '${item.depreciationPercentage!.toStringAsFixed(1)}%'
            : '-';
      case EquipmentPrintField.assetAge:
        final years = item.assetAgeYears;
        if (years == null) return '-';
        return years == 1 ? '1 year' : '$years years';
      case EquipmentPrintField.monthlyDepreciation:
        return item.monthlyDepreciation != null
            ? currencyFormat.format(item.monthlyDepreciation)
            : '-';
      case EquipmentPrintField.totalDepreciation:
        return item.totalDepreciation != null
            ? currencyFormat.format(item.totalDepreciation)
            : '-';
      case EquipmentPrintField.currentBookValue:
        return item.currentBookValue != null
            ? currencyFormat.format(item.currentBookValue)
            : '-';
      case EquipmentPrintField.supplier:
        return item.supplier ?? '-';
      case EquipmentPrintField.warrantyExpiry:
        return item.warrantyExpiry != null
            ? dateFormat.format(item.warrantyExpiry!)
            : '-';
      case EquipmentPrintField.currentHolder:
        return item.currentHolderName ?? '-';
      case EquipmentPrintField.notes:
        return item.notes ?? '-';
    }
  }

  pw.Widget _buildEquipmentTableRow(
    List<pw.Widget> cells,
    List<int> flexes, {
    bool isHeader = false,
  }) {
    final styles = pw.TextStyle(
      fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
      fontSize: isHeader ? 8 : 7,
    );

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: isHeader ? PdfColors.indigo50 : null,
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: pw.Row(
        children: List.generate(cells.length, (index) {
          return pw.Expanded(
            flex: flexes[index],
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 2),
              child: pw.DefaultTextStyle(
                style: styles,
                child: cells[index],
              ),
            ),
          );
        }),
      ),
    );
  }

  pw.Widget _buildFieldWidget(
    Equipment item,
    EquipmentPrintField field,
    DateFormat dateFormat,
    NumberFormat currencyFormat,
  ) {
    if (field == EquipmentPrintField.assetTagQr) {
      final tag = item.assetTag;
      if (tag == null || tag.isEmpty) return pw.Text('-');
      return pw.Center(
        child: pw.BarcodeWidget(
          barcode: Barcode.qrCode(),
          data: tag,
          width: 40,
          height: 40,
          drawText: false,
        ),
      );
    }

    if (field == EquipmentPrintField.assetTagBarcode) {
      final tag = item.assetTag;
      if (tag == null || tag.isEmpty) return pw.Text('-');
      return pw.Center(
        child: pw.BarcodeWidget(
          barcode: Barcode.code128(),
          data: tag,
          width: 80,
          height: 24,
          drawText: false,
        ),
      );
    }

    return pw.Text(
      _getFieldValue(item, field, dateFormat, currencyFormat),
      maxLines: 2,
      overflow: pw.TextOverflow.clip,
    );
  }

  Future<String> exportReport(PettyCashReport report) async {
    final pdf = await _createPdfDocument();
    final dateFormat = DateFormat('MMM dd, yyyy');
    final currencyFormat = NumberFormat.currency(symbol: '${AppConstants.currencySymbol} ');

    // Load logo
    pw.ImageProvider? logoImage;
    try {
      final logoData = await rootBundle.load(
        'assets/images/hope_channel_logo.png',
      );
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      // Logo loading failed, will use fallback
    }
    await PdfSignatureHelper.load();

    // Get transactions
    final rawTransactions = await FirestoreService().getTransactionsByReportId(
      report.id,
    );
    // Sort oldest → newest so PDF rows match chronological order
    final transactions = [...rawTransactions]..sort(_compareByDateAndReceipt);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(report, logoImage),
        footer: (context) => _buildFooter(context, report),
        build: (context) => [
          _buildInfoSection(report, dateFormat),
          pw.SizedBox(height: 20),

          // Opening Balance — highlighted box
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            decoration: pw.BoxDecoration(
              color: PdfColor(0.86, 0.93, 1.0),
              border: pw.Border.all(
                color: PdfColor(0.18, 0.52, 0.80),
                width: 1.5,
              ),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Opening Balance',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 12,
                    color: PdfColor(0.10, 0.35, 0.60),
                  ),
                ),
                pw.Text(
                  report.hasForeignOpeningBalance
                      ? '${currencyFormat.format(report.openingBalance)}  '
                          '(${report.openingBalanceCurrency} '
                          '${NumberFormat('#,##0.00').format(report.openingBalanceForeign)})'
                      : currencyFormat.format(report.openingBalance),
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 13,
                    color: PdfColor(0.10, 0.35, 0.60),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Transactions Table (auto-paginates)
          pw.Text(
            'Transactions',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          _buildTransactionsTable(
            transactions,
            dateFormat,
            currencyFormat,
            fxCode: report.hasForeignOpeningBalance
                ? report.openingBalanceCurrency
                : null,
            fxRate: report.hasForeignOpeningBalance
                ? report.openingExchangeRate
                : null,
          ),
          pw.SizedBox(height: 15),

          // Summary and Signature Section combined to stay together
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Summary
              _buildSummarySection(report, currencyFormat),

              // Notes
              if (report.notes != null && report.notes!.isNotEmpty) ...[
                pw.SizedBox(height: 15),
                pw.Text(
                  'Notes:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 5),
                pw.Text(report.notes!),
              ],

              // Signature Section
              pw.SizedBox(height: 15),
              _buildSignatureSection(),
            ],
          ),
        ],
      ),
    );

    final pdfBytes = await pdf.save();

    if (kIsWeb) {
      // Web: open browser print dialog instead of saving to file
      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: '${report.reportNumber}.pdf',
      );
      return '';
    }

    // Mobile / desktop: save to local file
    final directory = await getApplicationDocumentsDirectory();
    final fileName =
        '${report.reportNumber}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final filePath = '${directory.path}/$fileName';
    await File(filePath).writeAsBytes(pdfBytes);
    return filePath;
  }

  /// [conversionCurrency] (e.g. 'MYR') and [conversionRate] (THB per 1 unit
  /// of that currency) add a converted-amounts box to the settlement form.
  Future<String> exportAdvanceSettlementReport(
    PettyCashReport report, {
    List<Transaction>? transactions,
    String? conversionCurrency,
    double? conversionRate,
  }) async {
    final pdf = await _createPdfDocument();
    final currencyFormat = NumberFormat('#,##0.00');
    final dateFormat = DateFormat('dd/MM/yyyy');

    // Load logo
    pw.ImageProvider? logoImage;
    try {
      final logoData = await rootBundle.load(
        'assets/images/hope_channel_logo.png',
      );
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {
      // Logo loading failed, continue without logo
    }
    await PdfSignatureHelper.load();

    final sourceTransactions =
        transactions ??
        await FirestoreService().getTransactionsByReportId(report.id);
    final sortedTransactions = [...sourceTransactions]
      ..sort(_compareByDateAndReceipt);

    final approvedOrProcessed = sortedTransactions
        .where(
          (t) =>
              t.status == TransactionStatus.approved.name ||
              t.status == TransactionStatus.processed.name,
        )
        .toList();
    final effectiveTransactions = approvedOrProcessed.isNotEmpty
        ? approvedOrProcessed
        : sortedTransactions;

    final formRows = effectiveTransactions.take(20).toList();
    final totalAmount = formRows.fold<double>(0, (sum, t) => sum + t.amount);

    final settlementDate = effectiveTransactions.isNotEmpty
        ? effectiveTransactions.last.date
        : report.periodEnd;
    final purpose = (report.purpose != null && report.purpose!.trim().isNotEmpty)
        ? report.purpose!.trim()
        : effectiveTransactions.isNotEmpty
            ? effectiveTransactions.first.description
            : report.department;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 22, 28, 22),
        build: (context) => _buildAdvanceSettlementForm(
          report: report,
          logoImage: logoImage,
          rows: formRows,
          purpose: purpose,
          settlementDate: settlementDate,
          totalAmount: totalAmount,
          dateFormat: dateFormat,
          currencyFormat: currencyFormat,
          hasMoreRows: effectiveTransactions.length > 20,
          conversionCurrency:
              conversionRate != null ? conversionCurrency : null,
          conversionRate: conversionRate,
        ),
      ),
    );

    final pdfBytes = await pdf.save();

    if (kIsWeb) {
      // Web: open browser print dialog instead of saving to file
      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: '${report.reportNumber}_advance_settlement.pdf',
      );
      return '';
    }

    // Mobile / desktop: save to local file
    final directory = await getApplicationDocumentsDirectory();
    final fileName =
        '${report.reportNumber}_advance_settlement_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final filePath = '${directory.path}/$fileName';
    await File(filePath).writeAsBytes(pdfBytes);
    return filePath;
  }

  pw.Widget _buildAdvanceSettlementForm({
    required PettyCashReport report,
    required pw.ImageProvider? logoImage,
    required List<Transaction> rows,
    required String purpose,
    required DateTime settlementDate,
    required double totalAmount,
    required DateFormat dateFormat,
    required NumberFormat currencyFormat,
    required bool hasMoreRows,
    String? conversionCurrency,
    double? conversionRate,
  }) {
    final advanceDate = report.advanceTakenDate ?? report.periodStart;
    final showConversion = conversionCurrency != null &&
        conversionRate != null &&
        conversionRate > 0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildAdvanceSettlementHeader(logoImage),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Row(
                children: [
                  pw.Text('Name: ', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(
                    report.custodianName.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                'ID NO.: ....................',
                style: const pw.TextStyle(fontSize: 10),
                textAlign: pw.TextAlign.right,
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Text(
              'Date: ${dateFormat.format(settlementDate)}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'For the purpose of: ',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.Expanded(
              child: pw.Text(
                purpose.isNotEmpty
                    ? purpose
                    : '........................................',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          children: [
            pw.Text('Department: ', style: const pw.TextStyle(fontSize: 10)),
            pw.Text(
              (report.companyName ?? report.department).toUpperCase(),
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            _buildCheckBox(
              label: 'Cash Advance took on ${dateFormat.format(advanceDate)}',
              checked: false,
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              'Amount of ........................... Baht',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        _buildCheckBox(label: 'Reimbursement', checked: true),
        pw.SizedBox(height: 8),
        pw.SizedBox(height: 8),
        pw.Text(
          'Details:',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 2),
        _buildAdvanceSettlementTable(
          rows,
          totalAmount,
          currencyFormat,
          // Give up a few blank filler rows to make room for the box below.
          fillerRowTarget: showConversion ? 16 : 20,
        ),
        if (showConversion) ...[
          pw.SizedBox(height: 6),
          _buildConversionBox(
            report: report,
            totalAmount: totalAmount,
            currencyCode: conversionCurrency,
            rate: conversionRate,
            currencyFormat: currencyFormat,
            dateFormat: dateFormat,
          ),
        ],
        pw.SizedBox(height: 10),
        pw.Row(
          children: [
            pw.Text('Reported by: ', style: const pw.TextStyle(fontSize: 10)),
            pw.Text(
              report.custodianName.toUpperCase(),
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Approved by: .................................',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Date: .......... / .......... / ..........',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Action No. # ........................................',
          style: const pw.TextStyle(fontSize: 10),
        ),
        if (hasMoreRows) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            '* More than 20 items exist in this report; only the first 20 are shown in this form.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.red700),
          ),
        ],
        pw.SizedBox(height: 6),
        pw.Text(
          '*Please attach an official/original expenditure receipts with English translation. '
          'Cash remaining balance from your cash advance, please deposit to bank account '
          'and submit bank transfer slip to the finance office.',
          style: const pw.TextStyle(fontSize: 7.5),
        ),
      ],
    );
  }

  pw.Widget _buildAdvanceSettlementHeader(pw.ImageProvider? logoImage) {
    return pw.Column(
      children: [
        pw.Text(
          'SOUTHEASTERN ASIA UNION MISSION OF SEVENTH-DAY ADVENTIST FOUNDATION (SEUM)',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'ADVANCE SETTLEMENT REPORT',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          AppConstants.organizationAddress,
          style: const pw.TextStyle(fontSize: 9),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          children: [
            pw.SizedBox(
              width: 60,
              child: logoImage != null
                  ? pw.Image(logoImage, width: 42, height: 42, fit: pw.BoxFit.contain)
                  : pw.SizedBox(width: 42, height: 42),
            ),
            pw.Expanded(
              child: pw.SizedBox(height: 42),
            ),
            pw.SizedBox(
              width: 60,
              child: pw.Text(
                'NO: ....................',
                style: const pw.TextStyle(fontSize: 10),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildCheckBox({required String label, required bool checked}) {
    return pw.Row(
      children: [
        pw.Container(
          width: 16,
          height: 16,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black)),
          child: checked
              ? pw.Text(
                  'X',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                )
              : null,
        ),
        pw.SizedBox(width: 6),
        pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  pw.Widget _buildConversionBox({
    required PettyCashReport report,
    required double totalAmount,
    required String currencyCode,
    required double rate,
    required NumberFormat currencyFormat,
    required DateFormat dateFormat,
  }) {
    final advanceAmount = report.openingBalance;
    final availableBalance = advanceAmount - totalAmount;
    final hasAdvance = advanceAmount > 0;

    pw.Widget row(String label, double thbAmount, {bool bold = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
              ),
            ),
            pw.SizedBox(
              width: 100,
              child: pw.Text(
                'THB ${currencyFormat.format(thbAmount)}',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
            pw.SizedBox(
              width: 100,
              child: pw.Text(
                '$currencyCode ${currencyFormat.format(thbAmount / rate)}',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
      );
    }

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey700, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'CURRENCY CONVERSION ($currencyCode)   —   '
            'Rate: 1 $currencyCode = ${NumberFormat('#,##0.0000').format(rate)} THB '
            '(as of ${dateFormat.format(DateTime.now())})',
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 3),
          if (hasAdvance) row('Advance Amount', advanceAmount),
          row('Total Spent', totalAmount),
          if (hasAdvance)
            row('Available Balance', availableBalance, bold: true),
        ],
      ),
    );
  }

  pw.Widget _buildAdvanceSettlementTable(
    List<Transaction> rows,
    double totalAmount,
    NumberFormat currencyFormat, {
    int fillerRowTarget = 20,
  }) {
    const tableBorder = pw.TableBorder(
      left: pw.BorderSide(color: PdfColors.black, width: 0.5),
      right: pw.BorderSide(color: PdfColors.black, width: 0.5),
      top: pw.BorderSide(color: PdfColors.black, width: 0.5),
      bottom: pw.BorderSide(color: PdfColors.black, width: 0.5),
      horizontalInside: pw.BorderSide(color: PdfColors.grey700, width: 0.4),
      verticalInside: pw.BorderSide(color: PdfColors.grey700, width: 0.4),
    );

    final bodyRows = <pw.TableRow>[];

    final rowCount =
        rows.length > fillerRowTarget ? rows.length : fillerRowTarget;
    for (var i = 0; i < rowCount; i++) {
      if (i < rows.length) {
        final tx = rows[i];
        bodyRows.add(
          pw.TableRow(
            children: [
              _cell('${i + 1}.', align: pw.TextAlign.center),
              _cell(tx.description),
              _cell('1', align: pw.TextAlign.center),
              _cell('', align: pw.TextAlign.right),
              _cell(currencyFormat.format(tx.amount), align: pw.TextAlign.right),
            ],
          ),
        );
      } else {
        bodyRows.add(
          pw.TableRow(
            children: [
              _cell(''),
              _cell(''),
              _cell(''),
              _cell(''),
              _cell(''),
            ],
          ),
        );
      }
    }

    bodyRows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          _cell('TOTAL', bold: true, align: pw.TextAlign.left),
          _cell(''),
          _cell(''),
          _cell(''),
          _cell(currencyFormat.format(totalAmount), bold: true, align: pw.TextAlign.right),
        ],
      ),
    );

    return pw.Table(
      border: tableBorder,
      columnWidths: const {
        0: pw.FlexColumnWidth(1.0),
        1: pw.FlexColumnWidth(6.6),
        2: pw.FlexColumnWidth(1.0),
        3: pw.FlexColumnWidth(1.8),
        4: pw.FlexColumnWidth(1.8),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _cell('NO.', bold: true, align: pw.TextAlign.center),
            _cell('DESCRIPTION', bold: true, align: pw.TextAlign.center),
            _cell('QTY', bold: true, align: pw.TextAlign.center),
            _cell('UNIT PRICE', bold: true, align: pw.TextAlign.center),
            _cell('AMOUNT', bold: true, align: pw.TextAlign.center),
          ],
        ),
        ...bodyRows,
      ],
    );
  }

  pw.Widget _cell(
    String text, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: align,
        maxLines: 2,
      ),
    );
  }

  pw.Widget _buildInfoSection(PettyCashReport report, DateFormat dateFormat) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Report Number:', report.reportNumber),
          _buildInfoRow(
            'Period:',
            '${dateFormat.format(report.periodStart)} - ${dateFormat.format(report.periodEnd)}',
          ),
          _buildInfoRow('Department:', report.department),
          _buildInfoRow('Custodian:', report.custodianName),
          _buildInfoRow('Status:', report.statusEnum.displayName),
        ],
      ),
    );
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }

  /// Inserts a hyphen line-break inside any word that exceeds [maxLen]
  /// characters so the pdf renderer can fit it within the column width.
  /// Word-boundary wrapping (softWrap) handles normal spaces; this handles
  /// long unbroken tokens like serial numbers, URLs, or compound words.
  String _breakLongWords(String text, {int maxLen = 25}) {
    return text.split(' ').map((word) {
      if (word.length <= maxLen) return word;
      final buffer = StringBuffer();
      var i = 0;
      while (i < word.length) {
        final end = i + maxLen;
        if (end < word.length) {
          buffer.write(word.substring(i, end));
          buffer.write('-\n');
        } else {
          buffer.write(word.substring(i));
        }
        i = end;
      }
      return buffer.toString();
    }).join(' ');
  }

  pw.Widget _buildTransactionsTable(
    List<Transaction> transactions,
    DateFormat dateFormat,
    NumberFormat currencyFormat, {
    String? fxCode,
    double? fxRate,
  }) {
    final showFx = fxCode != null && fxRate != null && fxRate > 0;
    const cellPadding = pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8);
    final headerStyle = pw.TextStyle(
      fontWeight: pw.FontWeight.bold,
      fontSize: 10,
    );
    final cellStyle = pw.TextStyle(
      fontWeight: pw.FontWeight.normal,
      fontSize: 9,
    );

    pw.Widget headerCell(String text, {bool rightAlign = false}) =>
        pw.Padding(
          padding: cellPadding,
          child: pw.Text(
            text,
            style: headerStyle,
            textAlign: rightAlign ? pw.TextAlign.right : pw.TextAlign.left,
          ),
        );

    pw.Widget dataCell(
      String text, {
      bool rightAlign = false,
      bool wrap = false,
    }) =>
        pw.Padding(
          padding: cellPadding,
          child: pw.Text(
            text,
            style: cellStyle,
            textAlign: rightAlign ? pw.TextAlign.right : pw.TextAlign.left,
            softWrap: wrap,
            overflow: pw.TextOverflow.clip,
          ),
        );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.0),   // Date
        1: const pw.FlexColumnWidth(1.5),   // Receipt No
        2: pw.FlexColumnWidth(showFx ? 3.5 : 4.5), // Description — widest, wraps
        3: const pw.FlexColumnWidth(2.5),   // Category
        4: const pw.FlexColumnWidth(1.5),   // Amount
        if (showFx) 5: const pw.FlexColumnWidth(1.5), // Foreign amount
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            headerCell('Date'),
            headerCell('Receipt No'),
            headerCell('Description'),
            headerCell('Category'),
            headerCell('Amount (THB)', rightAlign: true),
            if (showFx) headerCell('Amount ($fxCode)', rightAlign: true),
          ],
        ),
        // Data rows
        ...transactions.map(
          (t) => pw.TableRow(
            children: [
              dataCell(dateFormat.format(t.date)),
              dataCell(t.receiptNo),
              dataCell(_breakLongWords(t.description), wrap: true),
              dataCell(_breakLongWords(t.categoryDisplayName), wrap: true),
              dataCell(currencyFormat.format(t.amount), rightAlign: true),
              if (showFx)
                dataCell(
                  NumberFormat('#,##0.00').format(t.amount / fxRate),
                  rightAlign: true,
                ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildHeader(PettyCashReport report, pw.ImageProvider? logoImage) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Add logo
            if (logoImage != null)
              pw.Container(
                width: 40,
                height: 40,
                child: pw.Image(logoImage, fit: pw.BoxFit.contain),
              )
            else
              pw.Container(
                width: 40,
                height: 40,
                child: pw.Padding(
                  padding: pw.EdgeInsets.all(5),
                  child: pw.DecoratedBox(
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey300,
                      borderRadius: pw.BorderRadius.circular(5),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        "H",
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            pw.SizedBox(width: 10),
            // Organization name and address
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    AppConstants.organizationName,
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.left,
                  ),
                  pw.Text(
                    AppConstants.organizationAddress,
                    style: const pw.TextStyle(fontSize: 9),
                    textAlign: pw.TextAlign.left,
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          report.reportType == 'advance_settlement'
              ? 'ADVANCE SETTLEMENT'
              : 'PETTY CASH REPORT',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Report: ${report.reportNumber}',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.Divider(),
        pw.SizedBox(height: 12),
      ],
    );
  }

  pw.Widget _buildFooter(pw.Context context, PettyCashReport report) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated on: ${DateFormat('MMM dd, yyyy hh:mm a').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummarySection(
    PettyCashReport report,
    NumberFormat currencyFormat,
  ) {
    final fxRate =
        report.hasForeignOpeningBalance ? report.openingExchangeRate : null;
    final fxCode = report.openingBalanceCurrency;
    String fmt(double thb) => fxRate == null
        ? currencyFormat.format(thb)
        : '${currencyFormat.format(thb)}  '
            '($fxCode ${NumberFormat('#,##0.00').format(thb / fxRate)})';

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        color: PdfColors.grey100,
      ),
      child: pw.Column(
        children: [
          if (fxRate != null)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    'Exchange rate: 1 $fxCode = '
                    '${NumberFormat('#,##0.0000').format(fxRate)} THB',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
          _buildSummaryRow(
            'Opening Balance:',
            fmt(report.openingBalance),
          ),
          _buildSummaryRow(
            'Total Disbursements:',
            fmt(report.totalDisbursements),
          ),
          pw.Divider(),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildSummaryRow(
                'Balance:',
                fmt(report.openingBalance - report.totalDisbursements),
                isBold: true,
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 4, top: 2),
                child: pw.Text(
                  '(${_convertToWords(report.openingBalance - report.totalDisbursements)})',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          _buildSummaryRow(
            'Cash on Hand:',
            fmt(report.cashOnHand),
          ),
          _buildSummaryRow(
            'Closing Balance:',
            fmt(report.closingBalance),
          ),
          _buildSummaryRow('Variance:', currencyFormat.format(report.variance)),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSignatureSection() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildSignatureBox('Requested By:', '(Pr. Heary Healdy Sairin)', showSignature: true),
          _buildSignatureBox('Approved By:', ''),
          _buildApprovedByBox(),
        ],
      ),
    );
  }

  pw.Widget _buildSignatureBox(String title, String subtitle, {bool showSignature = false}) {
    return pw.Container(
      width: 150,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          showSignature
              ? PdfSignatureHelper.slot(width: 100, height: 36)
              : pw.SizedBox(height: 20),
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black)),
            ),
            height: 1,
          ),
          pw.SizedBox(height: 4),
          if (subtitle.isNotEmpty)
            pw.Text(
              subtitle,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
        ],
      ),
    );
  }

  pw.Widget _buildApprovedByBox() {
    return pw.Container(
      width: 120,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Action No:',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 30),
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black)),
            ),
            height: 1,
          ),
        ],
      ),
    );
  }

  String _convertToWords(double amount) {
    final baht = amount.floor();
    final satang = ((amount - baht) * 100).round();

    final bahtInWords = _numberToWords(baht);
    final satangInWords = satang > 0
        ? 'and ${_numberToWords(satang)} Satang'
        : '';

    return '${bahtInWords.toUpperCase()} BAHT $satangInWords'.trim();
  }

  String _numberToWords(int number) {
    if (number == 0) return 'Zero';
    if (number < 0) return 'Minus ${_numberToWords(-number)}';

    final ones = [
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
    ];
    final teens = [
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen',
    ];
    final tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety',
    ];

    if (number < 10) return ones[number];
    if (number < 20) return teens[number - 10];
    if (number < 100) {
      return '${tens[number ~/ 10]} ${ones[number % 10]}'.trim();
    }
    if (number < 1000) {
      return '${ones[number ~/ 100]} Hundred ${_numberToWords(number % 100)}'
          .trim();
    }
    if (number < 1000000) {
      return '${_numberToWords(number ~/ 1000)} Thousand ${_numberToWords(number % 1000)}'
          .trim();
    }

    return number.toString(); // Fallback for very large numbers
  }
}

class StickerPrintConfig {
  StickerPrintConfig({
    required this.stickerWidthMm,
    required this.stickerHeightMm,
    required this.sheetWidthMm,
    required this.sheetHeightMm,
    required this.rows,
    required this.columns,
    this.marginMm = 0,
    this.horizontalGapMm = 0,
    this.verticalGapMm = 0,
    this.offsetLeftMm = 0,
    this.offsetRightMm = 0,
    this.stickerLeftPaddingMm = 0,
    this.includeQr = true,
    this.includeBarcode = true,
    this.startRow = 1,
    this.startColumn = 1,
  });

  final double stickerWidthMm;
  final double stickerHeightMm;
  final double sheetWidthMm;
  final double sheetHeightMm;
  final int rows;
  final int columns;
  final double marginMm;
  final double horizontalGapMm;
  final double verticalGapMm;
  final double offsetLeftMm;
  final double offsetRightMm;
  final double stickerLeftPaddingMm;
  final bool includeQr;
  final bool includeBarcode;
  // Start position (1-indexed: 1 = first row/column)
  final int startRow;
  final int startColumn;

  /// Calculate how many sticker positions to skip on first page
  int get skipPositions {
    final row = (startRow - 1).clamp(0, rows - 1);
    final col = (startColumn - 1).clamp(0, columns - 1);
    return row * columns + col;
  }

  double get stickerWidthPt => _mmToPt(stickerWidthMm);
  double get stickerHeightPt => _mmToPt(stickerHeightMm);
  double get marginPt => _mmToPt(marginMm);
  double get horizontalGapPt => _mmToPt(horizontalGapMm);
  double get verticalGapPt => _mmToPt(verticalGapMm);
  double get offsetLeftPt => _mmToPt(offsetLeftMm);
  double get offsetRightPt => _mmToPt(offsetRightMm);
  double get stickerLeftPaddingPt => _mmToPt(stickerLeftPaddingMm);
  double get qrSizePt => _mmToPt(18);
  double get barcodeWidthPt => _mmToPt(40);
  double get barcodeHeightPt => _mmToPt(10);
  double get textSize => 8;
  PdfPageFormat get pageFormat =>
      PdfPageFormat(_mmToPt(sheetWidthMm), _mmToPt(sheetHeightMm));

  static double _mmToPt(double mm) => mm * 72 / 25.4;
}
