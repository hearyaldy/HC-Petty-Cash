import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../models/staff.dart';
import '../models/salary_benefits.dart';

class EmploymentLetterPdfService {
  // Generate employment letter PDF
  Future<Uint8List> generateEmploymentLetterPdf({
    required Staff staff,
    required SalaryBenefits? salaryBenefits,
    required String templateContent,
    String? customContent,
    String? date,
  }) async {
    // Use custom content if provided, otherwise use template content
    String content = customContent ?? templateContent;

    // Replace placeholders with actual values
    content = _replacePlaceholders(
      content: content,
      staff: staff,
      salaryBenefits: salaryBenefits,
      date: date,
    );

    // Create the PDF document
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Text(
                'HOPE CHANNEL SOUTHEAST ASIA',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Bangkok, Thailand', style: pw.TextStyle(fontSize: 12)),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 20),

              // Date
              pw.Text(
                date ??
                    '${DateTime.now().day} ${_getMonthName(DateTime.now().month)} ${DateTime.now().year}',
                style: pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 20),

              // Recipient
              pw.Text(
                'Dear ${staff.fullName},',
                style: pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 20),

              // Content - using RichText to preserve formatting
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 10),
                  child: pw.RichText(
                    text: pw.TextSpan(
                      style: pw.TextStyle(fontSize: 11, color: PdfColors.black),
                      children: _parseFormattedText(content),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  // Replace placeholders in the template with actual values from staff and salary benefits
  String _replacePlaceholders({
    required String content,
    required Staff staff,
    required SalaryBenefits? salaryBenefits,
    String? date,
  }) {
    // Replace basic placeholders
    content = content
        .replaceAll(
          '{{date}}',
          date ??
              '${DateTime.now().day} ${_getMonthName(DateTime.now().month)} ${DateTime.now().year}',
        )
        .replaceAll('{{staffName}}', staff.fullName)
        .replaceAll('{{position}}', staff.position)
        .replaceAll('{{year}}', DateTime.now().year.toString())
        .replaceAll('{{signatureName}}', 'Heary Healdy Sairin')
        .replaceAll('{{signatureTitle}}', 'Manager');

    // Replace salary-related placeholders if salary benefits are available
    if (salaryBenefits != null) {
      // Use actual values from salary benefits
      content = content
          .replaceAll(
            '{{seumWageFactor}}',
            salaryBenefits.baseSalary.toInt().toString(),
          )
          .replaceAll(
            '{{salaryScale}}',
            ((salaryBenefits.baseSalary / 41000) * 100).round().toString(),
          )
          .replaceAll(
            '{{grossSalary}}',
            salaryBenefits.grossSalary.toInt().toString(),
          )
          .replaceAll(
            '{{healthBenefitsOutpatient}}',
            (salaryBenefits.healthInsurancePercentage ?? 75).toInt().toString(),
          )
          .replaceAll(
            '{{healthBenefitsInpatient}}',
            (salaryBenefits.healthInsurancePercentage ?? 90).toInt().toString(),
          )
          .replaceAll('{{annualLeave}}', '10') // Could be made configurable
          .replaceAll(
            '{{housingAllowance}}',
            (salaryBenefits.allowances?.toInt() ?? 4000).toString(),
          )
          .replaceAll(
            '{{housingAllowancePercent}}',
            '50',
          ); // Could be made configurable

      // Use actual deduction values from salary benefits or staff
      content = content
          .replaceAll(
            '{{titheAmount}}',
            (staff.titheAmount ?? (salaryBenefits.baseSalary * 0.1))
                .toInt()
                .toString(),
          )
          .replaceAll(
            '{{socialSecurityAmount}}',
            (staff.socialSecurityAmount ?? 750).toInt().toString(),
          )
          .replaceAll(
            '{{providentFundAmount}}',
            (staff.providentFundAmount ?? (salaryBenefits.baseSalary * 0.1))
                .toInt()
                .toString(),
          )
          .replaceAll(
            '{{housingRentalAmount}}',
            '4500',
          ); // Could be made configurable
    } else {
      // Use staff-level values if no salary benefits available
      content = content
          .replaceAll(
            '{{seumWageFactor}}',
            (staff.monthlySalary ?? 41000).toInt().toString(),
          )
          .replaceAll('{{salaryScale}}', '65') // Default value
          .replaceAll(
            '{{grossSalary}}',
            (staff.monthlySalary ?? 26650).toInt().toString(),
          )
          .replaceAll('{{healthBenefitsOutpatient}}', '75')
          .replaceAll('{{healthBenefitsInpatient}}', '90')
          .replaceAll('{{annualLeave}}', '10')
          .replaceAll(
            '{{housingAllowance}}',
            (staff.allowances?.toInt() ?? 4000).toString(),
          )
          .replaceAll('{{housingAllowancePercent}}', '50')
          .replaceAll(
            '{{titheAmount}}',
            (staff.titheAmount ?? 2665).toInt().toString(),
          )
          .replaceAll(
            '{{socialSecurityAmount}}',
            (staff.socialSecurityAmount ?? 750).toInt().toString(),
          )
          .replaceAll(
            '{{providentFundAmount}}',
            (staff.providentFundAmount ?? 2665).toInt().toString(),
          )
          .replaceAll('{{housingRentalAmount}}', '4500');
    }

    return content;
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  // Parse text with formatting tags and return list of TextSpans
  List<pw.InlineSpan> _parseFormattedText(String text) {
    final List<pw.InlineSpan> spans = [];

    // Regular expression to match formatting tags: <b>, <i>, <bi>, <u>
    final RegExp tagPattern = RegExp(
      r'<(b|i|bi|u)>(.*?)</\1>',
      dotAll: true,
    );

    int lastEnd = 0;

    for (final match in tagPattern.allMatches(text)) {
      // Add text before this match as plain text
      if (match.start > lastEnd) {
        final plainText = text.substring(lastEnd, match.start);
        if (plainText.isNotEmpty) {
          spans.add(pw.TextSpan(text: plainText));
        }
      }

      // Get the tag type and content
      final tag = match.group(1)!;
      final content = match.group(2)!;

      // Create styled TextSpan based on tag
      pw.TextStyle style;
      switch (tag) {
        case 'b':
          style = pw.TextStyle(fontWeight: pw.FontWeight.bold);
          break;
        case 'i':
          style = pw.TextStyle(fontStyle: pw.FontStyle.italic);
          break;
        case 'bi':
          style = pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontStyle: pw.FontStyle.italic,
          );
          break;
        case 'u':
          style = pw.TextStyle(decoration: pw.TextDecoration.underline);
          break;
        default:
          style = pw.TextStyle();
      }

      // Recursively parse nested tags in the content
      final nestedSpans = _parseFormattedText(content);
      if (nestedSpans.length == 1 && nestedSpans.first is pw.TextSpan) {
        final nestedSpan = nestedSpans.first as pw.TextSpan;
        // Merge styles for simple content
        spans.add(pw.TextSpan(
          text: nestedSpan.text,
          style: style,
        ));
      } else {
        // For complex nested content, wrap in a styled span
        spans.add(pw.TextSpan(
          style: style,
          children: nestedSpans,
        ));
      }

      lastEnd = match.end;
    }

    // Add any remaining text after the last match
    if (lastEnd < text.length) {
      final remainingText = text.substring(lastEnd);
      if (remainingText.isNotEmpty) {
        spans.add(pw.TextSpan(text: remainingText));
      }
    }

    // If no matches were found, return the original text as a single span
    if (spans.isEmpty) {
      spans.add(pw.TextSpan(text: text));
    }

    return spans;
  }

  // Generate a sample employment letter PDF with the provided content
  Future<Uint8List> generateSampleLetterPdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'HOPE CHANNEL SOUTHEAST ASIA',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Bangkok, Thailand', style: pw.TextStyle(fontSize: 12)),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 20),

              pw.Text('24 March 2025', style: pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 20),

              pw.Text('Dear Doreen,', style: pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 20),

              pw.Text(
                'HOPE CHANNEL EMPLOYEE SALARY AND BENEFIT 2025',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),

              pw.Text(
                'New Year\'s greetings from Hope Channel Southeast Asia!',
                style: pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 10),

              pw.Text(
                'On behalf of Hope Channel SEA and its Board of Directors, I would like to express our sincere gratitude and appreciation for your dedicated services rendered, serving as Media Specialist. May God continue to bless you in all your evangelistic endeavors through media ministry. We truly believe that God has been working through you as you channel His love and hope to our viewers and HC communities at large. On January 8, 2025, the Hope Channel Board has approved the Operating Budget and Workers Remunerations for the year 2025. Please take note of the following salary and benefits that you will be receiving this year.',
                style: pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 10),

              pw.Text(
                'SEUM Wage Factor 2025:THB41,000',
                style: pw.TextStyle(fontSize: 12),
              ),
              pw.Text(
                'Your Salary Scale:65%',
                style: pw.TextStyle(fontSize: 12),
              ),
              pw.Text(
                'Your Gross Salary:THB26,650',
                style: pw.TextStyle(fontSize: 12),
              ),
              pw.Text(
                'Health Benefits:75% (Out-Patient)',
                style: pw.TextStyle(fontSize: 12),
              ),
              pw.Text('90% (In-Patient)', style: pw.TextStyle(fontSize: 12)),
              pw.Text(
                'Annual Leave:10 Working Days',
                style: pw.TextStyle(fontSize: 12),
              ),
              pw.Text(
                'Housing Allowance:Up to THB4,000 (50%)',
                style: pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 10),

              pw.Text(
                'Deductions:',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Tithe (10%):THB2,665',
                style: pw.TextStyle(fontSize: 12),
              ),
              pw.Text(
                'Social Security:THB750',
                style: pw.TextStyle(fontSize: 12),
              ),
              pw.Text(
                'Provident Fund (10%):THB2,665',
                style: pw.TextStyle(fontSize: 12),
              ),
              pw.Text(
                'Housing Rental and Excess:THB4,500',
                style: pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 20),

              pw.Text(
                'Once again thank you so much for your dedication and commitment serving the Lord through Hope Channel. Looking forward to a blessed and fruitful year ahead! Thank you.',
                style: pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 20),

              pw.Text(
                'In the Lord\'s Service,',
                style: pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 20),

              pw.Text(
                'Heary Healdy Sairin',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text('...………………………', style: pw.TextStyle(fontSize: 12)),
              pw.Text(
                'Heary Healdy Sairin',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text('Manager', style: pw.TextStyle(fontSize: 12)),
              pw.Text(
                'Hope Channel Southeast Asia',
                style: pw.TextStyle(fontSize: 12),
              ),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }
}
