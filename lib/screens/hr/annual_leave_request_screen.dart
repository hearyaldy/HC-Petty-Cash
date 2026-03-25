import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../models/annual_leave_request.dart';
import '../../providers/auth_provider.dart';
import '../../services/annual_leave_pdf_service.dart';
import '../../services/salary_benefits_service.dart';
import '../../services/staff_service.dart';
import '../../utils/responsive_helper.dart';

class AnnualLeaveRequestScreen extends StatefulWidget {
  const AnnualLeaveRequestScreen({super.key});

  @override
  State<AnnualLeaveRequestScreen> createState() =>
      _AnnualLeaveRequestScreenState();
}

class _AnnualLeaveRequestScreenState extends State<AnnualLeaveRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _submitting = false;
  bool _loadingBalance = true;
  int _annualLeaveDays = 0;
  int _usedLeaveDays = 0;
  String? _employeeId;
  String? _position;
  String? _email;

  final StaffService _staffService = StaffService();
  final SalaryBenefitsService _salaryBenefitsService = SalaryBenefitsService();

  @override
  void initState() {
    super.initState();
    _loadLeaveBalance();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? _startDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      } else {
        _endDate = picked;
      }
    });
  }

  int? get _totalDays {
    if (_startDate == null || _endDate == null) return null;
    return _countWeekdays(_startDate!, _endDate!);
  }

  int get _availableLeaveDays => _annualLeaveDays - _usedLeaveDays;

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

  Future<void> _loadLeaveBalance() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) return;

    try {
      final staff = await _staffService.getStaffByUserId(user.id);
      if (staff == null) {
        if (mounted) {
          setState(() {
            _annualLeaveDays = 0;
            _usedLeaveDays = 0;
            _employeeId = null;
            _position = null;
            _email = user.email;
            _loadingBalance = false;
          });
        }
        return;
      }

      final salaryBenefits =
          await _salaryBenefitsService.getCurrentSalaryBenefitsOnce(staff.id);
      final annualLeaveDays = salaryBenefits?.annualLeaveDays ?? 0;

      final approvedSnapshot = await FirebaseFirestore.instance
          .collection('annual_leave_requests')
          .where('requesterId', isEqualTo: user.id)
          .where('status', whereIn: ['approved', 'submitted'])
          .get();

      var used = 0;
      for (final doc in approvedSnapshot.docs) {
        final data = doc.data();
        final start = (data['startDate'] as Timestamp?)?.toDate();
        final end = (data['endDate'] as Timestamp?)?.toDate();
        if (start != null && end != null) {
          used += _countWeekdays(start, end);
        } else {
          used += (data['totalDays'] as int?) ?? 0;
        }
      }

      if (mounted) {
        setState(() {
          _annualLeaveDays = annualLeaveDays;
          _usedLeaveDays = used;
          _employeeId = staff.employeeId;
          _position = staff.position;
          _email = user.email;
          _loadingBalance = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _annualLeaveDays = 0;
          _usedLeaveDays = 0;
          _employeeId = null;
          _position = null;
          _email = user.email;
          _loadingBalance = false;
        });
      }
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) return;
    if (_startDate == null || _endDate == null) return;

    final totalDays = _totalDays ?? 0;
    if (totalDays <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected dates do not include any weekdays'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_availableLeaveDays < totalDays) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Insufficient annual leave. Available: $_availableLeaveDays days.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final payload = AnnualLeaveRequest(
        id: '',
        requesterId: user.id,
        requesterName: user.name,
        department: user.department,
        employeeId: _employeeId,
        position: _position,
        email: _email,
        startDate: _startDate!,
        endDate: _endDate!,
        totalDays: totalDays,
        reason: _reasonController.text.trim(),
        status: 'submitted',
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('annual_leave_requests')
          .add(payload.toFirestore());

      if (mounted) {
        setState(() {
          _reasonController.clear();
          _startDate = null;
          _endDate = null;
        });
        await _loadLeaveBalance();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leave request submitted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseException catch (e) {
      final message = e.code == 'permission-denied'
          ? 'Permission denied. Please contact HR/Admin.'
          : 'Failed to submit request: ${e.message ?? e.code}';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _printRequest(AnnualLeaveRequest request) async {
    final service = AnnualLeavePdfService();
    final bytes = await service.buildPdf(request);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    final dateFormat = DateFormat('MMM dd, yyyy');
    final spacing = ResponsiveHelper.getSpacing(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: ResponsiveContainer(
          child: SingleChildScrollView(
            child: _buildPageWithHeader(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Request Details',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickDate(isStart: true),
                                  icon: const Icon(Icons.date_range),
                                  label: Text(
                                    _startDate == null
                                        ? 'Start Date'
                                        : dateFormat.format(_startDate!),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _startDate == null
                                      ? null
                                      : () => _pickDate(isStart: false),
                                  icon: const Icon(Icons.date_range),
                                  label: Text(
                                    _endDate == null
                                        ? 'End Date'
                                        : dateFormat.format(_endDate!),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_totalDays != null) ...[
                            const SizedBox(height: 8),
                            Text('Weekdays: $_totalDays'),
                          ],
                          const SizedBox(height: 8),
                          _loadingBalance
                              ? const LinearProgressIndicator(minHeight: 2)
                              : Row(
                                  children: [
                                    Text(
                                      'Annual Leave: $_annualLeaveDays',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Used: $_usedLeaveDays',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Available: $_availableLeaveDays',
                                      style: TextStyle(
                                        color: _availableLeaveDays > 0
                                            ? Colors.teal.shade700
                                            : Colors.red.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _reasonController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Reason',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a reason';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _submitting ? null : _submitRequest,
                              icon: _submitting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send),
                              label: const Text('Submit Request'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: spacing),
                Text(
                  'My Requests',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('annual_leave_requests')
                      .where('requesterId', isEqualTo: user.id)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          'Failed to load requests: ${snapshot.error}',
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data?.docs ?? [];
                    final sortedDocs = List.of(docs)
                      ..sort((a, b) {
                        final aTime =
                            (a.data()['createdAt'] as Timestamp?)?.toDate() ??
                                DateTime.fromMillisecondsSinceEpoch(0);
                        final bTime =
                            (b.data()['createdAt'] as Timestamp?)?.toDate() ??
                                DateTime.fromMillisecondsSinceEpoch(0);
                        return bTime.compareTo(aTime);
                      });
                    if (docs.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Center(
                          child: Text(
                            'No leave requests yet',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: sortedDocs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final request =
                            AnnualLeaveRequest.fromFirestore(sortedDocs[index]);
                        final statusColor = request.status == 'approved'
                            ? Colors.green
                            : request.status == 'rejected'
                                ? Colors.red
                                : Colors.orange;
                        return Card(
                          elevation: 1,
                          child: ListTile(
                            title: Text(
                              '${dateFormat.format(request.startDate)} → ${dateFormat.format(request.endDate)}',
                            ),
                            subtitle: Text(
                              '${request.totalDays} days • ${request.reason}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Wrap(
                              spacing: 8,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    request.status.toUpperCase(),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.print),
                                  onPressed: () => _printRequest(request),
                                  tooltip: 'Print',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageWithHeader({required Widget child}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildWelcomeHeader(),
        ),
        child,
      ],
    );
  }

  Widget _buildWelcomeHeader() {
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
              _buildHeaderActionButton(
                icon: Icons.arrow_back,
                tooltip: 'Back to Dashboard',
                onPressed: () => context.go('/admin-hub'),
              ),
              _buildHeaderActionButton(
                icon: Icons.home_outlined,
                tooltip: 'Home',
                onPressed: () => context.go('/admin-hub'),
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
                  Icons.event_available,
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
                      'Annual Leave Request',
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Submit and track your leave requests',
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
}
