import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/enums.dart';
import '../../models/media_period_report.dart';
import '../../models/media_yearly_stats.dart';
import '../../providers/auth_provider.dart';
import '../../services/media_period_report_service.dart';
import '../../services/media_yearly_stats_service.dart';
import '../../utils/responsive_helper.dart';

class MediaPeriodReportsScreen extends StatefulWidget {
  const MediaPeriodReportsScreen({super.key});

  @override
  State<MediaPeriodReportsScreen> createState() =>
      _MediaPeriodReportsScreenState();
}

class _MediaPeriodReportsScreenState extends State<MediaPeriodReportsScreen> {
  final _service = MediaPeriodReportService();
  final _yearlyService = MediaYearlyStatsService();
  final _uuid = const Uuid();
  final _dateFormat = DateFormat('MMM dd, yyyy');

  int _selectedYear = DateTime.now().year;
  String _selectedLanguage = 'all';
  String _selectedPlatform = 'all';
  String _pageName = '';
  final TextEditingController _pageFilterController = TextEditingController();

  bool _isLoading = true;
  List<MediaPeriodReport> _reports = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadReports();
    });
  }

  @override
  void dispose() {
    _pageFilterController.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final reports = await _service.listReports(
        year: _selectedYear,
        language: _selectedLanguage == 'all' ? null : _selectedLanguage,
        platform: _selectedPlatform == 'all' ? null : _selectedPlatform,
        pageName: _pageName.trim(),
      );
      if (!mounted) return;
      setState(() => _reports = reports);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load reports: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showReportForm({MediaPeriodReport? report}) async {
    final isEdit = report != null;

    String periodType = report?.periodType ?? 'monthly';
    int selectedYear = report?.periodStart.year ?? _selectedYear;
    int selectedMonth = report?.periodStart.month ?? DateTime.now().month;
    int selectedQuarter = ((selectedMonth - 1) ~/ 3) + 1;
    DateTime customStart = report?.periodStart ?? DateTime.now();
    DateTime customEnd = report?.periodEnd ?? DateTime.now();

    String language = report?.language ?? _selectedLanguage;
    String platform = report?.platform ?? _selectedPlatform;
    final pageNameController = TextEditingController(
      text: report?.pageName ?? _pageName,
    );

    final controllers = <String, TextEditingController>{
      'resultTotalFollower': TextEditingController(
        text: report?.resultTotalFollower?.toString() ?? '',
      ),
      'resultNetFollowerGain': TextEditingController(
        text: report?.resultNetFollowerGain?.toString() ?? '',
      ),
      'resultView': TextEditingController(
        text: report?.resultView?.toString() ?? '',
      ),
      'resultViewers': TextEditingController(
        text: report?.resultViewers?.toString() ?? '',
      ),
      'resultContentInteraction': TextEditingController(
        text: report?.resultContentInteraction?.toString() ?? '',
      ),
      'resultLinkClick': TextEditingController(
        text: report?.resultLinkClick?.toString() ?? '',
      ),
      'resultVisit': TextEditingController(
        text: report?.resultVisit?.toString() ?? '',
      ),
      'resultFollow': TextEditingController(
        text: report?.resultFollow?.toString() ?? '',
      ),
      'audienceFollow': TextEditingController(
        text: report?.audienceFollow?.toString() ?? '',
      ),
      'audienceReturningViewers': TextEditingController(
        text: report?.audienceReturningViewers?.toString() ?? '',
      ),
      'audienceEngageFollower': TextEditingController(
        text: report?.audienceEngageFollower?.toString() ?? '',
      ),
      'contentOverviewView': TextEditingController(
        text: report?.contentOverviewView?.toString() ?? '',
      ),
      'contentOverviewThreeSecondView': TextEditingController(
        text: report?.contentOverviewThreeSecondView?.toString() ?? '',
      ),
      'contentOverviewOneMinuteView': TextEditingController(
        text: report?.contentOverviewOneMinuteView?.toString() ?? '',
      ),
      'contentOverviewContentInteraction': TextEditingController(
        text: report?.contentOverviewContentInteraction?.toString() ?? '',
      ),
      'contentOverviewWatchTime': TextEditingController(
        text: report?.contentOverviewWatchTime?.toString() ?? '',
      ),
      'viewBreakdownTotal': TextEditingController(
        text: report?.viewBreakdownTotal?.toString() ?? '',
      ),
      'viewBreakdownFromOrganic': TextEditingController(
        text: report?.viewBreakdownFromOrganic?.toString() ?? '',
      ),
      'viewBreakdownFromFollower': TextEditingController(
        text: report?.viewBreakdownFromFollower?.toString() ?? '',
      ),
      'viewBreakdownViewers': TextEditingController(
        text: report?.viewBreakdownViewers?.toString() ?? '',
      ),
      'contentReach': TextEditingController(
        text: report?.contentReach?.toString() ?? '',
      ),
      'contentWatchTime': TextEditingController(
        text: report?.contentWatchTime?.toString() ?? '',
      ),
      'contentVideoAverage': TextEditingController(
        text: report?.contentVideoAverage?.toStringAsFixed(2) ?? '',
      ),
      'contentLikeReaction': TextEditingController(
        text: report?.contentLikeReaction?.toString() ?? '',
      ),
      'contentViewers': TextEditingController(
        text: report?.contentViewers?.toString() ?? '',
      ),
    };

    int? toInt(String v) => _parseHumanNumber(v.trim());
    int? toDurationHours(String v) => _parseDurationHours(v.trim());
    double? toDouble(String v) => double.tryParse(v.trim());

    DateTime computeStart() {
      if (periodType == 'monthly') {
        return DateTime(selectedYear, selectedMonth, 1);
      }
      if (periodType == 'quarterly') {
        final month = (selectedQuarter - 1) * 3 + 1;
        return DateTime(selectedYear, month, 1);
      }
      return customStart;
    }

    DateTime computeEnd() {
      if (periodType == 'monthly') {
        return DateTime(selectedYear, selectedMonth + 1, 0, 23, 59, 59);
      }
      if (periodType == 'quarterly') {
        final month = (selectedQuarter - 1) * 3 + 3;
        return DateTime(selectedYear, month + 1, 0, 23, 59, 59);
      }
      return customEnd;
    }

    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) => Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            isEdit ? 'Edit Report' : 'New Report',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(sheetContext).pop(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Form(
                      key: formKey,
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildSectionTitle('Period'),
                          DropdownButtonFormField<String>(
                            initialValue: periodType,
                            decoration: const InputDecoration(
                              labelText: 'Period Type',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'monthly',
                                child: Text('Monthly'),
                              ),
                              DropdownMenuItem(
                                value: 'quarterly',
                                child: Text('Quarterly'),
                              ),
                              DropdownMenuItem(
                                value: 'custom',
                                child: Text('Custom Range'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setSheetState(() => periodType = value);
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: selectedYear,
                                  decoration: const InputDecoration(
                                    labelText: 'Year',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: List.generate(6, (index) {
                                    final year = DateTime.now().year - index;
                                    return DropdownMenuItem(
                                      value: year,
                                      child: Text(year.toString()),
                                    );
                                  }),
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setSheetState(() => selectedYear = value);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (periodType == 'monthly')
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    initialValue: selectedMonth,
                                    decoration: const InputDecoration(
                                      labelText: 'Month',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: List.generate(12, (index) {
                                      final month = index + 1;
                                      return DropdownMenuItem(
                                        value: month,
                                        child: Text(
                                          DateFormat.MMMM().format(
                                            DateTime(2020, month, 1),
                                          ),
                                        ),
                                      );
                                    }),
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setSheetState(
                                        () => selectedMonth = value,
                                      );
                                    },
                                  ),
                                ),
                              if (periodType == 'quarterly')
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    initialValue: selectedQuarter,
                                    decoration: const InputDecoration(
                                      labelText: 'Quarter',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 1,
                                        child: Text('Q1'),
                                      ),
                                      DropdownMenuItem(
                                        value: 2,
                                        child: Text('Q2'),
                                      ),
                                      DropdownMenuItem(
                                        value: 3,
                                        child: Text('Q3'),
                                      ),
                                      DropdownMenuItem(
                                        value: 4,
                                        child: Text('Q4'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setSheetState(
                                        () => selectedQuarter = value,
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                          if (periodType == 'custom') ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _datePickerField(
                                    sheetContext,
                                    label: 'Start Date',
                                    value: customStart,
                                    onPick: (date) =>
                                        setSheetState(() => customStart = date),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _datePickerField(
                                    sheetContext,
                                    label: 'End Date',
                                    value: customEnd,
                                    onPick: (date) =>
                                        setSheetState(() => customEnd = date),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                          _buildSectionTitle('Target'),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: language,
                                  decoration: const InputDecoration(
                                    labelText: 'Language',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: MediaLanguage.values.map((lang) {
                                    return DropdownMenuItem(
                                      value: lang.code,
                                      child: Text(lang.displayName),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setSheetState(() => language = value);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: platform,
                                  decoration: const InputDecoration(
                                    labelText: 'Platform',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'youtube',
                                      child: Text('YouTube'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'facebook',
                                      child: Text('Facebook'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'instagram',
                                      child: Text('Instagram'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'tiktok',
                                      child: Text('TikTok'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setSheetState(() => platform = value);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: pageNameController,
                            decoration: const InputDecoration(
                              labelText: 'Page Name',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Page name is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildSectionTitle('Metrics'),
                          ..._metricFields(controllers),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (!formKey.currentState!.validate()) return;
                                final authProvider = sheetContext
                                    .read<AuthProvider>();
                                final user = authProvider.currentUser!;

                                final start = computeStart();
                                final end = computeEnd();

                                final newReport = MediaPeriodReport(
                                  id: report?.id ?? _uuid.v4(),
                                  periodType: periodType,
                                  periodStart: start,
                                  periodEnd: end,
                                  language: language,
                                  platform: platform,
                                  pageName: pageNameController.text.trim(),
                                  resultTotalFollower: toInt(
                                    controllers['resultTotalFollower']!.text,
                                  ),
                                  resultNetFollowerGain: toInt(
                                    controllers['resultNetFollowerGain']!.text,
                                  ),
                                  resultView: toInt(
                                    controllers['resultView']!.text,
                                  ),
                                  resultViewers: toInt(
                                    controllers['resultViewers']!.text,
                                  ),
                                  resultContentInteraction: toInt(
                                    controllers['resultContentInteraction']!
                                        .text,
                                  ),
                                  resultLinkClick: toInt(
                                    controllers['resultLinkClick']!.text,
                                  ),
                                  resultVisit: toInt(
                                    controllers['resultVisit']!.text,
                                  ),
                                  resultFollow: toInt(
                                    controllers['resultFollow']!.text,
                                  ),
                                  audienceFollow: toInt(
                                    controllers['audienceFollow']!.text,
                                  ),
                                  audienceReturningViewers: toInt(
                                    controllers['audienceReturningViewers']!
                                        .text,
                                  ),
                                  audienceEngageFollower: toInt(
                                    controllers['audienceEngageFollower']!.text,
                                  ),
                                  contentOverviewView: toInt(
                                    controllers['contentOverviewView']!.text,
                                  ),
                                  contentOverviewThreeSecondView: toInt(
                                    controllers['contentOverviewThreeSecondView']!
                                        .text,
                                  ),
                                  contentOverviewOneMinuteView: toInt(
                                    controllers['contentOverviewOneMinuteView']!
                                        .text,
                                  ),
                                  contentOverviewContentInteraction: toInt(
                                    controllers['contentOverviewContentInteraction']!
                                        .text,
                                  ),
                                  contentOverviewWatchTime: toDurationHours(
                                    controllers['contentOverviewWatchTime']!
                                        .text,
                                  ),
                                  viewBreakdownTotal: toInt(
                                    controllers['viewBreakdownTotal']!.text,
                                  ),
                                  viewBreakdownFromOrganic: toInt(
                                    controllers['viewBreakdownFromOrganic']!
                                        .text,
                                  ),
                                  viewBreakdownFromFollower: toInt(
                                    controllers['viewBreakdownFromFollower']!
                                        .text,
                                  ),
                                  viewBreakdownViewers: toInt(
                                    controllers['viewBreakdownViewers']!.text,
                                  ),
                                  contentReach: toInt(
                                    controllers['contentReach']!.text,
                                  ),
                                  contentWatchTime: toDurationHours(
                                    controllers['contentWatchTime']!.text,
                                  ),
                                  contentVideoAverage: toDouble(
                                    controllers['contentVideoAverage']!.text,
                                  ),
                                  contentLikeReaction: toInt(
                                    controllers['contentLikeReaction']!.text,
                                  ),
                                  contentViewers: toInt(
                                    controllers['contentViewers']!.text,
                                  ),
                                  createdById: user.id,
                                  createdByName: user.name,
                                  createdAt:
                                      report?.createdAt ?? DateTime.now(),
                                  updatedAt: DateTime.now(),
                                );

                                try {
                                  if (isEdit) {
                                    await _service.updateReport(newReport);
                                  } else {
                                    await _service.createReport(newReport);
                                  }
                                  if (!mounted) return;
                                  Navigator.of(sheetContext).pop();

                                  // Update filters to match the saved report
                                  setState(() {
                                    _selectedLanguage = language;
                                    _selectedPlatform = platform;
                                    _pageName = pageNameController.text.trim();
                                    _pageFilterController.text =
                                        pageNameController.text.trim();
                                    _selectedYear = computeStart().year;
                                  });
                                  await _loadReports();
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Save failed: $e')),
                                  );
                                }
                              },
                              child: Text(
                                isEdit ? 'Update Report' : 'Create Report',
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    pageNameController.dispose();
    for (final controller in controllers.values) {
      controller.dispose();
    }
  }

  List<Widget> _metricFields(Map<String, TextEditingController> controllers) {
    Widget field(
      String label,
      String key, {
      bool decimal = false,
      TextInputType? keyboardType,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controllers[key],
          keyboardType:
              keyboardType ??
              (decimal
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.number),
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      );
    }

    return [
      _buildSectionTitle('Result'),
      field('Total Follower', 'resultTotalFollower'),
      field('Net Follower Gain', 'resultNetFollowerGain'),
      field('View', 'resultView'),
      field('Viewers', 'resultViewers'),
      field('Content Interaction', 'resultContentInteraction'),
      field('Link Click', 'resultLinkClick'),
      field('Visit', 'resultVisit'),
      field('Follow', 'resultFollow'),
      _buildSectionTitle('Audience'),
      field('Follow', 'audienceFollow'),
      field('Returning Viewers', 'audienceReturningViewers'),
      field('Engage Follower', 'audienceEngageFollower'),
      _buildSectionTitle('Content Overview'),
      field('View', 'contentOverviewView'),
      field('3 Second View', 'contentOverviewThreeSecondView'),
      field('1 Minutes View', 'contentOverviewOneMinuteView'),
      field('Content Interaction', 'contentOverviewContentInteraction'),
      field(
        'Watch Time (days, hours)',
        'contentOverviewWatchTime',
        keyboardType: TextInputType.text,
      ),
      _buildSectionTitle('View Breakdown'),
      field('Total', 'viewBreakdownTotal'),
      field('From Organic', 'viewBreakdownFromOrganic'),
      field('From Follower', 'viewBreakdownFromFollower'),
      field('Viewers', 'viewBreakdownViewers'),
      _buildSectionTitle('Content'),
      field('Reach', 'contentReach'),
      field(
        'Watch Time (days, hours)',
        'contentWatchTime',
        keyboardType: TextInputType.text,
      ),
      field('Video Average', 'contentVideoAverage', decimal: true),
      field('Like and Reaction', 'contentLikeReaction'),
      field('Viewers', 'contentViewers'),
    ];
  }

  Future<void> _generateYearlyReport() async {
    if (_reports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No reports to aggregate for this year.')),
      );
      return;
    }

    int sumInt(int? value) => value ?? 0;
    double sumDouble(double? value) => value ?? 0.0;

    final resultTotalFollower = _reports.fold<int>(
      0,
      (sum, r) => sum + sumInt(r.resultTotalFollower),
    );
    final resultNetFollowerGain = _reports.fold<int>(
      0,
      (sum, r) => sum + sumInt(r.resultNetFollowerGain),
    );
    final resultView = _reports.fold<int>(
      0,
      (sum, r) => sum + sumInt(r.resultView),
    );
    final resultViewers = _reports.fold<int>(
      0,
      (sum, r) => sum + sumInt(r.resultViewers),
    );
    final resultContentInteraction = _reports.fold<int>(
      0,
      (sum, r) => sum + sumInt(r.resultContentInteraction),
    );
    final resultLinkClick = _reports.fold<int>(
      0,
      (sum, r) => sum + sumInt(r.resultLinkClick),
    );
    final resultVisit = _reports.fold<int>(
      0,
      (sum, r) => sum + sumInt(r.resultVisit),
    );
    final resultFollow = _reports.fold<int>(
      0,
      (sum, r) => sum + sumInt(r.resultFollow),
    );

    final audienceFollow = _reports.fold<int>(
      0,
      (sum, r) => sum + sumInt(r.audienceFollow),
    );
    final audienceReturningViewers = _reports.fold<int>(
      0,
      (sum, r) => sum + sumInt(r.audienceReturningViewers),
    );
    final audienceEngageFollower = _reports.fold<int>(
      0,
      (sum, r) => sum + sumInt(r.audienceEngageFollower),
    );

    final contentOverviewView = _reports.fold<int>(
      0,
      (sum, r) => sum + sumInt(r.contentOverviewView),
    );
    final contentOverviewThreeSecondView = _reports.fold<int>(
      0,
      (sum, r) => sum + sumInt(r.contentOverviewThreeSecondView),
    );
    final contentOverviewOneMinuteView = _reports.fold<int>(
      0,
      (sum, r) => sum + sumInt(r.contentOverviewOneMinuteView),
    );
    final contentOverviewContentInteraction = _reports.fold<int>(
      0,
      (sum, r) => sum + sumInt(r.contentOverviewContentInteraction),
    );
    final contentOverviewWatchTime = _reports.fold<int>(
      0,
      (sum, r) => sum + sumInt(r.contentOverviewWatchTime),
    );

    final viewBreakdownTotal = _reports.fold<int>(
      0,
      (sum, r) => sum + sumInt(r.viewBreakdownTotal),
    );
    final viewBreakdownFromOrganic = _reports.fold<int>(
      0,
      (sum, r) => sum + sumInt(r.viewBreakdownFromOrganic),
    );
    final viewBreakdownFromFollower = _reports.fold<int>(
      0,
      (sum, r) => sum + sumInt(r.viewBreakdownFromFollower),
    );
    final viewBreakdownViewers = _reports.fold<int>(
      0,
      (sum, r) => sum + sumInt(r.viewBreakdownViewers),
    );

    final contentReach = _reports.fold<int>(
      0,
      (sum, r) => sum + sumInt(r.contentReach),
    );
    final contentWatchTime = _reports.fold<int>(
      0,
      (sum, r) => sum + sumInt(r.contentWatchTime),
    );
    final contentVideoAverage = _reports.fold<double>(
      0,
      (sum, r) => sum + sumDouble(r.contentVideoAverage),
    );
    final contentLikeReaction = _reports.fold<int>(
      0,
      (sum, r) => sum + sumInt(r.contentLikeReaction),
    );
    final contentViewers = _reports.fold<int>(
      0,
      (sum, r) => sum + sumInt(r.contentViewers),
    );

    final platformStats = <String, Map<String, num>>{};
    for (final report in _reports) {
      final platform = report.platform;
      platformStats.putIfAbsent(platform, () => {});
      void addNum(String key, int? value) {
        if (value == null) return;
        platformStats[platform]![key] =
            (platformStats[platform]![key] ?? 0) + value;
      }

      addNum('resultView', report.resultView);
      addNum('resultViewers', report.resultViewers);
      addNum('contentReach', report.contentReach);
      addNum('contentWatchTime', report.contentWatchTime);
      addNum('contentLikeReaction', report.contentLikeReaction);
    }

    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser!;

    final yearly = MediaYearlyStats(
      id: '${_selectedYear}_$_selectedLanguage',
      year: _selectedYear,
      title: 'Aggregated $_selectedYear Report',
      notes: 'Generated from period reports',
      language: _selectedLanguage,
      platform: _selectedPlatform,
      pageName: _pageName.trim(),
      resultTotalFollower: resultTotalFollower,
      resultNetFollowerGain: resultNetFollowerGain,
      resultView: resultView,
      resultViewers: resultViewers,
      resultContentInteraction: resultContentInteraction,
      resultLinkClick: resultLinkClick,
      resultVisit: resultVisit,
      resultFollow: resultFollow,
      audienceFollow: audienceFollow,
      audienceReturningViewers: audienceReturningViewers,
      audienceEngageFollower: audienceEngageFollower,
      contentOverviewView: contentOverviewView,
      contentOverviewThreeSecondView: contentOverviewThreeSecondView,
      contentOverviewOneMinuteView: contentOverviewOneMinuteView,
      contentOverviewContentInteraction: contentOverviewContentInteraction,
      contentOverviewWatchTime: contentOverviewWatchTime,
      viewBreakdownTotal: viewBreakdownTotal,
      viewBreakdownFromOrganic: viewBreakdownFromOrganic,
      viewBreakdownFromFollower: viewBreakdownFromFollower,
      viewBreakdownViewers: viewBreakdownViewers,
      contentReach: contentReach,
      contentWatchTime: contentWatchTime,
      contentVideoAverage: contentVideoAverage,
      contentLikeReaction: contentLikeReaction,
      contentViewers: contentViewers,
      platformStats: platformStats,
      createdById: user.id,
      createdByName: user.name,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _yearlyService.saveStats(yearly);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Yearly report generated successfully.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showReportForm(),
        backgroundColor: Colors.pink,
        icon: const Icon(Icons.add),
        label: const Text('New Report'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadReports,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ResponsiveContainer(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          _buildHeaderBanner(),
                          const SizedBox(height: 16),
                          _buildFilters(),
                          const SizedBox(height: 16),
                          _buildStatisticsSummary(),
                          const SizedBox(height: 16),
                          if (_reports.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'No reports found for this selection.',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ),
                            )
                          else
                            ..._reports.map(_buildReportCard),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.pink.shade400,
            Colors.pink.shade600,
            Colors.pink.shade800,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.shade300,
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            right: 50,
            bottom: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildHeaderActionButton(
                      icon: Icons.arrow_back,
                      tooltip: 'Back to Dashboard',
                      onPressed: () => context.go('/media-dashboard'),
                    ),
                    Row(
                      children: [
                        _buildHeaderActionButton(
                          icon: Icons.summarize,
                          tooltip: 'Generate Yearly Report',
                          onPressed: _isLoading ? () {} : _generateYearlyReport,
                        ),
                        const SizedBox(width: 8),
                        _buildHeaderActionButton(
                          icon: Icons.refresh,
                          tooltip: 'Refresh',
                          onPressed: _isLoading ? () {} : _loadReports,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Social Media Reports',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  offset: const Offset(1, 1),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Monthly, quarterly & custom period reports',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.calendar_month,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ResponsiveBuilder(
              mobile: Column(
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: _selectedYear,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(6, (index) {
                      final year = DateTime.now().year - index;
                      return DropdownMenuItem(
                        value: year,
                        child: Text(year.toString()),
                      );
                    }),
                    onChanged: (value) async {
                      if (value == null) return;
                      setState(() => _selectedYear = value);
                      await _loadReports();
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedLanguage,
                    decoration: const InputDecoration(
                      labelText: 'Language',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('All Languages'),
                      ),
                      ...MediaLanguage.values.map((lang) {
                        return DropdownMenuItem(
                          value: lang.code,
                          child: Text(lang.displayName),
                        );
                      }),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      setState(() => _selectedLanguage = value);
                      await _loadReports();
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedPlatform,
                    decoration: const InputDecoration(
                      labelText: 'Platform',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('All Platforms'),
                      ),
                      DropdownMenuItem(
                        value: 'youtube',
                        child: Text('YouTube'),
                      ),
                      DropdownMenuItem(
                        value: 'facebook',
                        child: Text('Facebook'),
                      ),
                      DropdownMenuItem(
                        value: 'instagram',
                        child: Text('Instagram'),
                      ),
                      DropdownMenuItem(value: 'tiktok', child: Text('TikTok')),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      setState(() => _selectedPlatform = value);
                      await _loadReports();
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pageFilterController,
                    decoration: const InputDecoration(
                      labelText: 'Page Name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => _pageName = value,
                    onFieldSubmitted: (_) => _loadReports(),
                  ),
                ],
              ),
              tablet: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _selectedYear,
                          decoration: const InputDecoration(
                            labelText: 'Year',
                            border: OutlineInputBorder(),
                          ),
                          items: List.generate(6, (index) {
                            final year = DateTime.now().year - index;
                            return DropdownMenuItem(
                              value: year,
                              child: Text(year.toString()),
                            );
                          }),
                          onChanged: (value) async {
                            if (value == null) return;
                            setState(() => _selectedYear = value);
                            await _loadReports();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedLanguage,
                          decoration: const InputDecoration(
                            labelText: 'Language',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'all',
                              child: Text('All Languages'),
                            ),
                            ...MediaLanguage.values.map((lang) {
                              return DropdownMenuItem(
                                value: lang.code,
                                child: Text(lang.displayName),
                              );
                            }),
                          ],
                          onChanged: (value) async {
                            if (value == null) return;
                            setState(() => _selectedLanguage = value);
                            await _loadReports();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedPlatform,
                          decoration: const InputDecoration(
                            labelText: 'Platform',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('All Platforms'),
                            ),
                            DropdownMenuItem(
                              value: 'youtube',
                              child: Text('YouTube'),
                            ),
                            DropdownMenuItem(
                              value: 'facebook',
                              child: Text('Facebook'),
                            ),
                            DropdownMenuItem(
                              value: 'instagram',
                              child: Text('Instagram'),
                            ),
                            DropdownMenuItem(
                              value: 'tiktok',
                              child: Text('TikTok'),
                            ),
                          ],
                          onChanged: (value) async {
                            if (value == null) return;
                            setState(() => _selectedPlatform = value);
                            await _loadReports();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _pageFilterController,
                          decoration: const InputDecoration(
                            labelText: 'Page Name',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) => _pageName = value,
                          onFieldSubmitted: (_) => _loadReports(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsSummary() {
    // Calculate aggregated statistics from all loaded reports
    int totalFollowers = 0;
    int totalViews = 0;
    int totalEngagement = 0;
    int totalReach = 0;
    int totalWatchTime = 0;

    for (final report in _reports) {
      totalFollowers += report.resultTotalFollower ?? 0;
      totalViews += report.resultView ?? 0;
      totalEngagement +=
          (report.resultContentInteraction ?? 0) +
          (report.contentLikeReaction ?? 0);
      totalReach += report.contentReach ?? 0;
      totalWatchTime += report.contentWatchTime ?? 0;
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.pink.shade600),
                const SizedBox(width: 8),
                Text(
                  'Statistics Summary (${_reports.length} reports)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                _buildStatItem(
                  'Total Followers',
                  _formatNumber(totalFollowers),
                  Icons.people,
                  Colors.blue,
                ),
                _buildStatItem(
                  'Total Views',
                  _formatNumber(totalViews),
                  Icons.visibility,
                  Colors.green,
                ),
                _buildStatItem(
                  'Total Engagement',
                  _formatNumber(totalEngagement),
                  Icons.thumb_up,
                  Colors.orange,
                ),
                _buildStatItem(
                  'Total Reach',
                  _formatNumber(totalReach),
                  Icons.public,
                  Colors.purple,
                ),
                _buildStatItem(
                  'Watch Time',
                  _formatDuration(totalWatchTime),
                  Icons.timer,
                  Colors.teal,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return NumberFormat('#,###').format(number);
  }

  int? _parseHumanNumber(String value) {
    if (value.isEmpty) return null;
    final normalized = value.replaceAll(',', '').toLowerCase();
    final match = RegExp(
      r'^([0-9]*\.?[0-9]+)\s*([km]?)$',
    ).firstMatch(normalized);
    if (match == null) {
      return int.tryParse(normalized);
    }
    final number = double.tryParse(match.group(1) ?? '');
    if (number == null) return null;
    final suffix = match.group(2);
    final multiplier = suffix == 'k'
        ? 1000
        : suffix == 'm'
        ? 1000000
        : 1;
    return (number * multiplier).round();
  }

  int? _parseDurationHours(String value) {
    if (value.isEmpty) return null;
    final normalized = value.toLowerCase().replaceAll(',', '');
    final matches = RegExp(
      r'([0-9]*\.?[0-9]+)\s*([dh])',
    ).allMatches(normalized);
    if (matches.isNotEmpty) {
      double hours = 0;
      for (final match in matches) {
        final number = double.tryParse(match.group(1) ?? '');
        final unit = match.group(2);
        if (number == null) continue;
        if (unit == 'd') {
          hours += number * 24;
        } else {
          hours += number;
        }
      }
      return hours.round();
    }
    final asNumber = double.tryParse(normalized);
    if (asNumber == null) return null;
    return asNumber.round();
  }

  String _formatDuration(int hours) {
    if (hours <= 0) return '0h';
    final days = hours ~/ 24;
    final remainder = hours % 24;
    if (days == 0) return '${remainder}h';
    if (remainder == 0) return '${days}d';
    return '${days}d ${remainder}h';
  }

  Widget _buildReportCard(MediaPeriodReport report) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${report.periodType.toUpperCase()} • ${report.pageName}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_dateFormat.format(report.periodStart)} - ${_dateFormat.format(report.periodEnd)}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      await _showReportForm(report: report);
                    } else if (value == 'delete') {
                      await _confirmDelete(report);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildReportMetric(
                  'Followers',
                  report.resultTotalFollower,
                  Icons.people,
                ),
                _buildReportMetric(
                  'Views',
                  report.resultView,
                  Icons.visibility,
                ),
                _buildReportMetric(
                  'Engagement',
                  report.resultContentInteraction,
                  Icons.thumb_up,
                ),
                _buildReportMetric('Reach', report.contentReach, Icons.public),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportMetric(String label, int? value, IconData icon) {
    final displayValue = value != null ? _formatNumber(value) : '-';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        Text(
          displayValue,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(MediaPeriodReport report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Report'),
        content: const Text('Are you sure you want to delete this report?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.deleteReport(report.id);
    await _loadReports();
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _datePickerField(
    BuildContext context, {
    required String label,
    required DateTime value,
    required ValueChanged<DateTime> onPick,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          onPick(DateTime(picked.year, picked.month, picked.day));
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(_dateFormat.format(value)),
      ),
    );
  }
}
