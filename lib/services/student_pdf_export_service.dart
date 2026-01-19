import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/student_timesheet.dart';

class StudentPdfExportService {
  Future<Uint8List> exportStudentReport({
    required String studentName,
    required String studentNumber,
    required String monthDisplay,
    required String reportId,
    required String status,
    required double hourlyRate,
    required List<StudentTimesheet> timesheets,
    required String? grade,
    required String? course,
    required String? yearLevel,
    required String? phoneNumber,
    required String? language,
    required String? role,
    required String? paymentStatus,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('HH:mm');

    final timesheetCount = timesheets.length;
    final totalHours = timesheets.fold<double>(
      0.0,
      (sum, ts) => sum + ts.totalHours,
    );
    final totalAmount = totalHours * hourlyRate;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(studentName, monthDisplay),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildInfoSection(
            studentName: studentName,
            studentNumber: studentNumber,
            monthDisplay: monthDisplay,
            reportId: reportId,
            status: status,
            hourlyRate: hourlyRate,
            grade: grade,
            course: course,
            yearLevel: yearLevel,
            phoneNumber: phoneNumber,
            language: language,
            role: role,
            paymentStatus: paymentStatus,
          ),
          pw.SizedBox(height: 20),

          // Summary
          pw.Text(
            'Summary',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          _buildSummaryTable(
            timesheetCount: timesheetCount,
            totalHours: totalHours,
            hourlyRate: hourlyRate,
            totalAmount: totalAmount,
          ),
          pw.SizedBox(height: 20),

          // Detailed Timesheet Entries
          pw.Text(
            'Detailed Timesheet Entries',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          _buildTimesheetTable(timesheets, dateFormat, timeFormat),
          pw.SizedBox(height: 30),

          // Signature Section
          _buildSignatureSection(),
        ],
      ),
    );

    return await pdf.save();
  }

