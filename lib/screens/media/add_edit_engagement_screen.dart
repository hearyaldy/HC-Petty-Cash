import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/media_production_provider.dart';
import '../../models/media_production.dart';
import '../../models/enums.dart';
import '../../utils/responsive_helper.dart';

class AddEditEngagementScreen extends StatefulWidget {
  final String? productionId;
  final String? engagementId;

  const AddEditEngagementScreen({
    super.key,
    this.productionId,
    this.engagementId,
  });

  @override
  State<AddEditEngagementScreen> createState() => _AddEditEngagementScreenState();
}

class _AddEditEngagementScreenState extends State<AddEditEngagementScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _viewsController = TextEditingController(text: '0');
  final _likesController = TextEditingController(text: '0');
  final _commentsController = TextEditingController(text: '0');
  final _sharesController = TextEditingController(text: '0');
  final _subscribersController = TextEditingController();
  final _watchTimeController = TextEditingController();
  final _impressionsController = TextEditingController();
  final _reachController = TextEditingController();
  final _savesController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedProductionId;
  String _selectedPlatform = MediaPlatform.youtube.name;
  DateTime _recordedDate = DateTime.now();
  DateTime _periodStart = DateTime.now().subtract(const Duration(days: 30));
  DateTime _periodEnd = DateTime.now();

  bool _isLoading = false;
  List<MediaProduction> _productions = [];

  @override
  void initState() {
    super.initState();
    _selectedProductionId = widget.productionId;
    _loadProductions();
  }

  Future<void> _loadProductions() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final mediaProvider = Provider.of<MediaProductionProvider>(context, listen: false);
      final user = authProvider.currentUser;
      final isAdmin = user?.role == 'admin';

      if (isAdmin) {
        await mediaProvider.loadAllProductions();
      } else if (user != null) {
        await mediaProvider.loadProductionsForUser(user.mediaPermissions.assignedLanguages);
      }

      setState(() {
        _productions = mediaProvider.productions;
      });
    } catch (e) {
      debugPrint('Error loading productions: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveEngagement() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProductionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a production')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final provider = Provider.of<MediaProductionProvider>(context, listen: false);
      final user = authProvider.currentUser!;

      await provider.addEngagement(
        productionId: _selectedProductionId!,
        platform: _selectedPlatform,
        recordedDate: _recordedDate,
        periodStart: _periodStart,
        periodEnd: _periodEnd,
        views: int.tryParse(_viewsController.text) ?? 0,
        likes: int.tryParse(_likesController.text) ?? 0,
        comments: int.tryParse(_commentsController.text) ?? 0,
        shares: int.tryParse(_sharesController.text) ?? 0,
        subscribers: _subscribersController.text.isNotEmpty
            ? int.tryParse(_subscribersController.text)
            : null,
        watchTimeHours: _watchTimeController.text.isNotEmpty
            ? int.tryParse(_watchTimeController.text)
            : null,
        impressions: _impressionsController.text.isNotEmpty
            ? int.tryParse(_impressionsController.text)
            : null,
        reach: _reachController.text.isNotEmpty
            ? int.tryParse(_reachController.text)
            : null,
        saves: _savesController.text.isNotEmpty
            ? int.tryParse(_savesController.text)
            : null,
        enteredById: user.id,
        enteredByName: user.name,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Engagement data saved successfully')),
        );
        context.pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(String type) async {
    final initialDate = type == 'recorded'
        ? _recordedDate
        : type == 'start'
            ? _periodStart
            : _periodEnd;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );

    if (picked != null) {
      setState(() {
        if (type == 'recorded') {
          _recordedDate = picked;
        } else if (type == 'start') {
          _periodStart = picked;
        } else {
          _periodEnd = picked;
        }
      });
    }
  }

  @override
  void dispose() {
    _viewsController.dispose();
    _likesController.dispose();
    _commentsController.dispose();
    _sharesController.dispose();
    _subscribersController.dispose();
    _watchTimeController.dispose();
    _impressionsController.dispose();
    _reachController.dispose();
    _savesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: _isLoading && _productions.isEmpty
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
                          _buildProductionSelector(),
                          const SizedBox(height: 16),
                          _buildPlatformAndDate(),
                          const SizedBox(height: 16),
                          _buildCoreMetrics(),
                          const SizedBox(height: 16),
                          _buildPlatformSpecificMetrics(),
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
                        onPressed: _saveEngagement,
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
                            'Add Engagement Data',
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
                            'Record social media engagement metrics',
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
                      child: const Icon(
                        Icons.analytics,
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

  Widget _buildProductionSelector() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.video_library, color: Colors.pink.shade600),
                const SizedBox(width: 8),
                const Text(
                  'Select Production',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedProductionId,
              decoration: const InputDecoration(
                labelText: 'Production *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.movie),
              ),
              items: _productions.map((production) {
                return DropdownMenuItem(
                  value: production.id,
                  child: Text(
                    '${production.title} (${production.languageDisplayName})',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedProductionId = value);
              },
              validator: (value) {
                if (value == null) return 'Please select a production';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformAndDate() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.pink.shade600),
                const SizedBox(width: 8),
                const Text(
                  'Platform & Period',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedPlatform,
              decoration: const InputDecoration(
                labelText: 'Platform *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.public),
              ),
              items: MediaPlatform.values.map((platform) {
                return DropdownMenuItem(
                  value: platform.name,
                  child: Text(platform.displayName),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedPlatform = value!);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDateField(
                    'Recorded Date',
                    _recordedDate,
                    () => _selectDate('recorded'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDateField(
                    'Period Start',
                    _periodStart,
                    () => _selectDate('start'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDateField(
                    'Period End',
                    _periodEnd,
                    () => _selectDate('end'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField(String label, DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(DateFormat('MMM dd, yyyy').format(date)),
      ),
    );
  }

  Widget _buildCoreMetrics() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.pink.shade600),
                const SizedBox(width: 8),
                const Text(
                  'Core Metrics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildNumberField(
                    'Views',
                    _viewsController,
                    Icons.visibility,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildNumberField(
                    'Likes',
                    _likesController,
                    Icons.thumb_up,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildNumberField(
                    'Comments',
                    _commentsController,
                    Icons.comment,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildNumberField(
                    'Shares',
                    _sharesController,
                    Icons.share,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformSpecificMetrics() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: Colors.pink.shade600),
                const SizedBox(width: 8),
                const Text(
                  'Platform-Specific Metrics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Optional fields based on platform',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 16),
            if (_selectedPlatform == 'youtube') ...[
              Row(
                children: [
                  Expanded(
                    child: _buildNumberField(
                      'New Subscribers',
                      _subscribersController,
                      Icons.person_add,
                      Colors.red,
                      required: false,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildNumberField(
                      'Watch Time (hours)',
                      _watchTimeController,
                      Icons.access_time,
                      Colors.red,
                      required: false,
                    ),
                  ),
                ],
              ),
            ],
            if (_selectedPlatform == 'facebook' || _selectedPlatform == 'instagram') ...[
              Row(
                children: [
                  Expanded(
                    child: _buildNumberField(
                      'Impressions',
                      _impressionsController,
                      Icons.remove_red_eye,
                      Colors.blue,
                      required: false,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildNumberField(
                      'Reach',
                      _reachController,
                      Icons.groups,
                      Colors.blue,
                      required: false,
                    ),
                  ),
                ],
              ),
            ],
            if (_selectedPlatform == 'instagram') ...[
              const SizedBox(height: 16),
              _buildNumberField(
                'Saves',
                _savesController,
                Icons.bookmark,
                Colors.pink,
                required: false,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNumberField(
    String label,
    TextEditingController controller,
    IconData icon,
    Color color, {
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon, color: color),
      ),
      keyboardType: TextInputType.number,
      validator: required
          ? (value) {
              if (value == null || value.isEmpty) {
                return 'Required';
              }
              if (int.tryParse(value) == null) {
                return 'Enter a valid number';
              }
              return null;
            }
          : null,
    );
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
                hintText: 'Any observations or comments...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
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
        onPressed: _isLoading ? null : _saveEngagement,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.save),
        label: const Text('Save Engagement Data'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.pink,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
