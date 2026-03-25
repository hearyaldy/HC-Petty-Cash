import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/meeting_template.dart';
import '../../services/meeting_template_service.dart';
import '../../utils/responsive_helper.dart';

class MeetingTemplateListScreen extends StatefulWidget {
  const MeetingTemplateListScreen({super.key});

  @override
  State<MeetingTemplateListScreen> createState() =>
      _MeetingTemplateListScreenState();
}

class _MeetingTemplateListScreenState extends State<MeetingTemplateListScreen> {
  final MeetingTemplateService _service = MeetingTemplateService();
  String _selectedOrganization = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveContainer(
            child: Padding(
              padding: ResponsiveHelper.getScreenPadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeHeader(),
                  const SizedBox(height: 24),
                  _buildFilterChips(),
                  const SizedBox(height: 16),
                  _buildTemplateList(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
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
            color: Colors.teal.withValues(alpha: 0.3),
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
                onPressed: () => context.go('/admin-hub'),
              ),
              Row(
                children: [
                  _buildHeaderActionButton(
                    icon: Icons.add,
                    tooltip: 'Create New Template',
                    onPressed: () => _createNewTemplate(),
                  ),
                  const SizedBox(width: 8),
                  _buildHeaderActionButton(
                    icon: Icons.home_outlined,
                    tooltip: 'Home',
                    onPressed: () => context.go('/admin-hub'),
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
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.description_outlined,
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
                      'Meeting Templates',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage agenda and minutes templates',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: isMobile ? 12 : 14,
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

  Widget _buildHeaderActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Wrap(
      spacing: 8,
      children: [
        FilterChip(
          label: const Text('All'),
          selected: _selectedOrganization == 'All',
          onSelected: (selected) {
            setState(() => _selectedOrganization = 'All');
          },
        ),
        FilterChip(
          label: const Text('ADCOM'),
          selected: _selectedOrganization == 'ADCOM',
          onSelected: (selected) {
            setState(() => _selectedOrganization = 'ADCOM');
          },
        ),
        FilterChip(
          label: const Text('HC Board'),
          selected: _selectedOrganization == 'HC Board',
          onSelected: (selected) {
            setState(() => _selectedOrganization = 'HC Board');
          },
        ),
      ],
    );
  }

  Widget _buildTemplateList() {
    return StreamBuilder<List<MeetingTemplate>>(
      stream: _service.getTemplates(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        }

        var templates = snapshot.data ?? [];

        if (_selectedOrganization != 'All') {
          templates = templates
              .where((t) => t.organization == _selectedOrganization)
              .toList();
        }

        if (templates.isEmpty) {
          return _buildEmptyState();
        }

        // Group by organization
        final adcomTemplates =
            templates.where((t) => t.organization == 'ADCOM').toList();
        final hcBoardTemplates =
            templates.where((t) => t.organization == 'HC Board').toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (adcomTemplates.isNotEmpty &&
                (_selectedOrganization == 'All' ||
                    _selectedOrganization == 'ADCOM')) ...[
              _buildSectionHeader('ADCOM Templates', adcomTemplates.length),
              const SizedBox(height: 12),
              ...adcomTemplates.map((t) => _buildTemplateCard(t)),
              const SizedBox(height: 24),
            ],
            if (hcBoardTemplates.isNotEmpty &&
                (_selectedOrganization == 'All' ||
                    _selectedOrganization == 'HC Board')) ...[
              _buildSectionHeader(
                  'HC Board Templates', hcBoardTemplates.length),
              const SizedBox(height: 12),
              ...hcBoardTemplates.map((t) => _buildTemplateCard(t)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.teal.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.teal.shade700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.description_outlined,
              size: 64,
              color: Colors.teal.shade300,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Templates Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create templates for your meeting agendas and minutes',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _createNewTemplate(),
            icon: const Icon(Icons.add),
            label: const Text('Create Template'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(MeetingTemplate template) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final typeColor = _getTypeColor(template.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => context.push('/admin/meeting-template/${template.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getTypeIcon(template.type),
                  color: typeColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      template.type.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () =>
                    context.push('/admin/meeting-template/${template.id}'),
                tooltip: 'Edit',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _confirmDelete(template),
                tooltip: 'Delete',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(MeetingTemplateType type) {
    switch (type) {
      case MeetingTemplateType.agendaIntroduction:
        return Colors.blue;
      case MeetingTemplateType.openingPrayer:
        return Colors.purple;
      case MeetingTemplateType.closingPrayer:
        return Colors.indigo;
      case MeetingTemplateType.minutesHeader:
        return Colors.teal;
      case MeetingTemplateType.resolutionTemplate:
        return Colors.orange;
    }
  }

  IconData _getTypeIcon(MeetingTemplateType type) {
    switch (type) {
      case MeetingTemplateType.agendaIntroduction:
        return Icons.article_outlined;
      case MeetingTemplateType.openingPrayer:
        return Icons.volunteer_activism;
      case MeetingTemplateType.closingPrayer:
        return Icons.handshake_outlined;
      case MeetingTemplateType.minutesHeader:
        return Icons.title;
      case MeetingTemplateType.resolutionTemplate:
        return Icons.gavel;
    }
  }

  Future<void> _createNewTemplate() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _CreateTemplateDialog(),
    );

    if (result != null) {
      try {
        final template = MeetingTemplate(
          name: result['name'] as String,
          type: result['type'] as MeetingTemplateType,
          organization: result['organization'] as String,
          content: '',
        );

        final templateId = await _service.createTemplate(template);

        if (mounted) {
          context.push('/admin/meeting-template/$templateId');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating template: $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmDelete(MeetingTemplate template) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text('Are you sure you want to delete "${template.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && template.id != null) {
      try {
        await _service.deleteTemplate(template.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Template deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting template: $e')),
          );
        }
      }
    }
  }
}

class _CreateTemplateDialog extends StatefulWidget {
  const _CreateTemplateDialog();

  @override
  State<_CreateTemplateDialog> createState() => _CreateTemplateDialogState();
}

class _CreateTemplateDialogState extends State<_CreateTemplateDialog> {
  final _nameController = TextEditingController();
  MeetingTemplateType _selectedType = MeetingTemplateType.agendaIntroduction;
  String _selectedOrganization = 'ADCOM';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.description_outlined, color: Colors.teal),
          SizedBox(width: 12),
          Text('Create New Template'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Template Name',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Enter template name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Organization',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedOrganization,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'ADCOM', child: Text('ADCOM')),
                DropdownMenuItem(value: 'HC Board', child: Text('HC Board')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedOrganization = value);
                }
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Template Type',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<MeetingTemplateType>(
              initialValue: _selectedType,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: MeetingTemplateType.values
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.displayName),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedType = value);
                }
              },
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
          onPressed: () {
            if (_nameController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a template name')),
              );
              return;
            }
            Navigator.pop(context, {
              'name': _nameController.text.trim(),
              'type': _selectedType,
              'organization': _selectedOrganization,
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
          ),
          child: const Text('Create'),
        ),
      ],
    );
  }
}
