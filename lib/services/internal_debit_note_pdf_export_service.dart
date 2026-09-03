import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/internal_debit_note.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
import 'pdf_signature_helper.dart';

class InternalDebitNotePdfExportService {
  pw.Font? _ttf;
  pw.Font? _ttfBold;
  pw.Font? _notoFallback;
  pw.Font? _emojiFont;
  pw.ImageProvider? _logoImage;

  Future<void> _loadAssets() async {
    if (_ttf != null && _ttfBold != null) return;

    try {
      final fontData =
          await rootBundle.load('assets/fonts/NotoSansThai-Regular.ttf');
      _ttf = pw.Font.ttf(fontData);
      final fontBoldData =
          await rootBundle.load('assets/fonts/NotoSansThai-Bold.ttf');
      _ttfBold = pw.Font.ttf(fontBoldData);
    } catch (e) {
      AppLogger.warning('InternalDebitNotePdf: Failed to load custom fonts: $e');
    }

    try {
      _notoFallback = await PdfGoogleFonts.notoSansRegular();
    } catch (_) {}
    try {
      _emojiFont = await PdfGoogleFonts.notoColorEmojiRegular();
    } catch (_) {}

    try {
      final logoData =
          await rootBundle.load('assets/images/hope_channel_logo.png');
      _logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      AppLogger.warning('InternalDebitNotePdf: Failed to load logo: $e');
    }
    await PdfSignatureHelper.load();
  }

