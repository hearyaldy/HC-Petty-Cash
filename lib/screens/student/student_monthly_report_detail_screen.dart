import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' as excel_package;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/student_timesheet.dart';
import '../../providers/auth_provider.dart';
import '../../utils/responsive_helper.dart';
import '../../services/student_pdf_export_service.dart';

class StudentMonthlyReportDetailScreen extends StatefulWidget {
  final String reportId;
  final String month;
  final String monthDisplay;

  const StudentMonthlyReportDetailScreen({
    super.key,
    required this.reportId,
    required this.month,
    required this.monthDisplay,
  });

  @override
  State<StudentMonthlyReportDetailScreen> createState() =>
      _StudentMonthlyReportDetailScreenState();
}

class _StudentMonthlyReportDetailScreenState
    extends State<StudentMonthlyReportDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _reportData;
  List<StudentTimesheet> _timesheets = [];

  @override
  void initState() {
    super.initState();
    _loadReportDetails();
  }

  Future<void> _loadReportDetails() async {
    setState(() => _isLoading = true);

    try {
      // Load the monthly report
      final reportDoc = await FirebaseFirestore.instance
          .collection('student_monthly_reports')
          .doc(widget.reportId)
          .get();

      if (reportDoc.exists) {
        _reportData = reportDoc.data() as Map<String, dynamic>;

        // Load associated timesheets
        final timesheetQuery = await FirebaseFirestore.instance
            .collection('student_timesheets')
            .where('reportId', isEqualTo: widget.reportId)
            .orderBy('date', descending: false)
            .get();

        _timesheets = timesheetQuery.docs
            .map((doc) => StudentTimesheet.fromFirestore(doc))
            .toList();
      }
    } catch (e) {
      print('Error loading report details: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _generatePdf() async {
    // Get student profile to get grade
    String? grade;
    try {
      final studentProfileDoc = await FirebaseFirestore.instance
          .collection('student_profiles')
          .doc(_reportData?['studentId'])
          .get();

      if (studentProfileDoc.exists) {
        final profileData = studentProfileDoc.data() as Map<String, dynamic>;
        grade = profileData['grade'];
      }
    } catch (e) {
      print('Error getting student profile: $e');
    }

    // Get student profile to get additional fields
    String? course, yearLevel, phoneNumber, language, role;
    try {
      final studentProfileDoc = await FirebaseFirestore.instance
          .collection('student_profiles')
          .doc(_reportData?['studentId'])
          .get();

      if (studentProfileDoc.exists) {
        final profileData = studentProfileDoc.data() as Map<String, dynamic>;
        course = profileData['course'];
        yearLevel = profileData['yearLevel'];
        phoneNumber = profileData['phoneNumber'];
        language = profileData['language'];
        role = profileData['role'];
      }
    } catch (e) {
      print('Error getting student profile: $e');
    }

    final service = StudentPdfExportService();
    final pdfBytes = await service.exportStudentReport(
      studentName: _reportData?['studentName'] ?? 'Unknown',
      studentNumber: _reportData?['studentNumber'] ?? 'Unknown',
      monthDisplay: widget.monthDisplay,
      reportId: widget.reportId,
      status: _reportData?['status'] ?? 'draft',
      hourlyRate: _reportData?['hourlyRate'] ?? 0.0,
      timesheets: _timesheets,
      grade: grade,
      course: course,
      yearLevel: yearLevel,
      phoneNumber: phoneNumber,
      language: language,
      role: role,
      paymentStatus: _reportData?['paymentStatus'] ?? 'not_paid',
    );

    // Show the PDF using the printing package
    await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
  }

  Future<void> _generateExcel() async {
    final excel = excel_package.Excel.createExcel();
    final sheet =
        excel['Student_Labour_Report_${widget.monthDisplay.replaceAll(' ', '_')}'];

    var rowIndex = 0;

    // Header
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'Student Labour Report - ${widget.monthDisplay}',
    );
    rowIndex++;

    rowIndex++; // Empty row

    // Report Info
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'Student:',
    );
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      _reportData?['studentName'] ?? '',
    );
    rowIndex++;

    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'Student ID:',
    );
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      _reportData?['studentId'] ?? '',
    );
    rowIndex++;

    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'Report Period:',
    );
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      widget.monthDisplay,
    );
    rowIndex++;

    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'Report ID:',
    );
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      widget.reportId,
    );
    rowIndex++;

    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'Status:',
    );
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      _reportData?['status'] ?? 'Unknown',
    );
    rowIndex++;

    rowIndex++; // Empty row

    // Summary
    final timesheetCount = _timesheets.length;
    final totalHours = _timesheets.fold<double>(
      0.0,
      (sum, ts) => sum + ts.totalHours,
    );
    final hourlyRate = _reportData?['hourlyRate'] ?? 0.0;
    final totalAmount = totalHours * hourlyRate;

    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'SUMMARY',
    );
    rowIndex++;

    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'Entries',
    );
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'Total Hours',
    );
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 2,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'Hourly Rate',
    );
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 3,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'Total Amount',
    );
    rowIndex++;

    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.IntCellValue(
      timesheetCount,
    );
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      totalHours.toStringAsFixed(2),
    );
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 2,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      '฿${hourlyRate.toStringAsFixed(2)}/h',
    );
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 3,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      '฿${totalAmount.toStringAsFixed(2)}',
    );
    rowIndex++;

    rowIndex++; // Empty row

    // Detailed entries
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'DETAILED TIMESHEET ENTRIES',
    );
    rowIndex++;

    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'Date',
    );
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'Start Time',
    );
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 2,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'End Time',
    );
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 3,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'Task',
    );
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 4,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'Hours',
    );
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 5,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'Amount',
    );
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 6,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'Status',
    );
    rowIndex++;

    for (final ts in _timesheets) {
      sheet
          .cell(
            excel_package.CellIndex.indexByColumnRow(
              columnIndex: 0,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_package.TextCellValue(
        DateFormat('dd/MM/yyyy').format(ts.date),
      );
      sheet
          .cell(
            excel_package.CellIndex.indexByColumnRow(
              columnIndex: 1,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_package.TextCellValue(
        DateFormat('HH:mm').format(ts.startTime),
      );
      sheet
          .cell(
            excel_package.CellIndex.indexByColumnRow(
              columnIndex: 2,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_package.TextCellValue(
        DateFormat('HH:mm').format(ts.endTime),
      );
      sheet
          .cell(
            excel_package.CellIndex.indexByColumnRow(
              columnIndex: 3,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_package.TextCellValue(
        ts.task,
      );
      sheet
          .cell(
            excel_package.CellIndex.indexByColumnRow(
              columnIndex: 4,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_package.TextCellValue(
        ts.totalHours.toStringAsFixed(2),
      );
      sheet
          .cell(
            excel_package.CellIndex.indexByColumnRow(
              columnIndex: 5,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_package.TextCellValue(
        ts.totalAmount.toStringAsFixed(2),
      );
      sheet
          .cell(
            excel_package.CellIndex.indexByColumnRow(
              columnIndex: 6,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_package.TextCellValue(
        ts.status,
      );
      rowIndex++;
    }

    // Save the Excel file
    final bytes = excel.save();
    if (bytes != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: Text('Download Excel')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.file_download, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text('Excel file generated successfully!'),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // In a real app, you would save the file to device storage
                      // For now, we'll just show a success message
                      Navigator.of(context).pop();
                    },
                    child: Text('Download File'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Report Details - ${widget.monthDisplay}'),
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
          PopupMenuButton<String>(
            icon: Icon(Icons.print),
            onSelected: (value) {
              if (value == 'print') {
                _generatePdf();
              } else if (value == 'pdf') {
                _generatePdf();
              } else if (value == 'excel') {
                _generateExcel();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'print',
                child: Row(
                  children: [
                    Icon(Icons.print, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Print Report'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Export as PDF'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'excel',
                child: Row(
                  children: [
                    Icon(Icons.table_chart, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Export as Excel'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ],
      ),
      floatingActionButton: (_reportData?['status'] ?? 'draft') == 'draft'
          ? FloatingActionButton.extended(
              onPressed: _showAddTimesheetDialog,
              backgroundColor: Colors.orange.shade600,
              icon: const Icon(Icons.add),
              label: const Text('Add Time Entry'),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reportData == null
          ? const Center(child: Text('Report not found'))
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final timesheetCount = _timesheets.length;
    final totalHours = _timesheets.fold<double>(
      0.0,
      (sum, ts) => sum + ts.totalHours,
    );
    final hourlyRate = _reportData?['hourlyRate'] ?? 0.0;
    final totalAmount = totalHours * hourlyRate;

    return SingleChildScrollView(
      child: ResponsiveContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Report Header - Extended with Student Information
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
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
                  // Title Row with Status Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.description,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Student Labour Report',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_month,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Period: ${widget.monthDisplay}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Status Badge
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getStatusIcon(_reportData?['status']),
                              color: _getStatusColor(_reportData?['status']),
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _reportData?['status']?.toUpperCase() ?? 'DRAFT',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(_reportData?['status']),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Divider
                  Container(height: 1, color: Colors.white.withOpacity(0.3)),

                  const SizedBox(height: 20),

                  // Student Information Grid
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Student Information',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Row 1: Name and Student Number
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoRow(
                              Icons.person,
                              'Student Name',
                              _reportData?['studentName'] ?? 'N/A',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInfoRow(
                              Icons.badge,
                              'Student Number',
                              _reportData?['studentNumber'] ?? 'N/A',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Row 2: Email and Department
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoRow(
                              Icons.email,
                              'Email',
                              _reportData?['studentEmail'] ?? 'N/A',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInfoRow(
                              Icons.business,
                              'Department',
                              _reportData?['department'] ?? 'N/A',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Row 3: Report ID and Hourly Rate
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoRow(
                              Icons.fingerprint,
                              'Report ID',
                              '${widget.reportId.substring(0, 8)}...',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInfoRow(
                              Icons.attach_money,
                              'Hourly Rate',
                              '฿${hourlyRate.toStringAsFixed(2)}/hr',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.event_note, color: Colors.orange.shade700),
                        const SizedBox(height: 8),
                        Text(
                          '$timesheetCount',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Entries',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.access_time, color: Colors.blue.shade700),
                        const SizedBox(height: 8),
                        Text(
                          totalHours.toStringAsFixed(2),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hours',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.attach_money, color: Colors.green.shade700),
                        const SizedBox(height: 8),
                        Text(
                          '฿${totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getStatusColor(_reportData?['status']).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getStatusColor(
                    _reportData?['status'],
                  ).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(_reportData?['status']),
                    color: _getStatusColor(_reportData?['status']),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Status: ${_reportData?['status']?.toUpperCase() ?? 'UNKNOWN'}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(_reportData?['status']),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Detailed Table/Card View (responsive)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Detailed Timesheet Entries',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_timesheets.length} entries',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Use LayoutBuilder to detect screen size
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;

                      if (isMobile) {
                        // Card-based layout for mobile
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(12),
                          itemCount: _timesheets.length,
                          itemBuilder: (context, index) {
                            final ts = _timesheets[index];
                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Date and Status Row
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.calendar_today,
                                              size: 16,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              DateFormat(
                                                'dd MMM yyyy',
                                              ).format(ts.date),
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(
                                              ts.status,
                                            ).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            ts.status.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: _getStatusColor(ts.status),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Divider(
                                      height: 1,
                                      color: Colors.grey.shade200,
                                    ),
                                    const SizedBox(height: 12),

                                    // Time Range
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 16,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Time:',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${DateFormat('HH:mm').format(ts.startTime)} - ${DateFormat('HH:mm').format(ts.endTime)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Task Description
                                    if (ts.task.isNotEmpty) ...[
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.task_alt,
                                            size: 16,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Task:',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey[600],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  ts.task,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                    ],

                                    // Hours and Amount Row
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.schedule,
                                              size: 16,
                                              color: Colors.blue.shade600,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Hours:',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${ts.totalHours.toStringAsFixed(2)} h',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.attach_money,
                                              size: 16,
                                              color: Colors.green.shade600,
                                            ),
                                            Text(
                                              '฿${ts.totalAmount.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      } else {
                        // Table layout for larger screens
                        return Column(
                          children: [
                            // Table Header
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Date',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Time Range',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        'Task',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        'Hours',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        'Amount',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        'Status',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Table Rows
                            ListView.builder(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemCount: _timesheets.length,
                              itemBuilder: (context, index) {
                                final ts = _timesheets[index];
                                return Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: index == _timesheets.length - 1
                                            ? Colors.transparent
                                            : Colors.grey.shade200,
                                      ),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            DateFormat(
                                              'dd/MM/yyyy',
                                            ).format(ts.date),
                                            style: TextStyle(fontSize: 14),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            '${DateFormat('HH:mm').format(ts.startTime)} - ${DateFormat('HH:mm').format(ts.endTime)}',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            ts.task,
                                            style: TextStyle(fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 2,
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            '${ts.totalHours.toStringAsFixed(2)} h',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            '฿${ts.totalAmount.toStringAsFixed(2)}',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(
                                                ts.status,
                                              ).withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              ts.status.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: _getStatusColor(
                                                  ts.status,
                                                ),
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Submit Button (only show for draft status)
            if ((_reportData?['status'] ?? 'draft') == 'draft' &&
                _timesheets.isNotEmpty)
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade500, Colors.green.shade700],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.shade200,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _submitReport,
                    borderRadius: BorderRadius.circular(12),
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send, color: Colors.white),
                          SizedBox(width: 12),
                          Text(
                            'Submit Report for Approval',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Info message for draft reports
            if ((_reportData?['status'] ?? 'draft') == 'draft' &&
                _timesheets.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Add at least one time entry before submitting your report',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Status message for submitted reports
            if ((_reportData?['status'] ?? 'draft') != 'draft')
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This report has been submitted and cannot be edited',
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'paid':
        return Colors.blue;
      case 'submitted':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'paid':
        return Icons.payment;
      case 'submitted':
        return Icons.pending;
      default:
        return Icons.help_outline;
    }
  }

  Future<void> _showAddTimesheetDialog() async {
    DateTime? selectedDate;
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    final taskController = TextEditingController();
    final notesController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.access_time, color: Colors.orange.shade600),
                const SizedBox(width: 12),
                const Text('Add Time Entry'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Picker
                  Text(
                    'Date',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      // Parse month to get valid date range
                      final monthParts = widget.month.split('-');
                      final year = int.parse(monthParts[0]);
                      final month = int.parse(monthParts[1]);
                      final firstDay = DateTime(year, month, 1);
                      final lastDay = DateTime(year, month + 1, 0);

                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: firstDay,
                        lastDate: lastDay,
                      );
                      if (date != null) {
                        setDialogState(() => selectedDate = date);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedDate == null
                                ? 'Select date'
                                : DateFormat(
                                    'MMM dd, yyyy',
                                  ).format(selectedDate!),
                          ),
                          const Icon(Icons.calendar_today, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Start Time
                  Text(
                    'Start Time',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: startTime ?? TimeOfDay.now(),
                      );
                      if (time != null) {
                        setDialogState(() => startTime = time);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            startTime == null
                                ? 'Select start time'
                                : startTime!.format(context),
                          ),
                          const Icon(Icons.access_time, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // End Time
                  Text(
                    'End Time',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: endTime ?? TimeOfDay.now(),
                      );
                      if (time != null) {
                        setDialogState(() => endTime = time);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            endTime == null
                                ? 'Select end time'
                                : endTime!.format(context),
                          ),
                          const Icon(Icons.access_time, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Task Description (Required)
                  Text(
                    'Task Description *',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: taskController,
                    decoration: InputDecoration(
                      labelText: 'Task *',
                      hintText: 'Describe the work or task completed',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      errorText: null,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),

                  // Notes
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: 'Notes (Optional)',
                      hintText: 'Add any notes about this time entry',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedDate == null ||
                      startTime == null ||
                      endTime == null ||
                      taskController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill in all required fields'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  // Calculate hours
                  final start = DateTime(
                    selectedDate!.year,
                    selectedDate!.month,
                    selectedDate!.day,
                    startTime!.hour,
                    startTime!.minute,
                  );
                  final end = DateTime(
                    selectedDate!.year,
                    selectedDate!.month,
                    selectedDate!.day,
                    endTime!.hour,
                    endTime!.minute,
                  );
                  final duration = end.difference(start);
                  final hours = duration.inMinutes / 60.0;

                  if (hours <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('End time must be after start time'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  // Create timesheet entry
                  final timesheetRef = FirebaseFirestore.instance
                      .collection('student_timesheets')
                      .doc();

                  final hourlyRate = _reportData?['hourlyRate'] ?? 0.0;
                  final timesheet = StudentTimesheet(
                    id: timesheetRef.id,
                    studentId: _reportData!['studentId'],
                    studentName: _reportData!['studentName'],
                    studentEmail: _reportData!['studentEmail'],
                    department: _reportData!['department'] ?? '',
                    studentNumber: _reportData!['studentNumber'] ?? '',
                    date: selectedDate!,
                    startTime: start,
                    endTime: end,
                    totalHours: hours,
                    hourlyRate: hourlyRate,
                    totalAmount: hours * hourlyRate,
                    status: 'draft',
                    task: taskController.text.trim(),
                    notes: notesController.text.isNotEmpty
                        ? notesController.text
                        : null,
                    createdAt: DateTime.now(),
                    reportId: widget.reportId,
                    reportMonth: widget.month,
                  );

                  await timesheetRef.set(timesheet.toFirestore());

                  // Update report totals
                  await _updateReportTotals();

                  Navigator.pop(context);
                  _loadReportDetails();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Time entry added successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add Entry'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateReportTotals() async {
    final timesheetQuery = await FirebaseFirestore.instance
        .collection('student_timesheets')
        .where('reportId', isEqualTo: widget.reportId)
        .get();

    final timesheets = timesheetQuery.docs
        .map((doc) => StudentTimesheet.fromFirestore(doc))
        .toList();

    final totalHours = timesheets.fold<double>(
      0.0,
      (sum, ts) => sum + ts.totalHours,
    );
    final hourlyRate = _reportData?['hourlyRate'] ?? 0.0;

    await FirebaseFirestore.instance
        .collection('student_monthly_reports')
        .doc(widget.reportId)
        .update({
          'timesheetCount': timesheets.length,
          'totalHours': totalHours,
          'totalAmount': totalHours * hourlyRate,
        });
  }

  Future<void> _submitReport() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.send, color: Colors.orange.shade600),
            const SizedBox(width: 12),
            const Text('Submit Report?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to submit this report for approval?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You will not be able to edit the report after submission',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
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
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.currentUser;

      // Update report status to submitted
      await FirebaseFirestore.instance
          .collection('student_monthly_reports')
          .doc(widget.reportId)
          .update({
            'status': 'submitted',
            'submittedAt': DateTime.now(),
            'submittedBy': user?.name ?? 'Unknown',
          });

      // Update all associated timesheets to submitted status
      final timesheetQuery = await FirebaseFirestore.instance
          .collection('student_timesheets')
          .where('reportId', isEqualTo: widget.reportId)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in timesheetQuery.docs) {
        batch.update(doc.reference, {'status': 'submitted'});
      }
      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted successfully for approval!'),
          backgroundColor: Colors.green,
        ),
      );

      // Reload the report to show updated status
      _loadReportDetails();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
