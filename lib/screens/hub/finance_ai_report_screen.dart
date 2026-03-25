import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:convert';
import '../../utils/constants.dart';
import '../../utils/responsive_helper.dart';

class FinanceAiReportScreen extends StatefulWidget {
  const FinanceAiReportScreen({super.key});

  @override
  State<FinanceAiReportScreen> createState() => _FinanceAiReportScreenState();
}

class _FinanceAiReportScreenState extends State<FinanceAiReportScreen> {
  final Set<_AiReportScope> _aiReportScopes = {
    _AiReportScope.transactions,
    _AiReportScope.pettyCashReports,
  };
  _AiReportRange _aiReportRange = _AiReportRange.month;
  _AiReportPreset _aiReportPreset = _AiReportPreset.thisMonth;
  DateTime? _aiCustomStart;
  DateTime? _aiCustomEnd;
  bool _aiReportLoading = false;
  String? _aiReportError;
  List<_TrendPoint> _aiTrendPoints = [];
  Map<String, double> _aiCategoryTotals = {};
  _CashFlowSummary _aiCashFlow = const _CashFlowSummary(0, 0, 0);
  String _aiSummaryText = 'Select filters and generate a report.';
  String _aiDetailText = 'No analysis generated yet.';
  String _aiFeedbackText = 'No AI feedback generated yet.';
  bool _aiFeedbackLoading = false;
  String? _aiFeedbackError;
  String? _aiFeedbackDebug;

