import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/media_yearly_stats.dart';
import '../utils/constants.dart';

class MediaYearlyStatsPdfService {
  Future<Uint8List> exportYearlyStats(MediaYearlyStats stats) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('MMM dd, yyyy');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _buildHeader(stats, dateFormat),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _sectionTitle('Result'),
          _twoColumnStats([
            _kv('Total Follower', stats.resultTotalFollower),
            _kv('Net Follower Gain', stats.resultNetFollowerGain),
            _kv('View', stats.resultView),
            _kv('Viewers', stats.resultViewers),
            _kv('Content Interaction', stats.resultContentInteraction),
            _kv('Link Click', stats.resultLinkClick),
            _kv('Visit', stats.resultVisit),
            _kv('Follow', stats.resultFollow),
          ]),
          pw.SizedBox(height: 12),
          _sectionTitle('Audience'),
          _twoColumnStats([
            _kv('Follow', stats.audienceFollow),
            _kv('Returning Viewers', stats.audienceReturningViewers),
            _kv('Engage Follower', stats.audienceEngageFollower),
          ]),
          pw.SizedBox(height: 12),
          _sectionTitle('Content Overview'),
          _twoColumnStats([
            _kv('View', stats.contentOverviewView),
            _kv('3 Second View', stats.contentOverviewThreeSecondView),
            _kv('1 Minutes View', stats.contentOverviewOneMinuteView),
            _kv('Content Interaction', stats.contentOverviewContentInteraction),
            _kvDuration('Watch Time', stats.contentOverviewWatchTime),
          ]),
          pw.SizedBox(height: 12),
          _sectionTitle('View Breakdown'),
          _twoColumnStats([
            _kv('Total', stats.viewBreakdownTotal),
            _kv('From Organic', stats.viewBreakdownFromOrganic),
            _kv('From Follower', stats.viewBreakdownFromFollower),
            _kv('Viewers', stats.viewBreakdownViewers),
          ]),
          pw.SizedBox(height: 12),
          _sectionTitle('Content'),
          _twoColumnStats([
            _kv('Reach', stats.contentReach),
            _kvDuration('Watch Time', stats.contentWatchTime),
            _kv('Video Average', stats.contentVideoAverage),
            _kv('Like and Reaction', stats.contentLikeReaction),
            _kv('Viewers', stats.contentViewers),
          ]),
          pw.SizedBox(height: 12),
          _sectionTitle('Platform Breakdown'),
          _buildPlatformTable(stats.platformStats),
          if (stats.notes != null && stats.notes!.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _sectionTitle('Notes'),
            pw.Text(stats.notes!, style: const pw.TextStyle(fontSize: 10)),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(MediaYearlyStats stats, DateFormat dateFormat) {
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
          'YEARLY SOCIAL MEDIA STATS',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          'Year: ${stats.year}',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.Text(
          'Language: ${stats.language}',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.Text(
          'Platform: ${stats.platform.toUpperCase()}',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        if (stats.pageName.isNotEmpty)
          pw.Text(
            'Page: ${stats.pageName}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        if (stats.title != null && stats.title!.isNotEmpty)
          pw.Text(
            'Title: ${stats.title}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        pw.Text(
          'Generated: ${dateFormat.format(DateTime.now())}',
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

  pw.Widget _sectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  MapEntry<String, String> _kv(String label, Object? value) {
    if (value == null) return MapEntry(label, '-');
    if (value is double) {
      return MapEntry(label, value.toStringAsFixed(2));
    }
    return MapEntry(label, value.toString());
  }

  MapEntry<String, String> _kvDuration(String label, int? hours) {
    if (hours == null) return MapEntry(label, '-');
    return MapEntry(label, _formatDuration(hours));
  }

  pw.Widget _twoColumnStats(List<MapEntry<String, String>> entries) {
    final rows = <pw.TableRow>[];
    for (var i = 0; i < entries.length; i += 2) {
      final left = entries[i];
      final right = i + 1 < entries.length ? entries[i + 1] : null;
      rows.add(
        pw.TableRow(
          children: [
            _statCell(left.key, left.value),
            right == null ? pw.Container() : _statCell(right.key, right.value),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: const {
        0: pw.FlexColumnWidth(1),
        1: pw.FlexColumnWidth(1),
      },
      children: rows,
    );
  }

  pw.Widget _statCell(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPlatformTable(
    Map<String, Map<String, num>> platformStats,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _headerCell('Platform'),
            _headerCell('View'),
            _headerCell('Viewers'),
            _headerCell('Reach'),
            _headerCell('Watch Time'),
            _headerCell('Like/Reaction'),
          ],
        ),
        ...platformStats.entries.map((entry) {
          final data = entry.value;
          return pw.TableRow(
            children: [
              _cell(entry.key.toUpperCase()),
              _cell(_numText(data['resultView'])),
              _cell(_numText(data['resultViewers'])),
              _cell(_numText(data['contentReach'])),
              _cell(_durationText(data['contentWatchTime'])),
              _cell(_numText(data['contentLikeReaction'])),
            ],
          );
        }),
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

  pw.Widget _cell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
    );
  }

  String _numText(num? value) => value == null ? '-' : value.toString();

  String _durationText(num? value) {
    if (value == null) return '-';
    return _formatDuration(value.round());
  }

  String _formatDuration(int hours) {
    if (hours <= 0) return '0h';
    final days = hours ~/ 24;
    final remainder = hours % 24;
    if (days == 0) return '${remainder}h';
    if (remainder == 0) return '${days}d';
    return '${days}d ${remainder}h';
  }
}
