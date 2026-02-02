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

    // Sanitize content - replace special Unicode characters that Helvetica can't render
    content = _sanitizeContent(content);

    // Remove duplicate date and greeting headers if present
    // This handles cases where template has both hardcoded and placeholder versions
    content = _removeDuplicateHeaders(content, staff.fullName, date);

    // Replace placeholders with actual values
    content = _replacePlaceholders(
      content: content,
      staff: staff,
      salaryBenefits: salaryBenefits,
      date: date,
    );

    // Run duplicate removal again after placeholder replacement
    // to catch any remaining duplicates
    content = _removeDuplicateHeaders(content, staff.fullName, date);

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

              // Content - using RichText to preserve formatting (date and greeting are in the template)
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
            (salaryBenefits.wageFactor ?? salaryBenefits.baseSalary)
                .toInt()
                .toString(),
          )
          .replaceAll(
            '{{salaryScale}}',
            (salaryBenefits.salaryPercentage ??
                    ((salaryBenefits.baseSalary /
                            (salaryBenefits.wageFactor ?? 41000)) *
                        100))
                .round()
                .toString(),
          )
          .replaceAll(
            '{{grossSalary}}',
            salaryBenefits.grossSalary.toInt().toString(),
          )
          .replaceAll(
            '{{healthBenefitsOutpatient}}',
            (salaryBenefits.outPatientPercentage ?? 75).toInt().toString(),
          )
          .replaceAll(
            '{{healthBenefitsInpatient}}',
            (salaryBenefits.inPatientPercentage ?? 90).toInt().toString(),
          )
          .replaceAll(
            '{{annualLeave}}',
            (salaryBenefits.annualLeaveDays ?? 10).toString(),
          )
          .replaceAll(
            '{{housingAllowance}}',
            (salaryBenefits.housingAllowance ??
                    salaryBenefits.allowances ??
                    4000)
                .toInt()
                .toString(),
          )
          .replaceAll(
            '{{housingAllowancePercent}}',
            (salaryBenefits.houseRentalPercentage ?? 50).toInt().toString(),
          )
          .replaceAll(
            '{{equipmentAllowance}}',
            (salaryBenefits.equipmentAllowance ?? 0).toInt().toString(),
          )
          .replaceAll(
            '{{continueEducationAllowance}}',
            (salaryBenefits.continueEducationAllowance ?? 0).toInt().toString(),
          );

      // Use actual deduction values from salary benefits
      content = content
          .replaceAll(
            '{{titheAmount}}',
            salaryBenefits.titheAmount.toInt().toString(),
          )
          .replaceAll(
            '{{tithePercentage}}',
            (salaryBenefits.tithePercentage ?? 10).toInt().toString(),
          )
          .replaceAll(
            '{{socialSecurityAmount}}',
            salaryBenefits.socialSecurityAmount.toInt().toString(),
          )
          .replaceAll(
            '{{providentFundAmount}}',
            salaryBenefits.providentFundAmount.toInt().toString(),
          )
          .replaceAll(
            '{{providentFundPercentage}}',
            (salaryBenefits.providentFundPercentage ?? 10).toInt().toString(),
          )
          .replaceAll(
            '{{housingRentalAmount}}',
            salaryBenefits.houseRentalAmount.toInt().toString(),
          )
          .replaceAll(
            '{{houseRentalPercentage}}',
            (salaryBenefits.houseRentalPercentage ?? 0).toInt().toString(),
          )
          .replaceAll(
            '{{netSalary}}',
            salaryBenefits.netSalary.toInt().toString(),
          )
          .replaceAll(
            '{{totalCompensation}}',
            salaryBenefits.totalCompensation.toInt().toString(),
          );
    } else {
      // Use staff-level values if no salary benefits available
      content = content
          .replaceAll(
            '{{seumWageFactor}}',
            '41000', // Default SEUM wage factor
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
          .replaceAll('{{equipmentAllowance}}', '0')
          .replaceAll('{{continueEducationAllowance}}', '0')
          .replaceAll(
            '{{titheAmount}}',
            (staff.titheAmount ?? 2665).toInt().toString(),
          )
          .replaceAll('{{tithePercentage}}', '10')
          .replaceAll(
            '{{socialSecurityAmount}}',
            (staff.socialSecurityAmount ?? 750).toInt().toString(),
          )
          .replaceAll(
            '{{providentFundAmount}}',
            (staff.providentFundAmount ?? 2665).toInt().toString(),
          )
          .replaceAll('{{providentFundPercentage}}', '10')
          .replaceAll('{{housingRentalAmount}}', '0')
          .replaceAll('{{houseRentalPercentage}}', '0')
          .replaceAll(
            '{{netSalary}}',
            (staff.monthlySalary ?? 26650).toInt().toString(),
          )
          .replaceAll(
            '{{totalCompensation}}',
            ((staff.monthlySalary ?? 26650) + (staff.allowances ?? 0))
                .toInt()
                .toString(),
          );
    }

    return content;
  }

  // Remove duplicate date and greeting headers from content
  // This handles cases where a template might have both hardcoded values and placeholders
  String _removeDuplicateHeaders(
    String content,
    String staffName,
    String? date,
  ) {
    // Pattern to match date lines (e.g., "2 February 2026" or "24 March 2025")
    final datePattern = RegExp(
      r'^\d{1,2}\s+(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{4}\s*$',
      multiLine: true,
      caseSensitive: false,
    );

    // Pattern to match greeting lines (e.g., "Dear John Doe," or "Dear {{staffName}},")
    final greetingPattern = RegExp(
      r'^Dear\s+.+,?\s*$',
      multiLine: true,
      caseSensitive: false,
    );

    // Find all matches
    final dateMatches = datePattern.allMatches(content).toList();
    final greetingMatches = greetingPattern.allMatches(content).toList();

    // If there are multiple date lines, remove the first one
    if (dateMatches.length > 1) {
      content = content.replaceFirst(datePattern, '');
      // Clean up any resulting double newlines
      content = content.replaceAll(RegExp(r'^\n+'), '');
    }

    // If there are multiple greeting lines, remove the first one
    if (greetingMatches.length > 1) {
      content = content.replaceFirst(greetingPattern, '');
      // Clean up any resulting double newlines
      content = content.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    }

    return content.trim();
  }

  // Sanitize content to replace special Unicode characters that Helvetica font can't render
  String _sanitizeContent(String content) {
    return content
        .replaceAll('…', '...') // Replace ellipsis with three dots
        .replaceAll('–', '-') // Replace en-dash with hyphen
        .replaceAll('—', '-') // Replace em-dash with hyphen
        .replaceAll(''', "'")    // Replace smart single quotes
        .replaceAll(''', "'")
        .replaceAll('"', '"') // Replace smart double quotes
        .replaceAll('"', '"')
        .replaceAll('•', '-'); // Replace bullet with hyphen
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
    final RegExp tagPattern = RegExp(r'<(b|i|bi|u)>(.*?)</\1>', dotAll: true);

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
        spans.add(pw.TextSpan(text: nestedSpan.text, style: style));
      } else {
        // For complex nested content, wrap in a styled span
        spans.add(pw.TextSpan(style: style, children: nestedSpans));
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
              pw.Text(
                '................................',
                style: pw.TextStyle(fontSize: 12),
              ),
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
