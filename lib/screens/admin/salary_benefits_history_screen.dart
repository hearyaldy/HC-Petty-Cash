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
    extends State<SalaryBenefitsHistoryScreen> {
  final SalaryBenefitsService _salaryBenefitsService = SalaryBenefitsService();
  Staff? _staff;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = GoRouterState.of(context).extra as Map<String, dynamic>?;
    if (args != null) {
      _staff = args['staff'] as Staff?;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_staff == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Salary History')),
        body: const Center(child: Text('Staff information not found')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          // Modern SliverAppBar with gradient
          SliverAppBar(
            expandedHeight: 200,
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
                            // Staff Avatar
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
                                    'Salary History',
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
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.home_outlined),
                onPressed: () => context.go('/dashboard'),
                tooltip: 'Home',
              ),
            ],
          ),
          // Content
          SliverToBoxAdapter(
            child: ResponsiveContainer(
              child: Padding(
                padding: ResponsiveHelper.getScreenPadding(context),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildHistoryList(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return StreamBuilder<List<SalaryBenefits>>(
      stream: _salaryBenefitsService.getSalaryHistoryForStaff(_staff!.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final salaryHistory = snapshot.data ?? [];

        if (salaryHistory.isEmpty) {
          return _buildEmptyState();
        }

        return Column(
          children: [
            // Summary Card
            _buildSummaryCard(salaryHistory),
            const SizedBox(height: 24),
            // History Timeline
            ...salaryHistory.asMap().entries.map((entry) {
              final index = entry.key;
              final record = entry.value;
              return _buildHistoryCard(record, index == 0);
            }),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(List<SalaryBenefits> history) {
    final current = history.isNotEmpty ? history.first : null;
    final recordCount = history.length;

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
                        child: const Icon(Icons.timeline, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Salary Timeline',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$recordCount Records',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (current != null)
                    Text(
                      'Current: ${current.currency} ${NumberFormat('#,##0').format(current.netSalary)}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
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
                Icons.history,
                color: Colors.white,
                size: 32,
              ),
            ),
          ],
        ),
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
            'Add salary records to see history',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(SalaryBenefits record, bool isMostRecent) {
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
                            'Current',
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
                _buildInfoRow(
                  'Base Salary',
                  '${record.currency} ${NumberFormat('#,##0').format(record.baseSalary)}',
                ),
                if (record.overtimeRate != null)
                  _buildInfoRow(
                    'Overtime Rate',
                    '${record.currency} ${NumberFormat('#,##0').format(record.overtimeRate)}',
                  ),
                if (record.bonus != null)
                  _buildInfoRow(
                    'Bonus',
                    '${record.currency} ${NumberFormat('#,##0').format(record.bonus)}',
                  ),
                if (record.allowances != null)
                  _buildInfoRow(
                    'Allowances',
                    '${record.currency} ${NumberFormat('#,##0').format(record.allowances)}',
                  ),
                if (record.deductions != null)
                  _buildInfoRow(
                    'Deductions',
                    '${record.currency} ${NumberFormat('#,##0').format(record.deductions)}',
                  ),
                const Divider(height: 24),
                _buildInfoRow(
                  'Gross Salary',
                  '${record.currency} ${NumberFormat('#,##0').format(record.grossSalary)}',
                  isBold: true,
                ),
                _buildInfoRow(
                  'Net Salary',
                  '${record.currency} ${NumberFormat('#,##0').format(record.netSalary)}',
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
              ],
            ),
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
}
