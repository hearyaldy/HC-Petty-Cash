import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../models/staff.dart';
import '../../models/salary_benefits.dart';
import '../../models/employment_letter.dart';
import '../../services/employment_letter_service.dart';
import '../../services/employment_letter_pdf_service.dart';
import '../../services/salary_benefits_service.dart';
import '../../utils/responsive_helper.dart';

class SendEmploymentLetterScreen extends StatefulWidget {
  const SendEmploymentLetterScreen({super.key});

  @override
  State<SendEmploymentLetterScreen> createState() =>
      _SendEmploymentLetterScreenState();
}

class _SendEmploymentLetterScreenState
    extends State<SendEmploymentLetterScreen> {
  final EmploymentLetterService _letterService = EmploymentLetterService();
  final SalaryBenefitsService _salaryService = SalaryBenefitsService();
  final EmploymentLetterPdfService _pdfService = EmploymentLetterPdfService();

  Staff? _staff;
  SalaryBenefits? _salaryBenefits;
  List<EmploymentLetterTemplate> _templates = [];
  EmploymentLetterTemplate? _selectedTemplate;
  String _customContent = '';
  bool _isLoading = true;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    // Delay context access until after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;

    try {
      final args = GoRouterState.of(context).extra as Map<String, dynamic>?;
      _staff = args?['staff'] as Staff?;

      if (_staff == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Invalid staff data')));
          context.pop();
        }
        return;
      }

      // Load current salary benefits for the staff using one-time fetch
      try {
        final salaryBenefits = await _salaryService.getCurrentSalaryBenefitsOnce(_staff!.id);
        if (mounted) {
          setState(() {
            _salaryBenefits = salaryBenefits;
          });
        }
      } catch (e) {
        debugPrint('Error loading salary benefits: $e');
      }

      // Load available templates using one-time fetch
      try {
        final templatesSnapshot = await FirebaseFirestore.instance
            .collection('employment_letter_templates')
            .where('isActive', isEqualTo: true)
            .get();

        final templates = templatesSnapshot.docs
            .map((doc) => EmploymentLetterTemplate.fromFirestore(doc))
            .toList();
        templates.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (mounted) {
          setState(() {
            _templates = templates;
            if (templates.isNotEmpty) {
              _selectedTemplate = templates.first;
              _customContent = templates.first.content;
            }
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading templates: $e')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _generateAndPreviewPdf() async {
    if (_staff == null || _selectedTemplate == null) return;

    try {
      setState(() {
        _isGenerating = true;
      });

      final pdfBytes = await _pdfService.generateEmploymentLetterPdf(
        staff: _staff!,
        salaryBenefits: _salaryBenefits,
        templateContent: _selectedTemplate!.content,
        customContent: _customContent,
        date:
            '${DateTime.now().day} ${_getMonthName(DateTime.now().month)} ${DateTime.now().year}',
      );

      // Show the PDF preview
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) => pdfBytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
      }
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  Future<void> _sendLetter() async {
    if (_staff == null || _selectedTemplate == null) return;

    try {
      setState(() {
        _isGenerating = true;
      });

      // Generate the PDF
      await _pdfService.generateEmploymentLetterPdf(
        staff: _staff!,
        salaryBenefits: _salaryBenefits,
        templateContent: _selectedTemplate!.content,
        customContent: _customContent,
        date:
            '${DateTime.now().day} ${_getMonthName(DateTime.now().month)} ${DateTime.now().year}',
      );

      // Create employment letter record
      final letter = EmploymentLetter(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        templateId: _selectedTemplate!.id,
        staffId: _staff!.id,
        staffName: _staff!.fullName,
        staffPosition: _staff!.position,
        staffDepartment: _staff!.department,
        customContent: _customContent != _selectedTemplate!.content
            ? _customContent
            : null,
        generatedPdfUrl:
            null, // In a real app, you would upload to Firebase Storage
        issuedDate: DateTime.now(),
        issuedBy: null, // Would be set to current user ID in a real app
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _letterService.createLetter(letter);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Employment letter sent successfully!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sending letter: $e')));
      }
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
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

  Widget _buildHeaderCard({List<Widget>? actions}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade600, Colors.indigo.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Navigation row
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
              if (actions != null) ...actions,
              const SizedBox(width: 8),
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
          // Content row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mail_outline, size: 40, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Send Employment Letter',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Generate and send employment letters',
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

  Widget _buildSimpleHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade600, Colors.indigo.shade400],
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
                child: const Icon(Icons.mail_outline, size: 40, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Send Employment Letter',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Generate and send employment letters',
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
    if (_isLoading) {
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
                const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ),
      );
    }

    if (_staff == null) {
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
                const Center(child: Text('Invalid staff data')),
              ],
            ),
          ),
        ),
      );
    }

    if (_templates.isEmpty || _selectedTemplate == null) {
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
                const SizedBox(height: 48),
                const Icon(
                  Icons.description_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No employment letter templates found',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please create a template first',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () =>
                      context.push('/admin/employment-letter-template'),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Template'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: ResponsiveContainer(
          padding: ResponsiveHelper.getScreenPadding(context).copyWith(
            top: MediaQuery.of(context).padding.top + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeaderCard(
                actions: [
                  _isGenerating
                      ? Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : InkWell(
                          onTap: _sendLetter,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.send, color: Colors.white, size: 20),
                          ),
                        ),
                ],
              ),
              const SizedBox(height: 16),

              // Staff Information Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sending to: ${_staff!.fullName}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Position: ${_staff!.position}',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      Text(
                        'Department: ${_staff!.department}',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      Text(
                        'Employee ID: ${_staff!.employeeId}',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Template Selection
              if (_selectedTemplate != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Letter Template',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedTemplate!.id,
                          decoration: const InputDecoration(
                            labelText: 'Select Template',
                            border: OutlineInputBorder(),
                          ),
                          items: _templates
                              .map<DropdownMenuItem<String>>((template) {
                                return DropdownMenuItem(
                                  value: template.id,
                                  child: Text(template.title),
                                );
                              }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              final newTemplate = _templates.firstWhere(
                                (t) => t.id == value,
                                orElse: () => _selectedTemplate!,
                              );
                              setState(() {
                                _selectedTemplate = newTemplate;
                                _customContent = newTemplate.content;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isGenerating
                                    ? null
                                    : _generateAndPreviewPdf,
                                icon: const Icon(Icons.preview),
                                label: const Text('Preview Letter'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  if (_selectedTemplate != null) {
                                    setState(() {
                                      _customContent =
                                          _selectedTemplate!.content;
                                    });
                                  }
                                },
                                icon: const Icon(Icons.restore),
                                label: const Text('Reset'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // Custom Content Editor
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Customize Letter Content',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Edit the content below to customize the letter for this employee. Use placeholders like {{staffName}}, {{position}}, etc.',
                        style:
                            TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: _customContent,
                        maxLines: 20,
                        minLines: 10,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _customContent = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isGenerating ? null : _generateAndPreviewPdf,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Preview PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isGenerating ? null : _sendLetter,
                      icon: const Icon(Icons.send),
                      label: const Text('Send Letter'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
