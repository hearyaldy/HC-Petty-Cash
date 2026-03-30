import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../models/staff.dart';
import '../models/salary_benefits.dart';
import '../utils/constants.dart';

class StaffRecordPdfService {
  final currencyFormat = NumberFormat.currency(
    symbol: 'THB ',
    decimalDigits: 0,
  );
  final dateFormat = DateFormat('MMMM d, yyyy');

  Future<Uint8List> generateStaffRecordPdf(
    Staff staff, {
    SalaryBenefits? salaryBenefits,
  }) async {
    // Load fonts
    final fontData = await rootBundle.load(
      'assets/fonts/NotoSansThai-Regular.ttf',
    );
    final ttf = pw.Font.ttf(fontData);
    final boldFontData = await rootBundle.load(
      'assets/fonts/NotoSansThai-Bold.ttf',
    );
    final boldTtf = pw.Font.ttf(boldFontData);

    pw.Font? notoFallback;
    pw.Font? emojiFont;
    try {
      notoFallback = await PdfGoogleFonts.notoSansRegular();
    } catch (_) {}
    try {
      emojiFont = await PdfGoogleFonts.notoColorEmojiRegular();
    } catch (_) {}

    // Load logo
    pw.ImageProvider? logoImage;
    try {
      final logoData = await rootBundle.load(
        'assets/images/hope_channel_logo.png',
      );
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      // Logo loading failed
    }

    pw.ImageProvider? staffPhoto;
    if (staff.photoUrl != null && staff.photoUrl!.isNotEmpty) {
      try {
        staffPhoto = await networkImage(staff.photoUrl!);
      } catch (e) {
        // Failed to load staff photo
      }
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: ttf,
          bold: boldTtf,
          fontFallback: [?notoFallback, ?emojiFont],
        ),
        header: (context) => _buildHeader(staff, logoImage, staffPhoto),
        footer: (context) => _buildFooter(context),
        build: (pw.Context context) {
          return [
            pw.SizedBox(height: 16),
            _buildPersonalAndContactRow(staff),
            pw.SizedBox(height: 16),
            _buildEmploymentSection(staff),
            pw.SizedBox(height: 16),
            _buildFinancialSection(staff),
            if (salaryBenefits != null) ...[
              pw.SizedBox(height: 16),
              _buildSalaryBenefitsSection(salaryBenefits),
            ],
            if (staff.notes != null) ...[
              pw.SizedBox(height: 16),
              _buildNotesSection(staff),
            ],
          ];
        },
      ),
    );

    return await pdf.save();
  }

  pw.Widget _buildHeader(
    Staff staff,
    pw.ImageProvider? logoImage,
    pw.ImageProvider? staffPhoto,
  ) {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Logo
            if (logoImage != null)
              pw.Container(
                width: 50,
                height: 50,
                child: pw.Image(logoImage, fit: pw.BoxFit.contain),
              )
            else
              pw.Container(
                width: 50,
                height: 50,
                decoration: pw.BoxDecoration(
                  color: PdfColors.indigo100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'HC',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.indigo700,
                    ),
                  ),
                ),
              ),
            pw.SizedBox(width: 12),
            // Organization info
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    AppConstants.organizationName,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    AppConstants.organizationAddress,
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
            // Staff Record badge
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColors.indigo700,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                'STAFF RECORD',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 12),
        // Staff header row
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  staff.fullName,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  '${staff.position} | ${staff.department}',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
            pw.Row(
              children: [
                if (staffPhoto != null) ...[
                  _buildPhotoAvatar(
                    staffPhoto,
                    scale: (staff.photoScale ?? 1.0).clamp(0.8, 2.5),
                    offsetX: (staff.photoOffsetX ?? 0.0).clamp(-1.0, 1.0),
                    offsetY: (staff.photoOffsetY ?? 0.0).clamp(-1.0, 1.0),
                  ),
                  pw.SizedBox(width: 8),
                ],
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: PdfColors.blue200),
                  ),
                  child: pw.Text(
                    staff.employeeId,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: pw.BoxDecoration(
                    color: _getStatusColor(staff.employmentStatus),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    staff.employmentStatus.displayName,
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPhotoAvatar(
    pw.ImageProvider image, {
    required double scale,
    required double offsetX,
    required double offsetY,
  }) {
    const size = 42.0;
    return pw.ClipOval(
      child: pw.Container(
        width: size,
        height: size,
        child: pw.Stack(
          children: [
            pw.Positioned(
              left: offsetX * 8,
              top: offsetY * 8,
              child: pw.Transform.scale(
                scale: scale,
                child: pw.Image(
                  image,
                  width: size,
                  height: size,
                  fit: pw.BoxFit.cover,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PdfColor _getStatusColor(dynamic status) {
    switch (status.toString()) {
      case 'EmploymentStatus.active':
        return PdfColors.green600;
      case 'EmploymentStatus.onLeave':
        return PdfColors.orange600;
      case 'EmploymentStatus.resigned':
        return PdfColors.grey600;
      case 'EmploymentStatus.terminated':
        return PdfColors.red600;
      case 'EmploymentStatus.retired':
        return PdfColors.purple600;
      default:
        return PdfColors.grey600;
    }
  }

  pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: const pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey800,
        ),
      ),
    );
  }

  pw.Widget _buildInfoItem(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 1),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPersonalAndContactRow(Staff staff) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Basic Information Column
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Basic Information'),
              pw.SizedBox(height: 8),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildInfoItem('Full Name', staff.fullName),
                    _buildInfoItem('Email', staff.email),
                    if (staff.dateOfBirth != null)
                      _buildInfoItem(
                        'Date of Birth',
                        dateFormat.format(staff.dateOfBirth!),
                      ),
                    if (staff.gender != null)
                      _buildInfoItem('Gender', staff.gender!.displayName),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 16),
        // Contact Information Column
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Contact Information'),
              pw.SizedBox(height: 8),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (staff.phoneNumber != null)
                      _buildInfoItem('Phone Number', staff.phoneNumber!),
                    if (staff.address != null)
                      _buildInfoItem('Address', staff.address!),
                    if (staff.emergencyContactName != null) ...[
                      pw.SizedBox(height: 6),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.red50,
                          borderRadius: pw.BorderRadius.circular(4),
                          border: pw.Border.all(color: PdfColors.red200),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Emergency Contact',
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.red700,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            _buildInfoItem('Name', staff.emergencyContactName!),
                            if (staff.emergencyContactPhone != null)
                              _buildInfoItem(
                                'Phone',
                                staff.emergencyContactPhone!,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 16),
        // ID & Location Column
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('ID & Location'),
              pw.SizedBox(height: 8),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (staff.nationalIdNumber != null)
                      _buildInfoItem('National ID', staff.nationalIdNumber!),
                    if (staff.passportNumber != null)
                      _buildInfoItem('Passport', staff.passportNumber!),
                    if (staff.country != null)
                      _buildInfoItem('Country', staff.country!),
                    if (staff.provinceState != null)
                      _buildInfoItem('Province/State', staff.provinceState!),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildEmploymentSection(Staff staff) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Employment Details'),
        pw.SizedBox(height: 8),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildInfoItem('Employee ID', staff.employeeId),
                    _buildInfoItem('Department', staff.department),
                    _buildInfoItem('Position', staff.position),
                    _buildInfoItem('System Role', staff.role.displayName),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildInfoItem(
                      'Employment Type',
                      staff.employmentType.displayName,
                    ),
                    _buildInfoItem(
                      'Employment Status',
                      staff.employmentStatus.displayName,
                    ),
                    _buildInfoItem(
                      'Date of Joining',
                      dateFormat.format(staff.dateOfJoining),
                    ),
                    if (staff.dateOfLeaving != null)
                      _buildInfoItem(
                        'Date of Leaving',
                        dateFormat.format(staff.dateOfLeaving!),
                      ),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildInfoItem(
                      'Years of Service',
                      '${staff.yearsOfService} years',
                    ),
                    if (staff.approvalLimit != null)
                      _buildInfoItem(
                        'Approval Limit',
                        currencyFormat.format(staff.approvalLimit!),
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

  pw.Widget _buildFinancialSection(Staff staff) {
    final hasFinancialInfo =
        staff.bankAccountNumber != null ||
        staff.bankName != null ||
        staff.taxId != null ||
        staff.monthlySalary != null;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Financial Information'),
        pw.SizedBox(height: 8),
        if (!hasFinancialInfo)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8),
            child: pw.Text(
              'No financial information available',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          )
        else
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Banking Info
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Banking',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      if (staff.bankName != null)
                        _buildInfoItem('Bank Name', staff.bankName!),
                      if (staff.bankAccountNumber != null)
                        _buildInfoItem(
                          'Account Number',
                          staff.bankAccountNumber!,
                        ),
                      if (staff.taxId != null)
                        _buildInfoItem('Tax ID', staff.taxId!),
                    ],
                  ),
                ),
                // Salary Info
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Compensation',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      if (staff.monthlySalary != null)
                        _buildInfoItem(
                          'Monthly Salary',
                          currencyFormat.format(staff.monthlySalary!),
                        ),
                      if (staff.allowances != null)
                        _buildInfoItem(
                          'Allowances',
                          currencyFormat.format(staff.allowances!),
                        ),
                    ],
                  ),
                ),
                // Deductions Info
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Deductions',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      if (staff.tithePercentage != null)
                        _buildInfoItem(
                          'Tithe',
                          '${staff.tithePercentage!.toStringAsFixed(1)}%',
                        ),
                      if (staff.socialSecurityAmount != null)
                        _buildInfoItem(
                          'Social Security',
                          currencyFormat.format(staff.socialSecurityAmount!),
                        ),
                      if (staff.providentFundPercentage != null)
                        _buildInfoItem(
                          'Provident Fund',
                          '${staff.providentFundPercentage!.toStringAsFixed(1)}%',
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

  pw.Widget _buildSalaryBenefitsSection(SalaryBenefits salaryBenefits) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Salary & Benefits Details'),
        pw.SizedBox(height: 8),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Salary Structure
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Salary Structure',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    if (salaryBenefits.wageFactor != null)
                      _buildInfoItem(
                        'Wage Factor',
                        currencyFormat.format(salaryBenefits.wageFactor!),
                      ),
                    if (salaryBenefits.salaryPercentage != null)
                      _buildInfoItem(
                        'Salary Scale',
                        '${salaryBenefits.salaryPercentage!.toStringAsFixed(0)}%',
                      ),
                    _buildInfoItem(
                      'Gross Salary',
                      currencyFormat.format(salaryBenefits.grossSalary),
                    ),
                    _buildInfoItem(
                      'Net Salary',
                      currencyFormat.format(salaryBenefits.netSalary),
                    ),
                    _buildInfoItem(
                      'Effective Date',
                      dateFormat.format(salaryBenefits.effectiveDate),
                    ),
                  ],
                ),
              ),
              // Monthly Allowances
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Monthly Allowances',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    if (salaryBenefits.phoneAllowance != null)
                      _buildInfoItem(
                        'Phone Allowance',
                        currencyFormat.format(salaryBenefits.phoneAllowance!),
                      ),
                    if (salaryBenefits.housingAllowance != null)
                      _buildInfoItem(
                        'Housing Allowance',
                        currencyFormat.format(salaryBenefits.housingAllowance!),
                      ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Annual Allowances',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    if (salaryBenefits.equipmentAllowance != null)
                      _buildInfoItem(
                        'Equipment (Yearly)',
                        currencyFormat.format(
                          salaryBenefits.equipmentAllowance!,
                        ),
                      ),
                    if (salaryBenefits.continueEducationAllowance != null)
                      _buildInfoItem(
                        'Education (Yearly)',
                        currencyFormat.format(
                          salaryBenefits.continueEducationAllowance!,
                        ),
                      ),
                  ],
                ),
              ),
              // Deductions
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Deductions',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    if (salaryBenefits.tithePercentage != null)
                      _buildInfoItem(
                        'Tithe (${salaryBenefits.tithePercentage!.toStringAsFixed(0)}%)',
                        currencyFormat.format(salaryBenefits.titheAmount),
                      ),
                    if (salaryBenefits.socialSecurityPercentage != null)
                      _buildInfoItem(
                        'Social Security',
                        currencyFormat.format(
                          salaryBenefits.socialSecurityAmount,
                        ),
                      ),
                    if (salaryBenefits.providentFundPercentage != null)
                      _buildInfoItem(
                        'Provident Fund (${salaryBenefits.providentFundPercentage!.toStringAsFixed(0)}%)',
                        currencyFormat.format(
                          salaryBenefits.providentFundAmount,
                        ),
                      ),
                    if (salaryBenefits.houseRentalPercentage != null &&
                        salaryBenefits.houseRentalPercentage! > 0)
                      _buildInfoItem(
                        'House Rental (${salaryBenefits.houseRentalPercentage!.toStringAsFixed(0)}%)',
                        currencyFormat.format(salaryBenefits.houseRentalAmount),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Health Benefits
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Health Benefits',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    if (salaryBenefits.outPatientPercentage != null)
                      _buildInfoItem(
                        'Out-Patient Coverage',
                        '${salaryBenefits.outPatientPercentage!.toStringAsFixed(0)}%',
                      ),
                    if (salaryBenefits.inPatientPercentage != null)
                      _buildInfoItem(
                        'In-Patient Coverage',
                        '${salaryBenefits.inPatientPercentage!.toStringAsFixed(0)}%',
                      ),
                    if (salaryBenefits.annualLeaveDays != null)
                      _buildInfoItem(
                        'Annual Leave',
                        '${salaryBenefits.annualLeaveDays} days',
                      ),
                  ],
                ),
              ),
              // Totals
              pw.Expanded(
                flex: 2,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: PdfColors.green200),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      pw.Column(
                        children: [
                          pw.Text(
                            'Monthly Total',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green700,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            currencyFormat.format(
                              salaryBenefits.totalCompensation,
                            ),
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green800,
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        children: [
                          pw.Text(
                            'Annual Total',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green700,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            currencyFormat.format(
                              salaryBenefits.annualTotalCompensation,
                            ),
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildNotesSection(Staff staff) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Notes'),
        pw.SizedBox(height: 8),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8),
          child: pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.amber50,
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: PdfColors.amber200),
            ),
            child: pw.Text(
              staff.notes!,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.center,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Column(
        children: [
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated on ${DateFormat('MMMM d, yyyy HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey500,
                ),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
