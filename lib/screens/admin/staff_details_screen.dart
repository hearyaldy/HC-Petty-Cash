import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../models/staff.dart';
import '../../models/staff_document.dart';
import '../../models/enums.dart';
import '../../models/salary_benefits.dart';
import '../../services/staff_service.dart';
import '../../services/salary_benefits_service.dart';
import '../../services/staff_record_pdf_service.dart';
import '../../utils/responsive_helper.dart';
import '../../utils/constants.dart';

class StaffDetailsScreen extends StatefulWidget {
  final String staffId;

  const StaffDetailsScreen({super.key, required this.staffId});

  @override
  State<StaffDetailsScreen> createState() => _StaffDetailsScreenState();
}

class _StaffDetailsScreenState extends State<StaffDetailsScreen> {
  final StaffService _staffService = StaffService();
  final SalaryBenefitsService _salaryBenefitsService = SalaryBenefitsService();
  final StaffRecordPdfService _pdfService = StaffRecordPdfService();
  Staff? _staff;
  SalaryBenefits? _salaryBenefits;
  bool _isLoading = true;
  final currencyFormat = NumberFormat.currency(
    symbol: '${AppConstants.currencySymbol} ',
    decimalDigits: 0,
  );

  double get _photoScale => _staff?.photoScale ?? 1.0;
  double get _photoOffsetX => _staff?.photoOffsetX ?? 0.0;
  double get _photoOffsetY => _staff?.photoOffsetY ?? 0.0;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    try {
      final staff = await _staffService.getStaffById(widget.staffId);
      SalaryBenefits? salaryBenefits;

      // Load salary benefits for this staff member
      try {
        salaryBenefits = await _salaryBenefitsService
            .getCurrentSalaryBenefitsOnce(widget.staffId);
      } catch (e) {
        debugPrint('Error loading salary benefits: $e');
      }

      setState(() {
        _staff = staff;
        _salaryBenefits = salaryBenefits;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading staff: $e')));
      }
    }
  }

  Future<void> _deleteDocument(String documentId) async {
    try {
      await _staffService.deleteStaffDocument(documentId, widget.staffId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadStaff();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openDocument(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open document')),
        );
      }
    }
  }

