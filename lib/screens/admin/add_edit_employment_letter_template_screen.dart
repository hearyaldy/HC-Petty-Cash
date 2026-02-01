import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/employment_letter.dart';
import '../../services/employment_letter_service.dart';
import '../../utils/responsive_helper.dart';

class AddEditEmploymentLetterTemplateScreen extends StatefulWidget {
  const AddEditEmploymentLetterTemplateScreen({super.key});

  @override
  State<AddEditEmploymentLetterTemplateScreen> createState() =>
      _AddEditEmploymentLetterTemplateScreenState();
}

class _AddEditEmploymentLetterTemplateScreenState
    extends State<AddEditEmploymentLetterTemplateScreen> {
  final EmploymentLetterService _service = EmploymentLetterService();
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isActive = true;
  bool _isLoading = false;
  EmploymentLetterTemplate? _template;

  // Formatting options
  String _fontFamily = 'Sarabun';
  double _fontSize = 12;
  double _lineHeight = 1.5;
  String _textAlign = 'left';
  double _marginTop = 20;
  double _marginBottom = 20;
  double _marginLeft = 40;
  double _marginRight = 40;

  // Available font families
  final List<String> _fontFamilies = [
    'Sarabun',
    'NotoSansThai',
    'Roboto',
    'Open Sans',
    'Lato',
    'Times New Roman',
    'Arial',
    'Georgia',
  ];

  // Available font sizes
  final List<double> _fontSizes = [8, 9, 10, 11, 12, 14, 16, 18, 20, 24, 28, 32];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  void _loadInitialData() {
    final args = GoRouterState.of(context).extra as Map<String, dynamic>?;
    _template = args?['template'] as EmploymentLetterTemplate?;

    if (_template != null) {
      _titleController.text = _template!.title;
      _contentController.text = _template!.content;
      _descriptionController.text = _template!.description ?? '';
      _isActive = _template!.isActive;

      // Load formatting settings
      _fontFamily = _template!.formatting.fontFamily;
      _fontSize = _template!.formatting.fontSize;
      _lineHeight = _template!.formatting.lineHeight;
      _textAlign = _template!.formatting.textAlign;
      _marginTop = _template!.formatting.marginTop;
      _marginBottom = _template!.formatting.marginBottom;
      _marginLeft = _template!.formatting.marginLeft;
      _marginRight = _template!.formatting.marginRight;
    } else {
      // Set default content
      _contentController.text = '''{{date}}
Dear {{staffName}},

HOPE CHANNEL EMPLOYEE SALARY AND BENEFIT {{year}}

New Year's greetings from Hope Channel Southeast Asia!

On behalf of Hope Channel SEA and its Board of Directors, I would like to express our sincere gratitude and appreciation for your dedicated services rendered, serving as {{position}}. May God continue to bless you in all your evangelistic endeavors through media ministry. We truly believe that God has been working through you as you channel His love and hope to our viewers and HC communities at large. On January 8, 2025, the Hope Channel Board has approved the Operating Budget and Workers Remunerations for the year {{year}}. Please take note of the following salary and benefits that you will be receiving this year.

SEUM Wage Factor {{year}}:THB{{seumWageFactor}}
Your Salary Scale:{{salaryScale}}%
Your Gross Salary:THB{{grossSalary}}
Health Benefits:{{healthBenefitsOutpatient}}% (Out-Patient)
{{healthBenefitsInpatient}}% (In-Patient)
Annual Leave:{{annualLeave}} Working Days
Housing Allowance:Up to THB{{housingAllowance}} ({{housingAllowancePercent}}%)

Deductions:
Tithe (10%):THB{{titheAmount}}
Social Security:THB{{socialSecurityAmount}}
Provident Fund (10%):THB{{providentFundAmount}}
Housing Rental and Excess:THB{{housingRentalAmount}}

Once again thank you so much for your dedication and commitment serving the Lord through Hope Channel. Looking forward to a blessed and fruitful year ahead! Thank you.

In the Lord's Service,
{{signatureName}}
...………………………
{{signatureName}}
{{signatureTitle}}
Hope Channel Southeast Asia''';
    }
    setState(() {});
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final formatting = LetterFormatting(
        fontFamily: _fontFamily,
        fontSize: _fontSize,
        lineHeight: _lineHeight,
        textAlign: _textAlign,
        marginTop: _marginTop,
        marginBottom: _marginBottom,
        marginLeft: _marginLeft,
        marginRight: _marginRight,
      );

      final template = EmploymentLetterTemplate(
        id: _template?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        content: _contentController.text,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        isActive: _isActive,
        formatting: formatting,
        createdAt: _template != null ? _template!.createdAt : DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (_template != null) {
        await _service.updateTemplate(template);
      } else {
        await _service.createTemplate(template);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _template != null
                  ? 'Template updated successfully'
                  : 'Template created successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving template: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _insertPlaceholder(String placeholder) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      '{{$placeholder}}',
    );
    _contentController.text = newText;
    _contentController.selection = TextSelection.collapsed(
      offset: selection.start + placeholder.length + 4,
    );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    IconData? icon,
    String? helperText,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      hintText: hintText,
      prefixIcon: icon != null ? Icon(icon, color: Colors.grey.shade600) : null,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.orange.shade400, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Color> iconGradient,
    required List<Widget> children,
    Widget? trailing,
    bool initiallyExpanded = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: iconGradient),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          trailing: trailing,
          children: children,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _template != null;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          // Modern SliverAppBar with gradient
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.orange.shade600,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.orange.shade700,
                      Colors.orange.shade500,
                      Colors.deepOrange.shade400,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.description,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isEditing
                                        ? 'Edit Letter Template'
                                        : 'Add Letter Template',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Create and customize employment letter templates',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
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
                  ),
                ),
              ),
            ),
            actions: [
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton.icon(
                    onPressed: _saveTemplate,
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: const Text(
                      'Save',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Content
          SliverToBoxAdapter(
            child: ResponsiveContainer(
              child: Padding(
                padding: ResponsiveHelper.getScreenPadding(context),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),

                      // Basic Information Section
                      _buildSectionCard(
                        title: 'Basic Information',
                        icon: Icons.info_outline,
                        iconGradient: [
                          Colors.blue.shade400,
                          Colors.blue.shade600
                        ],
                        children: [
                          TextFormField(
                            controller: _titleController,
                            decoration: _buildInputDecoration(
                              label: 'Template Title *',
                              icon: Icons.title,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a title';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _descriptionController,
                            maxLines: 2,
                            decoration: _buildInputDecoration(
                              label: 'Description',
                              icon: Icons.description,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: SwitchListTile(
                              title: const Text('Active'),
                              subtitle: const Text(
                                  'Make this template available for use'),
                              value: _isActive,
                              onChanged: (value) {
                                setState(() {
                                  _isActive = value;
                                });
                              },
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Text Formatting Section
                      _buildSectionCard(
                        title: 'Text Formatting',
                        icon: Icons.text_format,
                        iconGradient: [
                          Colors.purple.shade400,
                          Colors.purple.shade600
                        ],
                        children: [
                          // Font Family and Size Row
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  value: _fontFamily,
                                  decoration: _buildInputDecoration(
                                    label: 'Font Family',
                                    icon: Icons.font_download,
                                  ),
                                  items: _fontFamilies.map((font) {
                                    return DropdownMenuItem(
                                      value: font,
                                      child: Text(font),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _fontFamily = value);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: DropdownButtonFormField<double>(
                                  value: _fontSize,
                                  decoration: _buildInputDecoration(
                                    label: 'Font Size',
                                    icon: Icons.format_size,
                                  ),
                                  items: _fontSizes.map((size) {
                                    return DropdownMenuItem(
                                      value: size,
                                      child: Text('${size.toInt()} pt'),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _fontSize = value);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Text Alignment
                          const Text(
                            'Text Alignment',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                _buildAlignmentButton(
                                  icon: Icons.format_align_left,
                                  value: 'left',
                                  label: 'Left',
                                ),
                                _buildAlignmentButton(
                                  icon: Icons.format_align_center,
                                  value: 'center',
                                  label: 'Center',
                                ),
                                _buildAlignmentButton(
                                  icon: Icons.format_align_right,
                                  value: 'right',
                                  label: 'Right',
                                ),
                                _buildAlignmentButton(
                                  icon: Icons.format_align_justify,
                                  value: 'justify',
                                  label: 'Justify',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Line Height
                          Row(
                            children: [
                              const Text(
                                'Line Height:',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Slider(
                                  value: _lineHeight,
                                  min: 1.0,
                                  max: 3.0,
                                  divisions: 20,
                                  label: _lineHeight.toStringAsFixed(1),
                                  activeColor: Colors.purple.shade400,
                                  onChanged: (value) {
                                    setState(() => _lineHeight = value);
                                  },
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _lineHeight.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Page Margins Section
                      _buildSectionCard(
                        title: 'Page Margins',
                        icon: Icons.space_bar,
                        iconGradient: [
                          Colors.teal.shade400,
                          Colors.teal.shade600
                        ],
                        initiallyExpanded: false,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildMarginField(
                                  label: 'Top',
                                  value: _marginTop,
                                  onChanged: (v) =>
                                      setState(() => _marginTop = v),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildMarginField(
                                  label: 'Bottom',
                                  value: _marginBottom,
                                  onChanged: (v) =>
                                      setState(() => _marginBottom = v),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildMarginField(
                                  label: 'Left',
                                  value: _marginLeft,
                                  onChanged: (v) =>
                                      setState(() => _marginLeft = v),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildMarginField(
                                  label: 'Right',
                                  value: _marginRight,
                                  onChanged: (v) =>
                                      setState(() => _marginRight = v),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Placeholders Section
                      _buildSectionCard(
                        title: 'Available Placeholders',
                        icon: Icons.code,
                        iconGradient: [
                          Colors.indigo.shade400,
                          Colors.indigo.shade600
                        ],
                        initiallyExpanded: false,
                        children: [
                          const Text(
                            'Click on a placeholder to insert it into your template content.',
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildPlaceholderChip('date', 'Current date'),
                              _buildPlaceholderChip(
                                  'staffName', 'Staff member name'),
                              _buildPlaceholderChip(
                                  'position', 'Staff position'),
                              _buildPlaceholderChip('year', 'Current year'),
                              _buildPlaceholderChip(
                                  'seumWageFactor', 'SEUM wage factor'),
                              _buildPlaceholderChip(
                                  'salaryScale', 'Salary scale %'),
                              _buildPlaceholderChip(
                                  'grossSalary', 'Gross salary'),
                              _buildPlaceholderChip('healthBenefitsOutpatient',
                                  'Outpatient %'),
                              _buildPlaceholderChip(
                                  'healthBenefitsInpatient', 'Inpatient %'),
                              _buildPlaceholderChip(
                                  'annualLeave', 'Annual leave days'),
                              _buildPlaceholderChip(
                                  'housingAllowance', 'Housing allowance'),
                              _buildPlaceholderChip('housingAllowancePercent',
                                  'Housing allowance %'),
                              _buildPlaceholderChip(
                                  'titheAmount', 'Tithe amount'),
                              _buildPlaceholderChip('socialSecurityAmount',
                                  'Social security'),
                              _buildPlaceholderChip(
                                  'providentFundAmount', 'Provident fund'),
                              _buildPlaceholderChip(
                                  'housingRentalAmount', 'Housing rental'),
                              _buildPlaceholderChip(
                                  'signatureName', 'Signature name'),
                              _buildPlaceholderChip(
                                  'signatureTitle', 'Signature title'),
                            ],
                          ),
                        ],
                      ),

                      // Template Content Section
                      _buildSectionCard(
                        title: 'Template Content',
                        icon: Icons.edit_document,
                        iconGradient: [
                          Colors.orange.shade400,
                          Colors.orange.shade600
                        ],
                        children: [
                          // Preview of formatting settings
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Colors.blue.shade700, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Current formatting: $_fontFamily, ${_fontSize.toInt()}pt, $_textAlign aligned, line height $_lineHeight',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Text Formatting Toolbar
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  'Format:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _buildFormatButton(
                                  icon: Icons.format_bold,
                                  label: 'B',
                                  tooltip: 'Bold',
                                  onPressed: () => _applyFormatting('b'),
                                ),
                                const SizedBox(width: 4),
                                _buildFormatButton(
                                  icon: Icons.format_italic,
                                  label: 'I',
                                  tooltip: 'Italic',
                                  isItalic: true,
                                  onPressed: () => _applyFormatting('i'),
                                ),
                                const SizedBox(width: 4),
                                _buildFormatButton(
                                  icon: Icons.format_bold,
                                  label: 'BI',
                                  tooltip: 'Bold Italic',
                                  isBoldItalic: true,
                                  onPressed: () => _applyFormatting('bi'),
                                ),
                                const SizedBox(width: 4),
                                _buildFormatButton(
                                  icon: Icons.format_underlined,
                                  label: 'U',
                                  tooltip: 'Underline',
                                  isUnderline: true,
                                  onPressed: () => _applyFormatting('u'),
                                ),
                                const Spacer(),
                                Tooltip(
                                  message: 'Use tags like <b>bold</b>, <i>italic</i>, <bi>bold italic</bi>, <u>underline</u>',
                                  child: Icon(
                                    Icons.help_outline,
                                    size: 18,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                              border: Border.all(color: Colors.grey.shade300),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: TextFormField(
                              controller: _contentController,
                              maxLines: 25,
                              minLines: 15,
                              style: TextStyle(
                                fontFamily: _fontFamily,
                                fontSize: _fontSize,
                                height: _lineHeight,
                              ),
                              textAlign: _getTextAlign(),
                              decoration: InputDecoration(
                                hintText: 'Enter your letter template here...',
                                border: OutlineInputBorder(
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(12),
                                    bottomRight: Radius.circular(12),
                                  ),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.all(16),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter template content';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlignmentButton({
    required IconData icon,
    required String value,
    required String label,
  }) {
    final isSelected = _textAlign == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _textAlign = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.purple.shade100 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.purple.shade700 : Colors.grey.shade600,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected
                      ? Colors.purple.shade700
                      : Colors.grey.shade600,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarginField({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ${value.toInt()} pt',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Slider(
          value: value,
          min: 0,
          max: 100,
          divisions: 20,
          activeColor: Colors.teal.shade400,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildPlaceholderChip(String placeholder, String description) {
    return Tooltip(
      message: description,
      child: ActionChip(
        avatar: const Icon(Icons.add, size: 16),
        label: Text('{{$placeholder}}'),
        backgroundColor: Colors.indigo.shade50,
        labelStyle: TextStyle(
          color: Colors.indigo.shade700,
          fontSize: 12,
        ),
        onPressed: () => _insertPlaceholder(placeholder),
      ),
    );
  }

  TextAlign _getTextAlign() {
    switch (_textAlign) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      case 'justify':
        return TextAlign.justify;
      default:
        return TextAlign.left;
    }
  }

  Widget _buildFormatButton({
    required IconData icon,
    required String label,
    required String tooltip,
    required VoidCallback onPressed,
    bool isItalic = false,
    bool isBoldItalic = false,
    bool isUnderline = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isBoldItalic || !isItalic && !isUnderline
                    ? FontWeight.bold
                    : FontWeight.normal,
                fontStyle: isItalic || isBoldItalic
                    ? FontStyle.italic
                    : FontStyle.normal,
                decoration:
                    isUnderline ? TextDecoration.underline : TextDecoration.none,
                fontSize: 14,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _applyFormatting(String tag) {
    final text = _contentController.text;
    final selection = _contentController.selection;

    // If there's selected text, wrap it with the tag
    if (selection.isValid && selection.start != selection.end) {
      final selectedText = text.substring(selection.start, selection.end);
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        '<$tag>$selectedText</$tag>',
      );
      _contentController.text = newText;
      // Position cursor after the closing tag
      _contentController.selection = TextSelection.collapsed(
        offset: selection.start + tag.length + 2 + selectedText.length + tag.length + 3,
      );
    } else {
      // If no selection, insert empty tags and position cursor between them
      final cursorPos = selection.isValid ? selection.start : text.length;
      final newText = text.replaceRange(
        cursorPos,
        cursorPos,
        '<$tag></$tag>',
      );
      _contentController.text = newText;
      // Position cursor between the tags
      _contentController.selection = TextSelection.collapsed(
        offset: cursorPos + tag.length + 2,
      );
    }
  }
}
