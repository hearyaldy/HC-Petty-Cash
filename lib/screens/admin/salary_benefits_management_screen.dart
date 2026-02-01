import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../models/staff.dart';
import '../../models/salary_benefits.dart';
import '../../services/staff_service.dart';
import '../../services/salary_benefits_service.dart';
import '../../utils/responsive_helper.dart';

class SalaryBenefitsManagementScreen extends StatefulWidget {
  const SalaryBenefitsManagementScreen({super.key});

  @override
  State<SalaryBenefitsManagementScreen> createState() => _SalaryBenefitsManagementScreenState();
}

class _SalaryBenefitsManagementScreenState extends State<SalaryBenefitsManagementScreen> {
  final StaffService _staffService = StaffService();
  final SalaryBenefitsService _salaryBenefitsService = SalaryBenefitsService();
  final TextEditingController _searchController = TextEditingController();

  String _searchTerm = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            backgroundColor: Colors.green.shade600,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.green.shade700,
                      Colors.green.shade500,
                      Colors.teal.shade400,
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
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.monetization_on,
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
                                    'Salary & Benefits',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Manage employee compensation',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
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
                    // Search Section
                    _buildSearchSection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          // Staff List
          SliverToBoxAdapter(
            child: ResponsiveContainer(
              child: Padding(
                padding: ResponsiveHelper.getScreenPadding(context),
                child: _buildStaffList(),
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade400, Colors.green.shade600],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.search, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Search Staff',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, employee ID, or email...',
                prefixIcon: Icon(Icons.person_search, color: Colors.grey.shade500),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey.shade500),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchTerm = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.green.shade400, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onChanged: (value) {
                setState(() {
                  _searchTerm = value.toLowerCase();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffList() {
    return StreamBuilder<List<Staff>>(
      stream: _staffService.getAllStaff(),
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

        var staffList = snapshot.data ?? [];

        // Apply search filter
        if (_searchTerm.isNotEmpty) {
          staffList = staffList.where((staff) {
            return staff.fullName.toLowerCase().contains(_searchTerm) ||
                   staff.employeeId.toLowerCase().contains(_searchTerm) ||
                   staff.email.toLowerCase().contains(_searchTerm) ||
                   staff.position.toLowerCase().contains(_searchTerm) ||
                   staff.department.toLowerCase().contains(_searchTerm);
          }).toList();
        }

        if (staffList.isEmpty) {
          return _buildEmptyState();
        }

        return Column(
          children: staffList.map((staff) => _buildStaffCard(staff)).toList(),
        );
      },
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
            'Error loading staff',
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
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.monetization_on_outlined, size: 48, color: Colors.green.shade400),
          ),
          const SizedBox(height: 16),
          Text(
            'No staff records found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            'Add staff members to manage their salary and benefits',
            style: TextStyle(color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStaffCard(Staff staff) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: EdgeInsets.zero,
          title: Row(
            children: [
              Hero(
                tag: 'salary_avatar_${staff.id}',
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Colors.green.shade300, Colors.green.shade500],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    image: staff.photoUrl != null
                        ? DecorationImage(
                            image: NetworkImage(staff.photoUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: staff.photoUrl == null
                      ? Center(
                          child: Text(
                            staff.fullName.isNotEmpty
                                ? staff.fullName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staff.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            staff.employeeId,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            staff.position,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          children: [
            _buildSalaryBenefitsSection(staff),
          ],
        ),
      ),
    );
  }

  Widget _buildSalaryBenefitsSection(Staff staff) {
    return StreamBuilder<SalaryBenefits?>(
      stream: _salaryBenefitsService.getCurrentOrLatestSalaryBenefitsForStaff(staff.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          debugPrint(
            'Salary benefits stream error: ${snapshot.error}\n'
            'If this is a Firestore index error, create this composite index:\n'
            'Collection: salary_benefits\n'
            'Fields: staffId (ASC), isActive (ASC), effectiveDate (DESC)',
          );
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Error loading salary info: ${snapshot.error}\n\n'
              'If this is a Firestore index error, create this composite index:\n'
              'Collection: salary_benefits\n'
              'Fields: staffId (ASC), isActive (ASC), effectiveDate (DESC)',
              style: TextStyle(color: Colors.red.shade700),
            ),
          );
        }

        final salaryBenefits = snapshot.data;

        return Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current Salary Benefits Display
              if (salaryBenefits != null) _buildCurrentSalaryBenefitsCard(salaryBenefits),

              if (salaryBenefits == null)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade600),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No salary information set for this employee',
                          style: TextStyle(color: Colors.orange.shade800),
                        ),
                      ),
                    ],
                  ),
                ),

              // Action Buttons
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: salaryBenefits != null
                              ? [Colors.blue.shade400, Colors.blue.shade600]
                              : [Colors.green.shade400, Colors.green.shade600],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: (salaryBenefits != null ? Colors.blue : Colors.green).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _navigateToAddEditSalaryBenefits(staff, salaryBenefits),
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.edit, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  salaryBenefits != null ? 'Edit Salary & Benefits' : 'Add Salary & Benefits',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (salaryBenefits != null) ...[
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _navigateToSalaryHistory(staff),
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Icon(Icons.history, color: Colors.grey.shade700, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'History',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrentSalaryBenefitsCard(SalaryBenefits salaryBenefits) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.teal.shade50],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade400, Colors.green.shade600],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Current Salary & Benefits',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: salaryBenefits.isActive ? Colors.green : Colors.grey,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  salaryBenefits.isActive ? 'Active' : 'Inactive',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Base Salary', '${salaryBenefits.currency} ${NumberFormat('#,##0').format(salaryBenefits.baseSalary)}'),
          if (salaryBenefits.overtimeRate != null)
            _buildInfoRow('Overtime Rate', '${salaryBenefits.currency} ${NumberFormat('#,##0').format(salaryBenefits.overtimeRate)}'),
          if (salaryBenefits.bonus != null)
            _buildInfoRow('Bonus', '${salaryBenefits.currency} ${NumberFormat('#,##0').format(salaryBenefits.bonus)}'),
          if (salaryBenefits.allowances != null)
            _buildInfoRow('Allowances', '${salaryBenefits.currency} ${NumberFormat('#,##0').format(salaryBenefits.allowances)}'),
          if (salaryBenefits.deductions != null)
            _buildInfoRow('Deductions', '${salaryBenefits.currency} ${NumberFormat('#,##0').format(salaryBenefits.deductions)}'),
          const Divider(height: 24),
          _buildInfoRow('Gross Salary', '${salaryBenefits.currency} ${NumberFormat('#,##0').format(salaryBenefits.grossSalary)}', isBold: true),
          _buildInfoRow('Net Salary', '${salaryBenefits.currency} ${NumberFormat('#,##0').format(salaryBenefits.netSalary)}', isBold: true, isHighlighted: true),
          const SizedBox(height: 8),
          _buildInfoRow('Effective Date', DateFormat('dd/MM/yyyy').format(salaryBenefits.effectiveDate)),
          if (salaryBenefits.salaryGrade != null)
            _buildInfoRow('Salary Grade', salaryBenefits.salaryGrade!),
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
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isHighlighted ? Colors.green.shade700 : Colors.grey.shade900,
              fontSize: isHighlighted ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToAddEditSalaryBenefits(Staff staff, SalaryBenefits? currentSalaryBenefits) {
    context.push(
      '/admin/salary-benefits/edit',
      extra: {'staff': staff, 'salaryBenefits': currentSalaryBenefits},
    );
  }

  void _navigateToSalaryHistory(Staff staff) {
    context.push('/admin/salary-benefits/history', extra: {'staff': staff});
  }
}
