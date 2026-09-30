import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/media_production_planning.dart';
import '../utils/constants.dart';

/// Exports a Media Production's Planning stage (Workflow HC's 8-step
/// template) as a printable / savable PDF — so a producer can come back
/// to the record for reference, print it, or file it locally.
class MediaPlanningPdfService {
  Future<Uint8List> exportPlanning({
    required String productionTitle,
    required MediaProductionPlanning planning,
  }) async {
    final theme = await _buildTheme();
    final logoImage = await _loadLogo();
    final pdf = pw.Document(theme: theme);
    final currencyFormat = NumberFormat.currency(
      symbol: '${planning.budget.currency} ',
      decimalDigits: 0,
    );
    final dateFormat = DateFormat.yMMMd();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => context.pageNumber == 1
            ? _buildHeader(productionTitle, logoImage)
            : pw.SizedBox(),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          _section('1. General Objective', [
            _field('Pains to attend', planning.objective.pains.isEmpty
                ? '-'
                : planning.objective.pains.map((p) => '• $p').join('\n')),
            _field('Why this program exists', planning.objective.whyItExists),
            _field('Practical conditions', planning.objective.practicalConditions),
            _field('Metric priority',
                planning.objective.metricPriority.isEmpty
                    ? '-'
                    : planning.objective.metricPriority.join(' > ')),
          ]),
          _section('2. Audience', [
            _field('Gender', planning.audience.gender),
            _field('Age', planning.audience.ageRange),
            _field('Social situation', planning.audience.socialSituation),
            _field('Activity', planning.audience.activity),
            _field('Geography', planning.audience.geography),
            _field('Who is NOT the target audience', planning.audience.notAudience),
          ]),
          _section('3. Strategic Intent', [
            _field('Transformation', planning.strategicIntent.transformation),
            _field('What attracts the audience', planning.strategicIntent.attractionHook),
            _field('Retention plan', planning.strategicIntent.retentionPlan),
            _field('Metrics', planning.strategicIntent.metrics.isEmpty
                ? '-'
                : planning.strategicIntent.metrics.join(', ')),
          ]),
          _section('4. Format — Market Research', [
            _field('Preferred platforms',
                planning.marketResearch.preferredPlatforms.isEmpty
                    ? '-'
                    : planning.marketResearch.preferredPlatforms.join(', ')),
            _field('Style', planning.marketResearch.style),
            _field('Aspect ratio', planning.marketResearch.aspectRatio.label),
            pw.SizedBox(height: 6),
            if (planning.marketResearch.references.isEmpty)
              pw.Text('No references added.', style: const pw.TextStyle(fontSize: 10))
            else
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.5),
                  1: pw.FlexColumnWidth(1.5),
                  2: pw.FlexColumnWidth(2.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _headerCell('Program'),
                      _headerCell('Link'),
                      _headerCell('What works'),
                    ],
                  ),
                  ...planning.marketResearch.references.map(
                    (r) => pw.TableRow(children: [
                      _cell(r.title.isEmpty ? '-' : r.title),
                      _cell(r.url.isEmpty ? '-' : r.url),
                      _cell(r.whatWorks.isEmpty ? '-' : r.whatWorks),
                    ]),
                  ),
                ],
              ),
          ]),
          _section('5. Program Identity', [
            _field('Program name', planning.identity.programName),
            _field('Briefing', planning.identity.briefing),
            _field('Font choice', planning.identity.fontChoice),
            _field('Color palette', planning.identity.colorPalette),
            _field('Key visual (KV)', planning.identity.keyVisualDescription),
            _field('Derivations needed', planning.identity.derivationsNeeded.join(', ')),
          ]),
          _section('6. Distribution', [
            _field(
              'Platforms',
              planning.distribution.platforms.isEmpty
                  ? '-'
                  : planning.distribution.platforms.join(', '),
            ),
            _field('Frequency', planning.distribution.frequency),
            _field(
              'Launch date',
              planning.distribution.launchDate == null
                  ? '-'
                  : DateFormat.yMMMd().format(planning.distribution.launchDate!),
            ),
            _field(
              'Format per platform',
              planning.distribution.formatByPlatform.isEmpty
                  ? '-'
                  : planning.distribution.formatByPlatform.entries
                      .map((e) => '${e.key}: ${e.value}')
                      .join('\n'),
            ),
            _field('Boosting — pre', planning.distribution.boostStrategyPre),
            _field('Boosting — during', planning.distribution.boostStrategyDuring),
            _field('Boosting — post', planning.distribution.boostStrategyPost),
            _field('Paid traffic', planning.distribution.usesPaidTraffic ? 'Yes' : 'No'),
            pw.SizedBox(height: 6),
            pw.Text('Editorial calendar', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            pw.SizedBox(height: 4),
            if (planning.distribution.editorialCalendar.isEmpty)
              pw.Text('No entries yet.', style: const pw.TextStyle(fontSize: 10))
            else
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.2),
                  1: pw.FlexColumnWidth(1.6),
                  2: pw.FlexColumnWidth(1.2),
                  3: pw.FlexColumnWidth(1.2),
                  4: pw.FlexColumnWidth(1.2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _headerCell('Date'),
                      _headerCell('Theme'),
                      _headerCell('Format'),
                      _headerCell('Channel'),
                      _headerCell('Status'),
                    ],
                  ),
                  ...planning.distribution.editorialCalendar.map(
                    (e) => pw.TableRow(children: [
                      _cell(dateFormat.format(e.date)),
                      _cell(e.theme.isEmpty ? '-' : e.theme),
                      _cell(e.format.isEmpty ? '-' : e.format),
                      _cell(e.channel.isEmpty ? '-' : e.channel),
                      _cell(e.status),
                    ]),
                  ),
                ],
              ),
          ]),
          _section('7. Budget', [
            if (planning.budget.items.isEmpty)
              pw.Text('No budget items added.', style: const pw.TextStyle(fontSize: 10))
            else
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(1.5)},
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [_headerCell('Item'), _headerCell('Amount')],
                  ),
                  ...planning.budget.items.map(
                    (i) => pw.TableRow(children: [
                      _cell(i.label.isEmpty ? '-' : i.label),
                      _cell(currencyFormat.format(i.amount), alignRight: true),
                    ]),
                  ),
                ],
              ),
            pw.SizedBox(height: 6),
            _field('Total budget', currencyFormat.format(planning.budget.total)),
            pw.SizedBox(height: 6),
            pw.Text('Phase breakdown', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            pw.SizedBox(height: 4),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: const {
                0: pw.FlexColumnWidth(2),
                1: pw.FlexColumnWidth(1),
                2: pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [_headerCell('Phase'), _headerCell('%'), _headerCell('Amount')],
                ),
                _budgetRow('Pre-production', planning.budget.split.preProductionPct,
                    planning.budget.preProduction, currencyFormat),
                _budgetRow('Production', planning.budget.split.productionPct,
                    planning.budget.production, currencyFormat),
                _budgetRow('Post-production', planning.budget.split.postProductionPct,
                    planning.budget.postProduction, currencyFormat),
                _budgetRow('Distribution', planning.budget.split.distributionPct,
                    planning.budget.distribution, currencyFormat),
                _budgetRow('Closure & documentation', planning.budget.split.closurePct,
                    planning.budget.closure, currencyFormat),
              ],
            ),
          ]),
          _section('8. Approvals', [
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: const {
                0: pw.FlexColumnWidth(2.5),
                1: pw.FlexColumnWidth(1),
                2: pw.FlexColumnWidth(1.3),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [_headerCell('Item'), _headerCell('Status'), _headerCell('Owner')],
                ),
                ...planning.approvals.map(
                  (a) => pw.TableRow(children: [
                    _cell(a.item),
                    _cell(a.status.label),
                    _cell(a.owner.isEmpty ? '-' : a.owner),
                  ]),
                ),
              ],
            ),
          ]),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _section(String title, List<pw.Widget> children) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.Divider(),
          ...children,
        ],
      ),
    );
  }

  pw.Widget _field(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
          pw.Text(value.isEmpty ? '-' : value, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  pw.TableRow _budgetRow(
    String label,
    double pct,
    double amount,
    NumberFormat currencyFormat,
  ) {
    return pw.TableRow(children: [
      _cell(label),
      _cell('${(pct * 100).toStringAsFixed(0)}%'),
      _cell(currencyFormat.format(amount), alignRight: true),
    ]);
  }

  pw.Widget _headerCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
    );
  }

  pw.Widget _cell(String text, {bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9),
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
      ),
    );
  }

  pw.Widget _buildHeader(String productionTitle, pw.ImageProvider? logoImage) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (logoImage != null)
          pw.Container(
            height: 36,
            alignment: pw.Alignment.centerLeft,
            child: pw.Image(logoImage, fit: pw.BoxFit.contain),
          ),
        if (logoImage != null) pw.SizedBox(height: 6),
        pw.Text(
          AppConstants.organizationName,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          AppConstants.organizationAddress,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'PLANNING DOCUMENT',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          productionTitle,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.pink700),
        ),
        pw.Text(
          'Generated: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
        pw.Divider(),
      ],
    );
  }

  Future<pw.ThemeData> _buildTheme() async {
    pw.Font? regular;
    pw.Font? bold;
    try {
      regular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSansThai-Regular.ttf'),
      );
      bold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSansThai-Bold.ttf'),
      );
    } catch (_) {}

    pw.Font? notoFallback;
    try {
      notoFallback = await PdfGoogleFonts.notoSansRegular();
    } catch (_) {}

    return pw.ThemeData.withFont(
      base: regular ?? pw.Font.helvetica(),
      bold: bold ?? pw.Font.helveticaBold(),
      fontFallback: [?notoFallback],
    );
  }

  Future<pw.ImageProvider?> _loadLogo() async {
    try {
      final data = await rootBundle.load(AppConstants.companyLogo);
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }
}
