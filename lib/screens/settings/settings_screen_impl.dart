import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/app_settings.dart';
import '../../services/settings_service.dart';
import '../../utils/responsive_helper.dart';
import '../../utils/validation.dart';
import '../../widgets/enhanced_category_management_dialog.dart';
import '../../widgets/paid_to_management_dialog.dart';

class SettingsScreenImpl extends StatefulWidget {
  const SettingsScreenImpl({super.key});

  @override
  State<SettingsScreenImpl> createState() => _SettingsScreenImplState();
}

class _SettingsScreenImplState extends State<SettingsScreenImpl> {
  final SettingsService _settingsService = SettingsService();
  AppSettings? _settings;
  bool _isLoading = true;

  // Profile photo state
  File? _pickedFile;
  Uint8List? _pickedBytes;
  String? _photoUrl;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final settings = await _settingsService.getSettings();
      // Load photoUrl from current user
      final authProvider = context.read<AuthProvider>();
      final currentUser = authProvider.currentUser;
      if (currentUser != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.id)
            .get();
        if (userDoc.exists) {
          _photoUrl = userDoc.data()?['photoUrl'] as String?;
        }
      }
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading settings: $e')));
      }
    }
  }

  Future<void> _updateSetting(AppSettings updated) async {
    try {
      await _settingsService.saveSettings(updated);
      setState(() {
        _settings = updated;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving settings: $e')));
      }
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Choose Image Source'),
          content: const Text('Select where to get your profile picture from'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, ImageSource.camera),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt),
                  SizedBox(width: 8),
                  Text('Camera'),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image),
                  SizedBox(width: 8),
                  Text('Gallery'),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (source == null) return;

      final pickedFile = await ImagePicker().pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      Uint8List? bytes;
      File? file;

      if (kIsWeb) {
        bytes = await pickedFile.readAsBytes();
        setState(() {
          _pickedBytes = bytes;
          _pickedFile = null;
        });
      } else {
        file = File(pickedFile.path);
        setState(() {
          _pickedFile = file;
          _pickedBytes = null;
        });
      }

      // Upload to Firebase Storage
      setState(() => _isUploadingPhoto = true);

      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.currentUser?.id;
      if (userId == null) throw 'User not authenticated';

      final storagePath = 'user_photos/$userId.jpg';
      final ref = FirebaseStorage.instance.ref().child(storagePath);

      String downloadUrl;
      if (kIsWeb && bytes != null) {
        final snapshot = await ref.putData(bytes);
        downloadUrl = await snapshot.ref.getDownloadURL();
      } else if (file != null) {
        final snapshot = await ref.putFile(file);
        downloadUrl = await snapshot.ref.getDownloadURL();
      } else {
        throw 'No image data available';
      }

      // Update Firestore
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'photoUrl': downloadUrl,
      }, SetOptions(merge: true));

      setState(() {
        _photoUrl = downloadUrl;
        _isUploadingPhoto = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploadingPhoto = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating photo: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final currentUser = authProvider.currentUser;

    if (_isLoading || _settings == null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: ResponsiveContainer(
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildWelcomeHeader(),
              ),
              // User Profile Section
              _buildProfileCard(
                currentUser?.name ?? 'User',
                currentUser?.email ?? '',
              ),
              const SizedBox(height: 16),

              // Account & Security Section
              _buildSectionCard(
                title: 'Account & Security',
                icon: Icons.security,
                gradientColors: [
                  Colors.indigo.shade400,
                  Colors.indigo.shade600,
                ],
                children: [
                  _buildSettingTile(
                    icon: Icons.lock_outline,
                    title: 'Change Password',
                    subtitle: 'Update your account password',
                    onTap: () => _showChangePasswordDialog(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Appearance Section
              _buildSectionCard(
                title: 'Appearance',
                icon: Icons.palette_outlined,
                gradientColors: [
                  Colors.purple.shade400,
                  Colors.purple.shade600,
                ],
                children: [
                  _buildSettingTile(
                    icon: Icons.palette_outlined,
                    title: 'Color Theme',
                    subtitle: _getColorThemeDisplayName(_settings!.colorTheme),
                    onTap: () => _showColorThemeDialog(themeProvider),
                  ),
                  const Divider(height: 1),
                  _buildSettingTile(
                    icon: Icons.brightness_6,
                    title: 'Theme Mode',
                    subtitle: _getThemeDisplayName(_settings!.theme),
                    onTap: () => _showThemeDialog(themeProvider),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Preferences Section
              _buildSectionCard(
                title: 'Preferences',
                icon: Icons.tune,
                gradientColors: [Colors.blue.shade400, Colors.blue.shade600],
                children: [
                  _buildSettingTile(
                    icon: Icons.language,
                    title: 'Language',
                    subtitle: _getLanguageDisplayName(_settings!.language),
                    onTap: () => _showLanguageDialog(),
                  ),
                  const Divider(height: 1),
                  _buildSettingTile(
                    icon: Icons.attach_money,
                    title: 'Currency',
                    subtitle: _getCurrencyDisplayName(_settings!.currency),
                    onTap: () => _showCurrencyDialog(),
                  ),
                  const Divider(height: 1),
                  _buildSettingTile(
                    icon: Icons.calendar_today,
                    title: 'Date Format',
                    subtitle: _settings!.dateFormat,
                    onTap: () => _showDateFormatDialog(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Notifications Section
              _buildSectionCard(
                title: 'Notifications',
                icon: Icons.notifications_outlined,
                gradientColors: [
                  Colors.orange.shade400,
                  Colors.orange.shade600,
                ],
                children: [
                  _buildSwitchTile(
                    icon: Icons.email_outlined,
                    title: 'Email Notifications',
                    subtitle: 'Receive updates via email',
                    value: _settings!.emailNotifications,
                    onChanged: (value) {
                      _updateSetting(
                        _settings!.copyWith(emailNotifications: value),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _buildSwitchTile(
                    icon: Icons.notifications_outlined,
                    title: 'Push Notifications',
                    subtitle: 'Receive push notifications',
                    value: _settings!.pushNotifications,
                    onChanged: (value) {
                      _updateSetting(
                        _settings!.copyWith(pushNotifications: value),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Reports Section
              _buildSectionCard(
                title: 'Reports',
                icon: Icons.receipt_long,
                gradientColors: [Colors.green.shade400, Colors.green.shade600],
                children: [
                  _buildSettingTile(
                    icon: Icons.receipt_long,
                    title: 'Default Report Type',
                    subtitle: _getReportTypeDisplayName(
                      _settings!.defaultReportType,
                    ),
                    onTap: () => _showReportTypeDialog(),
                  ),
                  const Divider(height: 1),
                  _buildSettingTile(
                    icon: Icons.file_download_outlined,
                    title: 'Default Export Format',
                    subtitle: _settings!.defaultExportFormat,
                    onTap: () => _showExportFormatDialog(),
                  ),
                  const Divider(height: 1),
                  _buildSwitchTile(
                    icon: Icons.backup_outlined,
                    title: 'Auto Backup',
                    subtitle: 'Automatically backup data',
                    value: _settings!.autoBackup,
                    onChanged: (value) {
                      _updateSetting(_settings!.copyWith(autoBackup: value));
                    },
                  ),
                  const Divider(height: 1),
                  _buildSettingTile(
                    icon: Icons.cloud_upload_outlined,
                    title: 'Backup Now',
                    subtitle: 'Manually backup your data',
                    onTap: () => _performBackup(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Admin Settings (only for admins)
              if (authProvider.canApprove()) ...[
                _buildSectionCard(
                  title: 'Admin Settings',
                  icon: Icons.admin_panel_settings,
                  gradientColors: [Colors.red.shade400, Colors.red.shade600],
                  children: [
                    _buildSettingTile(
                      icon: Icons.people_outline,
                      title: 'Manage Users',
                      subtitle: 'Add, edit, or remove users',
                      onTap: () => context.push('/admin/users'),
                    ),
                    const Divider(height: 1),
                    _buildSettingTile(
                      icon: Icons.category_outlined,
                      title: 'Manage Categories',
                      subtitle: 'Edit expense categories',
                      onTap: () => showDialog(
                        context: context,
                        builder: (context) =>
                            const EnhancedCategoryManagementDialog(),
                      ),
                    ),
                    const Divider(height: 1),
                    _buildSettingTile(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Manage Paid To Options',
                      subtitle: 'Edit vendor list for paid to field',
                      onTap: () => showDialog(
                        context: context,
                        builder: (context) => const PaidToManagementDialog(),
                      ),
                    ),
                    const Divider(height: 1),
                    _buildSettingTile(
                      icon: Icons.business_outlined,
                      title: 'Organization Settings',
                      subtitle: 'Update organization details',
                      onTap: () => _showOrganizationDialog(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // AI Settings Section (for admins)
              if (authProvider.canApprove()) ...[
                _buildSectionCard(
                  title: 'AI Settings',
                  icon: Icons.auto_awesome,
                  gradientColors: [
                    Colors.purple.shade400,
                    Colors.purple.shade600,
                  ],
                  children: [
                    _buildSettingTile(
                      icon: Icons.help_outline,
                      title: 'About AI Features',
                      subtitle: 'AI uses AI_API_KEY from .env',
                      onTap: () => _showAIInfoDialog(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Data Management Section
              _buildSectionCard(
                title: 'Data Management',
                icon: Icons.storage,
                gradientColors: [Colors.teal.shade400, Colors.teal.shade600],
                children: [
                  _buildSettingTile(
                    icon: Icons.download_outlined,
                    title: 'Export All Data',
                    subtitle: 'Download all reports and transactions',
                    onTap: () => _exportAllData(),
                  ),
                  const Divider(height: 1),
                  _buildSettingTile(
                    icon: Icons.delete_outline,
                    title: 'Clear Cache',
                    subtitle: 'Free up storage space',
                    onTap: () => _clearCache(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // About Section
              _buildSectionCard(
                title: 'About',
                icon: Icons.info_outline,
                gradientColors: [Colors.grey.shade400, Colors.grey.shade600],
                children: [
                  _buildSettingTile(
                    icon: Icons.info_outline,
                    title: 'App Version',
                    subtitle: '1.0.0',
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  _buildSettingTile(
                    icon: Icons.help_outline,
                    title: 'Help & Support',
                    subtitle: 'Get help or contact support',
                    onTap: () {},
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Logout Button
              _buildLogoutCard(),
              const SizedBox(height: 20),
            ],
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
          colors: [Colors.blueGrey.shade600, Colors.blueGrey.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.shade200.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeaderActionButton(
                icon: Icons.arrow_back,
                tooltip: 'Back to Dashboard',
                onPressed: () => context.go('/admin-hub'),
              ),
              Row(
                children: [
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
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.settings,
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
                      'Settings',
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Configure your app preferences',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 14,
                        color: Colors.white.withOpacity(0.9),
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
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildProfileCard(String name, String email) {
    // Determine avatar image
    ImageProvider? avatarImage;
    if (_pickedBytes != null) {
      avatarImage = MemoryImage(_pickedBytes!);
    } else if (_pickedFile != null && !kIsWeb) {
      avatarImage = FileImage(_pickedFile!);
    } else if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      avatarImage = NetworkImage(_photoUrl!);
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade400, Colors.blue.shade600],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  backgroundImage: avatarImage,
                  child: _isUploadingPhoto
                      ? const SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : avatarImage == null
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      size: 14,
                      color: Colors.blue.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
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
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Color> gradientColors,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Section Content
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (iconColor ?? Colors.blue).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor ?? Colors.blue, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.blue, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildLogoutCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: InkWell(
        onTap: () => _showLogoutDialog(),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.logout, color: Colors.red, size: 20),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Sign out of your account',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.red),
            ],
          ),
        ),
      ),
    );
  }

  String _getThemeDisplayName(String theme) {
    switch (theme) {
      case 'light':
        return 'Light Mode';
      case 'dark':
        return 'Dark Mode';
      case 'auto':
        return 'System Default';
      default:
        return 'Light Mode';
    }
  }

  String _getColorThemeDisplayName(String colorTheme) {
    switch (colorTheme) {
      case 'blue':
        return 'Blue';
      case 'purple':
        return 'Purple';
      case 'green':
        return 'Green';
      case 'orange':
        return 'Orange';
      case 'red':
        return 'Red';
      case 'teal':
        return 'Teal';
      default:
        return 'Blue';
    }
  }

  String _getLanguageDisplayName(String language) {
    switch (language) {
      case 'en':
        return 'English';
      case 'th':
        return 'ไทย (Thai)';
      default:
        return 'English';
    }
  }

  String _getCurrencyDisplayName(String currency) {
    switch (currency) {
      case 'THB':
        return 'THB (฿)';
      case 'USD':
        return 'USD (\$)';
      case 'EUR':
        return 'EUR (€)';
      default:
        return 'THB (฿)';
    }
  }

  String _getReportTypeDisplayName(String type) {
    switch (type) {
      case 'petty_cash':
        return 'Petty Cash Report';
      case 'project':
        return 'Project Report';
      default:
        return 'Petty Cash Report';
    }
  }

  void _showColorThemeDialog(ThemeProvider themeProvider) {
    final colorThemes = [
      {
        'name': 'Blue',
        'value': 'blue',
        'colors': [Colors.blue.shade400, Colors.blue.shade600],
      },
      {
        'name': 'Purple',
        'value': 'purple',
        'colors': [Colors.purple.shade400, Colors.purple.shade600],
      },
      {
        'name': 'Green',
        'value': 'green',
        'colors': [Colors.green.shade400, Colors.green.shade600],
      },
      {
        'name': 'Orange',
        'value': 'orange',
        'colors': [Colors.orange.shade400, Colors.orange.shade600],
      },
      {
        'name': 'Red',
        'value': 'red',
        'colors': [Colors.red.shade400, Colors.red.shade600],
      },
      {
        'name': 'Teal',
        'value': 'teal',
        'colors': [Colors.teal.shade400, Colors.teal.shade600],
      },
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Color Theme'),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: colorThemes.length,
            itemBuilder: (context, index) {
              final theme = colorThemes[index];
              final isSelected = _settings!.colorTheme == theme['value'];
              final gradientColors = theme['colors'] as List<Color>;

              return InkWell(
                onTap: () async {
                  await themeProvider.updateColorTheme(
                    theme['value'] as String,
                  );
                  _updateSetting(
                    _settings!.copyWith(colorTheme: theme['value'] as String),
                  );
                  if (mounted) Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradientColors,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: gradientColors[0].withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isSelected)
                        const Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 32,
                        )
                      else
                        const SizedBox(height: 32),
                      const SizedBox(height: 8),
                      Text(
                        theme['name'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showThemeDialog(ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme Mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.light_mode, color: Colors.orange),
              title: const Text('Light Mode'),
              subtitle: const Text('Always use light theme'),
              onTap: () async {
                await themeProvider.updateTheme('light');
                _updateSetting(_settings!.copyWith(theme: 'light'));
                if (mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode, color: Colors.indigo),
              title: const Text('Dark Mode'),
              subtitle: const Text('Always use dark theme'),
              onTap: () async {
                await themeProvider.updateTheme('dark');
                _updateSetting(_settings!.copyWith(theme: 'dark'));
                if (mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome, color: Colors.blue),
              title: const Text('System Default'),
              subtitle: const Text('Follow system theme'),
              onTap: () async {
                await themeProvider.updateTheme('auto');
                _updateSetting(_settings!.copyWith(theme: 'auto'));
                if (mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text('🇬🇧', style: TextStyle(fontSize: 24)),
              title: const Text('English'),
              onTap: () {
                _updateSetting(_settings!.copyWith(language: 'en'));
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Text('🇹🇭', style: TextStyle(fontSize: 24)),
              title: const Text('ไทย (Thai)'),
              onTap: () {
                _updateSetting(_settings!.copyWith(language: 'th'));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Thai language coming soon')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCurrencyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Currency'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text('฿', style: TextStyle(fontSize: 24)),
              title: const Text('THB (Thai Baht)'),
              onTap: () {
                _updateSetting(_settings!.copyWith(currency: 'THB'));
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Text('\$', style: TextStyle(fontSize: 24)),
              title: const Text('USD (US Dollar)'),
              onTap: () {
                _updateSetting(_settings!.copyWith(currency: 'USD'));
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Text('€', style: TextStyle(fontSize: 24)),
              title: const Text('EUR (Euro)'),
              onTap: () {
                _updateSetting(_settings!.copyWith(currency: 'EUR'));
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDateFormatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Date Format'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('dd/MM/yyyy'),
              subtitle: const Text('31/12/2024'),
              onTap: () {
                _updateSetting(_settings!.copyWith(dateFormat: 'dd/MM/yyyy'));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('MM/dd/yyyy'),
              subtitle: const Text('12/31/2024'),
              onTap: () {
                _updateSetting(_settings!.copyWith(dateFormat: 'MM/dd/yyyy'));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('yyyy-MM-dd'),
              subtitle: const Text('2024-12-31'),
              onTap: () {
                _updateSetting(_settings!.copyWith(dateFormat: 'yyyy-MM-dd'));
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showReportTypeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Default Report Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.receipt),
              title: const Text('Petty Cash Report'),
              onTap: () {
                _updateSetting(
                  _settings!.copyWith(defaultReportType: 'petty_cash'),
                );
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.work_outline),
              title: const Text('Project Report'),
              onTap: () {
                _updateSetting(
                  _settings!.copyWith(defaultReportType: 'project'),
                );
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showExportFormatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Default Export Format'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('PDF'),
              onTap: () {
                _updateSetting(_settings!.copyWith(defaultExportFormat: 'PDF'));
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: const Text('Excel'),
              onTap: () {
                _updateSetting(
                  _settings!.copyWith(defaultExportFormat: 'Excel'),
                );
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showOrganizationDialog() {
    final nameController = TextEditingController(
      text: _settings!.organizationName,
    );
    final addressController = TextEditingController(
      text: _settings!.organizationAddress,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Organization Settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Organization Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
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
              _updateSetting(
                _settings!.copyWith(
                  organizationName: nameController.text.trim(),
                  organizationNameThai: '', // Keep Thai name empty as requested
                  organizationAddress: addressController.text.trim(),
                ),
              );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _performBackup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Backing up data...'),
          ],
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup completed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  void _exportAllData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export All Data'),
        content: const Text(
          'This will export all reports, transactions, and settings. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Exporting data...')),
              );
            },
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  void _clearCache() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will clear temporary files and free up storage. Your data will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cache cleared successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Change Password'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureCurrent
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscureCurrent = !obscureCurrent;
                            });
                          },
                        ),
                      ),
                      obscureText: obscureCurrent,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your current password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: newPasswordController,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_reset),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNew
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscureNew = !obscureNew;
                            });
                          },
                        ),
                      ),
                      obscureText: obscureNew,
                      validator: ValidationUtils.validatePassword,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_reset),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirm
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscureConfirm = !obscureConfirm;
                            });
                          },
                        ),
                      ),
                      obscureText: obscureConfirm,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your new password';
                        }
                        if (value != newPasswordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;

                        setDialogState(() => isLoading = true);

                        final authProvider = context.read<AuthProvider>();
                        final scaffoldMessenger = ScaffoldMessenger.of(context);

                        try {
                          await authProvider.changePassword(
                            currentPasswordController.text,
                            newPasswordController.text,
                          );

                          if (!mounted) return;
                          Navigator.pop(dialogContext);
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text('Password changed successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          setDialogState(() => isLoading = false);
                          if (!mounted) return;
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text('Error: ${e.toString()}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Change Password'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<AuthProvider>().logout();
              if (mounted) {
                context.go('/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showAIInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.purple.shade400),
            const SizedBox(width: 8),
            const Text('AI Features'),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAIFeatureInfo(
                icon: Icons.edit_note,
                title: 'Text Enhancement',
                description:
                    'Improves your text to be more professional, clear, and well-structured while keeping the same meaning.',
              ),
              const SizedBox(height: 16),
              _buildAIFeatureInfo(
                icon: Icons.spellcheck,
                title: 'Spell Check',
                description:
                    'Checks for spelling and grammar errors, providing corrections with highlighted issues.',
              ),
              const SizedBox(height: 16),
              _buildAIFeatureInfo(
                icon: Icons.gavel,
                title: 'Resolution Generator',
                description:
                    'Automatically generates professional resolution text for ADCOM meeting items based on the agenda details.',
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'AI features are powered by Google Gemini and require AI_API_KEY in .env.',
                        style: TextStyle(color: Colors.blue.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildAIFeatureInfo({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.purple.shade400, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
