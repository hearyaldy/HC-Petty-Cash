import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/budget_line_item.dart';
import '../../models/budget_year.dart';
import '../../providers/budget_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/budget_pdf_export_service.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/add_budget_item_dialog.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/edit_budget_line_item_dialog.dart';

class BudgetYearDetailScreen extends StatefulWidget {
  final String budgetYearId;
  const BudgetYearDetailScreen({super.key, required this.budgetYearId});

  @override
  State<BudgetYearDetailScreen> createState() => _BudgetYearDetailScreenState();
}

class _BudgetSectionEditData {
  final String scheduleCode;
  final String sectionTitle;
  final String sectionType;

  const _BudgetSectionEditData({
    required this.scheduleCode,
    required this.sectionTitle,
    required this.sectionType,
  });
}

class _BudgetYearDetailScreenState extends State<BudgetYearDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _fmt = NumberFormat('#,##0.00', 'en_US');
  final Set<String> _collapsed = {};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        await context.read<BudgetProvider>().loadYearById(widget.budgetYearId);
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // ─── Top bar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildTopBar(BuildContext context, BudgetYear? year) {
    final cs = Theme.of(context).colorScheme;
    final maxWidth = ResponsiveHelper.getMaxContentWidth(context);
    final hPad = ResponsiveHelper.getScreenPadding(context).horizontal / 2;

    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: BoxDecoration(
          color: cs.primary,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
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
                      Builder(
                        builder: (ctx) => IconButton(
                          icon: const Icon(Icons.menu, color: Colors.white),
                          tooltip: 'Menu',
                          onPressed: () => Scaffold.of(ctx).openDrawer(),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Center(
                          child: Text(
                            'HC',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              year != null
                                  ? 'Budget ${year.year}'
                                  : 'Annual Budget',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Admin · Annual Budget',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (year != null) ...[
                        _statusChip(year),
                        const SizedBox(width: 4),
                        if (!year.isApproved)
                          IconButton(
                            icon: const Icon(
                              Icons.check_circle_outline,
                              color: Colors.white,
                              size: 22,
                            ),
                            tooltip: 'Approve Budget',
                            onPressed: _approve,
                          ),
                        IconButton(
                          icon: const Icon(
                            Icons.refresh,
                            color: Colors.white,
                            size: 22,
                          ),
                          tooltip: 'Refresh Actuals',
                          onPressed: () =>
                              context.read<BudgetProvider>().refreshActuals(),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.print,
                            color: Colors.white,
                            size: 22,
                          ),
                          tooltip: 'Print / Export PDF',
                          onPressed: () => _printBudget(year),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.add_circle_outline,
                            color: Colors.white,
                            size: 22,
                          ),
                          tooltip: 'Add Line Item / New Section',
                          onPressed: () => _showAddDialog(),
                        ),
                      ],
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

  // ─── Actions ───────────────────────────────────────────────────────────────

  String get _currentTabType => ['income', 'expense'][_tabs.index];

  Future<void> _showAddDialog({
    String? sectionCode,
    String? sectionTitle,
    String? sectionType,
  }) async {
    final result = await showDialog<NewBudgetItemData>(
      context: context,
      builder: (_) => AddBudgetItemDialog(
        scheduleCode: sectionCode,
        sectionTitle: sectionTitle,
        sectionType: sectionType ?? _currentTabType,
      ),
    );
    if (result != null && mounted) {
      await context.read<BudgetProvider>().addLineItem(
        scheduleCode: result.scheduleCode,
        sectionTitle: result.sectionTitle,
        sectionType: result.sectionType,
        name: result.name,
        budgetAmount: result.budgetAmount,
        linkedTransactionCategory: result.linkedTransactionCategory,
        linkedReportType: result.linkedReportType,
      );
    }
  }

  Future<void> _editItem(BudgetLineItem item) async {
    final result = await showDialog<BudgetLineItem>(
      context: context,
      builder: (_) => EditBudgetLineItemDialog(item: item),
    );
    if (result != null && mounted) {
      await context.read<BudgetProvider>().updateLineItem(result);
    }
  }

  Future<void> _editSection(BudgetSection section) async {
    final result = await showDialog<_BudgetSectionEditData>(
      context: context,
      builder: (_) => _EditBudgetSectionDialog(section: section),
    );
    if (result != null && mounted) {
      await context.read<BudgetProvider>().updateSection(
        currentScheduleCode: section.code,
        scheduleCode: result.scheduleCode,
        sectionTitle: result.sectionTitle,
        sectionType: result.sectionType,
      );
    }
  }

  Future<void> _deleteItem(BudgetLineItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Line Item'),
        content: Text('Delete "${item.name}" from ${item.sectionTitle}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await context.read<BudgetProvider>().deleteLineItem(item.id);
    }
  }

  Future<void> _deleteSection(BudgetSection section) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Section'),
        content: Text(
          'Delete ${section.code} · ${section.title} and all ${section.items.length} line item(s)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Delete Section'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await context.read<BudgetProvider>().deleteSection(section.code);
      if (mounted) {
        setState(() => _collapsed.remove(section.code));
      }
    }
  }

  Future<void> _approve() async {
    final auth = context.read<AuthProvider>();
    if (auth.currentUser == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Approve Budget'),
        content: const Text(
          'Mark this budget as approved? This signals it is final for the year.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await context.read<BudgetProvider>().approveYear(auth.currentUser!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Budget approved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _printBudget(BudgetYear year) async {
    final provider = context.read<BudgetProvider>();
    try {
      await BudgetPdfExportService().printBudget(
        year: year,
        items: provider.lineItems,
        actuals: provider.actuals,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<BudgetProvider>(
      builder: (context, provider, _) {
        final year = provider.selectedYear;
        final maxWidth = ResponsiveHelper.getMaxContentWidth(context);
        return Scaffold(
          appBar: _buildTopBar(context, year),
          drawer: const AppDrawer(),
          body: year == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Center(
                      child: Container(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: _buildSummaryBanner(provider, year),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildTabBar(context),
                    Expanded(
                      child: TabBarView(
                        controller: _tabs,
                        children: [
                          _buildTabContent(provider, 'income'),
                          _buildTabContent(provider, 'expense'),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  // ─── Summary banner ────────────────────────────────────────────────────────

  Widget _buildSummaryBanner(BudgetProvider p, BudgetYear year) {
    final cs = Theme.of(context).colorScheme;
    final netBudget = p.totalIncomeBudget - p.totalExpenseBudget;
    final netActual = p.totalIncomeActual - p.totalExpenseActual;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary.withValues(alpha: 0.85), cs.primary],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 600;
          final pills = Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _summaryPill(
                'Income & Approp.',
                p.totalIncomeBudget,
                Colors.greenAccent,
              ),
              _summaryPill(
                'Expense',
                p.totalExpenseBudget,
                Colors.orangeAccent,
              ),
              _summaryPill(
                'Net Budget',
                netBudget,
                netBudget >= 0 ? Colors.greenAccent : Colors.redAccent,
              ),
              if (p.totalIncomeActual > 0 || p.totalExpenseActual > 0)
                _summaryPill(
                  'Net Actual',
                  netActual,
                  netActual >= 0 ? Colors.greenAccent : Colors.redAccent,
                ),
            ],
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Budget ${year.year}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                pills,
              ],
            );
          }

          return Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Budget ${year.year}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Hope Channel Southeast Asia',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              pills,
            ],
          );
        },
      ),
    );
  }

  Widget _summaryPill(String label, double value, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '฿${_fmt.format(value.abs())}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(BudgetYear year) {
    final color = year.isApproved ? Colors.greenAccent : Colors.orangeAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        year.isApproved ? 'Approved' : 'Draft',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // ─── Tab bar ───────────────────────────────────────────────────────────────

  Widget _buildTabBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      child: TabBar(
        controller: _tabs,
        labelColor: cs.primary,
        unselectedLabelColor: cs.onSurfaceVariant,
        indicatorColor: cs.primary,
        tabs: const [
          Tab(icon: Icon(Icons.arrow_downward, size: 16), text: 'Income'),
          Tab(icon: Icon(Icons.arrow_upward, size: 16), text: 'Expenses'),
        ],
      ),
    );
  }

  // ─── Tab content ──────────────────────────────────────────────────────────

  Widget _buildTabContent(BudgetProvider provider, String type) {
    final cs = Theme.of(context).colorScheme;
    final maxWidth = ResponsiveHelper.getMaxContentWidth(context);
    final hPad = ResponsiveHelper.getScreenPadding(context).horizontal / 2;

    if (type == 'income') {
      final incomeSections = provider.sectionsOfType('income');
      final appropSections = provider.sectionsOfType('appropriation');
      if (incomeSections.isEmpty && appropSections.isEmpty) {
        return Center(
          child: Text(
            'No data',
            style: TextStyle(color: cs.outlineVariant, fontSize: 15),
          ),
        );
      }
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 12),
            children: [
              ...incomeSections.map((s) => _buildSection(s, provider)),
              if (appropSections.isNotEmpty) ...[
                _buildSectionDividerLabel('Appropriations Received'),
                ...appropSections.map((s) => _buildSection(s, provider)),
              ],
              _buildCombinedIncomeTotal(provider),
            ],
          ),
        ),
      );
    }

    // Expenses tab
    final sections = provider.sectionsOfType(type);
    if (sections.isEmpty) {
      return Center(
        child: Text(
          'No data',
          style: TextStyle(color: cs.outlineVariant, fontSize: 15),
        ),
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 12),
          itemCount: sections.length + 1,
          itemBuilder: (context, index) {
            if (index == sections.length) {
              return _buildTypeTotal(sections, type, provider);
            }
            return _buildSection(sections[index], provider);
          },
        ),
      ),
    );
  }

  Widget _buildSectionDividerLabel(String label) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCombinedIncomeTotal(BudgetProvider provider) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Total Income & Appropriations',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: cs.onPrimaryContainer,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '฿${_fmt.format(provider.totalIncomeBudget)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: cs.onPrimaryContainer,
                ),
              ),
              if (provider.totalIncomeActual > 0)
                Text(
                  'Actual: ฿${_fmt.format(provider.totalIncomeActual)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onPrimaryContainer.withValues(alpha: 0.8),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BudgetSection section, BudgetProvider provider) {
    final cs = Theme.of(context).colorScheme;
    final isCollapsed = _collapsed.contains(section.code);
    final actualTotal = section.items.fold(
      0.0,
      (s, i) => s + (provider.actuals[i.id] ?? 0),
    );
    final variance = section.budgetTotal - actualTotal;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(
              () => isCollapsed
                  ? _collapsed.remove(section.code)
                  : _collapsed.add(section.code),
            ),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      section.code,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      section.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '฿${_fmt.format(section.budgetTotal)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (actualTotal > 0)
                        Text(
                          variance >= 0
                              ? '-฿${_fmt.format(variance)}'
                              : '+฿${_fmt.format(variance.abs())}',
                          style: TextStyle(
                            fontSize: 10,
                            color: variance >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                    ],
                  ),
                  Tooltip(
                    message: 'Edit section',
                    child: IconButton(
                      icon: Icon(Icons.edit_note, size: 19, color: cs.primary),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _editSection(section),
                    ),
                  ),
                  Tooltip(
                    message: 'Add line item to ${section.title}',
                    child: IconButton(
                      icon: Icon(
                        Icons.add_circle_outline,
                        size: 19,
                        color: cs.primary,
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _showAddDialog(
                        sectionCode: section.code,
                        sectionTitle: section.title,
                        sectionType: section.type,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Delete section',
                    child: IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 19,
                        color: cs.error,
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _deleteSection(section),
                    ),
                  ),
                  Icon(
                    isCollapsed
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (!isCollapsed) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: cs.outlineVariant.withValues(alpha: 0.4),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: [
                  const Expanded(
                    flex: 4,
                    child: Text(
                      'Line Item',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _headerCell('Budget'),
                  _headerCell('Actual'),
                  _headerCell('Variance'),
                  const SizedBox(width: 64),
                ],
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),
            ...section.items.map((item) => _buildLineItemRow(item, provider)),
          ],
        ],
      ),
    );
  }

  Widget _headerCell(String text) => Expanded(
    flex: 3,
    child: Text(
      text,
      textAlign: TextAlign.right,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
    ),
  );

  Widget _buildLineItemRow(BudgetLineItem item, BudgetProvider provider) {
    final cs = Theme.of(context).colorScheme;
    final actual = provider.actuals[item.id] ?? 0.0;
    final variance = item.budgetAmount - actual;
    final hasActual = actual > 0;
    final isOver = variance < 0;

    return InkWell(
      onTap: () => _editItem(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  if (item.linkedTransactionCategory != null ||
                      item.linkedReportType != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.link,
                        size: 12,
                        color: cs.primary.withValues(alpha: 0.6),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                item.budgetAmount == 0
                    ? '—'
                    : '฿${_fmt.format(item.budgetAmount)}',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            Expanded(
              flex: 3,
              child: provider.isLoadingActuals
                  ? const Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      ),
                    )
                  : Text(
                      hasActual ? '฿${_fmt.format(actual)}' : '—',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        color: hasActual ? cs.onSurface : cs.outlineVariant,
                      ),
                    ),
            ),
            Expanded(
              flex: 3,
              child: hasActual
                  ? Text(
                      variance >= 0
                          ? '฿${_fmt.format(variance)}'
                          : '-฿${_fmt.format(variance.abs())}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isOver ? Colors.red : Colors.green,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            SizedBox(
              width: 64,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Edit line item',
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: cs.outlineVariant,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _editItem(item),
                  ),
                  IconButton(
                    tooltip: 'Delete line item',
                    icon: Icon(Icons.delete_outline, size: 16, color: cs.error),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _deleteItem(item),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeTotal(
    List<BudgetSection> sections,
    String type,
    BudgetProvider provider,
  ) {
    final cs = Theme.of(context).colorScheme;
    final budgetTotal = sections.fold(0.0, (s, sec) => s + sec.budgetTotal);
    final actualTotal = sections.fold(
      0.0,
      (s, sec) =>
          s +
          sec.items.fold(0.0, (ss, i) => ss + (provider.actuals[i.id] ?? 0)),
    );

    const label = 'Total Operating Expense';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: cs.onPrimaryContainer,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '฿${_fmt.format(budgetTotal)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: cs.onPrimaryContainer,
                ),
              ),
              if (actualTotal > 0)
                Text(
                  'Actual: ฿${_fmt.format(actualTotal)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onPrimaryContainer.withValues(alpha: 0.8),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditBudgetSectionDialog extends StatefulWidget {
  final BudgetSection section;

  const _EditBudgetSectionDialog({required this.section});

  @override
  State<_EditBudgetSectionDialog> createState() =>
      _EditBudgetSectionDialogState();
}

class _EditBudgetSectionDialogState extends State<_EditBudgetSectionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeCtrl;
  late final TextEditingController _titleCtrl;
  late String _sectionType;

  static const _sectionTypes = [
    (value: 'income', label: 'Income'),
    (value: 'expense', label: 'Expense'),
    (value: 'appropriation', label: 'Appropriation'),
  ];

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController(text: widget.section.code);
    _titleCtrl = TextEditingController(text: widget.section.title);
    _sectionType = widget.section.type;
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _BudgetSectionEditData(
        scheduleCode: _codeCtrl.text.trim(),
        sectionTitle: _titleCtrl.text.trim(),
        sectionType: _sectionType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.edit_note, color: cs.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Edit Budget Section',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: TextFormField(
                      controller: _codeCtrl,
                      textCapitalization: TextCapitalization.none,
                      decoration: const InputDecoration(
                        labelText: 'Code *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Section Title *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _sectionType,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: _sectionTypes
                    .map(
                      (type) => DropdownMenuItem(
                        value: type.value,
                        child: Text(type.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _sectionType = value);
                  }
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined, size: 16),
                    label: const Text('Save Section'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