  Future<void> _syncHrData() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.sync, color: Colors.blue),
            SizedBox(width: 12),
            Text('Sync HR Data'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will update the user\'s HR data submission with the current salary and benefits information.',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data to be synced:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('• Base Salary & Wage Factor'),
                  const Text('• Salary Percentage'),
                  const Text('• All Allowances'),
                  const Text('• Calculated Salary'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.sync),
            label: const Text('Sync Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Syncing HR data...'),
          ],
        ),
      ),
    );

    try {
      final success = await _salaryBenefitsService.syncStaffDataToHrSubmission(
        widget.staffId,
      );

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('HR data synced successfully!'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No HR submission found or salary benefits not set up for this staff.',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.orange.shade700,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error syncing HR data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Staff Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_staff == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Staff Details')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Staff not found',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.go('/dashboard'),
                icon: const Icon(Icons.home),
                label: const Text('Go to Dashboard'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: ResponsiveContainer(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildQuickStats(),
                    const SizedBox(height: 20),
                    _buildPersonalContactSection(),
                    const SizedBox(height: 16),
                    _buildEmploymentSection(),
                    const SizedBox(height: 16),
                    _buildFinancialSection(),
                    const SizedBox(height: 16),
                    _buildDocumentsSection(),
                    if (_staff!.notes != null) ...[
                      const SizedBox(height: 16),
                      _buildNotesSection(),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.indigo.shade700,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.indigo.shade800,
                Colors.indigo.shade600,
                Colors.blue.shade500,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 50, 24, 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Hero(
                    tag: 'staff_avatar_${widget.staffId}',
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 45,
                        backgroundColor: Colors.white,
                        child: _buildAvatarImage(size: 90),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _staff!.fullName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_staff!.position} • ${_staff!.department}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  _buildStatusChip(_staff!.employmentStatus),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.print, color: Colors.white),
          onPressed: _printStaffRecord,
          tooltip: 'Print Staff Record',
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          tooltip: 'More Options',
          onSelected: (value) {
            switch (value) {
              case 'photo_adjust':
                _showPhotoAdjustDialog();
                break;
              case 'edit':
                context.push('/admin/staff/edit/${widget.staffId}');
                break;
              case 'edit_id':
                _showEditStaffIdDialog();
                break;
              case 'sync_hr_data':
                _syncHrData();
                break;
              case 'home':
                context.go('/dashboard');
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'photo_adjust',
              child: ListTile(
                leading: Icon(Icons.tune),
                title: Text('Adjust Photo'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Edit Staff'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'edit_id',
              child: ListTile(
                leading: Icon(Icons.badge),
                title: Text('Edit Staff ID'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'sync_hr_data',
              child: ListTile(
                leading: Icon(Icons.sync, color: Colors.blue),
                title: Text('Sync HR Data'),
                subtitle: Text('Update user\'s HR submission'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'home',
              child: ListTile(
                leading: Icon(Icons.home_outlined),
                title: Text('Go to Dashboard'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusChip(EmploymentStatus status) {
    Color bgColor;
    Color textColor = Colors.white;
    IconData icon;

    switch (status) {
      case EmploymentStatus.active:
        bgColor = Colors.green.shade400;
        icon = Icons.check_circle;
        break;
      case EmploymentStatus.onLeave:
        bgColor = Colors.orange.shade400;
        icon = Icons.pause_circle;
        break;
      case EmploymentStatus.resigned:
        bgColor = Colors.grey.shade500;
        icon = Icons.exit_to_app;
        break;
      case EmploymentStatus.terminated:
        bgColor = Colors.red.shade400;
        icon = Icons.cancel;
        break;
      case EmploymentStatus.retired:
        bgColor = Colors.purple.shade400;
        icon = Icons.elderly;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: bgColor.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 18),
          const SizedBox(width: 6),
          Text(
            status.displayName,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarImage({required double size}) {
    if (_staff?.photoUrl == null) {
      return Text(
        _staff!.fullName.isNotEmpty ? _staff!.fullName[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
          color: Colors.indigo.shade700,
        ),
      );
    }

    final scale = _photoScale.clamp(0.6, 3.0);
    final offsetX = _photoOffsetX.clamp(-1.0, 1.0);
    final offsetY = _photoOffsetY.clamp(-1.0, 1.0);

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Transform.translate(
          offset: Offset(offsetX * (size / 4), offsetY * (size / 4)),
          child: Transform.scale(
            scale: scale,
            child: Image.network(
              _staff!.photoUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showPhotoAdjustDialog() async {
    if (_staff?.photoUrl == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No photo to adjust')));
      }
      return;
    }

    double scale = _photoScale;
    double offsetX = _photoOffsetX;
    double offsetY = _photoOffsetY;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Adjust Photo'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipOval(
                      child: Transform.translate(
                        offset: Offset(offsetX * 30, offsetY * 30),
                        child: Transform.scale(
                          scale: scale,
                          child: Image.network(
                            _staff!.photoUrl!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const SizedBox(width: 90, child: Text('Size')),
                    Expanded(
                      child: Slider(
                        value: scale,
                        min: 0.8,
                        max: 2.5,
                        divisions: 17,
                        label: scale.toStringAsFixed(2),
                        onChanged: (value) {
                          setDialogState(() => scale = value);
                        },
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const SizedBox(width: 90, child: Text('Horizontal')),
                    Expanded(
                      child: Slider(
                        value: offsetX,
                        min: -1.0,
                        max: 1.0,
                        divisions: 20,
                        label: offsetX.toStringAsFixed(2),
                        onChanged: (value) {
                          setDialogState(() => offsetX = value);
                        },
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const SizedBox(width: 90, child: Text('Vertical')),
                    Expanded(
                      child: Slider(
                        value: offsetY,
                        min: -1.0,
                        max: 1.0,
                        divisions: 20,
                        label: offsetY.toStringAsFixed(2),
                        onChanged: (value) {
                          setDialogState(() => offsetY = value);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setDialogState(() {
                  scale = 1.0;
                  offsetX = 0.0;
                  offsetY = 0.0;
                });
              },
              child: const Text('Reset'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && _staff != null) {
      try {
        final updated = _staff!.copyWith(
          photoScale: scale,
          photoOffsetX: offsetX,
          photoOffsetY: offsetY,
          updatedAt: DateTime.now(),
        );
        await _staffService.updateStaff(updated);
        if (mounted) {
          setState(() => _staff = updated);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo settings saved'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving photo settings: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Employee ID',
            _staff!.employeeId,
            Icons.badge,
            [Colors.blue.shade400, Colors.blue.shade600],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Years of Service',
            '${_staff!.yearsOfService}',
            Icons.timeline,
            [Colors.teal.shade400, Colors.teal.shade600],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Documents',
            '${_staff!.documentsCount}',
            Icons.folder,
            [Colors.orange.shade400, Colors.orange.shade600],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    List<Color> gradientColors,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Color> iconGradient,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: iconGradient),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalContactSection() {
    final hasEmergencyContact = _staff!.emergencyContactName != null;

    return _buildSectionCard(
      title: 'Personal & Contact',
      icon: Icons.person,
      iconGradient: [Colors.indigo.shade400, Colors.indigo.shade600],
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Basic Information Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionSubtitle('Basic Information'),
                  const SizedBox(height: 8),
                  _buildCompactInfoRow('Email', _staff!.email, Icons.email),
                  if (_staff!.dateOfBirth != null)
                    _buildCompactInfoRow(
                      'Date of Birth',
                      DateFormat('MMM d, yyyy').format(_staff!.dateOfBirth!),
                      Icons.cake,
                    ),
                  if (_staff!.gender != null)
                    _buildCompactInfoRow(
                      'Gender',
                      _staff!.gender!.displayName,
                      Icons.wc,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Contact Information Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionSubtitle('Contact Details'),
                  const SizedBox(height: 8),
                  if (_staff!.phoneNumber != null)
                    _buildCompactInfoRow(
                      'Phone',
                      _staff!.phoneNumber!,
                      Icons.phone,
                    ),
                  if (_staff!.address != null)
                    _buildCompactInfoRow(
                      'Address',
                      _staff!.address!,
                      Icons.location_on,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // ID & Location Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionSubtitle('ID & Location'),
                  const SizedBox(height: 8),
                  if (_staff!.nationalIdNumber != null &&
                      _staff!.nationalIdNumber!.isNotEmpty)
                    _buildCompactInfoRow(
                      'National ID',
                      _staff!.nationalIdNumber!,
                      Icons.badge,
                    ),
                  if (_staff!.passportNumber != null &&
                      _staff!.passportNumber!.isNotEmpty)
                    _buildCompactInfoRow(
                      'Passport',
                      _staff!.passportNumber!,
                      Icons.card_travel,
                    ),
                  if (_staff!.country != null && _staff!.country!.isNotEmpty)
                    _buildCompactInfoRow(
                      'Country',
                      _staff!.country!,
                      Icons.public,
                    ),
                  if (_staff!.provinceState != null &&
                      _staff!.provinceState!.isNotEmpty)
                    _buildCompactInfoRow(
                      'Province/State',
                      _staff!.provinceState!,
                      Icons.location_city,
                    ),
                  if ((_staff!.nationalIdNumber == null ||
                          _staff!.nationalIdNumber!.isEmpty) &&
                      (_staff!.passportNumber == null ||
                          _staff!.passportNumber!.isEmpty) &&
                      (_staff!.country == null || _staff!.country!.isEmpty) &&
                      (_staff!.provinceState == null ||
                          _staff!.provinceState!.isEmpty))
                    Text(
                      'No ID/Location info',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (hasEmergencyContact) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.emergency, color: Colors.red.shade700, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Emergency Contact',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_staff!.emergencyContactName!}${_staff!.emergencyContactPhone != null ? ' - ${_staff!.emergencyContactPhone}' : ''}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionSubtitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade700,
      ),
    );
  }

  Widget _buildCompactInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmploymentSection() {
    return _buildSectionCard(
      title: 'Employment Details',
      icon: Icons.work,
      iconGradient: [Colors.purple.shade400, Colors.purple.shade600],
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Column 1
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCompactInfoRow(
                    'Department',
                    _staff!.department,
                    Icons.business,
                  ),
                  _buildCompactInfoRow(
                    'Position',
                    _staff!.position,
                    Icons.work_outline,
                  ),
                  _buildCompactInfoRow(
                    'System Role',
                    _staff!.role.displayName,
                    Icons.security,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Column 2
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCompactInfoRow(
                    'Employment Type',
                    _staff!.employmentType.displayName,
                    Icons.badge,
                  ),
                  _buildCompactInfoRow(
                    'Date of Joining',
                    DateFormat('MMM d, yyyy').format(_staff!.dateOfJoining),
                    Icons.event_available,
                  ),
                  if (_staff!.dateOfLeaving != null)
                    _buildCompactInfoRow(
                      'Date of Leaving',
                      DateFormat('MMM d, yyyy').format(_staff!.dateOfLeaving!),
                      Icons.event_busy,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Column 3
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCompactInfoRow(
                    'Years of Service',
                    '${_staff!.yearsOfService} years',
                    Icons.timeline,
                  ),
                  if (_staff!.approvalLimit != null)
                    _buildCompactInfoRow(
                      'Approval Limit',
                      currencyFormat.format(_staff!.approvalLimit!),
                      Icons.verified_user,
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFinancialSection() {
    final hasFinancialInfo =
        _staff!.bankAccountNumber != null ||
        _staff!.bankName != null ||
        _staff!.taxId != null ||
        _staff!.monthlySalary != null ||
        _salaryBenefits != null;

    return _buildSectionCard(
      title: 'Financial Information',
      icon: Icons.account_balance_wallet,
      iconGradient: [Colors.amber.shade600, Colors.orange.shade600],
      trailing: ElevatedButton.icon(
        onPressed: () => _navigateToSalaryBenefits(),
        icon: const Icon(Icons.monetization_on, size: 18),
        label: const Text('Manage'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      children: hasFinancialInfo
          ? [
              // Salary highlight card
              if (_staff!.monthlySalary != null || _salaryBenefits != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade50, Colors.teal.shade50],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.attach_money,
                          color: Colors.green.shade700,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Monthly Salary (Gross)',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currencyFormat.format(
                                _salaryBenefits?.grossSalary ??
                                    _staff!.monthlySalary ??
                                    0,
                              ),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_salaryBenefits != null) ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Net Salary',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currencyFormat.format(
                                  _salaryBenefits!.netSalary,
                                ),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Salary Structure Section (from SalaryBenefits)
              if (_salaryBenefits != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Salary Structure Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionSubtitle('Salary Structure'),
                          const SizedBox(height: 8),
                          if (_salaryBenefits!.wageFactor != null)
                            _buildCompactInfoRow(
                              'Wage Factor',
                              currencyFormat.format(
                                _salaryBenefits!.wageFactor!,
                              ),
                              Icons.calculate,
                            ),
                          if (_salaryBenefits!.salaryPercentage != null)
                            _buildCompactInfoRow(
                              'Salary %',
                              '${_salaryBenefits!.salaryPercentage!.toStringAsFixed(1)}%',
                              Icons.percent,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Allowances Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionSubtitle('Allowances'),
                          const SizedBox(height: 8),
                          if (_salaryBenefits!.housingAllowance != null)
                            _buildCompactInfoRow(
                              'Housing',
                              currencyFormat.format(
                                _salaryBenefits!.housingAllowance!,
                              ),
                              Icons.home,
                            ),
                          if (_salaryBenefits!.phoneAllowance != null)
                            _buildCompactInfoRow(
                              'Phone',
                              currencyFormat.format(
                                _salaryBenefits!.phoneAllowance!,
                              ),
                              Icons.phone,
                            ),
                          if (_salaryBenefits!.continueEducationAllowance !=
                              null)
                            _buildCompactInfoRow(
                              'Education',
                              currencyFormat.format(
                                _salaryBenefits!.continueEducationAllowance!,
                              ),
                              Icons.school,
                            ),
                          if (_salaryBenefits!.equipmentAllowance != null)
                            _buildCompactInfoRow(
                              'Equipment',
                              currencyFormat.format(
                                _salaryBenefits!.equipmentAllowance!,
                              ),
                              Icons.computer,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Health Benefits Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionSubtitle('Health Benefits'),
                          const SizedBox(height: 8),
                          if (_salaryBenefits!.outPatientPercentage != null)
                            _buildCompactInfoRow(
                              'Out-Patient',
                              '${_salaryBenefits!.outPatientPercentage!.toStringAsFixed(0)}%',
                              Icons.local_hospital,
                            ),
                          if (_salaryBenefits!.inPatientPercentage != null)
                            _buildCompactInfoRow(
                              'In-Patient',
                              '${_salaryBenefits!.inPatientPercentage!.toStringAsFixed(0)}%',
                              Icons.hotel,
                            ),
                          if (_salaryBenefits!.annualLeaveDays != null)
                            _buildCompactInfoRow(
                              'Annual Leave',
                              '${_salaryBenefits!.annualLeaveDays} days',
                              Icons.beach_access,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Banking and Deductions Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banking Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionSubtitle('Banking'),
                        const SizedBox(height: 8),
                        if (_staff!.bankName != null)
                          _buildCompactInfoRow(
                            'Bank Name',
                            _staff!.bankName!,
                            Icons.business,
                          ),
                        if (_staff!.bankAccountNumber != null)
                          _buildCompactInfoRow(
                            'Account',
                            _staff!.bankAccountNumber!,
                            Icons.account_balance,
                          ),
                        if (_staff!.taxId != null)
                          _buildCompactInfoRow(
                            'Tax ID',
                            _staff!.taxId!,
                            Icons.numbers,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Compensation Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionSubtitle('Total Compensation'),
                        const SizedBox(height: 8),
                        if (_salaryBenefits != null)
                          _buildCompactInfoRow(
                            'Total',
                            currencyFormat.format(
                              _salaryBenefits!.totalCompensation,
                            ),
                            Icons.account_balance_wallet,
                          ),
                        if (_staff!.allowances != null &&
                            _salaryBenefits == null)
                          _buildCompactInfoRow(
                            'Allowances',
                            currencyFormat.format(_staff!.allowances!),
                            Icons.money,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Deductions Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionSubtitle('Deductions'),
                        const SizedBox(height: 8),
                        if (_salaryBenefits?.tithePercentage != null ||
                            _staff!.tithePercentage != null)
                          _buildCompactInfoRow(
                            'Tithe',
                            '${(_salaryBenefits?.tithePercentage ?? _staff!.tithePercentage)!.toStringAsFixed(1)}%',
                            Icons.percent,
                          ),
                        if (_salaryBenefits?.houseRentalPercentage != null)
                          _buildCompactInfoRow(
                            'House Rental',
                            '${_salaryBenefits!.houseRentalPercentage!.toStringAsFixed(1)}%',
                            Icons.house,
                          ),
                        if (_salaryBenefits?.socialSecurityPercentage != null ||
                            _staff!.socialSecurityAmount != null)
                          _buildCompactInfoRow(
                            'Social Security',
                            currencyFormat.format(
                              _salaryBenefits?.socialSecurityAmount ??
                                  _staff!.socialSecurityAmount ??
                                  0,
                            ),
                            Icons.shield,
                          ),
                        if (_salaryBenefits?.providentFundPercentage != null ||
                            _staff!.providentFundPercentage != null)
                          _buildCompactInfoRow(
                            'Provident Fund',
                            '${(_salaryBenefits?.providentFundPercentage ?? _staff!.providentFundPercentage)!.toStringAsFixed(1)}%',
                            Icons.savings,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ]
          : [
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No financial information available',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
    );
  }

  Widget _buildDocumentsSection() {
    return _buildSectionCard(
      title: 'Documents (${_staff!.documentsCount})',
      icon: Icons.folder,
      iconGradient: [Colors.blue.shade400, Colors.cyan.shade500],
      trailing: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.add, color: Colors.blue.shade700, size: 20),
        ),
        onPressed: () => context.push('/admin/staff/edit/${widget.staffId}'),
        tooltip: 'Add Document',
      ),
      children: [
        StreamBuilder<List<StaffDocument>>(
          stream: _staffService.getStaffDocuments(widget.staffId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: TextStyle(color: Colors.red.shade700),
                ),
              );
            }

            final documents = snapshot.data ?? [];

            if (documents.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.file_present,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No documents uploaded',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap + to add documents',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: documents
                  .map((doc) => _buildDocumentCard(doc))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDocumentCard(StaffDocument doc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: _getDocumentColor(doc.type).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(doc.type.icon, style: const TextStyle(fontSize: 24)),
          ),
        ),
        title: Text(
          doc.fileName,
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getDocumentColor(doc.type).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                doc.type.displayName,
                style: TextStyle(
                  fontSize: 11,
                  color: _getDocumentColor(doc.type),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${doc.formattedFileSize} • ${DateFormat('MMM d, y').format(doc.uploadedAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.download, color: Colors.blue.shade600),
              onPressed: () => _openDocument(doc.fileUrl),
              tooltip: 'Download',
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
              onPressed: () => _showDeleteDialog(doc),
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }

  Color _getDocumentColor(DocumentType type) {
    switch (type) {
      case DocumentType.idCard:
        return Colors.blue;
      case DocumentType.passport:
        return Colors.indigo;
      case DocumentType.resume:
        return Colors.teal;
      case DocumentType.contract:
        return Colors.purple;
      case DocumentType.certificate:
        return Colors.orange;
      case DocumentType.drivingLicense:
        return Colors.green;
      case DocumentType.other:
        return Colors.grey;
    }
  }

  void _showDeleteDialog(StaffDocument doc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red.shade600),
            const SizedBox(width: 8),
            const Text('Delete Document'),
          ],
        ),
        content: Text('Are you sure you want to delete "${doc.fileName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteDocument(doc.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return _buildSectionCard(
      title: 'Notes',
      icon: Icons.note,
      iconGradient: [Colors.grey.shade500, Colors.grey.shade700],
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.sticky_note_2, color: Colors.amber.shade700, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _staff!.notes!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade800,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _navigateToSalaryBenefits() {
    context.push(
      '/admin/salary-benefits/edit',
      extra: {'staff': _staff, 'salaryBenefits': _salaryBenefits},
    );
  }

  Future<void> _printStaffRecord() async {
    if (_staff == null) return;

    try {
      final pdfBytes = await _pdfService.generateStaffRecordPdf(
        _staff!,
        salaryBenefits: _salaryBenefits,
      );
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'Staff_Record_${_staff!.fullName.replaceAll(' ', '_')}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showEditStaffIdDialog() async {
    if (_staff == null) return;

    final controller = TextEditingController(text: _staff!.employeeId);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.badge, color: Colors.blue.shade700, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Edit Staff ID'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current ID: ${_staff!.employeeId}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'New Staff ID',
                hintText: 'e.g., HC-2024-95',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.edit),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              'Format: HC-[Year of Joining]-[Last 2 digits of Birth Year]',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            icon: const Icon(Icons.save, size: 18),
            label: const Text('Save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != _staff!.employeeId) {
      await _updateStaffId(result);
    }
  }

  Future<void> _updateStaffId(String newStaffId) async {
    try {
      await _staffService.updateStaffEmployeeId(widget.staffId, newStaffId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Staff ID updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadStaff(); // Reload staff data
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating Staff ID: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
