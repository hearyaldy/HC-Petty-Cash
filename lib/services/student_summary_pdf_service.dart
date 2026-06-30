import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

enum StudentSummaryReportType {
  workSummary,
  paymentByLanguage,
  taskByLanguage,
}

class _StudentTotals {
  final String name;
  final String language;
  final String role;
  final String grade;
  final double rate;
  double hours = 0;
  double amount = 0;
  int reports = 0;
  int approved = 0;
  int paid = 0;

  _StudentTotals({
    required this.name,
    required this.language,
    required this.role,
    required this.grade,
    required this.rate,
  });
}

class _TaskTotals {
  final String taskType;
  double hours = 0;
  double amount = 0;
  int entries = 0;
  final Set<String> studentIds = {};

  _TaskTotals({required this.taskType});
}

class StudentSummaryPdfService {
  static const _orange = PdfColor.fromInt(0xFFE65100);
  static const _orangeLight = PdfColor.fromInt(0xFFFBE9E7);
  static const _headerBg = PdfColor.fromInt(0xFFF57C00);
  static const _grey = PdfColor.fromInt(0xFF757575);
  static const _darkText = PdfColor.fromInt(0xFF212121);
  static const _white = PdfColors.white;
  static const _rowAlt = PdfColor.fromInt(0xFFFFF8F0);
  static const _divider = PdfColor.fromInt(0xFFE0E0E0);

  final _currency = NumberFormat('#,##0.00', 'en_US');
  final _dateFormat = DateFormat('MMM dd, yyyy HH:mm');

  Future<Uint8List> generateReport({
    required StudentSummaryReportType type,
    required List<Map<String, dynamic>> reports,
    required Map<String, Map<String, dynamic>> profiles,
    List<Map<String, dynamic>> timesheets = const [],
    String generatedBy = '',
    String? dateRange,
    String? statusFilter,
    // Budget data from student_labor_budgets/{year}: {totalBudget, allocations: {lang: pct}}
    Map<String, dynamic>? budgetData,
  }) {
    switch (type) {
      case StudentSummaryReportType.workSummary:
        return _buildWorkSummary(reports, profiles, generatedBy, dateRange, statusFilter, budgetData);
      case StudentSummaryReportType.paymentByLanguage:
        return _buildPaymentByLanguage(reports, profiles, generatedBy, dateRange, statusFilter, budgetData);
      case StudentSummaryReportType.taskByLanguage:
        return _buildTaskByLanguage(reports, profiles, timesheets, generatedBy, dateRange, statusFilter, budgetData);
    }
  }

  // ─── Report 1: Student Work Summary ─────────────────────────────────────────

