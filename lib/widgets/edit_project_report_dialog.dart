import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/project_report.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';

class EditProjectReportDialog extends StatefulWidget {
  final ProjectReport report;

  const EditProjectReportDialog({
    super.key,
    required this.report,
  });

  @override
  State<EditProjectReportDialog> createState() =>
      _EditProjectReportDialogState();
}

class _EditProjectReportDialogState extends State<EditProjectReportDialog> {
  final _formKey = GlobalKey<FormState>();
  final SettingsService _settingsService = SettingsService();
  late TextEditingController _projectNameController;
  late TextEditingController _reportNameController;
  late TextEditingController _budgetController;
  late TextEditingController _openingBalanceController;
  late TextEditingController _descriptionController;
  late DateTime _startDate;
  late DateTime _endDate;

  List<ProjectLanguage> _languages = [];
  ProjectLanguage? _selectedLanguage;
  bool _languageChanged = false;

  @override
  void initState() {
    super.initState();
    _projectNameController =
        TextEditingController(text: widget.report.projectName);
    _reportNameController =
        TextEditingController(text: widget.report.reportName);
    _budgetController = TextEditingController(text: widget.report.budget.toString());
    _openingBalanceController =
        TextEditingController(text: widget.report.openingBalance.toString());
    _descriptionController =
        TextEditingController(text: widget.report.description ?? '');
    _startDate = widget.report.startDate;
    _endDate = widget.report.endDate;
    _loadLanguages();
  }

  Future<void> _loadLanguages() async {
    final languages = await _settingsService.getProjectLanguages();
    setState(() {
      _languages = languages;
      if (widget.report.languageCode != null) {
        final matches = languages.where((l) => l.code == widget.report.languageCode);
        if (matches.isNotEmpty) {
          _selectedLanguage = matches.first;
        }
      }
    });
  }

  @override
  void dispose() {
    _projectNameController.dispose();
    _reportNameController.dispose();
    _budgetController.dispose();
    _openingBalanceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      var updatedReport = widget.report.copyWith(
        projectName: _projectNameController.text.trim(),
        reportName: _reportNameController.text.trim(),
        budget: double.parse(_budgetController.text.trim()),
        openingBalance: double.parse(_openingBalanceController.text.trim()),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        updatedAt: DateTime.now(),
        language: _selectedLanguage?.name,
        languageCode: _selectedLanguage?.code,
      );

      // If language changed, flag it so the caller can regenerate reportNumber
      if (_languageChanged) {
        // Generate a new report number with the updated language code
        final now = widget.report.createdAt;
        final formatter = DateFormat('yyyyMM');
        final monthStr = formatter.format(now);
        final langCode = _selectedLanguage?.code;
        String newReportNumber;
        if (langCode != null && langCode.isNotEmpty) {
          newReportNumber = 'PROJ-$langCode-$monthStr-001';
        } else {
          newReportNumber = 'PROJ-$monthStr-001';
        }
        updatedReport = updatedReport.copyWith(
          reportNumber: newReportNumber,
        );
      }

      Navigator.of(context).pop(updatedReport);
    }
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
        _languageChanged = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Project Report',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Report Number (Read-only)
                TextFormField(
                  initialValue: widget.report.reportNumber,
                  decoration: const InputDecoration(
                    labelText: 'Report Number',
                    border: OutlineInputBorder(),
                  ),
                  enabled: false,
                ),
                const SizedBox(height: 16),

                // Language
                DropdownButtonFormField<String>(
                  initialValue: _selectedLanguage?.code,
                  decoration: const InputDecoration(
                    labelText: 'Project Language',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.language),
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
                        final newLang = _languages.firstWhere((l) => l.code == value);
                        if (_selectedLanguage?.code != newLang.code) {
                          _languageChanged = true;
                        }
                        _selectedLanguage = newLang;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Project Name
                TextFormField(
                  controller: _projectNameController,
                  decoration: const InputDecoration(
                    labelText: 'Project Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter project name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Report Name
                TextFormField(
                  controller: _reportNameController,
                  decoration: const InputDecoration(
                    labelText: 'Report Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter report name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Budget
                TextFormField(
                  controller: _budgetController,
                  decoration: const InputDecoration(
                    labelText: 'Budget',
                    border: OutlineInputBorder(),
                    prefixText: '฿ ',
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter budget';
                    }
                    if (double.tryParse(value.trim()) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Opening Balance
                TextFormField(
                  controller: _openingBalanceController,
                  decoration: const InputDecoration(
                    labelText: 'Opening Balance',
                    border: OutlineInputBorder(),
                    prefixText: '฿ ',
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter opening balance';
                    }
                    if (double.tryParse(value.trim()) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Start and End Date
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context, true),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Start Date',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(dateFormat.format(_startDate)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context, false),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'End Date',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(dateFormat.format(_endDate)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Description (Optional)
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _save,
                      child: const Text('Save Changes'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
