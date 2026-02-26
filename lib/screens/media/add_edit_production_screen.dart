import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/media_production_provider.dart';
import '../../providers/project_report_provider.dart';
import '../../models/media_production.dart';
import '../../models/project_report.dart';
import '../../models/staff.dart';
import '../../services/staff_service.dart';
import '../../services/settings_service.dart';
import '../../models/enums.dart';
import '../../utils/responsive_helper.dart';

class AddEditProductionScreen extends StatefulWidget {
  final String? productionId;

  const AddEditProductionScreen({super.key, this.productionId});

  @override
  State<AddEditProductionScreen> createState() => _AddEditProductionScreenState();
}

class _AddEditProductionScreenState extends State<AddEditProductionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();
  final _totalSeasonsController = TextEditingController();
  final _totalEpisodesController = TextEditingController();
  final _budgetController = TextEditingController();
  final _yearController = TextEditingController();
  final _thumbnailUrlController = TextEditingController();
  final _newUrlController = TextEditingController();
  final _durationController = TextEditingController();
  final _newCategoryController = TextEditingController();

  static const List<String> _baseCategories = [
    'Religion',
    'Youth',
    'Education',
    'Women',
    'Children',
    'Health',
  ];

  String _selectedLanguage = MediaLanguage.english.code;
  String _selectedType = ProductionType.standalone.name;
  String _selectedStatus = ProductionStatus.planning.name;
  String? _selectedProjectId;
  String? _selectedProjectName;
  String? _selectedCategory;
  List<String> _categoryOptions = [];
  bool _isCategoryLoading = true;
  final List<String> _productionUrls = [];
  final List<String> _customCategories = [];
  final StaffService _staffService = StaffService();
  final SettingsService _settingsService = SettingsService();
  bool _isStaffLoading = true;
  List<Staff> _allStaff = [];
  final Set<String> _selectedStaffIds = {};

  bool _isLoading = false;
  bool _isEditMode = false;
  MediaProduction? _existingProduction;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.productionId != null;
    if (!_isEditMode) {
      _yearController.text = DateTime.now().year.toString();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadCategories();
      _loadStaff();
      _loadProjectReports();
      if (_isEditMode) {
        _loadExistingProduction();
      }
    });
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _settingsService.getMediaCategories();
      if (!mounted) return;
      setState(() {
        _categoryOptions = _mergeCategories(categories, _customCategories);
        _isCategoryLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading media categories: $e');
      if (!mounted) return;
      setState(() {
        _categoryOptions = _mergeCategories([], _customCategories);
        _isCategoryLoading = false;
      });
    }
  }

  Future<void> _loadStaff() async {
    try {
      final staffList = await _staffService.getAllStaff().first;
      if (!mounted) return;
      setState(() {
        _allStaff = staffList;
        _isStaffLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading staff: $e');
      if (!mounted) return;
      setState(() => _isStaffLoading = false);
    }
  }

  Future<void> _loadProjectReports() async {
    try {
      await context.read<ProjectReportProvider>().loadProjectReports();
      if (!mounted) return;
      final projectProvider = context.read<ProjectReportProvider>();
      final linkedProject = _getSelectedProject(projectProvider);
      if (linkedProject != null) {
        setState(() {
          _budgetController.text = linkedProject.budget.toStringAsFixed(2);
        });
      }
    } catch (e) {
      debugPrint('Error loading project reports: $e');
    }
  }

  Future<void> _loadExistingProduction() async {
    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<MediaProductionProvider>(context, listen: false);
      await provider.loadProductionWithDetails(widget.productionId!);
      final production = provider.currentProduction;

      if (production != null && mounted) {
        setState(() {
          _existingProduction = production;
          _titleController.text = production.title;
          _descriptionController.text = production.description ?? '';
          _notesController.text = production.notes ?? '';
          _totalSeasonsController.text = production.totalSeasons.toString();
          _totalEpisodesController.text = production.totalEpisodes.toString();
          _budgetController.text =
              production.budget != null ? production.budget!.toStringAsFixed(2) : '';
          _yearController.text =
              production.productionYear != null ? production.productionYear!.toString() : '';
          _thumbnailUrlController.text = production.thumbnailUrl ?? '';
          _durationController.text =
              production.durationMinutes != null
                  ? _formatDurationInput(production.durationMinutes!)
                  : '';
          _selectedLanguage = production.language;
          _selectedType = production.productionType;
          _selectedStatus = production.status;
          _selectedProjectId = production.projectId;
          _selectedProjectName = production.projectName;
          _selectedCategory = production.category;
          _productionUrls
            ..clear()
            ..addAll(production.productionUrls);
          _customCategories
            ..clear()
            ..addAll(production.customCategories);
          _categoryOptions = _mergeCategories(_categoryOptions, _customCategories);
          _selectedStaffIds
            ..clear()
            ..addAll(production.teamMemberIds);
        });

        final projectProvider = context.read<ProjectReportProvider>();
        final linkedProject = _getSelectedProject(projectProvider);
        if (linkedProject != null) {
          _budgetController.text = linkedProject.budget.toStringAsFixed(2);
        }
      }
    } catch (e) {
      debugPrint('Error loading production: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  ProjectReport? _getSelectedProject(ProjectReportProvider provider) {
    if (_selectedProjectId == null) return null;
    try {
      return provider.projectReports
          .firstWhere((report) => report.id == _selectedProjectId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveProduction() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final provider = Provider.of<MediaProductionProvider>(context, listen: false);
      final projectReportProvider = Provider.of<ProjectReportProvider>(
        context,
        listen: false,
      );
      final user = authProvider.currentUser!;
      final totalSeasons = int.tryParse(_totalSeasonsController.text.trim()) ?? 0;
      final totalEpisodes = int.tryParse(_totalEpisodesController.text.trim()) ?? 0;
      final linkedProject = _getSelectedProject(projectReportProvider);
      final budgetValue = linkedProject != null
          ? _existingProduction?.budget
          : double.tryParse(_budgetController.text.trim());
      final productionYear = int.tryParse(_yearController.text.trim());
      final thumbnailUrl = _thumbnailUrlController.text.trim().isEmpty
          ? null
          : _thumbnailUrlController.text.trim();
      final durationMinutes = _parseDurationMinutes(_durationController.text.trim());
      final staffById = {
        for (final staff in _allStaff) staff.id: staff,
      };
      final selectedStaffIds = _selectedStaffIds.toList();
      final selectedStaffNames = selectedStaffIds
          .map((id) => staffById[id]?.fullName)
          .whereType<String>()
          .toList();

      if (_isEditMode && _existingProduction != null) {
        // Update existing production
        final updated = _existingProduction!.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          language: _selectedLanguage,
          productionType: _selectedType,
          status: _selectedStatus,
          projectId: _selectedProjectId,
          projectName: _selectedProjectName,
          totalSeasons: totalSeasons,
          totalEpisodes: totalEpisodes,
          budget: budgetValue,
          productionYear: productionYear,
          thumbnailUrl: thumbnailUrl,
          productionUrls: List<String>.from(_productionUrls),
          durationMinutes: durationMinutes,
          category: _selectedCategory,
          customCategories: List<String>.from(_customCategories),
          teamMemberIds: selectedStaffIds,
          teamMemberNames: selectedStaffNames,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          updatedAt: DateTime.now(),
        );

        final success = await provider.updateProduction(updated);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Production updated successfully')),
          );
          context.pop();
        }
      } else {
        // Create new production
        final production = await provider.createProduction(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          language: _selectedLanguage,
          productionType: _selectedType,
          projectId: _selectedProjectId,
          projectName: _selectedProjectName,
          totalSeasons: totalSeasons,
          totalEpisodes: totalEpisodes,
          budget: linkedProject != null ? null : budgetValue,
          productionYear: productionYear,
          thumbnailUrl: thumbnailUrl,
          productionUrls: List<String>.from(_productionUrls),
          durationMinutes: durationMinutes,
          category: _selectedCategory,
          customCategories: List<String>.from(_customCategories),
          teamMemberIds: selectedStaffIds,
          teamMemberNames: selectedStaffNames,
          createdById: user.id,
          createdByName: user.name,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );

        if (production != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Production created successfully')),
          );
          context.pop();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    _totalSeasonsController.dispose();
    _totalEpisodesController.dispose();
    _budgetController.dispose();
    _yearController.dispose();
    _thumbnailUrlController.dispose();
    _newUrlController.dispose();
    _durationController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: _isLoading && _isEditMode && _existingProduction == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: ResponsiveContainer(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          _buildHeaderBanner(),
                          const SizedBox(height: 16),
                          _buildBasicInfoCard(),
                          const SizedBox(height: 16),
                          _buildProductionDetailsCard(),
                          const SizedBox(height: 16),
                          _buildCategoryCard(),
                          const SizedBox(height: 16),
                          _buildMediaLinksCard(),
                          const SizedBox(height: 16),
                          _buildStaffAssignmentCard(),
                          const SizedBox(height: 16),
                          _buildNotesCard(),
                          const SizedBox(height: 24),
                          _buildSaveButton(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.pink.shade400,
            Colors.pink.shade600,
            Colors.pink.shade800,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.shade300,
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            right: 50,
            bottom: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildHeaderActionButton(
                      icon: Icons.arrow_back,
                      tooltip: 'Back',
                      onPressed: () => context.pop(),
                    ),
                    if (!_isLoading)
                      _buildHeaderActionButton(
                        icon: Icons.save,
                        tooltip: 'Save',
                        onPressed: _saveProduction,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditMode ? 'Edit Production' : 'New Production',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  offset: const Offset(1, 1),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isEditMode
                                ? 'Update production details'
                                : 'Create a new media production',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        _isEditMode ? Icons.edit : Icons.add_circle,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ],
                ),
              ],
            ),
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

  Widget _buildBasicInfoCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.pink.shade600),
                const SizedBox(width: 8),
                const Text(
                  'Basic Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title *',
                hintText: 'Enter production title',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Title is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Enter production description',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.category, color: Colors.pink.shade600),
                const SizedBox(width: 8),
                const Text(
                  'Category & Status',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ResponsiveBuilder(
              mobile: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedLanguage,
                    decoration: const InputDecoration(
                      labelText: 'Language *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.language),
                    ),
                    items: MediaLanguage.values.map((lang) {
                      return DropdownMenuItem(
                        value: lang.code,
                        child: Text(lang.displayName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedLanguage = value!);
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Type *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.video_library),
                    ),
                    items: ProductionType.values.map((type) {
                      return DropdownMenuItem(
                        value: type.name,
                        child: Text(type.displayName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedType = value!);
                    },
                  ),
                ],
              ),
              tablet: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedLanguage,
                      decoration: const InputDecoration(
                        labelText: 'Language *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.language),
                      ),
                      items: MediaLanguage.values.map((lang) {
                        return DropdownMenuItem(
                          value: lang.code,
                          child: Text(lang.displayName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedLanguage = value!);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Type *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.video_library),
                      ),
                      items: ProductionType.values.map((type) {
                        return DropdownMenuItem(
                          value: type.name,
                          child: Text(type.displayName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedType = value!);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_isEditMode)
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.flag),
                ),
                items: ProductionStatus.values.map((status) {
                  return DropdownMenuItem(
                    value: status.name,
                    child: Text(status.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedStatus = value!);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductionDetailsCard() {
    final categoryOptions = _categoryOptions.isEmpty
        ? List<String>.from(_baseCategories)
        : _categoryOptions;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: Colors.pink.shade600),
                const SizedBox(width: 8),
                const Text(
                  'Production Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _totalSeasonsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Total Seasons',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.layers),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _totalEpisodesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Total Episodes',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.movie),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _budgetController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Budget',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                      helperText: 'Leave empty if linked to a project report',
                    ),
                    enabled: _selectedProjectId == null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _yearController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Production Year',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Consumer<ProjectReportProvider>(
              builder: (context, projectProvider, _) {
                final reports = projectProvider.projectReports;
                final linkedProject = _getSelectedProject(projectProvider);

                final selectedValue = _selectedProjectId != null &&
                        reports.any((r) => r.id == _selectedProjectId)
                    ? _selectedProjectId
                    : null;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedValue,
                      decoration: const InputDecoration(
                        labelText: 'Linked Project Report (optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.link),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('No linked project'),
                        ),
                        ...reports.map(
                          (report) => DropdownMenuItem(
                            value: report.id,
                            child: Text(
                              '${report.projectName} • ${report.reportNumber}',
                            ),
                          ),
                        ),
                      ],
                      onChanged: projectProvider.isLoading
                          ? null
                          : (value) {
                              setState(() {
                                _selectedProjectId = value;
                                if (value == null) {
                                  _selectedProjectName = null;
                                  return;
                                }
                                final selected = reports.firstWhere(
                                  (r) => r.id == value,
                                  orElse: () => reports.first,
                                );
                                _selectedProjectName = selected.projectName;
                                _budgetController.text =
                                    selected.budget.toStringAsFixed(2);
                              });
                            },
                    ),
                    if (linkedProject != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Project budget: ${linkedProject.budget.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _durationController,
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(
                labelText: 'Duration (HH:MM)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.timer),
                hintText: 'e.g. 1:30',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Duration is required';
                }
                if (_parseDurationMinutes(value.trim()) == null) {
                  return 'Enter duration as HH:MM or minutes';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Select category')),
                ...categoryOptions.map(
                  (category) => DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _selectedCategory = value),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Category is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _newCategoryController,
                    decoration: const InputDecoration(
                      labelText: 'Add category',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.add),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isCategoryLoading
                      ? null
                      : () async {
                          final value = _newCategoryController.text.trim();
                          if (value.isEmpty) return;
                          final lower = value.toLowerCase();
                          final exists = categoryOptions
                              .any((c) => c.toLowerCase() == lower);
                          if (exists) {
                            _newCategoryController.clear();
                            return;
                          }
                          try {
                            final updated = await _settingsService
                                .addMediaCategory(value);
                            if (!mounted) return;
                            setState(() {
                              _categoryOptions =
                                  _mergeCategories(updated, _customCategories);
                              _selectedCategory = value;
                              _newCategoryController.clear();
                            });
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to add category: $e')),
                            );
                          }
                        },
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _thumbnailUrlController,
              decoration: const InputDecoration(
                labelText: 'Thumbnail URL',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.image),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaLinksCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.link, color: Colors.pink.shade600),
                const SizedBox(width: 8),
                const Text(
                  'Production URLs',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _newUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Add URL',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    final value = _newUrlController.text.trim();
                    if (value.isEmpty) return;
                    setState(() {
                      _productionUrls.add(value);
                      _newUrlController.clear();
                    });
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
            if (_productionUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _productionUrls
                    .map(
                      (url) => Chip(
                        label: Text(
                          url,
                          overflow: TextOverflow.ellipsis,
                        ),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () {
                          setState(() => _productionUrls.remove(url));
                        },
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStaffAssignmentCard() {
    final selectedStaffNames = _allStaff
        .where((staff) => _selectedStaffIds.contains(staff.id))
        .map((staff) => staff.fullName)
        .toList();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Colors.pink.shade600),
                const SizedBox(width: 8),
                const Text(
                  'Staff Assignment',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _isStaffLoading ? null : _showStaffSelector,
                  icon: const Icon(Icons.edit),
                  label: const Text('Assign'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isStaffLoading)
              const LinearProgressIndicator()
            else if (selectedStaffNames.isEmpty)
              Text(
                'No staff assigned',
                style: TextStyle(color: Colors.grey[600]),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: selectedStaffNames
                    .map((name) => Chip(label: Text(name)))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showStaffSelector() async {
    final searchController = TextEditingController();
    final tempSelected = Set<String>.from(_selectedStaffIds);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final query = searchController.text.trim().toLowerCase();
          final filtered = query.isEmpty
              ? _allStaff
              : _allStaff
                  .where((staff) =>
                      staff.fullName.toLowerCase().contains(query) ||
                      staff.department.toLowerCase().contains(query))
                  .toList();

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) => Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Assign Staff',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(sheetContext).pop(),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search staff',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setSheetState(() {}),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final staff = filtered[index];
                        final isSelected = tempSelected.contains(staff.id);
                        return CheckboxListTile(
                          title: Text(staff.fullName),
                          subtitle: Text('${staff.position} • ${staff.department}'),
                          value: isSelected,
                          onChanged: (value) {
                            setSheetState(() {
                              if (value == true) {
                                tempSelected.add(staff.id);
                              } else {
                                tempSelected.remove(staff.id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedStaffIds
                              ..clear()
                              ..addAll(tempSelected);
                          });
                          Navigator.of(sheetContext).pop();
                        },
                        child: const Text('Apply Selection'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    searchController.dispose();
  }

  int? _parseDurationMinutes(String value) {
    if (value.isEmpty) return null;
    if (value.contains(':')) {
      final parts = value.split(':');
      if (parts.length != 2) return null;
      final hours = int.tryParse(parts[0]);
      final minutes = int.tryParse(parts[1]);
      if (hours == null || minutes == null || minutes < 0 || minutes >= 60) {
        return null;
      }
      return hours * 60 + minutes;
    }
    final minutes = int.tryParse(value);
    if (minutes == null || minutes < 0) return null;
    return minutes;
  }

  String _formatDurationInput(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) return minutes.toString();
    return '$hours:${mins.toString().padLeft(2, '0')}';
  }

  List<String> _mergeCategories(List<String> global, List<String> legacy) {
    final set = <String>{};
    for (final category in _baseCategories) {
      set.add(category);
    }
    for (final category in global) {
      set.add(category);
    }
    for (final category in legacy) {
      set.add(category);
    }
    return set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  Widget _buildNotesCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.note, color: Colors.pink.shade600),
                const SizedBox(width: 8),
                const Text(
                  'Notes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Additional Notes',
                hintText: 'Enter any additional notes...',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _saveProduction,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.save),
        label: Text(_isEditMode ? 'Update Production' : 'Create Production'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.pink,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
