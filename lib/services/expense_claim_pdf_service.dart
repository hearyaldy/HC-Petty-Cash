import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/expense_claim.dart';
import '../utils/constants.dart';
import 'pdf_signature_helper.dart';

class ExpenseClaimPdfService {
  pw.Font? _ttf;
  pw.Font? _ttfBold;
  pw.Font? _notoFallback;
  pw.ImageProvider? _logoImage;

  Future<void> _loadAssets() async {
    if (_ttf != null && _ttfBold != null) return;
    try {
      _ttf = pw.Font.ttf(
          await rootBundle.load('assets/fonts/NotoSansThai-Regular.ttf'));
      _ttfBold = pw.Font.ttf(
          await rootBundle.load('assets/fonts/NotoSansThai-Bold.ttf'));
    } catch (_) {}
    try {
      _notoFallback = await PdfGoogleFonts.notoSansRegular();
    } catch (_) {}
    try {
      final logoData = await rootBundle.load(AppConstants.companyLogo);
      _logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}
    await PdfSignatureHelper.load();
  }

  Future<void> printClaim(ExpenseClaim claim) async {
    final bytes = await buildPdf(claim);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<Uint8List> buildPdf(ExpenseClaim claim) async {
    await _loadAssets();

    final pdf = pw.Document();
    final dateFormat = DateFormat('MMM dd, yyyy');
    final dateTimeFormat = DateFormat('MMM dd, yyyy HH:mm');
    final currency = NumberFormat.currency(
        symbol: AppConstants.currencySymbol, decimalDigits: 2);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(
          base: _ttf ?? _notoFallback ?? pw.Font.helvetica(),
          bold: _ttfBold ?? _notoFallback ?? pw.Font.helveticaBold(),
          fontFallback: [?_notoFallback],
        ),
        header: (context) => _buildHeader(claim, dateFormat),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildInfoSection(claim, dateTimeFormat),
          pw.SizedBox(height: 16),
          _buildItemsTable(claim, dateFormat, currency),
          pw.SizedBox(height: 16),
          _buildTotalSection(claim, currency),
          if (claim.notes != null && claim.notes!.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _buildNotesSection(claim.notes!),
          ],
          pw.SizedBox(height: 30),
          _buildSignatureSection(),
        ],
      ),
    );

    return pdf.save();
  }

  // ── Header ────────────────────────────────────────────────────────────────────

  pw.Widget _buildHeader(ExpenseClaim claim, DateFormat dateFormat) {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (_logoImage != null)
              pw.Container(
                  width: 40,
                  height: 40,
                  child:
                      pw.Image(_logoImage!, fit: pw.BoxFit.contain))
            else
              pw.Container(
                width: 40,
                height: 40,
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey300,
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Center(
                  child: pw.Text('H',
                      style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700)),
                ),
              ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(AppConstants.organizationName,
                      style: pw.TextStyle(
                          fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text(AppConstants.organizationAddress,
                      style: const pw.TextStyle(
                          fontSize: 8, color: PdfColors.grey700)),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey600),
            borderRadius:
                const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: pw.Center(
            child: pw.Text('EXPENSE CLAIM',
                style: pw.TextStyle(
                    fontSize: 16, fontWeight: pw.FontWeight.bold)),
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('No: ${claim.claimNumber}',
                style: pw.TextStyle(
                    fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Date: ${dateFormat.format(claim.createdAt)}',
                    style: pw.TextStyle(
                        fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: pw.BoxDecoration(
                    color: claim.status == 'approved'
                        ? PdfColors.green50
                        : claim.status == 'rejected'
                            ? PdfColors.red50
                            : PdfColors.grey100,
                    border: pw.Border.all(
                      color: claim.status == 'approved'
                          ? PdfColors.green400
                          : claim.status == 'rejected'
                              ? PdfColors.red400
                              : PdfColors.grey400,
                    ),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    'Status: ${claim.status.toUpperCase()}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: claim.status == 'approved'
                          ? PdfColors.green800
                          : claim.status == 'rejected'
                              ? PdfColors.red800
                              : PdfColors.grey700,
                    ),
                  ),
                ),
                if (claim.status == 'approved') ...[
                  pw.SizedBox(height: 4),
                  if (claim.approverName != null)
                    pw.Text(
                      'Approved by: ${claim.approverName}',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.green800),
                    ),
                  if (claim.approvedAt != null)
                    pw.Text(
                      'On: ${DateFormat('MMM dd, yyyy HH:mm').format(claim.approvedAt!)}',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.green800),
                    ),
                ],
              ],
            ),
          ],
        ),
        pw.Divider(thickness: 1),
        pw.SizedBox(height: 8),
      ],
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────────

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated on: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
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

  // ── Info section ──────────────────────────────────────────────────────────────

  pw.Widget _buildInfoSection(ExpenseClaim claim, DateFormat fmt) {
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
              pw.Expanded(child: _infoItem('Requested By', claim.requesterName)),
              pw.Expanded(child: _infoItem('Department', claim.department)),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(
                  child: _infoItem(
                      'Submitted', fmt.format(claim.createdAt))),
              pw.Expanded(
                  child: _infoItem('Status', claim.status.toUpperCase())),
            ],
          ),
          if (claim.title.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            _infoItem('Title', claim.title),
          ],
          if (claim.purpose.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            _infoItem('Purpose', claim.purpose),
          ],
        ],
      ),
    );
  }

  pw.Widget _infoItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('$label:',
            style: pw.TextStyle(
                fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
      ],
    );
  }

  // ── Items table ───────────────────────────────────────────────────────────────

  pw.Widget _buildItemsTable(
      ExpenseClaim claim, DateFormat dateFormat, NumberFormat currency) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Expense Items:',
            style: pw.TextStyle(
                fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: const {
            0: pw.FixedColumnWidth(24),
            1: pw.FixedColumnWidth(60),
            2: pw.FixedColumnWidth(65),
            3: pw.FlexColumnWidth(3),
            4: pw.FixedColumnWidth(60),
            5: pw.FixedColumnWidth(80),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _cell('#', isHeader: true),
                _cell('Date', isHeader: true),
                _cell('Category', isHeader: true),
                _cell('Description', isHeader: true, align: pw.TextAlign.left),
                _cell('Receipt', isHeader: true),
                _cell('Amount', isHeader: true, align: pw.TextAlign.right),
              ],
            ),
            ...claim.items.asMap().entries.map(
              (e) => pw.TableRow(children: [
                _cell('${e.key + 1}'),
                _cell(dateFormat.format(e.value.date)),
                _cell(e.value.categoryDisplayName),
                _cell(e.value.description, align: pw.TextAlign.left),
                _cell(e.value.receiptRef ?? '-'),
                _cell(currency.format(e.value.amount),
                    align: pw.TextAlign.right),
              ]),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _cell(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 9 : 9,
          fontWeight:
              isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: align,
      ),
    );
  }

  // ── Total ─────────────────────────────────────────────────────────────────────

  pw.Widget _buildTotalSection(ExpenseClaim claim, NumberFormat currency) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 220,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey600, width: 1.5),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('TOTAL:',
                style: pw.TextStyle(
                    fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.Text(
              '${currency.format(claim.totalAmount)} Baht',
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // ── Notes ─────────────────────────────────────────────────────────────────────

  pw.Widget _buildNotesSection(String notes) {
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
          pw.Text('Notes:',
              style: pw.TextStyle(
                  fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(notes, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  // ── Signature ─────────────────────────────────────────────────────────────────

  pw.Widget _buildSignatureSection() {
    return pw.Column(
      children: [
        pw.Text('SIGNATURE SECTION',
            style: pw.TextStyle(
                fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 16),
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius:
                const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _signatureBox('Prepared By', showSignature: true),
              _signatureBox('Finance / HR'),
              _signatureBox('Approved By'),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _signatureBox(String label, {bool showSignature = false}) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center),
          showSignature
              ? PdfSignatureHelper.slot(width: 100, height: 40)
              : pw.SizedBox(height: 40),
          pw.Container(
            width: 120,
            decoration: const pw.BoxDecoration(
                border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.black))),
          ),
          pw.SizedBox(height: 4),
          pw.Text('(________________)',
              style: const pw.TextStyle(
                  fontSize: 9, color: PdfColors.grey500)),
        ],
      ),
    );
  }
}
