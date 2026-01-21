import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/purchase_requisition.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

class PurchaseRequisitionPdfExportService {
  pw.Font? _ttf;
  pw.Font? _ttfBold;
  pw.ImageProvider? _logoImage;

  Future<void> _loadFonts() async {
    if (_ttf != null && _ttfBold != null) return;

    try {
      final fontData = await rootBundle.load(
        'assets/fonts/NotoSansThai-Regular.ttf',
      );
      _ttf = pw.Font.ttf(fontData);
      final fontBoldData = await rootBundle.load(
        'assets/fonts/NotoSansThai-Bold.ttf',
      );
      _ttfBold = pw.Font.ttf(fontBoldData);
    } catch (e) {
      AppLogger.warning('Failed to load custom fonts: $e');
    }

    // Load logo
    try {
      final logoData = await rootBundle.load('assets/images/hope_channel_logo.png');
      _logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      // Logo loading failed, will use fallback
    }
  }

  Future<Uint8List> generatePurchaseRequisitionPdf(
    PurchaseRequisition requisition,
    List<PurchaseRequisitionItem> items,
  ) async {
    await _loadFonts();

    final pdf = pw.Document();
    final dateFormat = DateFormat('MMM dd, yyyy');
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');

    // Check if any item exceeds threshold
    final hasHighValueItems = items.any((item) => item.totalPrice > 20000);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(
          base: _ttf ?? pw.Font.helvetica(),
          bold: _ttfBold ?? pw.Font.helveticaBold(),
          fontFallback: [pw.Font.helvetica()],
        ),
        header: (context) => _buildHeader(requisition, dateFormat),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildInfoSection(requisition),
          pw.SizedBox(height: 20),
          _buildItemsTable(items, currencyFormat),
          pw.SizedBox(height: 16),
          _buildTotalSection(requisition, currencyFormat),
          pw.SizedBox(height: 20),
          _buildNoteSection(),
          pw.SizedBox(height: 30),
          _buildSignatureSection(requisition, hasHighValueItems),
        ],
      ),
    );

    return await pdf.save();
  }

  Future<void> printPurchaseRequisition(
    PurchaseRequisition requisition,
    List<PurchaseRequisitionItem> items,
  ) async {
    final pdfBytes = await generatePurchaseRequisitionPdf(requisition, items);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Purchase_Requisition_${requisition.requisitionNumber}',
    );
  }

  pw.Widget _buildOrganizationHeader() {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Add logo
            if (_logoImage != null)
              pw.Container(
                width: 40,
                height: 40,
                child: pw.Image(_logoImage!, fit: pw.BoxFit.contain),
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
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.left,
                  ),
                  pw.Text(
                    AppConstants.organizationAddress,
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                    textAlign: pw.TextAlign.left,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildHeader(
    PurchaseRequisition requisition,
    DateFormat dateFormat,
  ) {
    return pw.Column(
      children: [
        // Organization header
        _buildOrganizationHeader(),
        pw.SizedBox(height: 16),

        // Title
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey600),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: pw.Center(
            child: pw.Text(
              'PURCHASE REQUISITION',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ),
        pw.SizedBox(height: 16),

        // Document number and date
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'No: ${requisition.requisitionNumber}',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Date: ${dateFormat.format(requisition.requisitionDate)}',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.Divider(thickness: 1),
        pw.SizedBox(height: 8),
      ],
    );
  }

  pw.Widget _buildInfoSection(PurchaseRequisition requisition) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Requested By:',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      requisition.requestedBy,
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'ID No.:',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      requisition.idNo,
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Charge to Department:',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                requisition.chargeToDepartment,
                style: const pw.TextStyle(fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildItemsTable(
    List<PurchaseRequisitionItem> items,
    NumberFormat currencyFormat,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Details of Purchase:',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: {
            0: const pw.FixedColumnWidth(35),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FixedColumnWidth(50),
            3: const pw.FixedColumnWidth(70),
            4: const pw.FixedColumnWidth(80),
            5: const pw.FlexColumnWidth(2),
          },
          children: [
            // Header Row
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildTableCell('No.', isHeader: true),
                _buildTableCell('Description', isHeader: true),
                _buildTableCell('Qty', isHeader: true),
                _buildTableCell('Unit Price', isHeader: true),
                _buildTableCell('Total Price', isHeader: true),
                _buildTableCell('Remark', isHeader: true),
              ],
            ),
            // Data Rows
            ...items.map((item) {
              return pw.TableRow(
                children: [
                  _buildTableCell('${item.itemNo}'),
                  _buildTableCell(item.description, align: pw.TextAlign.left),
                  _buildTableCell('${item.quantity}'),
                  _buildTableCell(
                    currencyFormat.format(item.unitPrice),
                    align: pw.TextAlign.right,
                  ),
                  _buildTableCell(
                    currencyFormat.format(item.totalPrice),
                    align: pw.TextAlign.right,
                  ),
                  _buildTableCell(item.remark ?? '-'),
                ],
              );
            }),
            // Empty rows if less than 5 items
            ...List.generate(
              (5 - items.length).clamp(0, 5),
              (index) => pw.TableRow(
                children: [
                  _buildTableCell(''),
                  _buildTableCell(''),
                  _buildTableCell(''),
                  _buildTableCell(''),
                  _buildTableCell(''),
                  _buildTableCell(''),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: align,
      ),
    );
  }

  pw.Widget _buildTotalSection(
    PurchaseRequisition requisition,
    NumberFormat currencyFormat,
  ) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 200,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey600, width: 1.5),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'TOTAL:',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              '${currencyFormat.format(requisition.totalAmount)} Baht',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildNoteSection() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Note:',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'In case you plan to purchase items for more than one department, please identify on the "Remarks" column.',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSignatureSection(
    PurchaseRequisition requisition,
    bool hasHighValueItems,
  ) {
    return pw.Column(
      children: [
        pw.Text(
          'SIGNATURE SECTION',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 16),
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildSignatureBox('Requested By', requisition.requestedBy),
              _buildSignatureBox('Approved By', requisition.approvedBy),
              if (hasHighValueItems)
                _buildSignatureBox(
                  'Action No.\n(for amount > 20,000 Baht)',
                  requisition.actionNo,
                ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildSignatureBox(String label, String? value) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 40),
          pw.Container(
            width: 120,
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.black),
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value ?? '(________________)',
            style: pw.TextStyle(
              fontSize: 9,
              color: value != null ? PdfColors.black : PdfColors.grey500,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated on: ${DateFormat('MMM dd, yyyy hh:mm a').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
          ),
        ],
      ),
    );
  }

}