  Future<Uint8List> generatePdf(InternalDebitNote note) async {
    await _loadAssets();

    final pdf = pw.Document();
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(
          base: _ttf ?? pw.Font.helvetica(),
          bold: _ttfBold ?? pw.Font.helveticaBold(),
          fontFallback: [?_notoFallback, ?_emojiFont],
        ),
        header: (context) => _buildHeader(),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildInfoSection(note),
          pw.SizedBox(height: 16),
          _buildDetailsTable(note, currencyFormat),
          pw.SizedBox(height: 16),
          _buildTextSection('Reason for Debit:', note.reasonForDebit),
          pw.SizedBox(height: 12),
          _buildTextSection(
              'Payment / Settlement Terms:', note.paymentTerms),
          pw.SizedBox(height: 24),
          _buildSignatureSection(note),
          pw.SizedBox(height: 20),
          _buildDisclaimer(),
        ],
      ),
    );

    return pdf.save();
  }

  Future<void> printNote(InternalDebitNote note) async {
    final pdfBytes = await generatePdf(note);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Internal_Debit_Note_${note.debitNoteNumber}',
    );
  }

  // ---------------------------------------------------------------------------
  // Header (repeating on every page)
  // ---------------------------------------------------------------------------

  pw.Widget _buildOrganizationHeader() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
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
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildHeader() {
    return pw.Column(
      children: [
        _buildOrganizationHeader(),
        pw.SizedBox(height: 12),
        pw.Text(
          'Internal Debit Note',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Divider(thickness: 1),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Info section
  // ---------------------------------------------------------------------------

  pw.Widget _buildInfoSection(InternalDebitNote note) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Company:', note.companyName),
        pw.SizedBox(height: 6),
        _buildInfoRow('Debit Note No.:', note.debitNoteNumber),
        pw.SizedBox(height: 6),
        _buildInfoRow('Date:', DateFormat('dd MMMM yyyy').format(note.noteDate)),
        pw.SizedBox(height: 14),
        _buildInfoRow('Issued To:', note.issuedToCompany),
        pw.SizedBox(height: 6),
        _buildInfoRow('Department:', note.department),
      ],
    );
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 110,
          child: pw.Text(
            label,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Expanded(
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Details table
  // ---------------------------------------------------------------------------

  pw.Widget _buildDetailsTable(
      InternalDebitNote note, NumberFormat currencyFormat) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Details',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildTableCell('Description', isHeader: true),
                _buildTableCell('Amount', isHeader: true,
                    align: pw.TextAlign.right),
              ],
            ),
            ...note.lineItems.map(
              (item) => pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: _buildFormattedDescription(item.description),
                  ),
                  _buildTableCell(
                    '${note.currency} ${currencyFormat.format(item.amount)}',
                    align: pw.TextAlign.right,
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey600)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Total Debit Amount',
                style:
                    pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                '${note.currency} ${currencyFormat.format(note.totalAmount)}',
                style:
                    pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
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

  /// Renders a description that may be Quill Delta JSON, preserving
  /// bold/italic/underline/strikethrough and bullet/numbered lists.
  /// Falls back to plain text if it isn't Delta JSON.
  pw.Widget _buildFormattedDescription(String text, {double fontSize = 9}) {
    if (!text.startsWith('[')) {
      return pw.Text(text, style: pw.TextStyle(fontSize: fontSize));
    }

    List<dynamic> ops;
    try {
      ops = jsonDecode(text) as List;
    } catch (_) {
      return pw.Text(text, style: pw.TextStyle(fontSize: fontSize));
    }

    final lines = <List<pw.TextSpan>>[[]];
    final lineListType = <String?>[null];

    for (final op in ops) {
      if (op is! Map) continue;
      final insert = op['insert'];
      if (insert is! String) continue;
      final attrs = (op['attributes'] as Map?) ?? {};

      final parts = insert.split('\n');
      for (var i = 0; i < parts.length; i++) {
        final part = parts[i];
        if (part.isNotEmpty) {
          lines.last.add(
            pw.TextSpan(
              text: part,
              style: pw.TextStyle(
                fontSize: fontSize,
                fontWeight:
                    attrs['bold'] == true ? pw.FontWeight.bold : pw.FontWeight.normal,
                fontStyle:
                    attrs['italic'] == true ? pw.FontStyle.italic : pw.FontStyle.normal,
                decoration: attrs['underline'] == true
                    ? pw.TextDecoration.underline
                    : (attrs['strike'] == true
                        ? pw.TextDecoration.lineThrough
                        : pw.TextDecoration.none),
              ),
            ),
          );
        }
        // A '\n' between parts ends a line; a lone '\n' insert can also carry
        // block-level attributes (e.g. list type) for the line it closes.
        if (i != parts.length - 1) {
          if (insert == '\n' && attrs['list'] != null) {
            lineListType[lineListType.length - 1] = attrs['list'] as String?;
          }
          lines.add([]);
          lineListType.add(null);
        }
      }
    }

    if (lines.isNotEmpty && lines.last.isEmpty && lines.length > 1) {
      lines.removeLast();
      lineListType.removeLast();
    }

    var orderedIndex = 0;
    final widgets = <pw.Widget>[];
    for (var i = 0; i < lines.length; i++) {
      final spans = lines[i];
      if (spans.isEmpty) continue;
      final listType = lineListType[i];
      String prefix = '';
      if (listType == 'bullet') {
        prefix = '•  ';
      } else if (listType == 'ordered') {
        orderedIndex++;
        prefix = '$orderedIndex.  ';
      }
      widgets.add(
        pw.RichText(
          text: pw.TextSpan(
            children: [
              if (prefix.isNotEmpty)
                pw.TextSpan(text: prefix, style: pw.TextStyle(fontSize: fontSize)),
              ...spans,
            ],
          ),
        ),
      );
    }

    if (widgets.isEmpty) {
      return pw.Text('', style: pw.TextStyle(fontSize: fontSize));
    }

    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: widgets);
  }

  // ---------------------------------------------------------------------------
  // Reason / terms sections
  // ---------------------------------------------------------------------------

  pw.Widget _buildTextSection(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Signature section
  // ---------------------------------------------------------------------------

  pw.Widget _buildSignatureSection(InternalDebitNote note) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSignatureLine('Prepared by:', note.preparedByName,
            showSignature: true),
        pw.SizedBox(height: 14),
        _buildSignatureLine('Checked by:', note.checkedByName ?? ''),
        pw.SizedBox(height: 14),
        _buildSignatureLine('Approved by:', note.approvedByName ?? ''),
      ],
    );
  }

  pw.Widget _buildSignatureLine(String label, String name,
      {bool showSignature = false}) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.SizedBox(
          width: 110,
          child: pw.Text(
            label,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(
          width: 180,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (showSignature) PdfSignatureHelper.slot(width: 90, height: 36),
              pw.Container(height: 1, color: PdfColors.grey700),
              if (name.isNotEmpty) ...[
                pw.SizedBox(height: 3),
                pw.Text(name, style: const pw.TextStyle(fontSize: 9)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Disclaimer
  // ---------------------------------------------------------------------------

  pw.Widget _buildDisclaimer() {
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
            'Notes:',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 3),
          pw.RichText(
            text: pw.TextSpan(
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              children: [
                const pw.TextSpan(text: 'This document is for '),
                pw.TextSpan(
                  text: 'internal/intercompany accounting purposes',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                const pw.TextSpan(text: ' and is not a customer invoice.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Footer (repeating on every page)
  // ---------------------------------------------------------------------------

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
