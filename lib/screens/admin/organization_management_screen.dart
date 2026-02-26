import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/organization.dart';
import '../../services/organization_service.dart';
import '../../services/equipment_service.dart';
import '../../utils/responsive_helper.dart';

class OrganizationManagementScreen extends StatefulWidget {
  const OrganizationManagementScreen({super.key});

  @override
  State<OrganizationManagementScreen> createState() =>
      _OrganizationManagementScreenState();
}

class _OrganizationManagementScreenState
    extends State<OrganizationManagementScreen> {
  final OrganizationService _organizationService = OrganizationService();
  final EquipmentService _equipmentService = EquipmentService();
  List<Organization> _organizations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrganizations();
  }

  Future<void> _loadOrganizations() async {
    setState(() => _isLoading = true);
    try {
      final organizations = await _organizationService.getAllOrganizations(
        forceRefresh: true,
      );
      if (mounted) {
        setState(() {
          _organizations = organizations;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading organizations: $e')),
        );
      }
    }
  }

  Future<void> _showAddOrganizationDialog() async {
    final result = await showDialog<Map<String, String?>>(
      context: context,
      builder: (context) => const _AddEditOrganizationDialog(),
    );

    if (result != null && mounted) {
      try {
        await _organizationService.createOrganization(
          name: result['name']!,
          code: result['code']!,
          description: result['description'],
        );
        _loadOrganizations();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Organization created successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating organization: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showEditOrganizationDialog(Organization organization) async {
    final result = await showDialog<Map<String, String?>>(
      context: context,
      builder: (context) => _AddEditOrganizationDialog(
        organization: organization,
      ),
    );

    if (result != null && mounted) {
      try {
        await _organizationService.updateOrganization(
          organization.copyWith(
            name: result['name'],
            code: result['code'],
            description: result['description'],
          ),
        );
        _loadOrganizations();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Organization updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating organization: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleOrganizationStatus(Organization organization) async {
    try {
      if (organization.isActive) {
        await _organizationService.deactivateOrganization(organization.id);
      } else {
        await _organizationService.reactivateOrganization(organization.id);
      }
      _loadOrganizations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              organization.isActive
                  ? 'Organization deactivated'
                  : 'Organization activated',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _assignExistingEquipment(Organization organization) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Existing Equipment'),
        content: Text(
          'This will assign all equipment without an organization to "${organization.name}". Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: const Text('Assign'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final count = await _equipmentService.assignUnassignedEquipment(
          organization.id,
          organization.name,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Assigned $count equipment to ${organization.name}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            _buildWelcomeHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ResponsiveContainer(
                      child: _organizations.isEmpty
                          ? _buildEmptyState()
                          : _buildOrganizationList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.indigo.shade400, Colors.indigo.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.shade200,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Organization Management',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: [
                  _buildHeaderActionButton(
                    icon: Icons.add_business,
                    tooltip: 'Add Organization',
                    onPressed: _showAddOrganizationDialog,
                  ),
                  const SizedBox(width: 8),
                  _buildHeaderActionButton(
                    icon: Icons.refresh,
                    tooltip: 'Refresh',
                    onPressed: _loadOrganizations,
                  ),
                  const SizedBox(width: 8),
                  _buildHeaderActionButton(
                    icon: Icons.arrow_back,
                    tooltip: 'Back',
                    onPressed: () => context.pop(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.business, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Manage Organizations',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Create and manage organizations for inventory separation',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
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

  Future<void> _seedDefaultOrganizations() async {
    try {
      await _organizationService.seedDefaultOrganizations();
      _loadOrganizations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Default organizations created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.business_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No organizations yet',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first organization to get started',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _seedDefaultOrganizations,
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('Create Defaults'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _showAddOrganizationDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Custom'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizationList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _organizations.length,
      itemBuilder: (context, index) {
        final org = _organizations[index];
        return _buildOrganizationCard(org);
      },
    );
  }

  Widget _buildOrganizationCard(Organization organization) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: organization.isActive
              ? Colors.indigo.shade100
              : Colors.grey.shade200,
          child: Icon(
            Icons.business,
            color: organization.isActive ? Colors.indigo : Colors.grey,
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                organization.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                organization.code,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.indigo.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (!organization.isActive) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Inactive',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: organization.description != null
            ? Text(
                organization.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            // Use post-frame callback to ensure popup menu is fully dismissed
            // before performing any navigation or dialog actions
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              switch (value) {
                case 'edit':
                  _showEditOrganizationDialog(organization);
                  break;
                case 'toggle':
                  _toggleOrganizationStatus(organization);
                  break;
                case 'assign':
                  _assignExistingEquipment(organization);
                  break;
              }
            });
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'toggle',
              child: Row(
                children: [
                  Icon(
                    organization.isActive ? Icons.block : Icons.check_circle,
                    size: 20,
                    color: organization.isActive ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(organization.isActive ? 'Deactivate' : 'Activate'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'assign',
              child: Row(
                children: [
                  Icon(Icons.assignment_turned_in, size: 20, color: Colors.purple),
                  SizedBox(width: 8),
                  Text('Assign Existing Equipment'),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _showEditOrganizationDialog(organization),
      ),
    );
  }
}

class _AddEditOrganizationDialog extends StatefulWidget {
  final Organization? organization;

  const _AddEditOrganizationDialog({this.organization});

  @override
  State<_AddEditOrganizationDialog> createState() =>
      _AddEditOrganizationDialogState();
}

class _AddEditOrganizationDialogState extends State<_AddEditOrganizationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.organization?.name);
    _codeController = TextEditingController(text: widget.organization?.code);
    _descriptionController = TextEditingController(
      text: widget.organization?.description,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.organization != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Organization' : 'Add Organization'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Organization Name *',
                hintText: 'e.g., Hope Channel Southeast Asia',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Organization Code *',
                hintText: 'e.g., HCSEA',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a code';
                }
                if (value.length > 10) {
                  return 'Code should be 10 characters or less';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Optional description',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context, rootNavigator: true).pop({
                'name': _nameController.text.trim(),
                'code': _codeController.text.trim().toUpperCase(),
                'description': _descriptionController.text.trim().isEmpty
                    ? null
                    : _descriptionController.text.trim(),
              });
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
          child: Text(isEditing ? 'Update' : 'Create'),
        ),
      ],
    );
  }
}
