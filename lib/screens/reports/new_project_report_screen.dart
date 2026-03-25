import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../providers/auth_provider.dart';
import '../../providers/project_report_provider.dart';
import '../../models/app_settings.dart';
import '../../services/settings_service.dart';
import '../../utils/constants.dart';
import '../../utils/responsive_helper.dart';

class NewProjectReportScreen extends StatefulWidget {
  const NewProjectReportScreen({super.key});

  @override
  State<NewProjectReportScreen> createState() => _NewProjectReportScreenState();
}

class _NewProjectReportScreenState extends State<NewProjectReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _projectNameController = TextEditingController();
  final _budgetController = TextEditingController();
  final _descriptionController = TextEditingController();
  final SettingsService _settingsService = SettingsService();

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));

  List<ProjectLanguage> _languages = [];
  ProjectLanguage? _selectedLanguage;

  @override
  void initState() {
    super.initState();
    _loadLanguages();
  }

  Future<void> _loadLanguages() async {
    final languages = await _settingsService.getProjectLanguages();
    setState(() {
      _languages = languages;
    });
  }

  @override
  void dispose() {
    _projectNameController.dispose();
    _budgetController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: ResponsiveContainer(
          padding: ResponsiveHelper.getScreenPadding(context).copyWith(
            top: MediaQuery.of(context).padding.top + 16,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderCard(),
                const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Project Information',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _projectNameController,
                              decoration: const InputDecoration(
                                labelText: 'Project Name',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.folder_special),
                                helperText:
                                    'Enter a descriptive name for the project',
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a project name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _budgetController,
                              decoration: InputDecoration(
                                labelText: 'Budget Amount',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.attach_money),
                                prefixText: AppConstants.currencySymbol,
                                helperText:
                                    'Total budget allocated for this project',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a budget amount';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'Please enter a valid number';
                                }
                                if (double.parse(value) <= 0) {
                                  return 'Budget must be greater than zero';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedLanguage?.code,
                              decoration: const InputDecoration(
                                labelText: 'Project Language',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.language),
                                helperText:
                                    'Select the language for this project report',
                              ),
                              items: [
                                ..._languages.map((lang) => DropdownMenuItem(
                                      value: lang.code,
                                      child: Text('${lang.name} (${lang.code})'),
                                    )),
                                const DropdownMenuItem(
                                  value: '__add_new__',
                                  child: Row(
                                    children: [
                                      Icon(Icons.add, size: 18),
                                      SizedBox(width: 8),
                                      Text('Add Language...'),
                                    ],
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == '__add_new__') {
                                  _showAddLanguageDialog();
                                } else if (value != null) {
                                  setState(() {
                                    _selectedLanguage = _languages
                                        .firstWhere((l) => l.code == value);
                                  });
                                }
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty || value == '__add_new__') {
                                  return 'Please select a language';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Project Timeline',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDateField(
                                    'Start Date',
                                    _startDate,
                                    (date) {
                                      setState(() {
                                        _startDate = date;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildDateField('End Date', _endDate, (
                                    date,
                                  ) {
                                    setState(() {
                                      _endDate = date;
                                    });
                                  }),
                                ),
                              ],
                            ),
                            if (_endDate.isBefore(_startDate)) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'End date must be after start date',
                                style: TextStyle(color: Colors.red, fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Project Description',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Description (Optional)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.description),
                                helperText:
                                    'Provide details about the project scope and objectives',
                              ),
                              maxLines: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => context.pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: _createProjectReport,
                          icon: const Icon(Icons.check),
                          label: const Text('Create Project Report'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
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
        );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade600, Colors.green.shade400],
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
                child: const Icon(Icons.folder_special, size: 40, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create New Project Report',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage project budgets and expenses',
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

  Widget _buildDateField(
    String label,
    DateTime selectedDate,
    Function(DateTime) onDateSelected,
  ) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (date != null) {
          onDateSelected(date);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(
          DateFormat('MMM dd, yyyy').format(selectedDate),
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Future<void> _showAddLanguageDialog() async {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<ProjectLanguage>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Custom Language'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Language Name',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. Japanese',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a language name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: '3-Letter Code',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. JPN',
                ),
                maxLength: 3,
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a 3-letter code';
                  }
                  if (value.trim().length != 3) {
                    return 'Code must be exactly 3 letters';
                  }
                  if (!RegExp(r'^[A-Za-z]{3}$').hasMatch(value.trim())) {
                    return 'Code must contain only letters';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final lang = ProjectLanguage(
                  id: const Uuid().v4(),
                  name: nameController.text.trim(),
                  code: codeController.text.trim().toUpperCase(),
                  createdAt: DateTime.now(),
                );
                Navigator.of(context).pop(lang);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _settingsService.addProjectLanguage(result);
      await _loadLanguages();
      setState(() {
        _selectedLanguage = result;
      });
    }
  }

  Future<void> _createProjectReport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_endDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End date must be after start date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final projectReportProvider = context.read<ProjectReportProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not logged in'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await projectReportProvider.createProjectReport(
        projectName: _projectNameController.text,
        budgetAmount: double.parse(_budgetController.text),
        startDate: _startDate,
        endDate: _endDate,
        custodian: user,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        language: _selectedLanguage?.name,
        languageCode: _selectedLanguage?.code,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Project report created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate back to reports list
        context.go('/reports');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating project report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
