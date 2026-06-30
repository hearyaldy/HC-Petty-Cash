import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../utils/csv_downloader.dart';

import '../../models/survey.dart';
import '../../models/survey_response.dart';
import '../../providers/survey_provider.dart';
import '../../services/ai_text_service.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/app_drawer.dart';

class AdminSurveyResponsesScreen extends StatefulWidget {
  final String surveyId;
  const AdminSurveyResponsesScreen({super.key, required this.surveyId});

  @override
  State<AdminSurveyResponsesScreen> createState() =>
      _AdminSurveyResponsesScreenState();
}

class _AdminSurveyResponsesScreenState
    extends State<AdminSurveyResponsesScreen>
    with SingleTickerProviderStateMixin {
  Survey? _survey;
  bool _loadingSurvey = true;
  late TabController _tabs;

  // Filters
  String? _countryFilter;
  DateTimeRange? _dateFilter;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  final _dateFormat = DateFormat('MMM dd, yyyy HH:mm');
  final _dateShort = DateFormat('MMM dd, yyyy');

  // AI analysis
  final _aiService = AITextService();
  bool _aiLoading = false;
  String? _aiResult;
  String? _aiError;
  int _aiResponseCount = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadSurvey();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSurvey() async {
    final s = await context.read<SurveyProvider>().getSurvey(widget.surveyId);
    if (mounted) setState(() { _survey = s; _loadingSurvey = false; });
  }

  // ── Filtering ─────────────────────────────────────────────────────────────

  List<SurveyResponse> _filter(List<SurveyResponse> all) {
    return all.where((r) {
      if (_countryFilter != null && r.country != _countryFilter) return false;
      if (_dateFilter != null) {
        if (r.submittedAt.isBefore(_dateFilter!.start)) return false;
        if (r.submittedAt.isAfter(_dateFilter!.end.add(const Duration(days: 1)))) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = (r.respondentName ?? '').toLowerCase();
        final country = (r.country ?? '').toLowerCase();
        final answers = r.answers.map((a) => a.displayValue.toLowerCase()).join(' ');
        if (!name.contains(q) && !country.contains(q) && !answers.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  Set<String> _countries(List<SurveyResponse> all) =>
      all.map((r) => r.country ?? '').where((c) => c.isNotEmpty).toSet();

  // ── CSV export ────────────────────────────────────────────────────────────

  Future<void> _exportCsv(List<SurveyResponse> responses) async {
    if (_survey == null || responses.isEmpty) return;
    final allQuestions = _survey!.sections.expand((s) => s.questions).toList();

    final rows = <List<String>>[];

    // Header
    rows.add([
      'Respondent Name', 'Country', 'Submitted At',
      ...allQuestions.map((q) => '${q.code}: ${q.text}'),
    ]);

    // Data rows
    for (final r in responses) {
      rows.add([
        r.respondentName ?? 'Anonymous',
        r.country ?? '',
        _dateFormat.format(r.submittedAt),
        ...allQuestions.map((q) {
          final a = r.answerFor(q.id);
          return a?.displayValue ?? '';
        }),
      ]);
    }

    // Build CSV
    final csv = rows.map((row) =>
      row.map((cell) {
        final escaped = cell.replaceAll('"', '""');
        return '"$escaped"';
      }).join(',')
    ).join('\n');

    final filename = 'survey_${_survey!.code}_responses_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
    downloadCsvFile(csv, filename);
  }

  // ── AI analysis ───────────────────────────────────────────────────────────

  Future<void> _runAiAnalysis(List<SurveyResponse> responses) async {
    if (_survey == null || responses.isEmpty) return;
    setState(() { _aiLoading = true; _aiResult = null; _aiError = null; });

    final result = await _aiService.analyzeSurveyResponses(
      survey: _survey!,
      responses: responses,
    );

    if (mounted) {
      setState(() {
        _aiLoading = false;
        _aiResponseCount = responses.length;
        if (result.success) {
          _aiResult = result.text;
        } else {
          _aiError = result.error ?? 'Analysis failed';
        }
      });
    }
  }

  // ── AI export actions ─────────────────────────────────────────────────────

  Future<void> _copyAnalysis() async {
    if (_aiResult == null) return;
    await Clipboard.setData(ClipboardData(text: _aiResult!));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Analysis copied to clipboard'), backgroundColor: Colors.teal, behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _downloadAnalysis() async {
    if (_aiResult == null || _survey == null) return;
    final header =
        '# Survey ${_survey!.code} — AI Analysis\n'
        '# ${_survey!.title}\n\n'
        'Generated: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}\n'
        'Responses analysed: $_aiResponseCount\n\n'
        '---\n\n';
    final content = header + _aiResult!;
    final filename = 'Survey_${_survey!.code}_AI_Analysis_${DateFormat('yyyyMMdd').format(DateTime.now())}.txt';
    downloadTextFile(content, filename);
  }

  Future<void> _printAnalysis() async {
    if (_aiResult == null || _survey == null) return;
    final doc = pw.Document();
    final lines = _aiResult!.split('\n');

    pw.TextStyle bold(double size, {PdfColor color = PdfColors.black}) =>
        pw.TextStyle(fontSize: size, fontWeight: pw.FontWeight.bold, color: color);

    final bodyWidgets = <pw.Widget>[];
    for (final raw in lines) {
      final line = raw.trim();
      if (line.startsWith('## ')) {
        bodyWidgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 14, bottom: 4),
          child: pw.Text(line.substring(3), style: bold(13, color: PdfColors.indigo900)),
        ));
      } else if (line.startsWith('### ')) {
        bodyWidgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8, bottom: 3),
          child: pw.Text(line.substring(4), style: bold(11.5, color: PdfColors.teal800)),
        ));
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        final text = line.substring(2).replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'\1');
        bodyWidgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(left: 12, bottom: 3),
          child: pw.Text('• $text', style: const pw.TextStyle(fontSize: 11)),
        ));
      } else if (line.isNotEmpty) {
        final text = line.replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'\1').replaceAll(RegExp(r'\*(.+?)\*'), r'\1');
        bodyWidgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Text(text, style: const pw.TextStyle(fontSize: 11)),
        ));
      } else {
        bodyWidgets.add(pw.SizedBox(height: 4));
      }
    }

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (ctx) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColors.teal700,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('AI Analysis Report', style: bold(18, color: PdfColors.white)),
              pw.SizedBox(height: 4),
              pw.Text('${_survey!.code}: ${_survey!.title}', style: pw.TextStyle(fontSize: 13, color: PdfColor(1, 1, 1, 0.75))),
              pw.SizedBox(height: 2),
              pw.Text(
                'Generated: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())} · $_aiResponseCount responses',
                style: pw.TextStyle(fontSize: 10, color: PdfColor(1, 1, 1, 0.75)),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 20),
        ...bodyWidgets,
      ],
    ));

    await Printing.layoutPdf(
      onLayout: (format) => doc.save(),
      name: 'Survey_${_survey!.code}_AI_Analysis.pdf',
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loadingSurvey) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_survey == null) return const Scaffold(body: Center(child: Text('Survey not found')));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildTopBar(context),
      drawer: const AppDrawer(),
      body: StreamBuilder<List<SurveyResponse>>(
        stream: context.read<SurveyProvider>().watchResponses(widget.surveyId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
              const SizedBox(height: 12),
              Text('Failed to load responses', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(snapshot.error.toString(), style: TextStyle(color: Colors.grey.shade600, fontSize: 12), textAlign: TextAlign.center),
            ]));
          }

          final all = snapshot.data ?? [];
          final filtered = _filter(all);
          final countries = _countries(all);
          final loading = snapshot.connectionState == ConnectionState.waiting;

          return Column(
            children: [
              // ── Unified header panel ────────────────────────────────────
              Material(
                elevation: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsBar(all, filtered),
                    _buildFilters(all, countries),
                    _buildTabBar(),
                  ],
                ),
              ),
              // ── Tab content ─────────────────────────────────────────────
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabs,
                        children: [
                          _buildSummaryTab(filtered),
                          _buildIndividualTab(filtered),
                          _buildAiTab(filtered),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildTopBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxWidth = ResponsiveHelper.getMaxContentWidth(context);
    final hPad = ResponsiveHelper.getScreenPadding(context).horizontal / 2;

    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: BoxDecoration(
          color: cs.primary,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: kToolbarHeight,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: Row(
                    children: [
                      Builder(builder: (ctx) => IconButton(icon: const Icon(Icons.menu, color: Colors.white), onPressed: () => Scaffold.of(ctx).openDrawer())),
                      const SizedBox(width: 4),
                      Container(width: 28, height: 28, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(6)), child: const Center(child: Text('HC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10)))),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Survey ${_survey!.code} — Responses', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                            Text('MI Surveys', style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 10)),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20), onPressed: () => context.pop()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Stats bar ─────────────────────────────────────────────────────────────

  Widget _buildStatsBar(List<SurveyResponse> all, List<SurveyResponse> filtered) {
    final countries = _countries(all);
    String? dateRange;
    if (all.isNotEmpty) {
      final dates = all.map((r) => r.submittedAt).toList()..sort();
      dateRange = '${_dateShort.format(dates.first)} – ${_dateShort.format(dates.last)}';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.teal.shade700, Colors.cyan.shade500], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Row(
        children: [
          _statChip(Icons.people_outline, '${filtered.length}${all.length != filtered.length ? '/${all.length}' : ''} responses'),
          const SizedBox(width: 12),
          _statChip(Icons.public, '${countries.length} countries'),
          if (dateRange != null) ...[
            const SizedBox(width: 12),
            _statChip(Icons.calendar_today_outlined, dateRange),
          ],
          const Spacer(),
          StreamBuilder<List<SurveyResponse>>(
            stream: context.read<SurveyProvider>().watchResponses(widget.surveyId),
            builder: (_, snap) {
              final responses = _filter(snap.data ?? []);
              return OutlinedButton.icon(
                onPressed: responses.isEmpty ? null : () => _exportCsv(responses),
                icon: const Icon(Icons.download_outlined, size: 15, color: Colors.white),
                label: const Text('Export CSV', style: TextStyle(color: Colors.white, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _aiActionBtn(IconData icon, String tooltip, VoidCallback onTap) => Tooltip(
    message: tooltip,
    child: IconButton(
      icon: Icon(icon, size: 18, color: Colors.indigo.shade600),
      onPressed: onTap,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: const EdgeInsets.all(4),
    ),
  );

  Widget _statChip(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: Colors.white70),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
    ],
  );

  // ── Filters ───────────────────────────────────────────────────────────────

  Widget _buildFilters(List<SurveyResponse> all, Set<String> countries) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search by name, country, or answer...',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); })
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            ),
          ),
          if (countries.isNotEmpty || _dateFilter != null) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Country chips
                  _filterChip('All', _countryFilter == null, () => setState(() => _countryFilter = null)),
                  ...countries.map((c) => _filterChip(c, _countryFilter == c, () => setState(() => _countryFilter = c))),
                  const SizedBox(width: 8),
                  // Date range
                  ActionChip(
                    avatar: Icon(Icons.date_range, size: 14, color: _dateFilter != null ? Colors.teal.shade700 : Colors.grey.shade600),
                    label: Text(
                      _dateFilter != null ? '${_dateShort.format(_dateFilter!.start)} – ${_dateShort.format(_dateFilter!.end)}' : 'Date range',
                      style: TextStyle(fontSize: 12, color: _dateFilter != null ? Colors.teal.shade700 : Colors.grey.shade600),
                    ),
                    backgroundColor: _dateFilter != null ? Colors.teal.shade50 : null,
                    onPressed: () async {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                        initialDateRange: _dateFilter,
                        builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: Colors.teal)), child: child!),
                      );
                      if (range != null) setState(() => _dateFilter = range);
                    },
                  ),
                  if (_dateFilter != null) ...[
                    const SizedBox(width: 4),
                    ActionChip(
                      label: const Text('Clear date', style: TextStyle(fontSize: 12)),
                      onPressed: () => setState(() => _dateFilter = null),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: Colors.teal.shade100,
      checkmarkColor: Colors.teal.shade700,
      visualDensity: VisualDensity.compact,
    ),
  );

  // ── Tab bar ───────────────────────────────────────────────────────────────

  Widget _buildTabBar() => Container(
    color: Colors.white,
    child: TabBar(
      controller: _tabs,
      tabs: const [
        Tab(icon: Icon(Icons.bar_chart, size: 16), text: 'Summary'),
        Tab(icon: Icon(Icons.list_alt, size: 16), text: 'Individual'),
        Tab(icon: Icon(Icons.auto_awesome, size: 16), text: 'AI Analysis'),
      ],
      labelColor: Colors.teal.shade700,
      unselectedLabelColor: Colors.grey.shade600,
      indicatorColor: Colors.teal.shade600,
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );

  // ── Summary tab ───────────────────────────────────────────────────────────

  Widget _buildSummaryTab(List<SurveyResponse> responses) {
    if (responses.isEmpty) return _buildEmpty();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section-grouped analysis
              ..._survey!.sections.expand((section) => [
                _sectionHeader(section.title),
                const SizedBox(height: 8),
                ...section.questions.map((q) {
                  final answered = responses.where((r) => r.answerFor(q.id) != null).toList();
                  if (answered.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildQuestionChart(q, answered),
                  );
                }),
                const SizedBox(height: 8),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.teal.shade50,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.teal.shade200),
    ),
    child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal.shade800)),
  );

  Widget _buildQuestionChart(SurveyQuestion q, List<SurveyResponse> responses) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: _typeColor(q.type).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(q.code, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _typeColor(q.type))),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(q.text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
              Text('${responses.length} answered', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ]),
            const SizedBox(height: 12),
            switch (q.type) {
              QuestionType.singleChoice || QuestionType.multipleChoice => _buildBarChart(q, responses),
              QuestionType.yesNo => _buildYesNoChart(responses, q),
              QuestionType.scale => _buildScaleChart(q, responses),
              QuestionType.openText => _buildOpenTextSample(responses, q),
            },
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(SurveyQuestion q, List<SurveyResponse> responses) {
    final counts = <String, int>{};
    for (final r in responses) {
      final answer = r.answerFor(q.id)?.value;
      if (answer == null) continue;
      if (answer is List) {
        for (final v in answer) { counts[v.toString()] = (counts[v.toString()] ?? 0) + 1; }
      } else {
        final k = answer.toString();
        counts[k] = (counts[k] ?? 0) + 1;
      }
    }

    // Ensure all options appear even if 0 responses
    final options = q.options.isNotEmpty ? q.options : counts.keys.toList();
    final sorted = options.map((opt) => MapEntry(opt, counts[opt] ?? 0)).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxCount = sorted.isEmpty ? 1 : sorted.first.value;
    final colors = [
      Colors.teal.shade400, Colors.cyan.shade400, Colors.blue.shade400,
      Colors.indigo.shade400, Colors.purple.shade400, Colors.pink.shade400,
    ];

    return Column(
      children: sorted.asMap().entries.map((entry) {
        final i = entry.key;
        final e = entry.value;
        final pct = maxCount > 0 ? e.value / maxCount : 0.0;
        final totalPct = responses.isNotEmpty ? e.value / responses.length : 0.0;
        final color = colors[i % colors.length];

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 160,
                child: Text(e.key, style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Stack(
                  children: [
                    Container(height: 22, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4))),
                    FractionallySizedBox(
                      widthFactor: pct,
                      child: Container(
                        height: 22,
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 70,
                child: Text(
                  '${e.value} (${(totalPct * 100).toStringAsFixed(0)}%)',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildYesNoChart(List<SurveyResponse> responses, SurveyQuestion q) {
    final counts = <String, int>{'Yes': 0, 'No': 0, 'Not Sure': 0};
    for (final r in responses) {
      final v = r.answerFor(q.id)?.value?.toString();
      if (v != null && counts.containsKey(v)) counts[v] = counts[v]! + 1;
    }
    final total = responses.length;
    final colors = {'Yes': Colors.teal.shade400, 'No': Colors.red.shade400, 'Not Sure': Colors.orange.shade400};

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: counts.entries.map((e) {
        final pct = total > 0 ? e.value / total : 0.0;
        final color = colors[e.key] ?? Colors.grey;
        return Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 72, height: 72,
                  child: CircularProgressIndicator(
                    value: pct,
                    strokeWidth: 7,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                Text('${(pct * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
            const SizedBox(height: 6),
            Text(e.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            Text('${e.value}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildScaleChart(SurveyQuestion q, List<SurveyResponse> responses) {
    final values = responses.map((r) => r.answerFor(q.id)?.value).whereType<int>().toList();
    if (values.isEmpty) return const SizedBox.shrink();

    final avg = values.reduce((a, b) => a + b) / values.length;
    final min = q.scaleMin ?? 1;
    final max = q.scaleMax ?? 5;

    // Distribution
    final counts = <int, int>{};
    for (int i = min; i <= max; i++) { counts[i] = 0; }
    for (final v in values) { counts[v] = (counts[v] ?? 0) + 1; }
    final maxCount = counts.values.isEmpty ? 1 : counts.values.reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Average display
        Row(
          children: [
            Text(avg.toStringAsFixed(1), style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.teal.shade700, height: 1)),
            const SizedBox(width: 6),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('/ $max', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
              Text('avg (${values.length})', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            ]),
            const SizedBox(width: 16),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: max > min ? (avg - min) / (max - min) : 0,
                  minHeight: 10,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(Colors.teal.shade400),
                ),
              ),
            ),
            if (q.scaleMinLabel != null || q.scaleMaxLabel != null) ...[
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (q.scaleMaxLabel != null) Text(q.scaleMaxLabel!, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                if (q.scaleMinLabel != null) Text(q.scaleMinLabel!, style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
              ]),
            ],
          ],
        ),
        const SizedBox(height: 12),
        // Distribution bars
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: counts.entries.map((e) {
            final barPct = maxCount > 0 ? e.value / maxCount : 0.0;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  children: [
                    Text('${e.value}', style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
                    const SizedBox(height: 2),
                    Container(
                      height: 40 * barPct + 4,
                      decoration: BoxDecoration(
                        color: Colors.teal.shade300.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text('${e.key}', style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildOpenTextSample(List<SurveyResponse> responses, SurveyQuestion q) {
    final answers = responses
        .map((r) => r.answerFor(q.id)?.value?.toString())
        .where((v) => v != null && v.isNotEmpty)
        .take(5)
        .toList();

    if (answers.isEmpty) return Text('No text answers yet.', style: TextStyle(color: Colors.grey.shade400, fontStyle: FontStyle.italic, fontSize: 12));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sample responses (${answers.length} of ${responses.length}):', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        ...answers.map((a) => Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border(left: BorderSide(color: Colors.teal.shade200, width: 3)),
          ),
          child: Text(a!, style: const TextStyle(fontSize: 12, height: 1.5), maxLines: 4, overflow: TextOverflow.ellipsis),
        )),
      ],
    );
  }

  // ── Individual tab ────────────────────────────────────────────────────────

  Widget _buildIndividualTab(List<SurveyResponse> responses) {
    if (responses.isEmpty) return _buildEmpty();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: responses.length,
      itemBuilder: (context, index) => _buildResponseTile(index + 1, responses[index]),
    );
  }

  Widget _buildResponseTile(int index, SurveyResponse response) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        leading: CircleAvatar(
          radius: 14,
          backgroundColor: Colors.teal.shade100,
          child: Text('$index', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal.shade700)),
        ),
        title: Text(response.respondentName ?? 'Anonymous', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${response.country ?? 'Unknown'} · ${_dateFormat.format(response.submittedAt)}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${response.answers.length} answers', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
              tooltip: 'Delete response',
              onPressed: () => _deleteResponse(response.id),
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        children: _survey!.sections
            .expand((s) => s.questions)
            .map((q) {
              final answer = response.answerFor(q.id);
              if (answer == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(color: _typeColor(q.type).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text(q.code, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _typeColor(q.type))),
                      ),
                      const SizedBox(width: 6),
                      Expanded(child: Text(q.text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                    ]),
                    const SizedBox(height: 3),
                    Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Text(answer.displayValue, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    ),
                    const Divider(height: 12),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }

  Future<void> _deleteResponse(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Response'),
        content: const Text('Permanently delete this response?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<SurveyProvider>().deleteResponse(id);
  }

  // ── AI Analysis tab ───────────────────────────────────────────────────────

  Widget _buildAiTab(List<SurveyResponse> responses) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.indigo.shade700, Colors.purple.shade500], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('AI Analysis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text(
                            'Powered by Gemini · Analyzes ${responses.length} filtered response${responses.length == 1 ? '' : 's'}',
                            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: (responses.isEmpty || _aiLoading) ? null : () => _runAiAnalysis(responses),
                      icon: _aiLoading
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.indigo))
                          : const Icon(Icons.play_arrow_rounded, size: 16),
                      label: Text(_aiLoading ? 'Analyzing...' : _aiResult != null ? 'Re-analyze' : 'Analyze'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.indigo.shade700, textStyle: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              if (responses.isEmpty)
                _buildEmpty()
              else if (_aiLoading)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: Colors.indigo.shade400),
                        const SizedBox(height: 16),
                        Text('Analyzing ${responses.length} responses...', style: TextStyle(color: Colors.grey.shade600)),
                        const SizedBox(height: 8),
                        Text('This may take a few seconds', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                      ],
                    ),
                  ),
                )
              else if (_aiError != null)
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.error_outline, size: 40, color: Colors.red.shade400),
                        const SizedBox(height: 12),
                        Text('Analysis failed', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red.shade700)),
                        const SizedBox(height: 4),
                        Text(_aiError!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: () => _runAiAnalysis(responses), child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              else if (_aiResult != null)
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Result header with actions ──────────────────────
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          border: Border(bottom: BorderSide(color: Colors.indigo.shade100)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.insights, size: 16, color: Colors.indigo.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Analysis Results', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.indigo.shade700, fontSize: 14)),
                                  Text(
                                    '$_aiResponseCount responses · ${DateFormat('MMM dd, HH:mm').format(DateTime.now())}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                            // Action buttons
                            _aiActionBtn(Icons.copy_outlined, 'Copy', _copyAnalysis),
                            _aiActionBtn(Icons.download_outlined, 'Download', _downloadAnalysis),
                            _aiActionBtn(Icons.print_outlined, 'Print / Save PDF', _printAnalysis),
                          ],
                        ),
                      ),
                      // ── Markdown content ────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: MarkdownBody(
                          data: _aiResult!,
                          styleSheet: MarkdownStyleSheet(
                            h2: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.indigo.shade800, height: 2),
                            h3: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal.shade700, height: 1.8),
                            p: const TextStyle(fontSize: 13, height: 1.6),
                            listBullet: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                            strong: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      // ── Bottom action bar ───────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                          border: Border(top: BorderSide(color: Colors.grey.shade200)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _copyAnalysis,
                              icon: const Icon(Icons.copy_outlined, size: 14),
                              label: const Text('Copy', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.grey.shade700, side: BorderSide(color: Colors.grey.shade300), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), minimumSize: Size.zero),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _downloadAnalysis,
                              icon: const Icon(Icons.download_outlined, size: 14),
                              label: const Text('Download .txt', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.indigo.shade700, side: BorderSide(color: Colors.indigo.shade200), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), minimumSize: Size.zero),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _printAnalysis,
                              icon: const Icon(Icons.print_outlined, size: 14),
                              label: const Text('Print / PDF', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), minimumSize: Size.zero, textStyle: const TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.auto_awesome, size: 48, color: Colors.indigo.shade200),
                          const SizedBox(height: 12),
                          const Text('Click "Analyze" to generate AI insights', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text('Gemini will analyze patterns, summarize findings,\nand recommend content strategies.',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Empty ─────────────────────────────────────────────────────────────────

  Widget _buildEmpty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No responses found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
          const SizedBox(height: 6),
          Text('Try adjusting the filters above', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ],
      ),
    ),
  );

  // ── Helpers ───────────────────────────────────────────────────────────────

  Color _typeColor(QuestionType t) => switch (t) {
        QuestionType.singleChoice => Colors.blue,
        QuestionType.multipleChoice => Colors.purple,
        QuestionType.scale => Colors.orange,
        QuestionType.openText => Colors.green,
        QuestionType.yesNo => Colors.teal,
      };
}
