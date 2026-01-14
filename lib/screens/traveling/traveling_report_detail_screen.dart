import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/traveling_report.dart';
import '../../models/traveling_per_diem_entry.dart';
import '../../services/firestore_service.dart';
import '../../services/traveling_report_export_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/edit_traveling_report_dialog.dart';
import '../../widgets/traveling_per_diem_entry_dialog.dart';
import '../../widgets/support_document_upload_dialog.dart';

class TravelingReportDetailScreen extends StatefulWidget {
  final String reportId;

  const TravelingReportDetailScreen({super.key, required this.reportId});

  @override
  State<TravelingReportDetailScreen> createState() =>
      _TravelingReportDetailScreenState();
}

class _TravelingReportDetailScreenState
    extends State<TravelingReportDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TravelingReportExportService _exportService =
      TravelingReportExportService();

  Future<void> _editReport(TravelingReport report) async {
    if (report.status != 'draft') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Can only edit draft reports'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EditTravelingReportDialog(
        report: report,
        reporterId: report.reporterId,
        reporterName: report.reporterName,
      ),
    );

    if (result != null && mounted) {
      try {
        final updatedReport = report.copyWith(
          department: result['department'] as String,
          reportDate: result['reportDate'] as DateTime,
          purpose: result['purpose'] as String,
          placeName: result['placeName'] as String,
          departureTime: result['departureTime'] as DateTime,
          destinationTime: result['destinationTime'] as DateTime,
          totalMembers: result['totalMembers'] as int,
          travelLocation: result['travelLocation'] as String,
          mileageStart: result['mileageStart'] as double,
          mileageEnd: result['mileageEnd'] as double,
          notes: result['notes'] as String,
          updatedAt: DateTime.now(),
        );

        await _firestoreService.updateTravelingReport(updatedReport);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating report: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _addPerDiemEntry(TravelingReport report) async {
    if (report.status != 'draft') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Can only add entries to draft reports'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => TravelingPerDiemEntryDialog(report: report),
    );

    if (result != null && mounted) {
      try {
        final entry = TravelingPerDiemEntry.create(
          id: const Uuid().v4(),
          reportId: report.id,
          date: result['date'] as DateTime,
          hasBreakfast: result['hasBreakfast'] as bool,
          hasLunch: result['hasLunch'] as bool,
          hasSupper: result['hasSupper'] as bool,
          hasIncidentMeal: result['hasIncidentMeal'] as bool,
          notes: result['notes'] as String,
          mealRate: report.travelLocationEnum.perDiemRate,
          totalMembers: report.totalMembers,
        );

        await _firestoreService.saveTravelingPerDiemEntry(entry);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Per diem entry added'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error adding entry: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editPerDiemEntry(
    TravelingReport report,
    TravelingPerDiemEntry entry,
  ) async {
    if (report.status != 'draft') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Can only edit entries in draft reports'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          TravelingPerDiemEntryDialog(report: report, entry: entry),
    );

    if (result != null && mounted) {
      try {
        final updatedEntry = TravelingPerDiemEntry.create(
          id: entry.id,
          reportId: report.id,
          date: result['date'] as DateTime,
          hasBreakfast: result['hasBreakfast'] as bool,
          hasLunch: result['hasLunch'] as bool,
          hasSupper: result['hasSupper'] as bool,
          hasIncidentMeal: result['hasIncidentMeal'] as bool,
          notes: result['notes'] as String,
          mealRate: report.travelLocationEnum.perDiemRate,
          totalMembers: report.totalMembers,
        ).copyWith(createdAt: entry.createdAt, updatedAt: DateTime.now());

        await _firestoreService.updateTravelingPerDiemEntry(updatedEntry);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Entry updated'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating entry: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deletePerDiemEntry(
    TravelingReport report,
    TravelingPerDiemEntry entry,
  ) async {
    if (report.status != 'draft') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Can only delete entries from draft reports'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _firestoreService.deleteTravelingPerDiemEntry(entry.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Entry deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting entry: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _submitReport(TravelingReport report) async {
    if (report.status != 'draft') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report already submitted'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if there are per diem entries
    final entries = await _firestoreService.getPerDiemEntriesByReport(
      report.id,
    );
    if (entries.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please add at least one per diem entry before submitting',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user == null) return;

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Report'),
        content: const Text(
          'Are you sure you want to submit this report? You will not be able to edit it after submission.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _firestoreService.submitTravelingReport(report.id, user.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report submitted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error submitting report: $e'),
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

  Future<void> _printTravelingReportVoucher(TravelingReport report) async {
    try {
      await _exportService.printTravelingReportVoucher(report);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing voucher: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSupportDocumentUploadDialog(TravelingReport report) {
    showDialog(
      context: context,
      builder: (context) => SupportDocumentUploadDialog(
        transactionId: report.id,
        existingDocumentUrls: report.supportDocumentUrls,
        onDocumentsUploaded: (urls) async {
          try {
            final updatedReport = report.copyWith(
              supportDocumentUrls: urls,
              updatedAt: DateTime.now(),
            );
            await _firestoreService.updateTravelingReport(updatedReport);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Support documents updated successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error updating support documents: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _showSupportDocument(TravelingReport report) {
    if (report.supportDocumentUrls.isEmpty) return;

    // Show gallery dialog with all support documents
    showDialog(
      context: context,
      builder: (context) => SupportDocumentGallery(
        documentUrls: report.supportDocumentUrls,
        transactionReceiptNo: report.reportNumber,
      ),
    );
  }

  Future<void> _printSupportDocument(TravelingReport report) async {
    if (report.supportDocumentUrls.isEmpty) return;

    // Show selection dialog for choosing which documents to print
    showDialog(
      context: context,
      builder: (context) => SupportDocumentSelectionDialog(
        documentUrls: report.supportDocumentUrls,
        transactionReceiptNo: report.reportNumber,
        description: report.purpose,
        amount: report.perDiemTotal,
      ),
    );
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
                case 'edit':
                  _editReport(report);
                  break;
                case 'submit':
                  _submitReport(report);
                  break;
                case 'export':
                  _exportPDF(report);
                  break;
                case 'print':
                  _printReport(report);
                  break;
                case 'print_voucher':
                  _printTravelingReportVoucher(report);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20),
                    SizedBox(width: 12),
                    Text('Edit Report'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'submit',
                child: Row(
                  children: [
                    Icon(Icons.send, size: 20),
                    SizedBox(width: 12),
                    Text('Submit'),
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
              const PopupMenuItem(
                value: 'print_voucher',
                child: Row(
                  children: [
                    Icon(Icons.receipt, size: 20),
                    SizedBox(width: 12),
                    Text('Print Voucher'),
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
              ],
            ),
          ),
          if (report.supportDocumentUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showSupportDocument(report),
                  icon: const Icon(Icons.attach_file, size: 16),
                  label: Text('View Docs (${report.supportDocumentUrls.length})'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _printSupportDocument(report),
                  icon: const Icon(Icons.print, size: 16),
                  label: const Text('Print Docs'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showSupportDocumentUploadDialog(report),
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text('Upload Support Documents'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.orange.shade700,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              if (report.status == 'draft')
                ElevatedButton.icon(
                  onPressed: () => _addPerDiemEntry(report),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 24),
          StreamBuilder<List<TravelingPerDiemEntry>>(
            stream: _firestoreService.perDiemEntriesByReportStream(report.id),
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
                          'No per diem entries yet',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Click "Add" to create your first entry',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
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
                separatorBuilder: (context, index) => Divider(
                  color: Colors.grey.shade200,
                  height: 1,
                ),
                itemBuilder: (context, index) {
                  return _buildPerDiemEntryCard(report, entries[index]);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPerDiemEntryCard(
    TravelingReport report,
    TravelingPerDiemEntry entry,
  ) {
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
                        Icon(
                          Icons.note,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
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
              if (report.status == 'draft') ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, size: 18, color: Colors.blue.shade600),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => _editPerDiemEntry(report, entry),
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, size: 18, color: Colors.red.shade600),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => _deletePerDiemEntry(report, entry),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              ],
            ],
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
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                          ),
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
