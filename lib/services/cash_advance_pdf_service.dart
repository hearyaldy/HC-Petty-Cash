import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/cash_advance.dart';
import '../utils/constants.dart';
import 'pdf_signature_helper.dart';

class CashAdvancePdfService {
  pw.Font? _ttf;
  pw.Font? _ttfBold;
  pw.Font? _notoFallback;
  pw.ImageProvider? _logoImage;

  Future<void> _loadAssets() async {
    if (_ttf != null && _ttfBold != null) return;
    try {
      _ttf = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansThai-Regular.ttf'));
      _ttfBold = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansThai-Bold.ttf'));
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

  Future<Uint8List> buildPdf(CashAdvance advance) async {
    await _loadAssets();

    final pdf = pw.Document();
    final dateFormat = DateFormat('MMM dd, yyyy');
    final currency = NumberFormat.currency(symbol: AppConstants.currencySymbol, decimalDigits: 2);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(
          base: _ttf ?? _notoFallback ?? pw.Font.helvetica(),
          bold: _ttfBold ?? _notoFallback ?? pw.Font.helveticaBold(),
          fontFallback: [?_notoFallback],
        ),
        header: (context) => _buildHeader(advance, dateFormat),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildInfoSection(advance, dateFormat),
          pw.SizedBox(height: 16),
          if (advance.purpose.isNotEmpty) ...[
            _buildPurposeSection(advance.purpose),
            pw.SizedBox(height: 16),
          ],
          if (advance.items.isNotEmpty) ...[
            _buildItemsTable(advance, currency),
            pw.SizedBox(height: 16),
            _buildTotalSection(advance, currency),
          ],
          if (advance.meetingReferences.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _buildMeetingReferenceSection(advance),
          ],
          if (advance.notes != null && advance.notes!.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _buildNotesSection(advance.notes!),
          ],
          pw.SizedBox(height: 30),
          _buildSignatureSection(),
        ],
      ),
    );

