import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/cash_advance.dart';
import '../utils/constants.dart';

class CashAdvancePdfService {
  pw.Font? _regularFont;
  pw.Font? _boldFont;

  Future<pw.ThemeData> _getTheme() async {
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
    } catch (_) {}

    return pw.ThemeData.withFont(
      base: regular ?? pw.Font.helvetica(),
      bold: bold ?? pw.Font.helveticaBold(),
      fontFallback: [pw.Font.helvetica(), pw.Font.courier()],
    );
  }

  Future<Uint8List> buildPdf(CashAdvance advance) async {
    final theme = await _getTheme();
    final pdf = pw.Document(theme: theme);
    final dateFormat = DateFormat('MMM dd, yyyy');
    final currency = NumberFormat.currency(
      symbol: AppConstants.currencySymbol,
      decimalDigits: 2,
    );
    const brandColor = PdfColor.fromInt(0xFF3F51B5);
    const lightBrand = PdfColor.fromInt(0xFFE8EAF6);
    const darkText = PdfColor.fromInt(0xFF1F2937);
    const mutedText = PdfColor.fromInt(0xFF6B7280);

    pw.ImageProvider? logoImage;
    try {
      final logoData = await rootBundle.load(AppConstants.companyLogo);
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildHeader(logoImage),
            pw.SizedBox(height: 14),
            _buildHero(
              requestNumber: advance.requestNumber,
              status: advance.status.toUpperCase(),
              amount: currency.format(advance.requestedAmount),
              brandColor: brandColor,
              lightBrand: lightBrand,
            ),
            pw.SizedBox(height: 14),
            _sectionCard(
              title: 'Request Information',
              child: pw.Column(
                children: [
                  _row('Requester', advance.requesterName, darkText, mutedText),
                  _row('Department', advance.department, darkText, mutedText),
                  _row(
                    'Request Date',
                    dateFormat.format(advance.requestDate),
                    darkText,
                    mutedText,
                  ),
                  if (advance.requiredByDate != null)
                    _row(
                      'Required By',
                      dateFormat.format(advance.requiredByDate!),
                      darkText,
                      mutedText,
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            _sectionCard(
              title: 'Purpose',
              child: _boxedText(advance.purpose),
            ),
            if (advance.items.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              _sectionCard(
                title: 'Items',
                child: _buildItemsTable(advance, currency),
              ),
            ],
            pw.SizedBox(height: 12),
            _sectionCard(
              title: 'Summary',
              child: pw.Column(
                children: [
                  _row(
                    'Requested Amount',
                    currency.format(advance.requestedAmount),
                    darkText,
                    mutedText,
                  ),
                  _row(
                    'Status',
                    advance.status.toUpperCase(),
                    darkText,
                    mutedText,
                  ),
                ],
              ),
            ),
            if (advance.notes != null && advance.notes!.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              _sectionCard(
                title: 'Notes',
                child: _boxedText(advance.notes!),
              ),
            ],
            pw.SizedBox(height: 18),
            _sectionCard(
              title: 'Signatures',
              child: _buildSignatureSection(),
            ),
            pw.SizedBox(height: 16),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Generated on: ${dateFormat.format(DateTime.now())}',
                style: pw.TextStyle(fontSize: 9, color: mutedText),
              ),
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  pw.Widget _row(
    String label,
    String value,
    PdfColor darkText,
    PdfColor mutedText,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: mutedText,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(color: darkText),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _boxedText(String text) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(text),
    );
  }

  pw.Widget _buildHeader(pw.ImageProvider? logoImage) {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logoImage != null)
              pw.Container(
                width: 42,
                height: 42,
                child: pw.Image(logoImage, fit: pw.BoxFit.contain),
              )
            else
              pw.Container(
                width: 42,
                height: 42,
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey300,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'H',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
              ),
            pw.SizedBox(width: 10),
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
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(),
      ],
    );
  }

  pw.Widget _buildHero({
    required String requestNumber,
    required String status,
    required String amount,
    required PdfColor brandColor,
    required PdfColor lightBrand,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: lightBrand,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: brandColor),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Cash Advance Request',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: brandColor,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                requestNumber,
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                amount,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: brandColor,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: pw.BoxDecoration(
                  color: brandColor,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Text(
                  status,
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 8,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _sectionCard({
    required String title,
    required pw.Widget child,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 11,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  pw.Widget _buildItemsTable(
    CashAdvance advance,
    NumberFormat currency,
  ) {
    final headers = ['Item', 'Qty', 'Unit Price', 'Total'];
    final data = advance.items
        .map(
          (item) => [
            item.name,
            item.quantity.toString(),
            currency.format(item.unitPrice),
            currency.format(item.total),
          ],
        )
        .toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
      cellStyle: const pw.TextStyle(fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.all(4),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
      },
    );
  }

  pw.Widget _buildSignatureSection() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _buildSignatureBlock('Prepared By'),
        _buildSignatureBlock('Reviewed By'),
        _buildSignatureBlock('Approved By'),
      ],
    );
  }

  pw.Widget _buildSignatureBlock(String label) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        ),
        pw.SizedBox(height: 28),
        pw.Container(
          width: 160,
          height: 0.5,
          color: PdfColors.grey700,
        ),
        pw.SizedBox(height: 6),
        pw.Text('Name / Signature', style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }
}
