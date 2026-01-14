import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/traveling_report.dart';
import '../../models/traveling_per_diem_entry.dart';
import '../../services/firestore_service.dart';
import '../../services/traveling_report_export_service.dart';
import '../../providers/auth_provider.dart';

class AdminTravelingReportDetailScreen extends StatefulWidget {
  final String reportId;

  const AdminTravelingReportDetailScreen({super.key, required this.reportId});

  @override
  State<AdminTravelingReportDetailScreen> createState() =>
      _AdminTravelingReportDetailScreenState();
}

class _AdminTravelingReportDetailScreenState
    extends State<AdminTravelingReportDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TravelingReportExportService _exportService =
      TravelingReportExportService();

  Future<void> _approveReport(TravelingReport report) async {
    if (report.status != 'submitted') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Can only approve submitted reports'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Report'),
        content: const Text('Are you sure you want to approve this report?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _firestoreService.approveTravelingReport(report.id, user.name);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report approved successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error approving report: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _rejectReport(TravelingReport report) async {
    if (report.status != 'submitted') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Can only reject submitted reports'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final reasonController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a reason'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.of(context).pop(reason);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      try {
        await _firestoreService.rejectTravelingReport(report.id, result);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report rejected'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error rejecting report: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _revertReportToDraft(TravelingReport report) async {
    if (report.status != 'submitted') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Can only revert submitted reports to draft'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revert to Draft'),
        content: const Text(
          'Are you sure you want to revert this report back to draft status? The reporter will be able to edit it again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
            child: const Text('Revert to Draft'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _firestoreService.revertTravelingReportToDraft(report.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report reverted to draft successfully'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error reverting report: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _exportPDF(TravelingReport report) async {
    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Generating PDF...')));

      final filePath = await _exportService.exportTravelingReport(report);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF exported: $filePath'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _printReport(TravelingReport report) async {
    try {
      await _exportService.printTravelingReport(report);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Traveling Report'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.orange.shade400, Colors.orange.shade600],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () => context.go('/dashboard'),
            tooltip: 'Home',
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              final report = await _firestoreService.getTravelingReport(
                widget.reportId,
              );
              if (report == null) return;

              switch (value) {
                case 'revert':
                  _revertReportToDraft(report);
                  break;
                case 'approve':
                  _approveReport(report);
                  break;
                case 'reject':
                  _rejectReport(report);
                  break;
                case 'export':
                  _exportPDF(report);
                  break;
                case 'print':
                  _printReport(report);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'revert',
                child: Row(
                  children: [
                    Icon(Icons.restore, color: Colors.grey, size: 20),
                    SizedBox(width: 12),
                    Text('Revert to Draft'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'approve',
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 12),
                    Text('Approve'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reject',
                child: Row(
                  children: [
                    Icon(Icons.cancel, color: Colors.red, size: 20),
                    SizedBox(width: 12),
                    Text('Reject'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, size: 20),
                    SizedBox(width: 12),
                    Text('Export PDF'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'print',
                child: Row(
                  children: [
                    Icon(Icons.print, size: 20),
                    SizedBox(width: 12),
                    Text('Print'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: FutureBuilder<TravelingReport?>(
        future: _firestoreService.getTravelingReport(widget.reportId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final report = snapshot.data;
          if (report == null) {
            return const Center(child: Text('Report not found'));
          }

          return _buildReportContent(report);
        },
      ),
    );
  }

  Widget _buildReportContent(TravelingReport report) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildReportHeader(report),
              _buildTravelingDetails(report),
              _buildMileageSection(report),
              _buildPerDiemSection(report),
              _buildSummarySection(report),
              if (report.rejectionReason != null) _buildRejectionReason(report),
              if (report.status == 'submitted') _buildApprovalSection(report),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportHeader(TravelingReport report) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final statusColor = _getStatusColor(report.status);
    IconData statusIcon;

    switch (report.status) {
      case 'approved':
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusIcon = Icons.cancel;
        break;
      case 'submitted':
        statusIcon = Icons.pending;
        break;
      default:
        statusIcon = Icons.edit_document;
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.orange.shade400, Colors.orange.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.shade200,
            blurRadius: 12,
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
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.flight_takeoff,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.reportNumber,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateFormat.format(report.reportDate),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 16, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      report.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.person, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reporter',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            report.reporterName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.business, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Department',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            report.department,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (report.approvedBy != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_user,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Approved By',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              report.approvedBy!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTravelingDetails(TravelingReport report) {
    final dateTimeFormat = DateFormat('MMM dd, yyyy HH:mm');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange.shade600, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Traveling Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildDetailRow(Icons.flag, 'Purpose', report.purpose),
          const SizedBox(height: 12),
          _buildDetailRow(Icons.location_on, 'Place', report.placeName),
          const SizedBox(height: 12),
          _buildDetailRow(
            Icons.flight_takeoff,
            'Departure',
            dateTimeFormat.format(report.departureTime),
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            Icons.flight_land,
            'Destination',
            dateTimeFormat.format(report.destinationTime),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDetailRow(
                  Icons.people,
                  'Total Members',
                  report.totalMembers.toString(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDetailRow(
                  Icons.public,
                  'Travel Type',
                  report.travelLocationEnum.displayName,
                ),
              ),
            ],
          ),
          if (report.notes?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _buildDetailRow(Icons.note, 'Notes', report.notes!),
          ],
        ],
      ),
    );
  }

  Widget _buildMileageSection(TravelingReport report) {
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_car, color: Colors.blue.shade600, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Mileage',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: 24),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Table(
              border: TableBorder.symmetric(
                inside: BorderSide(color: Colors.grey.shade200),
              ),
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                  ),
                  children: [
                    _buildTableCell('Start', isHeader: true),
                    _buildTableCell('End', isHeader: true),
                    _buildTableCell('Total KM', isHeader: true),
                    _buildTableCell('Amount', isHeader: true),
                  ],
                ),
                TableRow(
                  children: [
                    _buildTableCell(
                      '${currencyFormat.format(report.mileageStart)} KM',
                    ),
                    _buildTableCell(
                      '${currencyFormat.format(report.mileageEnd)} KM',
                    ),
                    _buildTableCell(
                      '${currencyFormat.format(report.totalKM)} KM',
                    ),
                    _buildTableCell(
                      '฿${currencyFormat.format(report.mileageAmount)}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Rate: 5฿ per kilometer',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerDiemSection(TravelingReport report) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.restaurant, color: Colors.green.shade600, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Per Diem Entries',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: 24),
          FutureBuilder<List<TravelingPerDiemEntry>>(
            future: _firestoreService.getPerDiemEntriesByReport(report.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final entries = snapshot.data!;

              if (entries.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.restaurant_menu,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No per diem entries',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: entries.length,
                separatorBuilder: (context, index) =>
                    Divider(color: Colors.grey.shade200, height: 1),
                itemBuilder: (context, index) {
                  return _buildPerDiemEntryCard(entries[index]);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPerDiemEntryCard(TravelingPerDiemEntry entry) {
    final dateFormat = DateFormat('EEE, MMM dd, yyyy');
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateFormat.format(entry.date),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (entry.hasBreakfast)
                      _buildMealChip('B', 'Breakfast', Colors.amber.shade700),
                    if (entry.hasLunch)
                      _buildMealChip('L', 'Lunch', Colors.orange.shade700),
                    if (entry.hasSupper)
                      _buildMealChip('S', 'Supper', Colors.deepOrange.shade700),
                    if (entry.hasIncidentMeal)
                      _buildMealChip('I', 'Incident', Colors.purple.shade700),
                  ],
                ),
                if (entry.notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.note, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            entry.notes,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
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
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Text(
              '฿${currencyFormat.format(entry.dailyTotalAllMembers)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.green.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealChip(String label, String tooltip, Color color) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildSummarySection(TravelingReport report) {
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.orange.shade400, Colors.orange.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.shade200,
            blurRadius: 12,
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.summarize,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Summary',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.directions_car,
                          color: Colors.white.withValues(alpha: 0.9),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Mileage Total:',
                          style: TextStyle(color: Colors.white, fontSize: 15),
                        ),
                      ],
                    ),
                    Text(
                      '฿${currencyFormat.format(report.mileageAmount)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.restaurant,
                          color: Colors.white.withValues(alpha: 0.9),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Per Diem (${report.perDiemDays} days):',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '฿${currencyFormat.format(report.perDiemTotal)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      color: Colors.orange.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'GRAND TOTAL:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
                Text(
                  '฿${currencyFormat.format(report.grandTotal)}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectionReason(TravelingReport report) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Text(
                'Rejection Reason',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            report.rejectionReason!,
            style: TextStyle(color: Colors.red.shade900),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalSection(TravelingReport report) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Admin Actions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _approveReport(report),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _rejectReport(report),
                  icon: const Icon(Icons.cancel),
                  label: const Text('Reject'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          fontSize: isHeader ? 14 : 13,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.grey;
      case 'submitted':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'closed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