  @override
  void initState() {
    super.initState();
    _applyPreset(_aiReportPreset);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                _buildHeaderBanner(context),
                const SizedBox(height: 24),
                _buildAiReportCard(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBanner(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade400,
            Colors.blue.shade600,
            Colors.blue.shade800,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade300,
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
                      tooltip: 'Back to Finance Hub',
                      onPressed: () => context.go('/finance-dashboard'),
                    ),
                    _buildHeaderActionButton(
                      icon: Icons.refresh,
                      tooltip: 'Reset Filters',
                      onPressed: () {
                        setState(() {
                          _aiReportScopes
                            ..clear()
                            ..addAll({
                              _AiReportScope.transactions,
                              _AiReportScope.pettyCashReports,
                            });
                          _aiReportPreset = _AiReportPreset.thisMonth;
                          _aiReportRange = _AiReportRange.month;
                          _aiReportError = null;
                          _aiSummaryText =
                              'Select filters and generate a report.';
                          _aiTrendPoints = [];
                          _aiCategoryTotals = {};
                          _aiCashFlow = const _CashFlowSummary(0, 0, 0);
                          _aiDetailText = 'No analysis generated yet.';
                          _aiFeedbackText = 'No AI feedback generated yet.';
                          _aiFeedbackError = null;
                          _aiFeedbackDebug = null;
                          _applyPreset(_aiReportPreset);
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.auto_graph,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Finance Analysis',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Insights by month, quarter, year, or custom range',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                            ),
                          ),
                        ],
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _buildAiReportCard() {
    final rangeLabel = _formatRangeLabel();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.auto_graph,
                  color: Colors.indigo.shade600,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Finance Analysis',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton.icon(
                onPressed: _aiReportLoading ? null : _generateAiReport,
                icon: _aiReportLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow, size: 18),
                label: const Text('Generate'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildScopeChip('Transactions', _AiReportScope.transactions),
              _buildScopeChip('Petty Cash', _AiReportScope.pettyCashReports),
              _buildScopeChip('Project', _AiReportScope.projectReports),
              _buildScopeChip('Income', _AiReportScope.incomeReports),
              _buildScopeChip('Travel', _AiReportScope.travelReports),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<_AiReportRange>(
                  initialValue: _aiReportRange,
                  decoration: const InputDecoration(
                    labelText: 'Report Range',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _AiReportRange.values
                      .map(
                        (range) => DropdownMenuItem(
                          value: range,
                          child: Text(range.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _aiReportRange = value;
                      _aiReportPreset = _AiReportPreset.none;
                      _aiReportError = null;
                    });
                    _applyRangeDefault();
                  },
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _pickRange,
                icon: const Icon(Icons.date_range),
                label: const Text('Pick'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPresetChip('This Month', _AiReportPreset.thisMonth),
              _buildPresetChip('Last Month', _AiReportPreset.lastMonth),
              _buildPresetChip('YTD', _AiReportPreset.ytd),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            rangeLabel,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          if (_aiReportError != null) ...[
            const SizedBox(height: 8),
            Text(
              _aiReportError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          _buildChartSection(
            title: 'Trend Line',
            child: _buildTrendChart(_aiTrendPoints),
          ),
          const SizedBox(height: 16),
          _buildChartSection(
            title: 'Category Breakdown',
            child: _buildCategoryChart(_aiCategoryTotals),
          ),
          const SizedBox(height: 16),
          _buildChartSection(
            title: 'Cash Flow',
            child: _buildCashFlowChart(_aiCashFlow),
          ),
          const SizedBox(height: 12),
          SelectableText(
            _aiSummaryText,
            style: TextStyle(fontSize: 13, color: Colors.grey[800]),
          ),
          const SizedBox(height: 16),
          _buildChartSection(
            title: 'Text Report',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: _aiDetailText.trim().isEmpty
                        ? null
                        : () async {
                            await Clipboard.setData(
                              ClipboardData(text: _aiDetailText),
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Report copied to clipboard'),
                              ),
                            );
                          },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy'),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: SelectableText(
                    _aiDetailText,
                    style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildChartSection(
            title: 'AI Feedback',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _aiFeedbackLoading ? null : _requestAiFeedback,
                    icon: _aiFeedbackLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('Generate Feedback'),
                  ),
                ),
                if (_aiFeedbackError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _aiFeedbackError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
                if (_aiFeedbackDebug != null) ...[
                  const SizedBox(height: 6),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      'Debug Details',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: SelectableText(
                          _aiFeedbackDebug!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: MarkdownBody(
                    data: _aiFeedbackText,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(fontSize: 13, color: Colors.grey[800]),
                      h2: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[900],
                      ),
                      listBullet: TextStyle(fontSize: 13, color: Colors.grey[800]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeChip(String label, _AiReportScope scope) {
    final isSelected = _aiReportScopes.contains(scope);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _aiReportScopes.add(scope);
          } else {
            _aiReportScopes.remove(scope);
          }
        });
      },
      selectedColor: Colors.indigo.shade600,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[700],
      ),
    );
  }

  Widget _buildPresetChip(String label, _AiReportPreset preset) {
    final isSelected = _aiReportPreset == preset;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _applyPreset(preset),
      selectedColor: Colors.indigo.shade600,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[700],
      ),
    );
  }

  Widget _buildChartSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildTrendChart(List<_TrendPoint> points) {
    if (points.isEmpty) {
      return _buildEmptyChart();
    }
    return SizedBox(
      height: 160,
      child: CustomPaint(
        painter: _TrendLinePainter(points),
        child: Container(),
      ),
    );
  }

  Widget _buildCategoryChart(Map<String, double> data) {
    if (data.isEmpty) {
      return _buildEmptyChart();
    }
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).toList();
    final maxValue = top.first.value;

    return Column(
      children: top.map((entry) {
        final ratio = maxValue == 0 ? 0.0 : entry.value / maxValue;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  entry.key,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: ratio,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade400,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                NumberFormat.compactCurrency(
                  symbol: AppConstants.currencySymbol,
                ).format(entry.value),
                style: TextStyle(fontSize: 11, color: Colors.grey[700]),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCashFlowChart(_CashFlowSummary cashFlow) {
    final maxValue = [
      cashFlow.opening,
      cashFlow.disbursed,
      cashFlow.closing,
    ].fold<double>(0, (max, v) => v > max ? v : max);
    if (maxValue == 0) {
      return _buildEmptyChart();
    }

    Widget buildBar(String label, double value, Color color) {
      final ratio = maxValue == 0 ? 0.0 : value / maxValue;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(label, style: const TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Stack(
                children: [
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: ratio,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              NumberFormat.compactCurrency(
                symbol: AppConstants.currencySymbol,
              ).format(value),
              style: TextStyle(fontSize: 11, color: Colors.grey[700]),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        buildBar('Opening', cashFlow.opening, Colors.blue.shade400),
        buildBar('Disbursed', cashFlow.disbursed, Colors.red.shade400),
        buildBar('Closing', cashFlow.closing, Colors.green.shade500),
      ],
    );
  }

  Widget _buildEmptyChart() {
    return Container(
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        'No data for the selected range',
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
    );
  }

  String _formatRangeLabel() {
    final range = _resolveRange();
    final format = DateFormat('MMM d, y');
    return 'Range: ${format.format(range.start)} - ${format.format(range.end)}';
  }

  void _applyPreset(_AiReportPreset preset) {
    setState(() {
      _aiReportPreset = preset;
      _aiReportError = null;
    });

    final now = DateTime.now();
    if (preset == _AiReportPreset.thisMonth) {
      _aiReportRange = _AiReportRange.month;
      _aiCustomStart = DateTime(now.year, now.month, 1);
      _aiCustomEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    } else if (preset == _AiReportPreset.lastMonth) {
      final lastMonth = DateTime(now.year, now.month - 1, 1);
      _aiReportRange = _AiReportRange.month;
      _aiCustomStart = lastMonth;
      _aiCustomEnd = DateTime(
        lastMonth.year,
        lastMonth.month + 1,
        0,
        23,
        59,
        59,
      );
    } else if (preset == _AiReportPreset.ytd) {
      _aiReportRange = _AiReportRange.year;
      _aiCustomStart = DateTime(now.year, 1, 1);
      _aiCustomEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    }
  }

  void _applyRangeDefault() {
    final now = DateTime.now();
    if (_aiReportRange == _AiReportRange.month) {
      _aiCustomStart = DateTime(now.year, now.month, 1);
      _aiCustomEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    } else if (_aiReportRange == _AiReportRange.quarter) {
      final quarter = ((now.month - 1) ~/ 3) + 1;
      final startMonth = (quarter - 1) * 3 + 1;
      _aiCustomStart = DateTime(now.year, startMonth, 1);
      _aiCustomEnd = DateTime(now.year, startMonth + 3, 0, 23, 59, 59);
    } else if (_aiReportRange == _AiReportRange.year) {
      _aiCustomStart = DateTime(now.year, 1, 1);
      _aiCustomEnd = DateTime(now.year, 12, 31, 23, 59, 59);
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    if (_aiReportRange == _AiReportRange.custom) {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 5, 1, 1),
        lastDate: DateTime(now.year + 1, 12, 31),
        initialDateRange: _aiCustomStart != null && _aiCustomEnd != null
            ? DateTimeRange(start: _aiCustomStart!, end: _aiCustomEnd!)
            : null,
      );
      if (range != null) {
        setState(() {
          _aiCustomStart = DateTime(
            range.start.year,
            range.start.month,
            range.start.day,
          );
          _aiCustomEnd = DateTime(
            range.end.year,
            range.end.month,
            range.end.day,
            23,
            59,
            59,
          );
          _aiReportPreset = _AiReportPreset.none;
        });
      }
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: _aiCustomStart ?? now,
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null) return;

    setState(() {
      _aiReportPreset = _AiReportPreset.none;
      if (_aiReportRange == _AiReportRange.month) {
        _aiCustomStart = DateTime(picked.year, picked.month, 1);
        _aiCustomEnd = DateTime(picked.year, picked.month + 1, 0, 23, 59, 59);
      } else if (_aiReportRange == _AiReportRange.quarter) {
        final quarter = ((picked.month - 1) ~/ 3) + 1;
        final startMonth = (quarter - 1) * 3 + 1;
        _aiCustomStart = DateTime(picked.year, startMonth, 1);
        _aiCustomEnd = DateTime(picked.year, startMonth + 3, 0, 23, 59, 59);
      } else if (_aiReportRange == _AiReportRange.year) {
        _aiCustomStart = DateTime(picked.year, 1, 1);
        _aiCustomEnd = DateTime(picked.year, 12, 31, 23, 59, 59);
      }
    });
  }

  _AiDateRange _resolveRange() {
    final now = DateTime.now();
    final start = _aiCustomStart ?? DateTime(now.year, now.month, 1);
    final end =
        _aiCustomEnd ?? DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    return _AiDateRange(start, end);
  }

  Future<void> _generateAiReport() async {
    if (_aiReportScopes.isEmpty) {
      setState(() {
        _aiReportError = 'Select at least one data source.';
      });
      return;
    }

    setState(() {
      _aiReportLoading = true;
      _aiReportError = null;
    });

    try {
      final range = _resolveRange();
      final firestore = FirebaseFirestore.instance;
      final startTs = Timestamp.fromDate(range.start);
      final endTs = Timestamp.fromDate(range.end);

      final trendTotals = <DateTime, double>{};
      final categoryTotals = <String, double>{};

      double cashOpening = 0;
      double cashDisbursed = 0;
      double cashClosing = 0;

      double totalInflow = 0;
      double totalOutflow = 0;
      int totalItems = 0;
      final scopeCounts = <_AiReportScope, int>{};

      if (_aiReportScopes.contains(_AiReportScope.transactions)) {
        final snapshot = await firestore
            .collection('transactions')
            .where('date', isGreaterThanOrEqualTo: startTs)
            .where('date', isLessThanOrEqualTo: endTs)
            .get();
        scopeCounts[_AiReportScope.transactions] = snapshot.docs.length;
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final amount = (data['amount'] ?? 0).toDouble();
          final timestamp = data['date'] as Timestamp?;
          final date = timestamp?.toDate() ?? range.start;
          _accumulateTrend(trendTotals, date, amount, range);

          final category =
              (data['customCategory'] as String?)?.trim().isNotEmpty == true
              ? data['customCategory'] as String
              : (data['category'] as String?) ?? 'Other';
          categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
          totalOutflow += amount;
          totalItems += 1;
        }
      }

      if (_aiReportScopes.contains(_AiReportScope.pettyCashReports)) {
        final snapshot = await firestore
            .collection('reports')
            .where('createdAt', isGreaterThanOrEqualTo: startTs)
            .where('createdAt', isLessThanOrEqualTo: endTs)
            .get();
        scopeCounts[_AiReportScope.pettyCashReports] = snapshot.docs.length;
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final opening = (data['openingBalance'] ?? 0).toDouble();
          final disbursed = (data['totalDisbursements'] ?? 0).toDouble();
          final closing = (data['closingBalance'] ?? 0).toDouble();
          final date =
              (data['createdAt'] as Timestamp?)?.toDate() ?? range.start;
          _accumulateTrend(trendTotals, date, disbursed, range);

          cashOpening += opening;
          cashDisbursed += disbursed;
          cashClosing += closing;
          totalOutflow += disbursed;
          totalInflow += opening;
          totalItems += 1;
        }
      }

      if (_aiReportScopes.contains(_AiReportScope.projectReports)) {
        final snapshot = await firestore
            .collection('project_reports')
            .where('createdAt', isGreaterThanOrEqualTo: startTs)
            .where('createdAt', isLessThanOrEqualTo: endTs)
            .get();
        scopeCounts[_AiReportScope.projectReports] = snapshot.docs.length;
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final expenses = (data['totalExpenses'] ?? 0).toDouble();
          final date =
              (data['createdAt'] as Timestamp?)?.toDate() ?? range.start;
          _accumulateTrend(trendTotals, date, expenses, range);
          totalOutflow += expenses;
          totalItems += 1;
        }
      }

      if (_aiReportScopes.contains(_AiReportScope.incomeReports)) {
        final snapshot = await firestore
            .collection('income_reports')
            .where('createdAt', isGreaterThanOrEqualTo: startTs)
            .where('createdAt', isLessThanOrEqualTo: endTs)
            .get();
        scopeCounts[_AiReportScope.incomeReports] = snapshot.docs.length;
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final totalIncome = (data['totalIncome'] ?? 0).toDouble();
          final date =
              (data['createdAt'] as Timestamp?)?.toDate() ?? range.start;
          _accumulateTrend(trendTotals, date, totalIncome, range);
          totalInflow += totalIncome;
          totalItems += 1;
        }
      }

      if (_aiReportScopes.contains(_AiReportScope.travelReports)) {
        final snapshot = await firestore
            .collection('traveling_reports')
            .where('createdAt', isGreaterThanOrEqualTo: startTs)
            .where('createdAt', isLessThanOrEqualTo: endTs)
            .get();
        scopeCounts[_AiReportScope.travelReports] = snapshot.docs.length;
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final mileage = (data['mileageAmount'] ?? 0).toDouble();
          final date =
              (data['createdAt'] as Timestamp?)?.toDate() ?? range.start;
          _accumulateTrend(trendTotals, date, mileage, range);
          totalOutflow += mileage;
          totalItems += 1;
        }
      }

      final trendPoints = _buildTrendPoints(trendTotals);
      final summary = _buildSummaryText(
        totalInflow: totalInflow,
        totalOutflow: totalOutflow,
        totalItems: totalItems,
        categoryTotals: categoryTotals,
        range: range,
      );
      final detail = _buildDetailText(
        totalInflow: totalInflow,
        totalOutflow: totalOutflow,
        totalItems: totalItems,
        cashFlow: _CashFlowSummary(cashOpening, cashDisbursed, cashClosing),
        categoryTotals: categoryTotals,
        trendPoints: trendPoints,
        scopeCounts: scopeCounts,
        range: range,
      );

      setState(() {
        _aiTrendPoints = trendPoints;
        _aiCategoryTotals = categoryTotals;
        _aiCashFlow = _CashFlowSummary(cashOpening, cashDisbursed, cashClosing);
        _aiSummaryText = summary;
        _aiDetailText = detail;
      });

      await _requestAiFeedback(
        payload: _buildAiPayload(
          range: range,
          trendPoints: trendPoints,
          categoryTotals: categoryTotals,
          cashFlow: _CashFlowSummary(cashOpening, cashDisbursed, cashClosing),
          summary: summary,
          detail: detail,
          scopeCounts: scopeCounts,
          totalInflow: totalInflow,
          totalOutflow: totalOutflow,
        ),
      );
    } catch (e) {
      setState(() {
        _aiReportError = 'Failed to generate report: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _aiReportLoading = false;
        });
      }
    }
  }

  void _accumulateTrend(
    Map<DateTime, double> trendTotals,
    DateTime date,
    double amount,
    _AiDateRange range,
  ) {
    final spanDays = range.end.difference(range.start).inDays;
    final bucket = spanDays <= 40
        ? DateTime(date.year, date.month, date.day)
        : DateTime(date.year, date.month);
    trendTotals[bucket] = (trendTotals[bucket] ?? 0) + amount;
  }

  List<_TrendPoint> _buildTrendPoints(Map<DateTime, double> totals) {
    if (totals.isEmpty) return [];
    final entries = totals.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final spanDays = entries.last.key.difference(entries.first.key).inDays;
    final format = spanDays <= 40
        ? DateFormat('MMM d')
        : DateFormat('MMM yyyy');
    return entries
        .map((e) => _TrendPoint(format.format(e.key), e.value))
        .toList();
  }

  String _buildSummaryText({
    required double totalInflow,
    required double totalOutflow,
    required int totalItems,
    required Map<String, double> categoryTotals,
    required _AiDateRange range,
  }) {
    final format = NumberFormat.compactCurrency(
      symbol: AppConstants.currencySymbol,
    );
    final net = totalInflow - totalOutflow;
    String topCategory = 'N/A';
    if (categoryTotals.isNotEmpty) {
      final top = categoryTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      topCategory = top.first.key;
    }
    return 'Analyzed $totalItems records from '
        '${DateFormat('MMM d, y').format(range.start)} to '
        '${DateFormat('MMM d, y').format(range.end)}. '
        'Inflow ${format.format(totalInflow)}, '
        'Outflow ${format.format(totalOutflow)}, '
        'Net ${format.format(net)}. '
        'Top category: $topCategory.';
  }

  String _buildDetailText({
    required double totalInflow,
    required double totalOutflow,
    required int totalItems,
    required _CashFlowSummary cashFlow,
    required Map<String, double> categoryTotals,
    required List<_TrendPoint> trendPoints,
    required Map<_AiReportScope, int> scopeCounts,
    required _AiDateRange range,
  }) {
    final currency = NumberFormat.currency(symbol: AppConstants.currencySymbol);
    final compact = NumberFormat.compactCurrency(
      symbol: AppConstants.currencySymbol,
    );
    final net = totalInflow - totalOutflow;
    final scopeLines = _aiReportScopes
        .map((scope) {
          final count = scopeCounts[scope] ?? 0;
          return '- ${scope.label}: $count records';
        })
        .join('\n');

    String topCategory = 'N/A';
    double topCategoryValue = 0;
    if (categoryTotals.isNotEmpty) {
      final top = categoryTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      topCategory = top.first.key;
      topCategoryValue = top.first.value;
    }

    String peakTrend = 'N/A';
    if (trendPoints.isNotEmpty) {
      final top = trendPoints.reduce((a, b) => a.value >= b.value ? a : b);
      peakTrend = '${top.label} (${compact.format(top.value)})';
    }

    return 'Data coverage:\n'
        '$scopeLines\n\n'
        'Period: ${DateFormat('MMM d, y').format(range.start)} - '
        '${DateFormat('MMM d, y').format(range.end)}\n'
        'Total records: $totalItems\n'
        'Inflow: ${currency.format(totalInflow)}\n'
        'Outflow: ${currency.format(totalOutflow)}\n'
        'Net: ${currency.format(net)}\n\n'
        'Cash flow summary (from petty cash reports):\n'
        '- Opening: ${currency.format(cashFlow.opening)}\n'
        '- Disbursed: ${currency.format(cashFlow.disbursed)}\n'
        '- Closing: ${currency.format(cashFlow.closing)}\n\n'
        'Category highlight: $topCategory '
        '(${currency.format(topCategoryValue)})\n'
        'Peak period: $peakTrend';
  }

  Map<String, dynamic> _buildAiPayload({
    required _AiDateRange range,
    required List<_TrendPoint> trendPoints,
    required Map<String, double> categoryTotals,
    required _CashFlowSummary cashFlow,
    required String summary,
    required String detail,
    required Map<_AiReportScope, int> scopeCounts,
    required double totalInflow,
    required double totalOutflow,
  }) {
    return {
      'range': {
        'start': range.start.toIso8601String(),
        'end': range.end.toIso8601String(),
      },
      'totals': {
        'inflow': totalInflow,
        'outflow': totalOutflow,
        'net': totalInflow - totalOutflow,
      },
      'cashFlow': {
        'opening': cashFlow.opening,
        'disbursed': cashFlow.disbursed,
        'closing': cashFlow.closing,
      },
      'scopes': {
        for (final scope in _aiReportScopes)
          scope.label: scopeCounts[scope] ?? 0,
      },
      'trend': [
        for (final p in trendPoints) {'label': p.label, 'value': p.value},
      ],
      'categories': categoryTotals,
      'summary': summary,
      'detail': detail,
    };
  }

  Future<void> _requestAiFeedback({Map<String, dynamic>? payload}) async {
    setState(() {
      _aiFeedbackLoading = true;
      _aiFeedbackError = null;
      _aiFeedbackDebug = null;
    });

    try {
      final uri = _buildAiEndpoint();
      final body =
          payload ??
          _buildAiPayload(
            range: _resolveRange(),
            trendPoints: _aiTrendPoints,
            categoryTotals: _aiCategoryTotals,
            cashFlow: _aiCashFlow,
            summary: _aiSummaryText,
            detail: _aiDetailText,
            scopeCounts: {for (final scope in _aiReportScopes) scope: 0},
            totalInflow: 0,
            totalOutflow: 0,
          );

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final text = (data['text'] as String?)?.trim();
        if (text == null || text.isEmpty) {
          throw Exception('Empty AI response');
        }
        if (!mounted) return;
        setState(() {
          _aiFeedbackText = text;
          _aiFeedbackDebug =
              'Endpoint: $uri\nStatus: ${response.statusCode}\n'
              'Response: ${response.body}';
        });
      } else {
        String detail = response.body;
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          if (data['error'] != null) {
            detail = data['error'].toString();
          }
        } catch (_) {}
        final debug =
            'Endpoint: $uri\nStatus: ${response.statusCode}\n'
            'Response: ${response.body}\n'
            'Payload: ${jsonEncode(body)}';
        _aiFeedbackDebug = debug;
        throw Exception(
          'AI service error: ${response.statusCode} ${detail.trim()}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiFeedbackError = 'AI feedback failed: $e';
        _aiFeedbackDebug ??= e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _aiFeedbackLoading = false;
        });
      }
    }
  }

  Uri _buildAiEndpoint() {
    if (kIsWeb) {
      final host = Uri.base.host;
      final isLocalhost =
          host == 'localhost' ||
          host == '127.0.0.1' ||
          host == '::1' ||
          host.endsWith('.local');
      if (!isLocalhost) {
        return Uri.parse('${Uri.base.origin}/api/finance-ai-report');
      }
    }
    return Uri.parse(
      'https://us-central1-hc-petty-cash-report.cloudfunctions.net/financeAiReport',
    );
  }
}

