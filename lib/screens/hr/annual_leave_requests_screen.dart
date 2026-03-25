import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../models/annual_leave_request.dart';
import '../../providers/auth_provider.dart';
import '../../services/annual_leave_pdf_service.dart';
import '../../utils/responsive_helper.dart';

class AnnualLeaveRequestsScreen extends StatefulWidget {
  const AnnualLeaveRequestsScreen({super.key});

  @override
  State<AnnualLeaveRequestsScreen> createState() =>
      _AnnualLeaveRequestsScreenState();
}

class _AnnualLeaveRequestsScreenState extends State<AnnualLeaveRequestsScreen> {
  bool _isBackfilling = false;

  Future<void> _backfillStaffInfo() async {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.canManageUsers()) return;

    setState(() => _isBackfilling = true);
    int updated = 0;
    int skipped = 0;

    try {
      final firestore = FirebaseFirestore.instance;
      final requests = await firestore
          .collection('annual_leave_requests')
          .get();

      for (final doc in requests.docs) {
        final data = doc.data();
        final requesterId = data['requesterId'] as String?;
        if (requesterId == null || requesterId.isEmpty) {
          skipped++;
          continue;
        }

        final hasAll = (data['employeeId'] as String?)?.isNotEmpty == true &&
            (data['position'] as String?)?.isNotEmpty == true &&
            (data['email'] as String?)?.isNotEmpty == true;
        if (hasAll) {
          skipped++;
          continue;
        }

        final staffSnapshot = await firestore
            .collection('staff')
            .where('userId', isEqualTo: requesterId)
            .limit(1)
            .get();
        if (staffSnapshot.docs.isEmpty) {
          skipped++;
          continue;
        }

        final staffData = staffSnapshot.docs.first.data();
        final updates = <String, dynamic>{};
        final employeeId = staffData['employeeId'] as String?;
        final position = staffData['position'] as String?;
        final email = staffData['email'] as String?;

        if ((data['employeeId'] as String?)?.isNotEmpty != true &&
            employeeId != null &&
            employeeId.isNotEmpty) {
          updates['employeeId'] = employeeId;
        }
        if ((data['position'] as String?)?.isNotEmpty != true &&
            position != null &&
            position.isNotEmpty) {
          updates['position'] = position;
        }
        if ((data['email'] as String?)?.isNotEmpty != true &&
            email != null &&
            email.isNotEmpty) {
          updates['email'] = email;
        }

        if (updates.isNotEmpty) {
          updates['updatedAt'] = Timestamp.now();
          await firestore.collection('annual_leave_requests').doc(doc.id).update(
                updates,
              );
          updated++;
        } else {
          skipped++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backfill complete: $updated updated, $skipped skipped'),
            backgroundColor: updated > 0 ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backfill failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBackfilling = false);
    }
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

  Future<void> _approveRequest(AnnualLeaveRequest request) async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) return;

    final actionController = TextEditingController(
      text: request.actionNumber ?? '',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Optional: enter an Action Number.'),
            const SizedBox(height: 12),
            TextField(
              controller: actionController,
              decoration: const InputDecoration(
                labelText: 'Action Number',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await FirebaseFirestore.instance
        .collection('annual_leave_requests')
        .doc(request.id)
        .update({
      'status': 'approved',
      'approvedBy': user.name,
      'approvedAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
      'actionNumber': actionController.text.trim().isEmpty
          ? null
          : actionController.text.trim(),
      'rejectionReason': null,
    });
  }

  Future<void> _editActionNumber(AnnualLeaveRequest request) async {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.canManageUsers()) return;

    final controller = TextEditingController(
      text: request.actionNumber ?? '',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Action Number'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Action Number',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await FirebaseFirestore.instance
        .collection('annual_leave_requests')
        .doc(request.id)
        .update({
      'actionNumber': controller.text.trim().isEmpty
          ? null
          : controller.text.trim(),
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> _rejectRequest(AnnualLeaveRequest request) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a rejection reason.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final reason = controller.text.trim();
    if (reason.isEmpty) return;

    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('annual_leave_requests')
        .doc(request.id)
        .update({
      'status': 'rejected',
      'approvedBy': user.name,
      'approvedAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
      'rejectionReason': reason,
    });
  }

  Future<void> _printRequest(AnnualLeaveRequest request) async {
    final service = AnnualLeavePdfService();
    final bytes = await service.buildPdf(request);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Widget _buildSimpleHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade600, Colors.cyan.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => context.pop(),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => context.go('/admin-hub'),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.home_outlined, color: Colors.white, size: 20),
                ),
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
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.event_available, size: 40, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Annual Leave Requests',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Review and approve annual leave',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final canManage = authProvider.canManageUsers();

    if (!canManage) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: SingleChildScrollView(
          child: ResponsiveContainer(
            padding: ResponsiveHelper.getScreenPadding(context).copyWith(
              top: MediaQuery.of(context).padding.top + 16,
            ),
            child: Column(
              children: [
                _buildSimpleHeader(),
                const SizedBox(height: 100),
                Icon(Icons.lock_outline, size: 48, color: Colors.red.shade300),
                const SizedBox(height: 12),
                const Text(
                  'Access Denied',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'You do not have permission to review leave requests.',
                  style: TextStyle(color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final dateFormat = DateFormat('MMM dd, yyyy');
    final spacing = ResponsiveHelper.getSpacing(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: ResponsiveContainer(
          padding: ResponsiveHelper.getScreenPadding(context).copyWith(
            top: MediaQuery.of(context).padding.top + 16,
          ),
          child: _buildPageWithHeader(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pending & Reviewed Requests',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: spacing),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('annual_leave_requests')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data?.docs ?? [];
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
                            'No leave requests found',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: docs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final request =
                            AnnualLeaveRequest.fromFirestore(docs[index]);
                        final statusColor = request.status == 'approved'
                            ? Colors.green
                            : request.status == 'rejected'
                                ? Colors.red
                                : Colors.orange;
                        final isPending = request.status == 'submitted';

                        return Card(
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        request.requesterName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
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
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${dateFormat.format(request.startDate)} → ${dateFormat.format(request.endDate)} (${_countWeekdays(request.startDate, request.endDate)} weekdays)',
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Department: ${request.department}',
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  request.reason,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_note),
                                      onPressed: () =>
                                          _editActionNumber(request),
                                      tooltip: 'Edit Action Number',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.print),
                                      onPressed: () => _printRequest(request),
                                      tooltip: 'Print',
                                    ),
                                    if (isPending) ...[
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () =>
                                            _approveRequest(request),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Approve'),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton(
                                        onPressed: () =>
                                            _rejectRequest(request),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                        child: const Text('Reject'),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
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
              Row(
                children: [
                  _buildHeaderActionButton(
                    icon: Icons.manage_search,
                    tooltip: 'Backfill Staff Info',
                    onPressed: _isBackfilling ? () {} : _backfillStaffInfo,
                  ),
                  const SizedBox(width: 8),
                  _buildHeaderActionButton(
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
                      'Leave Requests',
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Review and approve annual leave',
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
