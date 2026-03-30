import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/media_production.dart';
import '../utils/constants.dart';

class MediaProductionPdfService {
  Future<Uint8List> exportProductionList({
    required List<MediaProduction> productions,
    String title = 'Media Productions List',
    Map<String, double>? projectBudgets,
  }) async {
    final theme = await _buildTheme();
    final logoImage = await _loadLogo();
    final pdf = pw.Document(theme: theme);
    final currencyFormat = NumberFormat.currency(
      symbol: '${AppConstants.currencySymbol} ',
      decimalDigits: 2,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _buildHeader(title, logoImage),
        footer: (context) => _buildFooter(context),
        build: (context) {
          final totalAmount = productions.fold<double>(0, (sum, production) {
            final projectBudget =
                production.projectId != null && projectBudgets != null
                ? projectBudgets[production.projectId!]
                : null;
            final budget = projectBudget ?? production.budget ?? 0;
            return sum + budget;
          });

          return [
            pw.Text(
              'Total Productions: ${productions.length}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Total Budget: ${currencyFormat.format(totalAmount)}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 12),
            _buildTable(productions, currencyFormat, projectBudgets),
          ];
        },
      ),
    );

    return pdf.save();
  }

  Future<Uint8List> exportProductionBudgetList({
    required List<MediaProduction> productions,
    required Map<String, double> projectBudgets,
    String title = 'Production Budget List',
    int? yearFilter,
  }) async {
    final theme = await _buildTheme();
    final logoImage = await _loadLogo();
    final pdf = pw.Document(theme: theme);
    final currencyFormat = NumberFormat.currency(
      symbol: '${AppConstants.currencySymbol} ',
      decimalDigits: 2,
    );

    final filtered = yearFilter == null
        ? productions
        : productions.where((p) => p.productionYear == yearFilter).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _buildHeader(
          yearFilter == null ? title : '$title ($yearFilter)',
          logoImage,
        ),
        footer: (context) => _buildFooter(context),
        build: (context) {
          final totalAmount = filtered.fold<double>(0, (sum, production) {
            final projectBudget = production.projectId != null
                ? projectBudgets[production.projectId!]
                : null;
            final effectiveBudget = projectBudget ?? production.budget ?? 0;
            return sum + effectiveBudget;
          });

          return [
            pw.Text(
              'Total Productions: ${filtered.length}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Total Budget: ${currencyFormat.format(totalAmount)}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 12),
            _buildBudgetTable(filtered, currencyFormat, projectBudgets),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(String title, pw.ImageProvider? logoImage) {
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
          title.toUpperCase(),
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          'Generated: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
        pw.Divider(),
      ],
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
      ),
    );
  }

  pw.Widget _buildTable(
    List<MediaProduction> productions,
    NumberFormat currencyFormat,
    Map<String, double>? projectBudgets,
  ) {
    final totalAmount = productions.fold<double>(0, (sum, production) {
      final projectBudget =
          production.projectId != null && projectBudgets != null
          ? projectBudgets[production.projectId!]
          : null;
      final budget = projectBudget ?? production.budget ?? 0;
      return sum + budget;
    });

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(1.2),
        2: pw.FlexColumnWidth(1.4),
        3: pw.FlexColumnWidth(1.2),
        4: pw.FlexColumnWidth(1.2),
        5: pw.FlexColumnWidth(1.2),
        6: pw.FlexColumnWidth(1.2),
        7: pw.FlexColumnWidth(1.4),
        8: pw.FlexColumnWidth(2.2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _headerCell('Title'),
            _headerCell('Language'),
            _headerCell('Type'),
            _headerCell('Status'),
            _headerCell('Seasons'),
            _headerCell('Episodes'),
            _headerCell('Duration'),
            _headerCell('Category'),
            _headerCell('Budget'),
          ],
        ),
        ...productions.map((production) {
          final projectBudget =
              production.projectId != null && projectBudgets != null
              ? projectBudgets[production.projectId!]
              : null;
          final effectiveBudget = projectBudget ?? production.budget;
          return pw.TableRow(
            children: [
              _cell(production.title),
              _cell(production.languageDisplayName),
              _cell(production.typeDisplayName),
              _cell(production.statusDisplayName),
              _cell(production.totalSeasons.toString()),
              _cell(production.totalEpisodes.toString()),
              _cell(_formatDuration(production.durationMinutes)),
              _cell(production.category ?? '-'),
              _cell(
                effectiveBudget == null
                    ? '-'
                    : currencyFormat.format(effectiveBudget),
                alignRight: true,
              ),
            ],
          );
        }),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _cell('Total', alignRight: false),
            _cell(''),
            _cell(''),
            _cell(''),
            _cell(''),
            _cell(''),
            _cell(''),
            _cell(''),
            _cell(currencyFormat.format(totalAmount), alignRight: true),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildBudgetTable(
    List<MediaProduction> productions,
    NumberFormat currencyFormat,
    Map<String, double> projectBudgets,
  ) {
    final totalAmount = productions.fold<double>(0, (sum, production) {
      final projectBudget = production.projectId != null
          ? projectBudgets[production.projectId!]
          : null;
      final effectiveBudget = projectBudget ?? production.budget ?? 0;
      return sum + effectiveBudget;
    });

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(1.1),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(1.1),
        4: pw.FlexColumnWidth(1.6),
        5: pw.FlexColumnWidth(1.4),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _headerCell('Title'),
            _headerCell('Year'),
            _headerCell('Language'),
            _headerCell('Type'),
            _headerCell('Budget'),
            _headerCell('Source'),
          ],
        ),
        ...productions.map((production) {
          final projectBudget = production.projectId != null
              ? projectBudgets[production.projectId!]
              : null;
          final effectiveBudget = projectBudget ?? production.budget ?? 0;
          final source = projectBudget != null ? 'Project Report' : 'Manual';

          return pw.TableRow(
            children: [
              _cell(production.title),
              _cell(production.productionYear?.toString() ?? '-'),
              _cell(production.languageDisplayName),
              _cell(production.typeDisplayName),
              _cell(currencyFormat.format(effectiveBudget), alignRight: true),
              _cell(source),
            ],
          );
        }),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _cell('Total', alignRight: false),
            _cell(''),
            _cell(''),
            _cell(''),
            _cell(currencyFormat.format(totalAmount), alignRight: true),
            _cell(''),
          ],
        ),
      ],
    );
  }

  pw.Widget _headerCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
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

  String _formatDuration(int? minutes) {
    if (minutes == null) return '-';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) return '${mins}m';
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
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
    pw.Font? emojiFont;
    try {
      notoFallback = await PdfGoogleFonts.notoSansRegular();
    } catch (_) {}
    try {
      emojiFont = await PdfGoogleFonts.notoColorEmojiRegular();
    } catch (_) {}

    return pw.ThemeData.withFont(
      base: regular ?? pw.Font.helvetica(),
      bold: bold ?? pw.Font.helveticaBold(),
      fontFallback: [?notoFallback, ?emojiFont],
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