enum _AiReportScope {
  pettyCashReports,
  transactions,
  projectReports,
  incomeReports,
  travelReports,
}

extension _AiReportScopeLabel on _AiReportScope {
  String get label {
    switch (this) {
      case _AiReportScope.pettyCashReports:
        return 'Petty Cash Reports';
      case _AiReportScope.transactions:
        return 'Transactions';
      case _AiReportScope.projectReports:
        return 'Project Reports';
      case _AiReportScope.incomeReports:
        return 'Income Reports';
      case _AiReportScope.travelReports:
        return 'Travel Reports';
    }
  }
}

enum _AiReportRange {
  month,
  quarter,
  year,
  custom;

  String get label {
    switch (this) {
      case _AiReportRange.month:
        return 'Month';
      case _AiReportRange.quarter:
        return 'Quarter';
      case _AiReportRange.year:
        return 'Year';
      case _AiReportRange.custom:
        return 'Custom';
    }
  }
}

enum _AiReportPreset { none, thisMonth, lastMonth, ytd }

class _AiDateRange {
  final DateTime start;
  final DateTime end;

  _AiDateRange(this.start, this.end);
}

class _TrendPoint {
  final String label;
  final double value;

  _TrendPoint(this.label, this.value);
}

class _CashFlowSummary {
  final double opening;
  final double disbursed;
  final double closing;

  const _CashFlowSummary(this.opening, this.disbursed, this.closing);
}

class _TrendLinePainter extends CustomPainter {
  final List<_TrendPoint> points;

  _TrendLinePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final maxValue = points
        .map((p) => p.value)
        .fold<double>(0, (max, v) => v > max ? v : max);
    final minValue = points
        .map((p) => p.value)
        .fold<double>(double.infinity, (min, v) => v < min ? v : min);
    final range = (maxValue - minValue).abs() < 0.01 ? 1 : maxValue - minValue;

    final paint = Paint()
      ..color = Colors.indigo.shade400
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..color = Colors.indigo.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();
    for (var i = 0; i < points.length; i++) {
      final x = (size.width) * (i / (points.length - 1));
      final normalized = (points[i].value - minValue) / range;
      final y = size.height - (normalized * (size.height - 16)) - 8;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
      canvas.drawCircle(
        Offset(x, y),
        3,
        Paint()..color = Colors.indigo.shade600,
      );
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrendLinePainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
