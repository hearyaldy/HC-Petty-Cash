import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/budget_line_item.dart';
import '../models/budget_year.dart';
import '../utils/logger.dart';

class BudgetPdfExportService {
  pw.Font? _regular;
  pw.Font? _bold;
  pw.Font? _latinRegular;
  pw.Font? _latinBold;
  pw.ImageProvider? _logo;

  static const _primary = PdfColor.fromInt(0xFF1565C0);
  static const _green = PdfColor.fromInt(0xFF2E7D32);
  static const _red = PdfColor.fromInt(0xFFC62828);
  static const _grey = PdfColor.fromInt(0xFF757575);
  static const _lightGrey = PdfColor.fromInt(0xFFF5F5F5);
  static const _darkBg = PdfColor.fromInt(0xFF1A237E);

  final _fmt = NumberFormat('#,##0.00', 'en_US');
  final _dateFmt = DateFormat('MMM dd, yyyy');

  Future<void> _load() async {
    if (_regular != null) return;
    try {
      _regular = pw.Font.ttf(
          await rootBundle.load('assets/fonts/NotoSansThai-Regular.ttf'));
      _bold = pw.Font.ttf(
          await rootBundle.load('assets/fonts/NotoSansThai-Bold.ttf'));
    } catch (e) {
      AppLogger.warning('Budget PDF: font load failed: $e');
    }
    try {
      _latinRegular = await PdfGoogleFonts.notoSansRegular();
      _latinBold = await PdfGoogleFonts.notoSansBold();
      _regular ??= _latinRegular;
      _bold ??= _latinBold;
    } catch (_) {}
    try {
      final data = await rootBundle.load('assets/images/hope_channel_logo.png');
      _logo = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {}
  }

  pw.TextStyle _style(
          {double size = 10, bool bold = false, PdfColor? color}) =>
      pw.TextStyle(
        font: bold ? _bold : _regular,
        fontFallback: [
          if (bold && _latinBold != null) _latinBold!,
          if (!bold && _latinRegular != null) _latinRegular!,
        ],
        fontSize: size,
        color: color ?? PdfColors.black,
      );

  Future<Uint8List> generateBudgetPdf({
    required BudgetYear year,
    required List<BudgetLineItem> items,
    required Map<String, double> actuals,
  }) async {
    await _load();
    final pdf = pw.Document();

    // Group items by type → section
    // Appropriations are part of income (funds received from conference/union).
    final incomeItems = items.where((i) => i.sectionType == 'income').toList();
    final expenseItems =
        items.where((i) => i.sectionType == 'expense').toList();
    final appropriationItems =
        items.where((i) => i.sectionType == 'appropriation').toList();

    final incomeBudgetTotal =
        (incomeItems + appropriationItems).fold(0.0, (s, i) => s + i.budgetAmount);
    final expenseBudgetTotal =
        expenseItems.fold(0.0, (s, i) => s + i.budgetAmount);
    final netBudget = incomeBudgetTotal - expenseBudgetTotal;

    final incomeActualTotal =
        (incomeItems + appropriationItems).fold(0.0, (s, i) => s + (actuals[i.id] ?? 0));
    final expenseActualTotal =
        expenseItems.fold(0.0, (s, i) => s + (actuals[i.id] ?? 0));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (_) => _buildHeader(year),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          pw.SizedBox(height: 12),
          _buildSummaryBox(
            incomeBudget: incomeBudgetTotal,
            expenseBudget: expenseBudgetTotal,
            netBudget: netBudget,
            incomeActual: incomeActualTotal,
            expenseActual: expenseActualTotal,
            year: year,
          ),
          pw.SizedBox(height: 16),
          if (incomeItems.isNotEmpty || appropriationItems.isNotEmpty) ...[
            _sectionTypeHeader('INCOME', _green),
            pw.SizedBox(height: 6),
            ..._buildSections(incomeItems, actuals),
            if (appropriationItems.isNotEmpty) ...[
              pw.SizedBox(height: 8),
              _subSectionLabel('APPROPRIATIONS RECEIVED'),
              pw.SizedBox(height: 4),
              ..._buildSections(appropriationItems, actuals),
            ],
            _buildCombinedTotal(
              'Total Income & Appropriations',
              incomeItems + appropriationItems,
              actuals,
              _green,
            ),
            pw.SizedBox(height: 16),
          ],
          if (expenseItems.isNotEmpty) ...[
            _sectionTypeHeader('EXPENSES', _red),
            pw.SizedBox(height: 6),
            ..._buildSections(expenseItems, actuals),
            _buildTypeTotal(
                'Total Operating Expense', expenseItems, actuals, _red),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(BudgetYear year) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
            bottom: pw.BorderSide(color: _primary, width: 2)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (_logo != null)
            pw.Image(_logo!, width: 36, height: 36)
          else
            pw.Container(
              width: 36,
              height: 36,
              decoration: pw.BoxDecoration(
                color: _primary,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Center(
                child: pw.Text('HC',
                    style: _style(size: 14, bold: true,
                        color: PdfColors.white)),
              ),
            ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('ANNUAL BUDGET ${year.year}',
                    style: _style(size: 14, bold: true, color: _primary)),
                pw.Text('Hope Channel Southeast Asia · HCSA Financial Plan',
                    style: _style(size: 9, color: _grey)),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Status: ${year.isApproved ? "APPROVED" : "DRAFT"}',
                  style: _style(
                      size: 9,
                      bold: true,
                      color:
                          year.isApproved ? _green : PdfColors.orange)),
              pw.Text(
                  'Generated: ${_dateFmt.format(DateTime.now())}',
                  style: _style(size: 8, color: _grey)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context ctx) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('HCSA Annual Budget — Confidential',
              style: _style(size: 8, color: _grey)),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: _style(size: 8, color: _grey)),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryBox({
    required double incomeBudget,
    required double expenseBudget,
    required double netBudget,
    required double incomeActual,
    required double expenseActual,
    required BudgetYear year,
  }) {
    final netActual = incomeActual - expenseActual;
    final hasActuals = incomeActual > 0 || expenseActual > 0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _darkBg,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Budget Summary — ${year.year}',
              style: _style(size: 11, bold: true, color: PdfColors.white)),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              _summaryCell('Income & Appropriations',
                  '฿${_fmt.format(incomeBudget)}', _green),
              _summaryCell('Total Expense Budget',
                  '฿${_fmt.format(expenseBudget)}', _red),
              _summaryCell(
                  'Net Budget',
                  '฿${_fmt.format(netBudget.abs())}${netBudget < 0 ? " (deficit)" : ""}',
                  netBudget >= 0 ? _green : _red),
              if (hasActuals)
                _summaryCell(
                    'Net Actual',
                    '฿${_fmt.format(netActual.abs())}${netActual < 0 ? " (def.)" : ""}',
                    netActual >= 0 ? _green : _red),
            ],
          ),
          if (year.notes != null && year.notes!.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text('Notes: ${year.notes}',
                style: _style(size: 8,
                    color: PdfColor.fromInt(0xCCFFFFFF))),
          ],
        ],
      ),
    );
  }

  pw.Widget _summaryCell(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.only(right: 8),
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromInt(0x22FFFFFF),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: _style(size: 7,
                    color: PdfColor.fromInt(0xAAFFFFFF))),
            pw.SizedBox(height: 2),
            pw.Text(value,
                style: _style(size: 10, bold: true, color: color)),
          ],
        ),
      ),
    );
  }

  pw.Widget _sectionTypeHeader(String label, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(label,
          style: _style(size: 10, bold: true, color: PdfColors.white)),
    );
  }

  pw.Widget _subSectionLabel(String label) {
    return pw.Row(
      children: [
        pw.Container(width: 3, height: 12, color: _green),
        pw.SizedBox(width: 6),
        pw.Text(label, style: _style(size: 8, bold: true, color: _grey)),
      ],
    );
  }

  pw.Widget _buildCombinedTotal(String label, List<BudgetLineItem> items,
      Map<String, double> actuals, PdfColor color) {
    final budgetTotal = items.fold(0.0, (s, i) => s + i.budgetAmount);
    final actualTotal = items.fold(0.0, (s, i) => s + (actuals[i.id] ?? 0));

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 4),
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(label,
                style: _style(size: 10, bold: true, color: PdfColors.white)),
          ),
          pw.Text('฿${_fmt.format(budgetTotal)}',
              style: _style(size: 11, bold: true, color: PdfColors.white)),
          if (actualTotal > 0) ...[
            pw.SizedBox(width: 16),
            pw.Text('Actual: ฿${_fmt.format(actualTotal)}',
                style: _style(size: 9, color: PdfColor.fromInt(0xCCFFFFFF))),
          ],
        ],
      ),
    );
  }

  List<pw.Widget> _buildSections(
      List<BudgetLineItem> items, Map<String, double> actuals) {
    final Map<String, List<BudgetLineItem>> bySection = {};
    for (final item in items) {
      bySection.putIfAbsent(item.scheduleCode, () => []).add(item);
    }

    return bySection.entries.map((entry) {
      final sectionItems = entry.value;
      final sectionTitle = sectionItems.first.sectionTitle;
      final sectionBudget =
          sectionItems.fold(0.0, (s, i) => s + i.budgetAmount);
      final sectionActual =
          sectionItems.fold(0.0, (s, i) => s + (actuals[i.id] ?? 0));

      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          children: [
            // Section header row
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: _lightGrey,
              child: pw.Row(
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: pw.BoxDecoration(
                      color: _primary,
                      borderRadius: pw.BorderRadius.circular(3),
                    ),
                    child: pw.Text(entry.key,
                        style: _style(
                            size: 8, bold: true, color: PdfColors.white)),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: pw.Text(sectionTitle,
                        style: _style(size: 9, bold: true)),
                  ),
                  pw.Text('฿${_fmt.format(sectionBudget)}',
                      style: _style(size: 9, bold: true)),
                  if (sectionActual > 0) ...[
                    pw.SizedBox(width: 8),
                    pw.Text('Actual: ฿${_fmt.format(sectionActual)}',
                        style: _style(size: 8, color: _grey)),
                  ],
                ],
              ),
            ),
            // Column headers
            pw.Padding(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: pw.Row(
                children: [
                  pw.Expanded(
                      flex: 5,
                      child: pw.Text('Line Item',
                          style: _style(size: 8, bold: true, color: _grey))),
                  pw.SizedBox(
                      width: 80,
                      child: pw.Text('Budget',
                          textAlign: pw.TextAlign.right,
                          style: _style(size: 8, bold: true, color: _grey))),
                  pw.SizedBox(
                      width: 80,
                      child: pw.Text('Actual',
                          textAlign: pw.TextAlign.right,
                          style: _style(size: 8, bold: true, color: _grey))),
                  pw.SizedBox(
                      width: 80,
                      child: pw.Text('Variance',
                          textAlign: pw.TextAlign.right,
                          style: _style(size: 8, bold: true, color: _grey))),
                ],
              ),
            ),
            pw.Divider(height: 1, color: PdfColors.grey300),
            // Line items
            ...sectionItems.asMap().entries.map((e) {
              final item = e.value;
              final actual = actuals[item.id] ?? 0.0;
              final variance = item.budgetAmount - actual;
              final hasActual = actual > 0;
              final isEven = e.key.isEven;

              return pw.Container(
                color: isEven ? PdfColors.white : _lightGrey,
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 5,
                      child: pw.Text(item.name,
                          style: _style(size: 8)),
                    ),
                    pw.SizedBox(
                      width: 80,
                      child: pw.Text(
                        item.budgetAmount == 0
                            ? '-'
                            : '฿${_fmt.format(item.budgetAmount)}',
                        textAlign: pw.TextAlign.right,
                        style: _style(size: 8),
                      ),
                    ),
                    pw.SizedBox(
                      width: 80,
                      child: pw.Text(
                        hasActual ? '฿${_fmt.format(actual)}' : '-',
                        textAlign: pw.TextAlign.right,
                        style: _style(size: 8),
                      ),
                    ),
                    pw.SizedBox(
                      width: 80,
                      child: hasActual
                          ? pw.Text(
                              variance >= 0
                                  ? '฿${_fmt.format(variance)}'
                                  : '-฿${_fmt.format(variance.abs())}',
                              textAlign: pw.TextAlign.right,
                              style: _style(
                                  size: 8,
                                  bold: true,
                                  color: variance < 0 ? _red : _green),
                            )
                          : pw.Text('-',
                              textAlign: pw.TextAlign.right,
                              style: _style(size: 8, color: _grey)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      );
    }).toList();
  }

  pw.Widget _buildTypeTotal(String label, List<BudgetLineItem> items,
      Map<String, double> actuals, PdfColor color) {
    final budgetTotal = items.fold(0.0, (s, i) => s + i.budgetAmount);
    final actualTotal =
        items.fold(0.0, (s, i) => s + (actuals[i.id] ?? 0));

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 4),
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(label,
                style:
                    _style(size: 10, bold: true, color: PdfColors.white)),
          ),
          pw.Text('฿${_fmt.format(budgetTotal)}',
              style: _style(size: 11, bold: true, color: PdfColors.white)),
          if (actualTotal > 0) ...[
            pw.SizedBox(width: 16),
            pw.Text('Actual: ฿${_fmt.format(actualTotal)}',
                style: _style(
                    size: 9, color: PdfColor.fromInt(0xCCFFFFFF))),
          ],
        ],
      ),
    );
  }

  Future<void> printBudget({
    required BudgetYear year,
    required List<BudgetLineItem> items,
    required Map<String, double> actuals,
  }) async {
    final bytes = await generateBudgetPdf(
        year: year, items: items, actuals: actuals);
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'Budget_${year.year}.pdf',
    );
  }
}