  Future<Uint8List> _buildWorkSummary(
    List<Map<String, dynamic>> reports,
    Map<String, Map<String, dynamic>> profiles,
    String generatedBy,
    String? dateRange,
    String? statusFilter,
    Map<String, dynamic>? budgetData,
  ) async {
    final totals = _aggregateByStudent(reports, profiles);
    final sorted = totals.values.toList()..sort((a, b) => a.name.compareTo(b.name));

    final totalHours = sorted.fold<double>(0, (s, t) => s + t.hours);
    final totalAmount = sorted.fold<double>(0, (s, t) => s + t.amount);
    final totalReports = sorted.fold<int>(0, (s, t) => s + t.reports);

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        header: (_) => _header(
          'Student Work Summary Report',
          generatedBy: generatedBy,
          dateRange: dateRange,
          statusFilter: statusFilter,
        ),
        footer: (ctx) => _footer(ctx),
        build: (_) => [
          // Summary banner
          _summaryBanner([
            _bannerStat('Students', '${sorted.length}'),
            _bannerStat('Reports', '$totalReports'),
            _bannerStat('Total Hours', '${totalHours.toStringAsFixed(1)}h'),
            _bannerStat('Total Paid', 'THB ${_currency.format(totalAmount)}'),
            if (budgetData != null)
              _bannerStat('Budget', 'THB ${_currency.format((budgetData['totalBudget'] as num).toDouble())}'),
          ]),
          if (budgetData != null) ...[
            pw.SizedBox(height: 6),
            _budgetOverviewBar(totalAmount, budgetData),
          ],
          pw.SizedBox(height: 16),
          // Main table
          pw.TableHelper.fromTextArray(
            headers: ['#', 'Student Name', 'Language', 'Role', 'Grade', 'Reports', 'Total Hours', 'Rate (THB/h)', 'Total Amount', 'Approved'],
            data: [
              ...sorted.asMap().entries.map((e) {
                final i = e.key + 1;
                final t = e.value;
                final approvedPct = t.reports > 0 ? '${t.approved}/${t.reports}' : '0/0';
                return [
                  '$i',
                  t.name,
                  t.language.isEmpty ? '-' : t.language,
                  t.role.isEmpty ? '-' : t.role,
                  t.grade.isEmpty ? '-' : t.grade,
                  '${t.reports}',
                  t.hours.toStringAsFixed(2),
                  _currency.format(t.rate),
                  'THB ${_currency.format(t.amount)}',
                  approvedPct,
                ];
              }),
              // Totals row
              [
                '',
                'TOTAL',
                '',
                '',
                '',
                '$totalReports',
                totalHours.toStringAsFixed(2),
                '',
                'THB ${_currency.format(totalAmount)}',
                '',
              ],
            ],
            headerStyle: pw.TextStyle(
              color: _white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 8,
            ),
            headerDecoration: const pw.BoxDecoration(color: _headerBg),
            cellStyle: const pw.TextStyle(fontSize: 8, color: _darkText),
            cellAlignments: {
              0: pw.Alignment.center,
              5: pw.Alignment.center,
              6: pw.Alignment.centerRight,
              7: pw.Alignment.centerRight,
              8: pw.Alignment.centerRight,
              9: pw.Alignment.center,
            },
            rowDecoration: const pw.BoxDecoration(color: _white),
            oddRowDecoration: const pw.BoxDecoration(color: _rowAlt),
            border: pw.TableBorder.all(color: _divider, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(20),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FixedColumnWidth(40),
              5: const pw.FixedColumnWidth(45),
              6: const pw.FixedColumnWidth(60),
              7: const pw.FixedColumnWidth(60),
              8: const pw.FixedColumnWidth(80),
              9: const pw.FixedColumnWidth(55),
            },
          ),
        ],
      ),
    );
    return doc.save();
  }

  // ─── Report 2: Payment by Language ──────────────────────────────────────────

  Future<Uint8List> _buildPaymentByLanguage(
    List<Map<String, dynamic>> reports,
    Map<String, Map<String, dynamic>> profiles,
    String generatedBy,
    String? dateRange,
    String? statusFilter,
    Map<String, dynamic>? budgetData,
  ) async {
    final totals = _aggregateByStudent(reports, profiles);

    // Group by language
    final langGroups = <String, List<_StudentTotals>>{};
    for (final t in totals.values) {
      final lang = t.language.trim().isEmpty ? 'Not Specified' : t.language;
      langGroups.putIfAbsent(lang, () => []).add(t);
    }
    for (final list in langGroups.values) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }
    final sortedLangs = langGroups.keys.toList()..sort();

    double grandHours = 0;
    double grandAmount = 0;
    int grandStudents = 0;
    for (final list in langGroups.values) {
      grandHours += list.fold(0, (s, t) => s + t.hours);
      grandAmount += list.fold(0, (s, t) => s + t.amount);
      grandStudents += list.length;
    }

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        header: (_) => _header(
          'Student Payment Summary by Language',
          generatedBy: generatedBy,
          dateRange: dateRange,
          statusFilter: statusFilter,
        ),
        footer: (ctx) => _footer(ctx),
        build: (_) {
          final widgets = <pw.Widget>[
            _summaryBanner([
              _bannerStat('Languages', '${sortedLangs.length}'),
              _bannerStat('Students', '$grandStudents'),
              _bannerStat('Total Hours', '${grandHours.toStringAsFixed(1)}h'),
              _bannerStat('Total Paid', 'THB ${_currency.format(grandAmount)}'),
            ]),
            pw.SizedBox(height: 16),
          ];

          // Build paid-by-language map for budget comparison
          final paidByLang = <String, double>{};
          for (final entry in langGroups.entries) {
            paidByLang[entry.key] =
                entry.value.fold<double>(0, (s, t) => s + t.amount);
          }

          for (final lang in sortedLangs) {
            final students = langGroups[lang]!;
            final langHours = students.fold<double>(0, (s, t) => s + t.hours);
            final langAmount = students.fold<double>(0, (s, t) => s + t.amount);

            // Budget info for this language
            String budgetLine = '';
            if (budgetData != null) {
              final totalBudget = (budgetData['totalBudget'] as num).toDouble();
              final allocations = budgetData['allocations'] as Map<String, dynamic>? ?? {};
              final pct = ((allocations[lang] ?? allocations[lang.trim()]) as num?)?.toDouble() ?? 0;
              final langBudget = totalBudget * (pct / 100);
              final remaining = langBudget - langAmount;
              if (langBudget > 0) {
                budgetLine = '   | Budget: THB ${_currency.format(langBudget)}   ${remaining < 0 ? "OVER by THB ${_currency.format(remaining.abs())}" : "Rem: THB ${_currency.format(remaining)}"}';
              }
            }

            widgets.add(
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: const pw.BoxDecoration(
                  color: _orangeLight,
                  border: pw.Border(left: pw.BorderSide(color: _orange, width: 3)),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        lang.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: _orange,
                        ),
                      ),
                    ),
                    pw.Text(
                      '${students.length} student${students.length == 1 ? '' : 's'}   | ${langHours.toStringAsFixed(1)}h   | THB ${_currency.format(langAmount)}$budgetLine',
                      style: const pw.TextStyle(fontSize: 9, color: _grey),
                    ),
                  ],
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 4));

            widgets.add(
              pw.TableHelper.fromTextArray(
                headers: ['Student Name', 'Role', 'Grade', 'Rate (THB/h)', 'Reports', 'Total Hours', 'Total Amount', 'Approved'],
                data: [
                  ...students.map((t) => [
                    t.name,
                    t.role.isEmpty ? '-' : t.role,
                    t.grade.isEmpty ? '-' : t.grade,
                    _currency.format(t.rate),
                    '${t.reports}',
                    t.hours.toStringAsFixed(2),
                    'THB ${_currency.format(t.amount)}',
                    '${t.approved}/${t.reports}',
                  ]),
                  // Language subtotal
                  [
                    'SUBTOTAL -$lang',
                    '', '', '',
                    '${students.fold<int>(0, (s, t) => s + t.reports)}',
                    langHours.toStringAsFixed(2),
                    'THB ${_currency.format(langAmount)}',
                    '',
                  ],
                ],
                headerStyle: pw.TextStyle(
                  color: _white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 8,
                ),
                headerDecoration: const pw.BoxDecoration(color: _headerBg),
                cellStyle: const pw.TextStyle(fontSize: 8, color: _darkText),
                cellAlignments: {
                  4: pw.Alignment.center,
                  5: pw.Alignment.centerRight,
                  6: pw.Alignment.centerRight,
                  7: pw.Alignment.center,
                },
                rowDecoration: const pw.BoxDecoration(color: _white),
                oddRowDecoration: const pw.BoxDecoration(color: _rowAlt),
                border: pw.TableBorder.all(color: _divider, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FixedColumnWidth(40),
                  3: const pw.FixedColumnWidth(65),
                  4: const pw.FixedColumnWidth(45),
                  5: const pw.FixedColumnWidth(65),
                  6: const pw.FixedColumnWidth(85),
                  7: const pw.FixedColumnWidth(60),
                },
              ),
            );
            widgets.add(pw.SizedBox(height: 14));
          }

          // Grand total
          widgets.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: const pw.BoxDecoration(color: _headerBg),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      'GRAND TOTAL',
                      style: pw.TextStyle(
                        color: _white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  pw.Text(
                    '$grandStudents students   | ${grandHours.toStringAsFixed(2)}h   | THB ${_currency.format(grandAmount)}',
                    style: pw.TextStyle(
                      color: _white,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          );

          // Budget comparison table (shown when budget data is available)
          if (budgetData != null) {
            widgets.add(pw.SizedBox(height: 20));
            widgets.add(_budgetComparisonTable(paidByLang, budgetData));
          }

          return widgets;
        },
      ),
    );
    return doc.save();
  }

  // ─── Report 3: Task Cross-Reference by Language ──────────────────────────────

  Future<Uint8List> _buildTaskByLanguage(
    List<Map<String, dynamic>> reports,
    Map<String, Map<String, dynamic>> profiles,
    List<Map<String, dynamic>> timesheets,
    String generatedBy,
    String? dateRange,
    String? statusFilter,
    Map<String, dynamic>? budgetData,
  ) async {
    // Build studentId → language map
    final studentLang = <String, String>{};
    for (final r in reports) {
      final sid = r['studentId'] ?? '';
      if (sid.isEmpty) continue;
      final profile = profiles[sid] ?? {};
      final lang = (profile['language'] as String?)?.trim().isEmpty == false
          ? profile['language'] as String
          : 'Not Specified';
      studentLang[sid] = lang;
    }
    // Also fill from timesheets whose student may not be in reports
    for (final ts in timesheets) {
      final sid = ts['studentId'] ?? '';
      if (sid.isEmpty || studentLang.containsKey(sid)) continue;
      final profile = profiles[sid] ?? {};
      final lang = (profile['language'] as String?)?.trim().isEmpty == false
          ? profile['language'] as String
          : 'Not Specified';
      studentLang[sid] = lang;
    }

    // Map<language, Map<taskType, _TaskTotals>>
    final langTaskMap = <String, Map<String, _TaskTotals>>{};

    for (final ts in timesheets) {
      final sid = ts['studentId'] ?? '';
      final lang = studentLang[sid] ?? 'Not Specified';
      final rawTask = ts['taskType'] ?? ts['task'] ?? 'other';
      final taskType = _taskTypeLabel(rawTask.toString());
      final hours = (ts['totalHours'] as num?)?.toDouble() ?? 0;
      final rate = (ts['hourlyRate'] as num?)?.toDouble() ?? 0;
      final amount = (ts['totalAmount'] as num?)?.toDouble() ?? (hours * rate);

      langTaskMap.putIfAbsent(lang, () => {});
      langTaskMap[lang]!.putIfAbsent(taskType, () => _TaskTotals(taskType: taskType));
      langTaskMap[lang]![taskType]!.hours += hours;
      langTaskMap[lang]![taskType]!.amount += amount;
      langTaskMap[lang]![taskType]!.entries++;
      langTaskMap[lang]![taskType]!.studentIds.add(sid);
    }

    // If no timesheets, fall back to language summary using report-level data
    final hasTsData = timesheets.isNotEmpty && langTaskMap.isNotEmpty;
    final sortedLangs = (hasTsData ? langTaskMap.keys : _aggregateByStudent(reports, profiles).values.map((t) => t.language.trim().isEmpty ? 'Not Specified' : t.language)).toSet().toList()..sort();

    double grandHours = 0;
    double grandAmount = 0;
    int grandEntries = 0;

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        header: (_) => _header(
          'Work Type Cross-Reference by Language',
          generatedBy: generatedBy,
          dateRange: dateRange,
          statusFilter: statusFilter,
        ),
        footer: (ctx) => _footer(ctx),
        build: (_) {
          if (!hasTsData) {
            // No timesheet detail: show language summary from monthly reports
            final totals = _aggregateByStudent(reports, profiles);
            final langGroups = <String, List<_StudentTotals>>{};
            for (final t in totals.values) {
              final lang = t.language.trim().isEmpty ? 'Not Specified' : t.language;
              langGroups.putIfAbsent(lang, () => []).add(t);
            }
            final langs = langGroups.keys.toList()..sort();

            return [
              pw.Text(
                'Note: Detailed timesheet data unavailable. Showing language summary from monthly reports.',
                style: const pw.TextStyle(fontSize: 8, color: _grey),
              ),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ['Language', 'Students', 'Total Reports', 'Total Hours', 'Total Amount'],
                data: langs.map((lang) {
                  final students = langGroups[lang]!;
                  final h = students.fold<double>(0, (s, t) => s + t.hours);
                  final a = students.fold<double>(0, (s, t) => s + t.amount);
                  final r = students.fold<int>(0, (s, t) => s + t.reports);
                  return [lang, '${students.length}', '$r', h.toStringAsFixed(2), 'THB ${_currency.format(a)}'];
                }).toList(),
                headerStyle: pw.TextStyle(color: _white, fontWeight: pw.FontWeight.bold, fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: _headerBg),
                cellStyle: const pw.TextStyle(fontSize: 9, color: _darkText),
                rowDecoration: const pw.BoxDecoration(color: _white),
                oddRowDecoration: const pw.BoxDecoration(color: _rowAlt),
                border: pw.TableBorder.all(color: _divider, width: 0.5),
              ),
            ];
          }

          final widgets = <pw.Widget>[];

          for (final lang in sortedLangs) {
            final taskMap = langTaskMap[lang] ?? {};
            final sortedTasks = taskMap.keys.toList()..sort();
            final langHours = taskMap.values.fold<double>(0, (s, t) => s + t.hours);
            final langAmount = taskMap.values.fold<double>(0, (s, t) => s + t.amount);
            final langEntries = taskMap.values.fold<int>(0, (s, t) => s + t.entries);
            grandHours += langHours;
            grandAmount += langAmount;
            grandEntries += langEntries;

            // Collect unique student names for this language
            final allStudentIds = taskMap.values.expand((t) => t.studentIds).toSet();

            // Budget info for this language
            String budgetSuffix = '';
            if (budgetData != null) {
              final totalBudget = (budgetData['totalBudget'] as num).toDouble();
              final allocations = budgetData['allocations'] as Map<String, dynamic>? ?? {};
              final pct = ((allocations[lang] ?? allocations[lang.trim()]) as num?)?.toDouble() ?? 0;
              final langBudget = totalBudget * (pct / 100);
              if (langBudget > 0) {
                final remaining = langBudget - langAmount;
                budgetSuffix = '   | Budget: THB ${_currency.format(langBudget)}   ${remaining < 0 ? "OVER" : "Rem: THB ${_currency.format(remaining)}"}';
              }
            }

            widgets.add(
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: const pw.BoxDecoration(
                  color: _orangeLight,
                  border: pw.Border(left: pw.BorderSide(color: _orange, width: 3)),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        lang.toUpperCase(),
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _orange),
                      ),
                    ),
                    pw.Text(
                      '${allStudentIds.length} student${allStudentIds.length == 1 ? '' : 's'}   | $langEntries entries   | ${langHours.toStringAsFixed(1)}h   | THB ${_currency.format(langAmount)}$budgetSuffix',
                      style: const pw.TextStyle(fontSize: 9, color: _grey),
                    ),
                  ],
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 4));

            widgets.add(
              pw.TableHelper.fromTextArray(
                headers: ['Task Type', 'Students', 'Entries', 'Total Hours', 'Total Amount', '% of Language Hours'],
                data: [
                  ...sortedTasks.map((task) {
                    final t = taskMap[task]!;
                    final pct = langHours > 0 ? (t.hours / langHours * 100).toStringAsFixed(1) : '0.0';
                    return [
                      t.taskType,
                      '${t.studentIds.length}',
                      '${t.entries}',
                      t.hours.toStringAsFixed(2),
                      'THB ${_currency.format(t.amount)}',
                      '$pct%',
                    ];
                  }),
                  // Subtotal
                  [
                    'SUBTOTAL -$lang',
                    '${allStudentIds.length}',
                    '$langEntries',
                    langHours.toStringAsFixed(2),
                    'THB ${_currency.format(langAmount)}',
                    '100%',
                  ],
                ],
                headerStyle: pw.TextStyle(color: _white, fontWeight: pw.FontWeight.bold, fontSize: 8),
                headerDecoration: const pw.BoxDecoration(color: _headerBg),
                cellStyle: const pw.TextStyle(fontSize: 8, color: _darkText),
                cellAlignments: {
                  1: pw.Alignment.center,
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                  5: pw.Alignment.center,
                },
                rowDecoration: const pw.BoxDecoration(color: _white),
                oddRowDecoration: const pw.BoxDecoration(color: _rowAlt),
                border: pw.TableBorder.all(color: _divider, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2.5),
                  1: const pw.FixedColumnWidth(55),
                  2: const pw.FixedColumnWidth(45),
                  3: const pw.FixedColumnWidth(70),
                  4: const pw.FixedColumnWidth(85),
                  5: const pw.FixedColumnWidth(80),
                },
              ),
            );
            widgets.add(pw.SizedBox(height: 14));
          }

          // Grand total
          widgets.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: const pw.BoxDecoration(color: _headerBg),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text('GRAND TOTAL',
                        style: pw.TextStyle(color: _white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ),
                  pw.Text(
                    '$grandEntries entries   | ${grandHours.toStringAsFixed(2)}h   | THB ${_currency.format(grandAmount)}',
                    style: pw.TextStyle(color: _white, fontWeight: pw.FontWeight.bold, fontSize: 10),
                  ),
                ],
              ),
            ),
          );

          return widgets;
        },
      ),
    );
    return doc.save();
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Map<String, _StudentTotals> _aggregateByStudent(
    List<Map<String, dynamic>> reports,
    Map<String, Map<String, dynamic>> profiles,
  ) {
    final result = <String, _StudentTotals>{};
    for (final r in reports) {
      final sid = r['studentId'] ?? '';
      final name = r['studentName'] ?? 'Unknown';
      final profile = profiles[sid] ?? {};
      final language = (profile['language'] as String?)?.trim() ?? '';
      final role = (profile['role'] as String?)?.trim() ?? '';
      final grade = (profile['grade'] as String?)?.trim() ?? '';
      final rate = (profile['hourlyRate'] as num?)?.toDouble() ??
          (r['hourlyRate'] as num?)?.toDouble() ?? 0.0;
      final hours = (r['totalHours'] as num?)?.toDouble() ?? 0.0;
      final amount = (r['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final status = r['status'] as String? ?? 'draft';

      result.putIfAbsent(
        sid,
        () => _StudentTotals(name: name, language: language, role: role, grade: grade, rate: rate),
      );
      result[sid]!.reports++;
      result[sid]!.hours += hours;
      result[sid]!.amount += amount;
      if (status == 'approved') result[sid]!.approved++;
      if (status == 'paid') result[sid]!.paid++;
    }
    return result;
  }

  String _taskTypeLabel(String raw) {
    switch (raw) {
      case 'videoEditing': return 'Video Editing';
      case 'contentCreation': return 'Content Creation';
      case 'translation': return 'Translation';
      case 'research': return 'Research';
      case 'production': return 'Production';
      case 'languageEditing': return 'Language Editing';
      default: return 'Other';
    }
  }

  pw.Widget _header(
    String title, {
    required String generatedBy,
    String? dateRange,
    String? statusFilter,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const pw.BoxDecoration(color: _orange),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'HOPE CHANNEL SOUTHEAST ASIA',
                      style: pw.TextStyle(color: _white, fontSize: 8, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      title,
                      style: pw.TextStyle(color: _white, fontSize: 13, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Generated: ${_dateFormat.format(DateTime.now())}',
                    style: const pw.TextStyle(color: _white, fontSize: 7),
                  ),
                  if (generatedBy.isNotEmpty)
                    pw.Text(
                      'By: $generatedBy',
                      style: const pw.TextStyle(color: _white, fontSize: 7),
                    ),
                  if (dateRange != null)
                    pw.Text(
                      'Period: $dateRange',
                      style: const pw.TextStyle(color: _white, fontSize: 7),
                    ),
                  if (statusFilter != null)
                    pw.Text(
                      'Status: ${statusFilter.toUpperCase()}',
                      style: const pw.TextStyle(color: _white, fontSize: 7),
                    ),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 8),
      ],
    );
  }

  pw.Widget _footer(pw.Context ctx) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Student Labour -Confidential',
          style: const pw.TextStyle(fontSize: 7, color: _grey),
        ),
        pw.Text(
          'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 7, color: _grey),
        ),
      ],
    );
  }

  pw.Widget _summaryBanner(List<pw.Widget> stats) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const pw.BoxDecoration(color: _orangeLight),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: stats,
      ),
    );
  }

  pw.Widget _bannerStat(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _orange)),
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: _grey)),
      ],
    );
  }

  pw.Widget _budgetOverviewBar(double totalPaid, Map<String, dynamic> budgetData) {
    final totalBudget = (budgetData['totalBudget'] as num).toDouble();
    final remaining = totalBudget - totalPaid;
    final pct = totalBudget > 0 ? (totalPaid / totalBudget * 100) : 0.0;
    final isOver = remaining < 0;
    final valueColor = isOver ? PdfColors.red700 : _orange;

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _orange, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        children: [
          pw.Text('BUDGET OVERVIEW  ', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _orange)),
          pw.Text('Budget: THB ${_currency.format(totalBudget)}', style: const pw.TextStyle(fontSize: 8, color: _darkText)),
          pw.Text('   |   ', style: const pw.TextStyle(fontSize: 8, color: _grey)),
          pw.Text('Paid: THB ${_currency.format(totalPaid)}', style: const pw.TextStyle(fontSize: 8, color: _darkText)),
          pw.Text('   |   ', style: const pw.TextStyle(fontSize: 8, color: _grey)),
          pw.Text(
            '${isOver ? "Over by" : "Remaining"}: THB ${_currency.format(remaining.abs())}',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: valueColor),
          ),
          pw.Text('   |   ', style: const pw.TextStyle(fontSize: 8, color: _grey)),
          pw.Text(
            'Utilization: ${pct.toStringAsFixed(1)}%',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: valueColor),
          ),
        ],
      ),
    );
  }

  pw.Widget _budgetComparisonTable(
    Map<String, double> paidByLang,
    Map<String, dynamic> budgetData,
  ) {
    final totalBudget = (budgetData['totalBudget'] as num).toDouble();
    final allocations = (budgetData['allocations'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k, (v as num).toDouble()));

    final allLangs = {...allocations.keys, ...paidByLang.keys}.toList()..sort();

    double grandBudget = 0;
    double grandPaid = 0;

    final rows = allLangs.map((lang) {
      final pct = allocations[lang] ?? 0;
      final langBudget = totalBudget * (pct / 100);
      final paid = paidByLang[lang] ?? 0;
      final variance = langBudget - paid;
      final util = langBudget > 0 ? (paid / langBudget * 100) : 0.0;
      grandBudget += langBudget;
      grandPaid += paid;
      return [
        lang,
        '${pct.toStringAsFixed(1)}%',
        'THB ${_currency.format(langBudget)}',
        'THB ${_currency.format(paid)}',
        variance < 0
            ? '-THB ${_currency.format(variance.abs())}'
            : 'THB ${_currency.format(variance)}',
        '${util.toStringAsFixed(1)}%',
      ];
    }).toList();

    final grandVariance = grandBudget - grandPaid;

    rows.add([
      'TOTAL',
      '100.0%',
      'THB ${_currency.format(grandBudget)}',
      'THB ${_currency.format(grandPaid)}',
      grandVariance < 0
          ? '-THB ${_currency.format(grandVariance.abs())}'
          : 'THB ${_currency.format(grandVariance)}',
      grandBudget > 0
          ? '${(grandPaid / grandBudget * 100).toStringAsFixed(1)}%'
          : '0.0%',
    ]);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: const pw.BoxDecoration(color: _orange),
          child: pw.Row(children: [
            pw.Text(
              'BUDGET vs ACTUAL COMPARISON',
              style: pw.TextStyle(color: _white, fontWeight: pw.FontWeight.bold, fontSize: 10),
            ),
            pw.Text(
              '   Total Budget: THB ${_currency.format(totalBudget)}',
              style: const pw.TextStyle(color: _white, fontSize: 9),
            ),
          ]),
        ),
        pw.TableHelper.fromTextArray(
          headers: ['Language', 'Alloc %', 'Budget (THB)', 'Actual Paid', 'Variance', 'Utilization'],
          data: rows,
          headerStyle: pw.TextStyle(color: _white, fontWeight: pw.FontWeight.bold, fontSize: 8),
          headerDecoration: const pw.BoxDecoration(color: _headerBg),
          cellStyle: const pw.TextStyle(fontSize: 8, color: _darkText),
          cellAlignments: {
            1: pw.Alignment.center,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
            5: pw.Alignment.center,
          },
          rowDecoration: const pw.BoxDecoration(color: _white),
          oddRowDecoration: const pw.BoxDecoration(color: _rowAlt),
          border: pw.TableBorder.all(color: _divider, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FixedColumnWidth(50),
            2: const pw.FixedColumnWidth(90),
            3: const pw.FixedColumnWidth(90),
            4: const pw.FixedColumnWidth(90),
            5: const pw.FixedColumnWidth(65),
          },
        ),
      ],
    );
  }
}
