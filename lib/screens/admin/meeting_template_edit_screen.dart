import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:go_router/go_router.dart';
import '../../models/meeting_template.dart';
import '../../services/meeting_template_service.dart';
import '../../utils/responsive_helper.dart';

class MeetingTemplateEditScreen extends StatefulWidget {
  final String templateId;

  const MeetingTemplateEditScreen({super.key, required this.templateId});

  @override
  State<MeetingTemplateEditScreen> createState() =>
      _MeetingTemplateEditScreenState();
}

class _MeetingTemplateEditScreenState extends State<MeetingTemplateEditScreen> {
  final MeetingTemplateService _service = MeetingTemplateService();
  final _nameController = TextEditingController();
  late quill.QuillController _quillController;
  final FocusNode _editorFocus = FocusNode();
  final ScrollController _editorScroll = ScrollController();

  MeetingTemplate? _template;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _quillController = quill.QuillController.basic();
    _loadTemplate();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quillController.dispose();
    _editorFocus.dispose();
    _editorScroll.dispose();
    super.dispose();
  }

  Future<void> _loadTemplate() async {
    setState(() => _isLoading = true);
    try {
      final template = await _service.getTemplateById(widget.templateId);
      if (template != null) {
        _template = template;
        _nameController.text = template.name;

        // Load content into Quill controller
        if (template.isQuillFormat && template.content.isNotEmpty) {
          try {
            final json = jsonDecode(template.content) as List<dynamic>;
            _quillController = quill.QuillController(
              document: quill.Document.fromJson(json),
              selection: const TextSelection.collapsed(offset: 0),
            );
          } catch (_) {
            // If JSON parsing fails, treat as plain text
            _quillController = quill.QuillController(
              document: quill.Document()..insert(0, template.content),
              selection: const TextSelection.collapsed(offset: 0),
            );
          }
        } else if (template.content.isNotEmpty) {
          // Plain text content
          _quillController = quill.QuillController(
            document: quill.Document()..insert(0, template.content),
            selection: const TextSelection.collapsed(offset: 0),
          );
        }

        // Listen for changes
        _quillController.addListener(_onContentChanged);
        _nameController.addListener(_onContentChanged);
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading template: $e')),
        );
      }
    }
  }

  void _onContentChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _saveTemplate() async {
    if (_template == null) return;

    setState(() => _isSaving = true);

    try {
      final content = jsonEncode(_quillController.document.toDelta().toJson());

      final updatedTemplate = _template!.copyWith(
        name: _nameController.text.trim(),
        content: content,
        isQuillFormat: true,
      );

      await _service.updateTemplate(updatedTemplate);

      setState(() {
        _hasChanges = false;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template saved successfully')),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving template: $e')),
        );
      }
    }
  }

  void _insertPlaceholder(String placeholder) {
    final index = _quillController.selection.baseOffset;
    _quillController.document.insert(index, placeholder);
    _quillController.updateSelection(
      TextSelection.collapsed(offset: index + placeholder.length),
      quill.ChangeSource.local,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _template == null
                ? _buildNotFound()
                : _buildContent(),
      ),
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Template not found',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/admin/meeting-templates'),
            child: const Text('Back to Templates'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final isMobile = ResponsiveHelper.isMobile(context);

    return SingleChildScrollView(
      child: ResponsiveContainer(
        child: Padding(
          padding: ResponsiveHelper.getScreenPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildTemplateInfo(),
              const SizedBox(height: 16),
              _buildPlaceholderButtons(),
              const SizedBox(height: 16),
              _buildEditor(isMobile),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isMobile = ResponsiveHelper.isMobile(context);
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade700, Colors.cyan.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeaderActionButton(
                icon: Icons.arrow_back,
                tooltip: 'Back',
                onPressed: () => _confirmExit(),
              ),
              Row(
                children: [
                  if (_hasChanges)
                    _buildHeaderActionButton(
                      icon: _isSaving ? Icons.hourglass_empty : Icons.save,
                      tooltip: 'Save',
                      onPressed: _isSaving ? null : () => _saveTemplate(),
                    ),
                  const SizedBox(width: 8),
                  _buildHeaderActionButton(
                    icon: Icons.home_outlined,
                    tooltip: 'Home',
                    onPressed: () => _confirmExit(),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: isMobile ? 16 : 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.edit_document,
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
                      'Edit Template',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_template!.organization} - ${_template!.type.displayName}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: isMobile ? 12 : 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (_hasChanges)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.withOpacity(0.5)),
                  ),
                  child: const Text(
                    'Unsaved',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    required String tooltip,
    VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildTemplateInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Template Name',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'Enter template name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildInfoChip(
                icon: Icons.business,
                label: _template!.organization,
                color: Colors.blue,
              ),
              const SizedBox(width: 12),
              _buildInfoChip(
                icon: Icons.category,
                label: _template!.type.displayName,
                color: Colors.teal,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.code, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                'Insert Placeholders',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPlaceholderChip('{{date}}', 'Meeting Date'),
              _buildPlaceholderChip('{{fullDate}}', 'Full Date'),
              _buildPlaceholderChip('{{organization}}', 'Organization'),
              _buildPlaceholderChip('{{meetingNumber}}', 'Meeting #'),
              _buildPlaceholderChip('{{year}}', 'Year'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderChip(String placeholder, String label) {
    return ActionChip(
      avatar: const Icon(Icons.add, size: 16),
      label: Text(label),
      onPressed: () => _insertPlaceholder(placeholder),
      backgroundColor: Colors.teal.shade50,
      labelStyle: TextStyle(
        fontSize: 12,
        color: Colors.teal.shade700,
      ),
    );
  }

  Widget _buildEditor(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: quill.QuillSimpleToolbar(
              controller: _quillController,
              config: const quill.QuillSimpleToolbarConfig(
                showBoldButton: true,
                showItalicButton: true,
                showUnderLineButton: true,
                showStrikeThrough: false,
                showInlineCode: false,
                showColorButton: false,
                showBackgroundColorButton: false,
                showClearFormat: true,
                showAlignmentButtons: true,
                showLeftAlignment: true,
                showCenterAlignment: true,
                showRightAlignment: true,
                showJustifyAlignment: false,
                showHeaderStyle: true,
                showListNumbers: true,
                showListBullets: true,
                showListCheck: false,
                showCodeBlock: false,
                showQuote: false,
                showIndent: true,
                showLink: false,
                showUndo: true,
                showRedo: true,
                showDirection: false,
                showSearchButton: false,
                showSubscript: false,
                showSuperscript: false,
                showSmallButton: false,
                showDividers: true,
                multiRowsDisplay: false,
              ),
            ),
          ),
          // Editor
          Container(
            height: isMobile ? 300 : 400,
            padding: const EdgeInsets.all(16),
            child: quill.QuillEditor(
              controller: _quillController,
              focusNode: _editorFocus,
              scrollController: _editorScroll,
              config: quill.QuillEditorConfig(
                placeholder: 'Enter template content here...',
                padding: EdgeInsets.zero,
                expands: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmExit() async {
    if (!_hasChanges) {
      context.go('/admin/meeting-templates');
      return;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content:
            const Text('You have unsaved changes. What would you like to do?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save & Exit'),
          ),
        ],
      ),
    );

    if (result == 'save') {
      await _saveTemplate();
      if (mounted) {
        context.go('/admin/meeting-templates');
      }
    } else if (result == 'discard') {
      if (mounted) {
        context.go('/admin/meeting-templates');
      }
    }
  }
}
