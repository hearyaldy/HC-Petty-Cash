import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';


import '../../models/staff.dart';
import '../../services/salary_benefits_service.dart';
import '../../services/staff_service.dart';
import '../../utils/responsive_helper.dart';

class AnnualLeaveStatsScreen extends StatefulWidget {
  const AnnualLeaveStatsScreen({super.key});

  @override
  State<AnnualLeaveStatsScreen> createState() => _AnnualLeaveStatsScreenState();
}

class _AnnualLeaveStatsScreenState extends State<AnnualLeaveStatsScreen> {
  final StaffService _staffService = StaffService();
  final SalaryBenefitsService _salaryService = SalaryBenefitsService();

  bool _loading = true;
  String? _error;
  List<_StaffLeaveRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  int _countWeekdays(DateTime start, DateTime end) {
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    if (endDate.isBefore(startDate)) return 0;
    var count = 0;
    var current = startDate;
    while (!current.isAfter(endDate)) {
      if (current.weekday != DateTime.saturday &&
          current.weekday != DateTime.sunday) {
        count++;
      }
      current = current.add(const Duration(days: 1));
    }
    return count;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. Get all active staff sorted by name
      final allStaff = await _staffService.getAllStaff().first;
      final activeStaff = allStaff.where((s) => s.isActive).toList()
        ..sort((a, b) => a.fullName.compareTo(b.fullName));

      // 2. Fetch all leave requests with status approved or submitted
      final snapshot = await FirebaseFirestore.instance
          .collection('annual_leave_requests')
          .where('status', whereIn: ['approved', 'submitted']).get();

      // 3. Build usage map keyed by requesterId
      final usageMap = <String, int>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final requesterId = data['requesterId'] as String?;
        if (requesterId == null) continue;
        final start = (data['startDate'] as Timestamp?)?.toDate();
        final end = (data['endDate'] as Timestamp?)?.toDate();
        int days;
        if (start != null && end != null) {
          days = _countWeekdays(start, end);
        } else {
          days = (data['totalDays'] as int?) ?? 0;
        }
        usageMap[requesterId] = (usageMap[requesterId] ?? 0) + days;
      }

      // 4 & 5. Build rows
      final rows = <_StaffLeaveRow>[];
      for (final staff in activeStaff) {
        final salary =
            await _salaryService.getCurrentSalaryBenefitsOnce(staff.id);
        final allocated = salary?.annualLeaveDays ?? 0;
        final used = usageMap[staff.userId ?? ''] ?? 0;
        rows.add(
          _StaffLeaveRow(staff: staff, allocated: allocated, used: used),
        );
      }

      if (mounted) {
        setState(() {
          _rows = rows;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load data: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: ResponsiveContainer(
          padding: ResponsiveHelper.getScreenPadding(context).copyWith(
            top: MediaQuery.of(context).padding.top + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                )
              else
                _buildTable(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isMobile = ResponsiveHelper.isMobile(context);
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade600, Colors.cyan.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.shade200.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeaderBtn(
                icon: Icons.arrow_back,
                tooltip: 'Back',
                onPressed: () => context.pop(),
              ),
              Row(
                children: [
                  _buildHeaderBtn(
                    icon: Icons.refresh,
                    tooltip: 'Refresh',
                    onPressed: _load,
                  ),
                  const SizedBox(width: 8),
                  _buildHeaderBtn(
                    icon: Icons.home_outlined,
                    tooltip: 'Home',
                    onPressed: () => context.go('/admin-hub'),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: isMobile ? 16 : 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bar_chart,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Leave Statistics',
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Staff annual leave balances',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBtn({
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

  Widget _buildTable() {
    if (_rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Text(
            'No active staff found',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    final totalAllocated = _rows.fold(0, (acc, r) => acc + r.allocated);
    final totalUsed = _rows.fold(0, (acc, r) => acc + r.used);
    final totalAvailable = totalAllocated - totalUsed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary cards
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                label: 'Total Allocated',
                value: totalAllocated,
                color: Colors.blue,
                icon: Icons.event_note,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                label: 'Total Used',
                value: totalUsed,
                color: Colors.orange,
                icon: Icons.event_busy,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                label: 'Total Available',
                value: totalAvailable,
                color: Colors.teal,
                icon: Icons.event_available,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Staff cards
        ..._rows.map(_buildStaffCard),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required int value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffCard(_StaffLeaveRow row) {
    final ratio = row.allocated > 0 ? row.used / row.allocated : 0.0;
    final isOverused = ratio >= 1.0;
    final progressColor = isOverused ? Colors.red : Colors.teal;
    final availableColor =
        row.available > 0 ? Colors.teal.shade700 : Colors.red.shade700;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: name, department, days-left pill
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.staff.fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (row.staff.department.isNotEmpty)
                        Text(
                          row.staff.department,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: availableColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${row.available} days left',
                    style: TextStyle(
                      color: availableColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
            const SizedBox(height: 10),
            // Bottom chips
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildChip(
                  label: 'Allocated',
                  value: row.allocated,
                  color: Colors.blue,
                ),
                _buildChip(
                  label: 'Used',
                  value: row.used,
                  color: Colors.orange,
                ),
                _buildChip(
                  label: 'Available',
                  value: row.available,
                  color: Colors.teal,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required int value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _StaffLeaveRow {
  final Staff staff;
  final int allocated;
  final int used;
  int get available => allocated - used;
  const _StaffLeaveRow({
    required this.staff,
    required this.allocated,
    required this.used,
  });
}
