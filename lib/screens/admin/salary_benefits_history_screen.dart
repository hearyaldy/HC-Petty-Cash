import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../models/staff.dart';
import '../../models/salary_benefits.dart';
import '../../services/salary_benefits_service.dart';
import '../../utils/responsive_helper.dart';

class SalaryBenefitsHistoryScreen extends StatefulWidget {
  const SalaryBenefitsHistoryScreen({super.key});

  @override
  State<SalaryBenefitsHistoryScreen> createState() =>
      _SalaryBenefitsHistoryScreenState();
}

class _SalaryBenefitsHistoryScreenState
    extends State<SalaryBenefitsHistoryScreen>
    with SingleTickerProviderStateMixin {
  final SalaryBenefitsService _salaryBenefitsService = SalaryBenefitsService();
  Staff? _staff;
  TabController? _tabController;
  List<int> _years = [];
  Map<int, List<SalaryBenefits>> _groupedRecords = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = GoRouterState.of(context).extra as Map<String, dynamic>?;
    if (args != null) {
      _staff = args['staff'] as Staff?;
    }
  }

  void _updateTabController(int tabCount) {
    if (_tabController?.length != tabCount) {
      _tabController?.dispose();
      if (tabCount > 0) {
        _tabController = TabController(length: tabCount, vsync: this);
      } else {
        _tabController = null;
      }
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Map<int, List<SalaryBenefits>> _groupByYear(List<SalaryBenefits> records) {
    final Map<int, List<SalaryBenefits>> grouped = {};
    for (final record in records) {
      final year = record.effectiveDate.year;
      grouped.putIfAbsent(year, () => []);
      grouped[year]!.add(record);
    }
    // Sort records within each year by effectiveDate descending
    for (final year in grouped.keys) {
      grouped[year]!.sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    if (_staff == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Salary History')),
        body: const Center(child: Text('Staff information not found')),
      );
    }

    return StreamBuilder<List<SalaryBenefits>>(
      stream: _salaryBenefitsService.getSalaryBenefitsForStaff(_staff!.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorScaffold(snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScaffold();
        }

        final allRecords = snapshot.data ?? [];
        _groupedRecords = _groupByYear(allRecords);
        _years = _groupedRecords.keys.toList()..sort((a, b) => b.compareTo(a));

        _updateTabController(_years.length);

        if (_years.isEmpty) {
          return _buildEmptyScaffold();
        }

        return _buildMainScaffold();
      },
    );
  }

  Widget _buildLoadingScaffold() {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(null),
        ],
        body: const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildErrorScaffold(String error) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(null),
        ],
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: _buildErrorState(error),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyScaffold() {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(null),
        ],
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: _buildEmptyState(),
          ),
        ),
      ),
      floatingActionButton: _buildNewYearFab(null),
    );
  }

  Widget _buildMainScaffold() {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(_tabController),
        ],
        body: TabBarView(
          controller: _tabController,
          children: _years.map((year) {
            final records = _groupedRecords[year]!;
            return _buildYearTab(records, year);
          }).toList(),
        ),
      ),
      floatingActionButton: _buildNewYearFab(
        _groupedRecords[_years.first]?.first,
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(TabController? tabController) {
    return SliverAppBar(
      expandedHeight: tabController != null ? 240 : 200,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.indigo.shade600,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.indigo.shade700,
                Colors.indigo.shade500,
                Colors.purple.shade400,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.2),
                          border: Border.all(color: Colors.white, width: 2),
                          image: _staff!.photoUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(_staff!.photoUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _staff!.photoUrl == null
                            ? Center(
                                child: Text(
                                  _staff!.fullName.isNotEmpty
                                      ? _staff!.fullName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _staff!.fullName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Salary & Benefits',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _staff!.employeeId,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (tabController != null) const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
      bottom: tabController != null
          ? TabBar(
              controller: tabController,
              isScrollable: true,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
              tabs: _years.map((year) => Tab(text: year.toString())).toList(),
            )
          : null,
      actions: [
        IconButton(
          icon: const Icon(Icons.home_outlined),
          onPressed: () => context.go('/dashboard'),
          tooltip: 'Home',
        ),
      ],
    );
  }

  Widget _buildYearTab(List<SalaryBenefits> records, int year) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ResponsiveContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Year summary card
            _buildYearSummaryCard(records, year),
            const SizedBox(height: 16),
            // Individual records
            ...records.asMap().entries.map((entry) {
              final record = entry.value;
              final isFirst = entry.key == 0;
              return _buildRecordCard(record, isFirst);
            }),
            const SizedBox(height: 80), // Space for FAB
          ],
        ),
      ),
    );
  }

  Widget _buildYearSummaryCard(List<SalaryBenefits> records, int year) {
    final latestRecord = records.first;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade400, Colors.purple.shade400],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.calendar_today, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Year $year',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${records.length} Record${records.length > 1 ? 's' : ''}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Latest: ${latestRecord.currency ?? "THB"} ${NumberFormat('#,##0').format(latestRecord.netSalary)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet,
                color: Colors.white,
                size: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCard(SalaryBenefits record, bool isMostRecent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isMostRecent ? Border.all(color: Colors.indigo.shade300, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: isMostRecent
                  ? LinearGradient(colors: [Colors.indigo.shade50, Colors.purple.shade50])
                  : null,
              color: isMostRecent ? null : Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isMostRecent
                              ? [Colors.indigo.shade400, Colors.purple.shade400]
                              : [Colors.grey.shade400, Colors.grey.shade500],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.calendar_today, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('dd MMMM yyyy').format(record.effectiveDate),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isMostRecent ? Colors.indigo.shade700 : Colors.grey.shade800,
                          ),
                        ),
                        if (isMostRecent)
                          Text(
                            'Latest',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.indigo.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: record.isActive ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    record.isActive ? 'Active' : 'Inactive',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (record.wageFactor != null)
                  _buildInfoRow(
                    'Wage Factor',
                    '${record.currency ?? "THB"} ${NumberFormat('#,##0').format(record.wageFactor)}',
                  ),
                if (record.salaryPercentage != null)
                  _buildInfoRow(
                    'Salary Scale',
                    '${record.salaryPercentage}%',
                  ),
                _buildInfoRow(
                  'Gross Salary',
                  '${record.currency ?? "THB"} ${NumberFormat('#,##0').format(record.grossSalary)}',
                  isBold: true,
                ),
                const Divider(height: 24),
                // Allowances
                if (record.phoneAllowance != null && record.phoneAllowance! > 0)
                  _buildInfoRow(
                    'Phone Allowance',
                    '${record.currency ?? "THB"} ${NumberFormat('#,##0').format(record.phoneAllowance)}',
                  ),
                if (record.housingAllowance != null && record.housingAllowance! > 0)
                  _buildInfoRow(
                    'Housing Allowance',
                    '${record.currency ?? "THB"} ${NumberFormat('#,##0').format(record.housingAllowance)}',
                  ),
                if (record.equipmentAllowance != null && record.equipmentAllowance! > 0)
                  _buildInfoRow(
                    'Equipment (Annual)',
                    '${record.currency ?? "THB"} ${NumberFormat('#,##0').format(record.equipmentAllowance)}',
                  ),
                if (record.continueEducationAllowance != null && record.continueEducationAllowance! > 0)
                  _buildInfoRow(
                    'Education (Annual)',
                    '${record.currency ?? "THB"} ${NumberFormat('#,##0').format(record.continueEducationAllowance)}',
                  ),
                // Deductions
                if (record.tithePercentage != null && record.tithePercentage! > 0)
                  _buildInfoRow(
                    'Tithe (${record.tithePercentage}%)',
                    '- ${record.currency ?? "THB"} ${NumberFormat('#,##0').format(record.titheAmount)}',
                  ),
                if (record.providentFundPercentage != null && record.providentFundPercentage! > 0)
                  _buildInfoRow(
                    'Provident Fund (${record.providentFundPercentage}%)',
                    '- ${record.currency ?? "THB"} ${NumberFormat('#,##0').format(record.providentFundAmount)}',
                  ),
                if (record.socialSecurityAmount > 0)
                  _buildInfoRow(
                    'Social Security',
                    '- ${record.currency ?? "THB"} ${NumberFormat('#,##0').format(record.socialSecurityAmount)}',
                  ),
                if (record.houseRentalPercentage != null && record.houseRentalPercentage! > 0)
                  _buildInfoRow(
                    'House Rental (${record.houseRentalPercentage}%)',
                    '- ${record.currency ?? "THB"} ${NumberFormat('#,##0').format(record.houseRentalAmount)}',
                  ),
                const Divider(height: 24),
                _buildInfoRow(
                  'Net Salary',
                  '${record.currency ?? "THB"} ${NumberFormat('#,##0').format(record.netSalary)}',
                  isBold: true,
                  isHighlighted: true,
                ),
                if (record.salaryGrade != null)
                  _buildInfoRow('Salary Grade', record.salaryGrade!),
                if (record.payGrade != null)
                  _buildInfoRow('Pay Grade', record.payGrade!),
                if (record.notes != null && record.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.note, size: 16, color: Colors.amber.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            record.notes!,
                            style: TextStyle(
                              color: Colors.amber.shade900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Edit button
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _navigateToEdit(record),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.indigo,
                      side: BorderSide(color: Colors.indigo.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
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

  Widget _buildNewYearFab(SalaryBenefits? latestRecord) {
    return FloatingActionButton.extended(
      onPressed: () => _navigateToNewYear(latestRecord),
      backgroundColor: Colors.indigo.shade600,
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text(
        'New Year',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading history',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.history_outlined, size: 48, color: Colors.indigo.shade400),
          ),
          const SizedBox(height: 16),
          Text(
            'No salary history found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "New Year" to add a salary record',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false, bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: isHighlighted ? Colors.green.shade700 : Colors.grey.shade900,
                fontSize: isHighlighted ? 16 : 14,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToEdit(SalaryBenefits record) {
    context.push(
      '/admin/salary-benefits/edit',
      extra: {'staff': _staff, 'salaryBenefits': record},
    );
  }

  void _navigateToNewYear(SalaryBenefits? latestRecord) {
    context.push(
      '/admin/salary-benefits/edit',
      extra: {
        'staff': _staff,
        'salaryBenefits': latestRecord,
        'isNewYearRecord': true,
      },
    );
  }
}