  pw.Widget _buildHeader(String studentName, String monthDisplay) {
    return pw.Column(
      children: [
        pw.Text(
          'STUDENT LABOUR REPORT',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Student: $studentName',
          style: const pw.TextStyle(fontSize: 12),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Period: $monthDisplay',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.Divider(),
        pw.SizedBox(height: 12),
      ],
    );
  }

  pw.Widget _buildInfoSection({
    required String studentName,
    required String studentNumber,
    required String monthDisplay,
    required String reportId,
    required String status,
    required double hourlyRate,
    required String? grade,
    required String? course,
    required String? yearLevel,
    required String? phoneNumber,
    required String? language,
    required String? role,
    required String? paymentStatus,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Student Information',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            children: [
              pw.TableRow(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Student Name:', studentName),
                        _buildInfoRow('Student Number:', studentNumber),
                        _buildInfoRow('Course:', course ?? 'Not Assigned'),
                        _buildInfoRow('Year Level:', yearLevel ?? 'Not Assigned'),
                        _buildInfoRow('Phone Number:', phoneNumber ?? 'Not Provided'),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Language:', language ?? 'Not Specified'),
                        _buildInfoRow('Role:', role ?? 'Not Assigned'),
                        _buildInfoRow('Grade:', grade ?? 'Not Assigned'),
                        _buildInfoRow('Report Period:', monthDisplay),
                        _buildInfoRow('Report ID:', reportId),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Report Status:', status.toUpperCase()),
                        _buildInfoRow('Payment Status:', _getPaymentStatus(status, paymentStatus)),
                        _buildInfoRow('Hourly Rate:', 'THB ${hourlyRate.toStringAsFixed(2)}/hr'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }

  String _getPaymentStatus(String? reportStatus, String? paymentStatus) {
    // If payment status is explicitly set, use it
    if (paymentStatus != null) {
      switch (paymentStatus.toLowerCase()) {
        case 'paid':
          return 'PAID';
        case 'not_paid':
          return 'NOT PAID';
        case 'review':
          return 'REVIEW';
        default:
          return paymentStatus.toUpperCase();
      }
    }

    // Otherwise, derive from report status
    if (reportStatus != null) {
      switch (reportStatus.toLowerCase()) {
        case 'paid':
          return 'PAID';
        case 'approved':
          return 'NOT PAID';
        case 'rejected':
          return 'REJECTED';
        case 'submitted':
          return 'REVIEW';
        case 'draft':
          return 'REVIEW';
        default:
          return 'REVIEW';
      }
    }

    return 'REVIEW';
  }

  pw.Widget _buildSummaryTable({
    required int timesheetCount,
    required double totalHours,
    required double hourlyRate,
    required double totalAmount,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(),
      children: [
        pw.TableRow(
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.all(8),
              child: pw.Text('Entries'),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(8),
              child: pw.Text('Total Hours'),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(8),
              child: pw.Text('Hourly Rate'),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(8),
              child: pw.Text('Total Amount'),
            ),
          ],
        ),
        pw.TableRow(
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.all(8),
              child: pw.Text('$timesheetCount'),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(8),
              child: pw.Text('${totalHours.toStringAsFixed(2)} h'),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(8),
              child: pw.Text('THB ${hourlyRate.toStringAsFixed(2)}/h'),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(8),
              child: pw.Text('THB ${totalAmount.toStringAsFixed(2)}'),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTimesheetTable(
    List<StudentTimesheet> timesheets,
    DateFormat dateFormat,
    DateFormat timeFormat,
  ) {
    return pw.ListView.builder(
      itemCount: timesheets.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildTimesheetHeaderRow();
        }

        final ts = timesheets[index - 1];
        return _buildTimesheetDataRow(
          ts,
          dateFormat,
          timeFormat,
        );
      },
    );
  }

  pw.Widget _buildTimesheetHeaderRow() {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.grey300,
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: pw.Row(
        children: [
          pw.Expanded(flex: 15, child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
          pw.Expanded(flex: 15, child: pw.Text('Start Time', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
          pw.Expanded(flex: 15, child: pw.Text('End Time', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
          pw.Expanded(flex: 25, child: pw.Text('Task', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
          pw.Expanded(flex: 10, child: pw.Text('Hours', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
          pw.Expanded(flex: 15, child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
          pw.Expanded(flex: 10, child: pw.Text('Status', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
        ],
      ),
    );
  }

  pw.Widget _buildTimesheetDataRow(
    StudentTimesheet ts,
    DateFormat dateFormat,
    DateFormat timeFormat,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: pw.Row(
        children: [
          pw.Expanded(flex: 15, child: pw.Text(dateFormat.format(ts.date), style: pw.TextStyle(fontSize: 9))),
          pw.Expanded(flex: 15, child: pw.Text(timeFormat.format(ts.startTime), style: pw.TextStyle(fontSize: 9))),
          pw.Expanded(flex: 15, child: pw.Text(timeFormat.format(ts.endTime), style: pw.TextStyle(fontSize: 9))),
          pw.Expanded(flex: 25, child: pw.Text(ts.task, style: pw.TextStyle(fontSize: 9))),
          pw.Expanded(flex: 10, child: pw.Text('${ts.totalHours.toStringAsFixed(2)} h', style: pw.TextStyle(fontSize: 9))),
          pw.Expanded(flex: 15, child: pw.Text('THB ${ts.totalAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9))),
          pw.Expanded(flex: 10, child: pw.Text(ts.status, style: pw.TextStyle(fontSize: 9))),
        ],
      ),
    );
  }

  pw.Widget _buildSignatureSection() {
    return pw.Column(
      children: [
        pw.SizedBox(height: 20),
        pw.Text(
          'SIGNATURE SECTION',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Student Signature',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 40),
                    pw.Container(
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          bottom: pw.BorderSide(color: PdfColors.black),
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Student Name',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Supervisor Approval',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 40),
                    pw.Container(
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          bottom: pw.BorderSide(color: PdfColors.black),
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Supervisor Name',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Admin Approval',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 40),
                    pw.Container(
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          bottom: pw.BorderSide(color: PdfColors.black),
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Admin Name',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated on: ${DateFormat('MMM dd, yyyy hh:mm a').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
          ),
        ],
      ),
    );
  }
}