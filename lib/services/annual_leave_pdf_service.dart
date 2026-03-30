import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/annual_leave_request.dart';
import '../utils/constants.dart';

class AnnualLeavePdfService {
  pw.Font? _regularFont;
  pw.Font? _boldFont;

  Future<pw.ThemeData> _getTheme() async {
    pw.Font? regular;
    pw.Font? bold;
    try {
      regular = _regularFont ??
          pw.Font.ttf(
            await rootBundle.load('assets/fonts/NotoSansThai-Regular.ttf'),
          );
      bold = _boldFont ??
          pw.Font.ttf(
            await rootBundle.load('assets/fonts/NotoSansThai-Bold.ttf'),
          );
      _regularFont = regular;
      _boldFont = bold;
    } catch (_) {
      // Use fallback fonts when custom fonts are unavailable.
    }

    pw.Font? notoFallback;
    pw.Font? emojiFont;
    try {
      notoFallback = await PdfGoogleFonts.notoSansRegular();
    } catch (_) {}
    try {
      emojiFont = await PdfGoogleFonts.notoColorEmojiRegular();
    } catch (_) {}

    return pw.ThemeData.withFont(
      base: regular ?? pw.Font.helvetica(),
      bold: bold ?? pw.Font.helveticaBold(),
      fontFallback: [?notoFallback, ?emojiFont],
    );
  }

  Future<Uint8List> buildPdf(AnnualLeaveRequest request) async {
    final theme = await _getTheme();
    final pdf = pw.Document(theme: theme);
    final dateFormat = DateFormat('MMM dd, yyyy');
    pw.ImageProvider? logoImage;

    try {
      final logoData = await rootBundle.load(AppConstants.companyLogo);
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {
      // Logo is optional.
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildHeader(logoImage),
            pw.SizedBox(height: 10),
            pw.Text(
              'Annual Leave Request',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            _sectionTitle('Staff Information'),
            _row('Requester', request.requesterName),
            _row('Department', request.department),
            _row('Requester ID', request.requesterId),
            if (request.employeeId != null && request.employeeId!.isNotEmpty)
              _row('Employee ID', request.employeeId!),
            if (request.position != null && request.position!.isNotEmpty)
              _row('Position', request.position!),
            if (request.email != null && request.email!.isNotEmpty)
              _row('Email', request.email!),
            pw.SizedBox(height: 10),
            _sectionTitle('Leave Information'),
            _row('Start Date', dateFormat.format(request.startDate)),
            _row('End Date', dateFormat.format(request.endDate)),
            _row('Total Days', request.totalDays.toString()),
            pw.SizedBox(height: 8),
            pw.Text(
              'Reason',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            ),
            pw.SizedBox(height: 6),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(request.reason),
            ),
            pw.SizedBox(height: 12),
            _sectionTitle('Approval Information'),
            _row('Status', request.status.toUpperCase()),
            if (request.approvedBy != null)
              _row('Approved By', request.approvedBy!),
            if (request.approvedAt != null)
              _row('Approved At', dateFormat.format(request.approvedAt!)),
            if (request.actionNumber != null &&
                request.actionNumber!.isNotEmpty)
              _row('Action Number', request.actionNumber!),
            if (request.rejectionReason != null &&
                request.rejectionReason!.isNotEmpty)
              _row('Rejection Reason', request.rejectionReason!),
            pw.SizedBox(height: 24),
            _sectionTitle('Signatures'),
            _buildSignatureSection(
              requesterName: request.requesterName,
              managerName: request.approvedBy,
            ),
            pw.SizedBox(height: 24),
            pw.Text(
              'Generated on: ${dateFormat.format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  pw.Widget _row(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }

  pw.Widget _buildHeader(pw.ImageProvider? logoImage) {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logoImage != null)
              pw.Container(
                width: 42,
                height: 42,
                child: pw.Image(logoImage, fit: pw.BoxFit.contain),
              )
            else
              pw.Container(
                width: 42,
                height: 42,
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey300,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'H',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
              ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    AppConstants.organizationName,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    AppConstants.organizationAddress,
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(),
      ],
    );
  }

  pw.Widget _sectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey200,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Text(
          title,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
        ),
      ),
    );
  }

  pw.Widget _buildSignatureSection({
    required String requesterName,
    String? managerName,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _signatureBlock('Requester', requesterName),
        _signatureBlock('Manager', managerName ?? ''),
      ],
    );
  }

  pw.Widget _signatureBlock(String label, String name) {
    return pw.Container(
      width: 220,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 24),
          pw.Container(
            height: 1,
            color: PdfColors.grey600,
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          if (name.isNotEmpty)
            pw.Text(
              name,
              style: pw.TextStyle(fontSize: 10),
            ),
        ],
      ),
    );
  }
}