    return pdf.save();
  }

  // ── Header (repeats on every page) ──────────────────────────────────────────

  pw.Widget _buildHeader(CashAdvance advance, DateFormat dateFormat) {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (_logoImage != null)
              pw.Container(width: 40, height: 40, child: pw.Image(_logoImage!, fit: pw.BoxFit.contain))
            else
              pw.Container(
                width: 40,
                height: 40,
                decoration: pw.BoxDecoration(color: PdfColors.grey300, borderRadius: pw.BorderRadius.circular(5)),
                child: pw.Center(child: pw.Text('H', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700))),
              ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(AppConstants.organizationName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text(AppConstants.organizationAddress, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey600),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: pw.Center(
            child: pw.Text('CASH ADVANCE REQUEST', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('No: ${advance.requestNumber}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.Text('Date: ${dateFormat.format(advance.requestDate)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          ],
        ),
        pw.Divider(thickness: 1),
        pw.SizedBox(height: 8),
      ],
    );
  }

  // ── Footer ───────────────────────────────────────────────────────────────────

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

  // ── Info section ─────────────────────────────────────────────────────────────

  pw.Widget _buildInfoSection(CashAdvance advance, DateFormat dateFormat) {
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
              pw.Expanded(child: _infoItem('Requested By', advance.requesterName)),
              pw.Expanded(child: _infoItem('Department', advance.department)),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(child: _infoItem('Request Date', dateFormat.format(advance.requestDate))),
              pw.Expanded(
                child: _infoItem(
                  'Required By',
                  advance.requiredByDate != null ? dateFormat.format(advance.requiredByDate!) : '-',
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(child: _infoItem('Status', advance.status.toUpperCase())),
              if (advance.actionNo != null)
                pw.Expanded(child: _infoItem('Action No.', advance.actionNo!))
              else
                pw.Expanded(child: pw.SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _infoItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('$label:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
      ],
    );
  }

  // ── Purpose section ──────────────────────────────────────────────────────────

  pw.Widget _buildPurposeSection(String purpose) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Purpose:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(purpose, style: const pw.TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  // ── Items table ──────────────────────────────────────────────────────────────

  pw.Widget _buildItemsTable(CashAdvance advance, NumberFormat currency) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Details of Cash Advance:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: const {
            0: pw.FixedColumnWidth(30),
            1: pw.FlexColumnWidth(4),
            2: pw.FixedColumnWidth(45),
            3: pw.FixedColumnWidth(80),
            4: pw.FixedColumnWidth(85),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _tableCell('No.', isHeader: true),
                _tableCell('Description', isHeader: true, align: pw.TextAlign.left),
                _tableCell('Qty', isHeader: true),
                _tableCell('Unit Price', isHeader: true),
                _tableCell('Total', isHeader: true),
              ],
            ),
            ...advance.items.asMap().entries.map((entry) => pw.TableRow(
              children: [
                _tableCell('${entry.key + 1}'),
                _tableCell(entry.value.name, align: pw.TextAlign.left),
                _tableCell(entry.value.quantity.toString()),
                _tableCell(currency.format(entry.value.unitPrice), align: pw.TextAlign.right),
                _tableCell(currency.format(entry.value.total), align: pw.TextAlign.right),
              ],
            )),
            ...List.generate(
              (5 - advance.items.length).clamp(0, 5),
              (_) => pw.TableRow(children: [
                _tableCell(''), _tableCell(''), _tableCell(''), _tableCell(''), _tableCell(''),
              ]),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _tableCell(
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

  // ── Total section ─────────────────────────────────────────────────────────────

  pw.Widget _buildTotalSection(CashAdvance advance, NumberFormat currency) {
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
            pw.Text('TOTAL:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.Text(
              '${currency.format(advance.requestedAmount)} Baht',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // ── Meeting reference ─────────────────────────────────────────────────────────

  pw.Widget _buildMeetingReferenceSection(CashAdvance advance) {
    final references = advance.meetingReferences;
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.indigo50,
        border: pw.Border.all(color: PdfColors.indigo200),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Meeting Reference${references.length > 1 ? 's' : ''}',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo800),
          ),
          pw.SizedBox(height: 8),
          for (var i = 0; i < references.length; i++) ...[
            if (i > 0) pw.SizedBox(height: 8),
            _refRow('Minutes', references[i].minutesLabel),
            _refRow('Action Item', references[i].actionItemNumber, bold: true),
            if (references[i].actionItemAction != null)
              _refRow('Action Type', references[i].actionItemAction!, bold: true),
            if (references[i].actionItemTitle != null)
              _refRow('Title', references[i].actionItemTitle!, bold: true),
            if (references[i].actionItemDescription != null &&
                references[i].actionItemDescription!.isNotEmpty)
              _refRow('Description', _stripMarkup(references[i].actionItemDescription!)),
          ],
        ],
      ),
    );
  }

  pw.Widget _refRow(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text('$label:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
            ),
          ),
        ],
      ),
    );
  }

  // ── Notes section ─────────────────────────────────────────────────────────────

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
          pw.Text('Notes:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(notes, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  // ── Signature section ─────────────────────────────────────────────────────────

  pw.Widget _buildSignatureSection() {
    return pw.Column(
      children: [
        pw.Text('SIGNATURE SECTION', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
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
              _signatureBox('Prepared By', showSignature: true),
              _signatureBox('Reviewed By'),
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
          pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
          showSignature
              ? PdfSignatureHelper.slot(width: 100, height: 40)
              : pw.SizedBox(height: 40),
          pw.Container(
            width: 120,
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black))),
          ),
          pw.SizedBox(height: 4),
          pw.Text('(________________)', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  String _stripMarkup(String text) {
    if (text.startsWith('[')) {
      try {
        final ops = jsonDecode(text) as List;
        return ops.whereType<Map>().map((op) => op['insert']).whereType<String>().join().trim();
      } catch (_) {}
    }
    return text;
  }
}
