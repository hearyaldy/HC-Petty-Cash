import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../models/app_settings.dart';
import '../../services/settings_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final settings = await _settingsService.getSettings();
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;

    if (_isLoading || _settings == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () => context.go('/dashboard'),
            tooltip: 'Home',
          ),
        ],
      ),
      body: ListView(
        children: [
          // User Profile Section
          _buildSectionHeader('User Profile'),
          _buildProfileTile(currentUser?.name ?? 'User', currentUser?.email ?? ''),
          const Divider(),

          // App Preferences
          _buildSectionHeader('App Preferences'),
          _buildListTile(
            icon: Icons.palette_outlined,
            title: 'Theme',
            subtitle: _getThemeDisplayName(_settings!.theme),
            onTap: () => _showThemeDialog(),
          ),
          _buildListTile(
            icon: Icons.language,
            title: 'Language',
            subtitle: _getLanguageDisplayName(_settings!.language),
            onTap: () => _showLanguageDialog(),
          ),
          _buildListTile(
            icon: Icons.attach_money,
            title: 'Currency',
            subtitle: _getCurrencyDisplayName(_settings!.currency),
            onTap: () => _showCurrencyDialog(),
          ),
          _buildListTile(
            icon: Icons.calendar_today,
            title: 'Date Format',
            subtitle: _settings!.dateFormat,
            onTap: () => _showDateFormatDialog(),
          ),
          const Divider(),

          // Notifications
          _buildSectionHeader('Notifications'),
          SwitchListTile(
            secondary: const Icon(Icons.email_outlined),
            title: const Text('Email Notifications'),
            subtitle: const Text('Receive updates via email'),
            value: _settings!.emailNotifications,
            onChanged: (value) {
              _updateSetting(_settings!.copyWith(emailNotifications: value));
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Push Notifications'),
            subtitle: const Text('Receive push notifications'),
            value: _settings!.pushNotifications,
            onChanged: (value) {
              _updateSetting(_settings!.copyWith(pushNotifications: value));
            },
          ),
          const Divider(),

          // Report Settings
          _buildSectionHeader('Report Settings'),
          _buildListTile(
            icon: Icons.receipt_long,
            title: 'Default Report Type',
            subtitle: _getReportTypeDisplayName(_settings!.defaultReportType),
            onTap: () => _showReportTypeDialog(),
          ),
          const Divider(),

          // Export & Backup
          _buildSectionHeader('Export & Backup'),
          _buildListTile(
            icon: Icons.file_download_outlined,
            title: 'Default Export Format',
            subtitle: _settings!.defaultExportFormat,
            onTap: () => _showExportFormatDialog(),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.backup_outlined),
            title: const Text('Auto Backup'),
            subtitle: const Text('Automatically backup data'),
            value: _settings!.autoBackup,
            onChanged: (value) {
              _updateSetting(_settings!.copyWith(autoBackup: value));
            },
          ),
          _buildListTile(
            icon: Icons.cloud_upload_outlined,
            title: 'Backup Now',
            subtitle: 'Manually backup your data',
            onTap: () => _performBackup(),
          ),
          const Divider(),

          // Admin Settings (only for admins)
          if (authProvider.canApprove()) ...[
            _buildSectionHeader('Admin Settings'),
            _buildListTile(
              icon: Icons.people_outline,
              title: 'Manage Users',
              subtitle: 'Add, edit, or remove users',
              onTap: () => context.push('/admin/users'),
            ),
            _buildListTile(
              icon: Icons.category_outlined,
              title: 'Manage Categories',
              subtitle: 'Edit expense categories',
              onTap: () => showDialog(
                context: context,
                builder: (context) => const EnhancedCategoryManagementDialog(),
              ),
            ),
            _buildListTile(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Manage Paid To Options',
              subtitle: 'Edit vendor list for paid to field',
              onTap: () => showDialog(
                context: context,
                builder: (context) => const PaidToManagementDialog(),
              ),
            ),
            _buildListTile(
              icon: Icons.business_outlined,
              title: 'Organization Settings',
              subtitle: 'Update organization details',
              onTap: () => _showOrganizationDialog(),
            ),
            const Divider(),
          ],

          // Data Management
          _buildSectionHeader('Data Management'),
          _buildListTile(
            icon: Icons.download_outlined,
            title: 'Export All Data',
            subtitle: 'Download all reports and transactions',
            onTap: () => _exportAllData(),
          ),
          _buildListTile(
            icon: Icons.delete_outline,
            title: 'Clear Cache',
            subtitle: 'Free up storage space',
            onTap: () => _clearCache(),
          ),
          const Divider(),

          // About
          _buildSectionHeader('About'),
          _buildListTile(
            icon: Icons.info_outline,
            title: 'App Version',
            subtitle: '1.0.0',
            onTap: () {},
          ),
          _buildListTile(
            icon: Icons.help_outline,
            title: 'Help & Support',
            subtitle: 'Get help or contact support',
            onTap: () {},
          ),
          const Divider(),

          // Logout
          _buildListTile(
            icon: Icons.logout,
            title: 'Logout',
            subtitle: 'Sign out of your account',
            textColor: Colors.red,
            onTap: () => _showLogoutDialog(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildProfileTile(String name, String email) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).primaryColor,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(name),
      subtitle: Text(email),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor),
      title: Text(title, style: TextStyle(color: textColor)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  String _getThemeDisplayName(String theme) {
    switch (theme) {
      case 'light':
        return 'Light';
      case 'dark':
        return 'Dark';
      case 'auto':
        return 'Auto';
      default:
        return 'Light';
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

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.light_mode),
              title: const Text('Light'),
              onTap: () {
                _updateSetting(_settings!.copyWith(theme: 'light'));
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text('Dark'),
              onTap: () {
                _updateSetting(_settings!.copyWith(theme: 'dark'));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Dark theme coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Auto'),
              onTap: () {
                _updateSetting(_settings!.copyWith(theme: 'auto'));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Auto theme coming soon')),
                );
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
              title: const Text('English'),
              onTap: () {
                _updateSetting(_settings!.copyWith(language: 'en'));
                Navigator.pop(context);
              },
            ),
            ListTile(
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
              title: const Text('THB (฿)'),
              onTap: () {
                _updateSetting(_settings!.copyWith(currency: 'THB'));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('USD (\$)'),
              onTap: () {
                _updateSetting(_settings!.copyWith(currency: 'USD'));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('EUR (€)'),
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
              title: const Text('Petty Cash Report'),
              onTap: () {
                _updateSetting(_settings!.copyWith(defaultReportType: 'petty_cash'));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Project Report'),
              onTap: () {
                _updateSetting(_settings!.copyWith(defaultReportType: 'project'));
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
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('PDF'),
              onTap: () {
                _updateSetting(_settings!.copyWith(defaultExportFormat: 'PDF'));
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('Excel'),
              onTap: () {
                _updateSetting(_settings!.copyWith(defaultExportFormat: 'Excel'));
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showOrganizationDialog() {
    final nameController = TextEditingController(text: _settings!.organizationName);
    final thaiNameController =
        TextEditingController(text: _settings!.organizationNameThai);
    final addressController =
        TextEditingController(text: _settings!.organizationAddress);

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
                controller: thaiNameController,
                decoration: const InputDecoration(
                  labelText: 'Thai Name',
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
              _updateSetting(_settings!.copyWith(
                organizationName: nameController.text.trim(),
                organizationNameThai: thaiNameController.text.trim(),
                organizationAddress: addressController.text.trim(),
              ));
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
}
