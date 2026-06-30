import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/app_drawer.dart';

class StudentReportsListScreen extends StatefulWidget {
  const StudentReportsListScreen({super.key});

  @override
  State<StudentReportsListScreen> createState() =>
      _StudentReportsListScreenState();
}

class _StudentReportsListScreenState extends State<StudentReportsListScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reports = [];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    final userId =
        Provider.of<AuthProvider>(context, listen: false).currentUser?.id ?? '';

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('student_monthly_reports')
          .where('studentId', isEqualTo: userId)
          .orderBy('month', descending: true)
          .get(const GetOptions(source: Source.server));

      final reports = snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();

      // Sort by periodStart descending when available
      reports.sort((a, b) {
        final aStart = a['periodStart'];
        final bStart = b['periodStart'];
        if (aStart is Timestamp && bStart is Timestamp) {
          return bStart.compareTo(aStart);
        }
        final aMonth = a['month'] ?? '';
        final bMonth = b['month'] ?? '';
        return bMonth.compareTo(aMonth);
      });

      if (mounted) {
        setState(() {
          _reports = reports;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading reports: $e')),
        );
      }
    }
  }

  String _formatPeriod(Map<String, dynamic> data) {
    final startRaw = data['periodStart'];
    final endRaw = data['periodEnd'];
    if (startRaw is Timestamp && endRaw is Timestamp) {
      final fmt = DateFormat('MMM dd, yyyy');
      return '${fmt.format(startRaw.toDate())} – ${fmt.format(endRaw.toDate())}';
    }
    return data['monthDisplay'] ?? data['month'] ?? 'Unknown';
  }

  // ─── Top bar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildTopBar(BuildContext context) {
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'My Reports',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Monthly report history',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh,
                            color: Colors.white, size: 20),
                        tooltip: 'Refresh',
                        onPressed: _loadReports,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add,
                            color: Colors.white, size: 22),
                        tooltip: 'New Report',
                        onPressed: () =>
                            context.push('/student-report/new').then((_) => _loadReports()),
                      ),
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

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hPad = ResponsiveHelper.getScreenPadding(context).left;

    return Scaffold(
      appBar: _buildTopBar(context),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveContainer(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadReports,
                      child: _reports.isEmpty
                          ? _buildEmpty(hPad)
                          : ListView.builder(
                              padding: EdgeInsets.symmetric(
                                horizontal: hPad,
                                vertical: 16,
                              ),
                              itemCount: _reports.length,
                              itemBuilder: (context, index) =>
                                  _buildReportCard(_reports[index]),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEmpty(double hPad) {
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
      children: [
        const SizedBox(height: 100),
        Center(
          child: Column(
            children: [
              Icon(Icons.description_outlined,
                  size: 72, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'No reports yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap + to create your first monthly report',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context
                    .push('/student-report/new')
                    .then((_) => _loadReports()),
                icon: const Icon(Icons.add),
                label: const Text('New Report'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final cs = Theme.of(context).colorScheme;
    final status = report['status'] ?? 'draft';
    final totalHours = (report['totalHours'] ?? 0.0).toDouble();
    final totalAmount = (report['totalAmount'] ?? 0.0).toDouble();
    final timesheetCount = (report['timesheetCount'] ?? 0) as int;
    final submittedAt = report['submittedAt'] is Timestamp
        ? (report['submittedAt'] as Timestamp).toDate()
        : null;
    final periodLabel = _formatPeriod(report);

    final (Color statusColor, IconData statusIcon) = switch (status) {
      'approved' => (Colors.green, Icons.check_circle),
      'rejected' => (Colors.red, Icons.cancel),
      'paid' => (Colors.blue, Icons.payments),
      'submitted' => (Colors.orange, Icons.pending),
      _ => (Colors.grey, Icons.edit_document),
    };

    final paymentStatus = report['paymentStatus'] as String? ?? 'not_paid';
    final (Color payColor, String payLabel, IconData payIcon) = switch (paymentStatus) {
      'paid' => (Colors.green, 'PAID', Icons.check_circle_outline),
      'review' => (Colors.orange, 'IN REVIEW', Icons.pending_outlined),
      _ => (Colors.grey, 'UNPAID', Icons.money_off_outlined),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push(
          '/student-monthly-report-detail',
          extra: {
            'reportId': report['id'],
            'month': report['month'] ?? '',
            'monthDisplay': periodLabel,
          },
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ──────────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.calendar_month,
                        color: cs.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          periodLabel,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (submittedAt != null)
                          Text(
                            'Submitted ${DateFormat('MMM d, yyyy').format(submittedAt)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Status + payment chips
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: statusColor.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 13, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: payColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: payColor.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(payIcon, size: 11, color: payColor),
                            const SizedBox(width: 3),
                            Text(
                              payLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: payColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const Divider(height: 20),

              // ── Stats row ───────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat(Icons.event_note, '$timesheetCount',
                      'Entries', Colors.purple),
                  _buildStat(Icons.access_time,
                      '${totalHours.toStringAsFixed(1)} h', 'Hours', cs.primary),
                  _buildStat(Icons.attach_money,
                      '฿${totalAmount.toStringAsFixed(2)}', 'Amount',
                      Colors.green),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(
      IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}
