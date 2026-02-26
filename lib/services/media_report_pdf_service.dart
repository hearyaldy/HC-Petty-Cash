import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/enums.dart';
import '../utils/constants.dart';

class MediaReportPdfService {
  Future<Uint8List> exportAnnualReport({
    required int year,
    required Map<String, dynamic> productionStats,
    required Map<String, dynamic> engagementStats,
    String? selectedLanguage,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('MMM dd, yyyy');

    final totalProductions = _asInt(productionStats['totalProductions']);
    final totalEpisodes = _asInt(productionStats['totalEpisodes']);
    final publishedCount = _asInt(productionStats['publishedCount']);
    final inProductionCount = _asInt(productionStats['inProductionCount']);
    final byLanguage = _asIntMap(productionStats['byLanguage']);
    final byType = _asIntMap(productionStats['byType']);

    final totalViews = _asInt(engagementStats['totalViews']);
    final totalLikes = _asInt(engagementStats['totalLikes']);
    final totalComments = _asInt(engagementStats['totalComments']);
    final totalShares = _asInt(engagementStats['totalShares']);
    final totalEngagement = _asInt(engagementStats['totalEngagement']);
    final engagementRate = _asDouble(engagementStats['engagementRate']);
    final byPlatform = _asNestedIntMap(engagementStats['byPlatform']);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _buildHeader(
          dateFormat,
          year: year,
          selectedLanguage: selectedLanguage,
        ),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildSectionTitle('Production Summary'),
          _buildProductionSummaryRow(
            totalProductions: totalProductions,
            totalEpisodes: totalEpisodes,
            publishedCount: publishedCount,
            inProductionCount: inProductionCount,
          ),
          pw.SizedBox(height: 16),
          _buildBreakdownTable(
            title: 'Productions by Language',
            rows: byLanguage.entries
                .map(
                  (entry) => _KeyValueRow(
                    entry.key.mediaLanguageDisplayName,
                    entry.value.toString(),
                  ),
                )
                .toList(),
          ),
          pw.SizedBox(height: 16),
          _buildBreakdownTable(
            title: 'Productions by Type',
            rows: byType.entries
                .map(
                  (entry) => _KeyValueRow(
                    entry.key.productionTypeDisplayName,
                    entry.value.toString(),
                  ),
                )
                .toList(),
          ),
          pw.SizedBox(height: 24),
          _buildSectionTitle('Engagement Summary'),
          _buildEngagementSummaryTable(
            totalViews: totalViews,
            totalLikes: totalLikes,
            totalComments: totalComments,
            totalShares: totalShares,
            totalEngagement: totalEngagement,
            engagementRate: engagementRate,
          ),
          pw.SizedBox(height: 16),
          _buildPlatformBreakdown(byPlatform),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(
    DateFormat dateFormat, {
    required int year,
    String? selectedLanguage,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
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
          'MEDIA PRODUCTION ANNUAL REPORT',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          'Year: $year',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.Text(
          'Language: ${selectedLanguage?.mediaLanguageDisplayName ?? 'All'}',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.Text(
          'Generated: ${dateFormat.format(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
        pw.Divider(),
        pw.SizedBox(height: 6),
      ],
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
      ),
    );
  }

  pw.Widget _buildSectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget _buildProductionSummaryRow({
    required int totalProductions,
    required int totalEpisodes,
    required int publishedCount,
    required int inProductionCount,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _buildStatBlock('Productions', totalProductions.toString()),
          _buildStatBlock('Episodes', totalEpisodes.toString()),
          _buildStatBlock('Published', publishedCount.toString()),
          _buildStatBlock('In Production', inProductionCount.toString()),
        ],
      ),
    );
  }

  pw.Widget _buildStatBlock(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  pw.Widget _buildBreakdownTable({
    required String title,
    required List<_KeyValueRow> rows,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _buildTableHeaderCell('Category'),
                _buildTableHeaderCell('Count', alignRight: true),
              ],
            ),
            ...rows.map(
              (row) => pw.TableRow(
                children: [
                  _buildTableCell(row.key),
                  _buildTableCell(row.value, alignRight: true),
                ],
              ),
            ),
            if (rows.isEmpty)
              pw.TableRow(
                children: [
                  _buildTableCell('No data'),
                  _buildTableCell('-', alignRight: true),
                ],
              ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildEngagementSummaryTable({
    required int totalViews,
    required int totalLikes,
    required int totalComments,
    required int totalShares,
    required int totalEngagement,
    required double engagementRate,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: const {
        0: pw.FlexColumnWidth(),
        1: pw.FlexColumnWidth(),
        2: pw.FlexColumnWidth(),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _buildTableHeaderCell('Metric'),
            _buildTableHeaderCell('Value', alignRight: true),
            _buildTableHeaderCell('Metric'),
          ],
        ),
        _buildSummaryRow('Views', totalViews, 'Likes', totalLikes),
        _buildSummaryRow('Comments', totalComments, 'Shares', totalShares),
        _buildSummaryRow(
          'Total Engagement',
          totalEngagement,
          'Engagement Rate',
          '${engagementRate.toStringAsFixed(2)}%',
        ),
      ],
    );
  }

  pw.TableRow _buildSummaryRow(
    String labelA,
    Object valueA,
    String labelB,
    Object valueB,
  ) {
    return pw.TableRow(
      children: [
        _buildTableCell(labelA),
        _buildTableCell(valueA.toString(), alignRight: true),
        _buildTableCell('$labelB: ${valueB.toString()}'),
      ],
    );
  }

  pw.Widget _buildPlatformBreakdown(Map<String, Map<String, int>> byPlatform) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Engagement by Platform',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _buildTableHeaderCell('Platform'),
                _buildTableHeaderCell('Views', alignRight: true),
                _buildTableHeaderCell('Likes', alignRight: true),
                _buildTableHeaderCell('Comments', alignRight: true),
                _buildTableHeaderCell('Shares', alignRight: true),
              ],
            ),
            ...byPlatform.entries.map((entry) {
              final metrics = entry.value;
              return pw.TableRow(
                children: [
                  _buildTableCell(entry.key.mediaPlatformDisplayName),
                  _buildTableCell(
                    _asInt(metrics['views']).toString(),
                    alignRight: true,
                  ),
                  _buildTableCell(
                    _asInt(metrics['likes']).toString(),
                    alignRight: true,
                  ),
                  _buildTableCell(
                    _asInt(metrics['comments']).toString(),
                    alignRight: true,
                  ),
                  _buildTableCell(
                    _asInt(metrics['shares']).toString(),
                    alignRight: true,
                  ),
                ],
              );
            }),
            if (byPlatform.isEmpty)
              pw.TableRow(
                children: [
                  _buildTableCell('No data'),
                  _buildTableCell('-', alignRight: true),
                  _buildTableCell('-', alignRight: true),
                  _buildTableCell('-', alignRight: true),
                  _buildTableCell('-', alignRight: true),
                ],
              ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTableHeaderCell(String text, {bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
      ),
    );
  }

  pw.Widget _buildTableCell(String text, {bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9),
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
      ),
    );
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return 0;
  }

  double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return 0.0;
  }

  Map<String, int> _asIntMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value.map((key, val) => MapEntry(key, _asInt(val)));
    }
    if (value is Map<String, int>) {
      return Map<String, int>.from(value);
    }
    return {};
  }

  Map<String, Map<String, int>> _asNestedIntMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value.map((key, val) => MapEntry(key, _asIntMap(val)));
    }
    return {};
  }
}

class _KeyValueRow {
  final String key;
  final String value;

  _KeyValueRow(this.key, this.value);
}
