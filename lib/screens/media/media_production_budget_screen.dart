import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import '../../providers/auth_provider.dart';
import '../../models/media_production.dart';
import '../../providers/media_production_provider.dart';
import '../../providers/project_report_provider.dart';
import '../../models/project_report.dart';
import '../../services/media_production_pdf_service.dart';
import '../../utils/constants.dart';
import '../../utils/responsive_helper.dart';

class MediaProductionBudgetScreen extends StatefulWidget {
  const MediaProductionBudgetScreen({super.key});

  @override
  State<MediaProductionBudgetScreen> createState() =>
      _MediaProductionBudgetScreenState();
}

class _MediaProductionBudgetScreenState
    extends State<MediaProductionBudgetScreen>
    with SingleTickerProviderStateMixin {
  String _selectedYear = 'all';
  late final TabController _tabController;
  final MediaProductionPdfService _pdfService = MediaProductionPdfService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final authProvider = context.read<AuthProvider>();
    final mediaProvider = context.read<MediaProductionProvider>();
    final projectProvider = context.read<ProjectReportProvider>();
    final user = authProvider.currentUser;
    final isAdmin = user?.role == 'admin';

    if (isAdmin) {
      await mediaProvider.loadAllProductions();
    } else if (user != null) {
      await mediaProvider.loadProductionsForUser(user.mediaPermissions.assignedLanguages);
    }
    await projectProvider.loadProjectReports();
  }

  List<int> _getAvailableYears(List<MediaProduction> productions) {
    final years = productions
        .map((p) => p.productionYear)
        .whereType<int>()
        .toSet()
        .toList();
    years.sort((a, b) => b.compareTo(a));
    return years;
  }

  List<MediaProduction> _getFilteredProductions(
    List<MediaProduction> productions,
  ) {
    if (_selectedYear == 'all') return productions;
    final year = int.tryParse(_selectedYear);
    if (year == null) return productions;
    return productions.where((p) => p.productionYear == year).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/media/productions/add'),
        backgroundColor: Colors.pink,
        icon: const Icon(Icons.add),
        label: const Text('New Production'),
      ),
      body: SafeArea(
        child: Consumer2<MediaProductionProvider, ProjectReportProvider>(
        builder: (context, provider, projectProvider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final productions = _getFilteredProductions(provider.productions);
          final availableYears = _getAvailableYears(provider.productions);
          final projectMap = {
            for (final report in projectProvider.projectReports) report.id: report,
          };
          final currencyFormat = NumberFormat.currency(
            symbol: '${AppConstants.currencySymbol} ',
            decimalDigits: 2,
          );
          final currentYearTotal = _getYearTotal(
            provider.productions,
            DateTime.now().year,
            projectMap,
          );

          return RefreshIndicator(
            onRefresh: _loadData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ResponsiveContainer(
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    _buildHeaderBanner(
                      onBack: () => context.go('/media-dashboard'),
                      onPrint: () => _exportBudgetPdf(
                        productions,
                        projectMap,
                      ),
                      onRefresh: _loadData,
                    ),
                    const SizedBox(height: 16),
                    _buildCurrentYearSummary(
                      currentYearTotal,
                      DateTime.now().year,
                      currencyFormat,
                    ),
                    const SizedBox(height: 16),
                    _buildTabBar(),
                    const SizedBox(height: 16),
                    if (_tabController.index == 0)
                      _buildYearFilterCard(availableYears),
                    const SizedBox(height: 16),
                    if (_tabController.index == 0)
                      if (productions.isEmpty)
                        _buildEmptyState()
                      else
                        _buildBudgetTable(productions, currencyFormat, projectMap)
                    else
                      _buildYearTotals(provider.productions, currencyFormat, projectMap),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          );
        },
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.pink,
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: Colors.pink,
        onTap: (_) => setState(() {}),
        tabs: const [
          Tab(text: 'By Production'),
          Tab(text: 'Year Totals'),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner({
    required VoidCallback onBack,
    required VoidCallback onPrint,
    required VoidCallback onRefresh,
  }) {
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
                      onPressed: onBack,
                    ),
                    Row(
                      children: [
                        _buildHeaderActionButton(
                          icon: Icons.print,
                          tooltip: 'Print List',
                          onPressed: onPrint,
                        ),
                        const SizedBox(width: 8),
                        _buildHeaderActionButton(
                          icon: Icons.refresh,
                          tooltip: 'Refresh',
                          onPressed: onRefresh,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Production Budget',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Track and edit budgets by production year',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
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

  Widget _buildCurrentYearSummary(
    double total,
    int year,
    NumberFormat currencyFormat,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.pink.shade600),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Current Year Total ($year)',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              currencyFormat.format(total),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearFilterCard(List<int> years) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.pink.shade600),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Filter by Year',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                value: _selectedYear,
                decoration: const InputDecoration(
                  labelText: 'Year',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('All Years')),
                  ...years.map(
                    (year) => DropdownMenuItem(
                      value: year.toString(),
                      child: Text(year.toString()),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedYear = value);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No productions available yet.',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      ),
    );
  }

  double _resolveBudget(
    MediaProduction production,
    Map<String, ProjectReport> projectMap,
  ) {
    final projectId = production.projectId;
    if (projectId != null) {
      final report = projectMap[projectId];
      if (report != null) return report.budget;
    }
    return production.budget ?? 0;
  }

  double _getYearTotal(
    List<MediaProduction> productions,
    int year,
    Map<String, ProjectReport> projectMap,
  ) {
    return productions
        .where((p) => p.productionYear == year)
        .fold(0.0, (sum, p) => sum + _resolveBudget(p, projectMap));
  }

  Widget _buildBudgetTable(
    List<MediaProduction> productions,
    NumberFormat currencyFormat,
    Map<String, ProjectReport> projectMap,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('Production')),
            DataColumn(label: Text('Year')),
            DataColumn(label: Text('Language')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Budget')),
            DataColumn(label: Text('Actions')),
          ],
          rows: productions.map((production) {
            final effectiveBudget = _resolveBudget(production, projectMap);
            final budgetText = currencyFormat.format(effectiveBudget);
            final linkedProject = production.projectId != null &&
                projectMap.containsKey(production.projectId);
            return DataRow(
              cells: [
                DataCell(Text(production.title)),
                DataCell(Text(production.productionYear?.toString() ?? '-')),
                DataCell(Text(production.languageDisplayName)),
                DataCell(Text(production.typeDisplayName)),
                DataCell(
                  SizedBox(
                    width: 140,
                    child: Text(budgetText),
                  ),
                ),
                DataCell(
                  IconButton(
                    icon: Icon(
                      linkedProject ? Icons.link : Icons.edit,
                      size: 18,
                    ),
                    onPressed: () => _showBudgetEditDialog(
                      context,
                      production,
                      projectMap[production.projectId],
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildYearTotals(
    List<MediaProduction> productions,
    NumberFormat currencyFormat,
    Map<String, ProjectReport> projectMap,
  ) {
    final Map<String, double> totals = {};
    final Map<String, int> counts = {};

    for (final production in productions) {
      final year = production.productionYear?.toString() ?? 'Unassigned';
      final budget = _resolveBudget(production, projectMap);
      totals[year] = (totals[year] ?? 0) + budget;
      counts[year] = (counts[year] ?? 0) + 1;
    }

    final years = totals.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    if (years.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: years.map((year) {
        final total = totals[year] ?? 0;
        final count = counts[year] ?? 0;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const Icon(Icons.calendar_today, color: Colors.pink),
            title: Text('Year $year'),
            subtitle: Text('$count productions'),
            trailing: Text(
              currencyFormat.format(total),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _showBudgetEditDialog(
    BuildContext context,
    MediaProduction production,
    ProjectReport? linkedReport,
  ) async {
    if (linkedReport != null) {
      final shouldOpen = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Budget Linked to Project'),
          content: Text(
            'This production is linked to "${linkedReport.projectName}". '
            'Budget is taken from the project report.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Open Project'),
            ),
          ],
        ),
      );

      if (shouldOpen == true && context.mounted) {
        context.push('/project-reports/${linkedReport.id}');
      }
      return;
    }

    final controller = TextEditingController(
      text: production.budget?.toStringAsFixed(2) ?? '',
    );

    final updated = await showDialog<double?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Budget'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Budget',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              Navigator.pop(dialogContext, value ?? 0.0);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (updated == null) return;

    final provider = context.read<MediaProductionProvider>();
    final updatedProduction = production.copyWith(
      budget: updated,
      updatedAt: DateTime.now(),
    );
    await provider.updateProduction(updatedProduction);
  }

  Future<void> _exportBudgetPdf(
    List<MediaProduction> productions,
    Map<String, ProjectReport> projectMap,
  ) async {
    final projectBudgets = <String, double>{};
    for (final entry in projectMap.entries) {
      projectBudgets[entry.key] = entry.value.budget;
    }

    final yearFilter =
        _selectedYear == 'all' ? null : int.tryParse(_selectedYear);
    final data = await _pdfService.exportProductionBudgetList(
      productions: productions,
      projectBudgets: projectBudgets,
      yearFilter: yearFilter,
    );
    await Printing.layoutPdf(onLayout: (_) async => data);
  }
}
