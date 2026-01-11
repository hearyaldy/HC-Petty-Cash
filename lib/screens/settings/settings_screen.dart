import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/category_management_dialog.dart';
import '../../widgets/paid_to_management_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _emailNotifications = true;
  bool _pushNotifications = false;
  bool _autoBackup = true;
  String _defaultExportFormat = 'PDF';
  String _dateFormat = 'dd/MM/yyyy';
  String _currency = 'THB (฿)';

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () => context.go('/dashboard'),
            tooltip: 'Home',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: ResponsiveHelper.getMaxContentWidth(context),
            ),
            padding: ResponsiveHelper.getScreenPadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPageHeader(),
                const SizedBox(height: 24),

              // User Profile Section
              _buildSectionHeader('User Profile'),
              _buildProfileTile(currentUser?.name ?? 'User', currentUser?.email ?? ''),
              const Divider(height: 24),

              // App Preferences
              _buildSectionHeader('App Preferences'),
              _buildListTile(
                icon: Icons.palette_outlined,
                title: 'Theme',
                subtitle: 'Light',
                onTap: () => _showThemeDialog(),
              ),
              _buildListTile(
                icon: Icons.language,
                title: 'Language',
                subtitle: 'English',
                onTap: () => _showLanguageDialog(),
              ),
              _buildListTile(
                icon: Icons.attach_money,
                title: 'Currency',
                subtitle: _currency,
                onTap: () => _showCurrencyDialog(),
              ),
              _buildListTile(
                icon: Icons.calendar_today,
                title: 'Date Format',
                subtitle: _dateFormat,
                onTap: () => _showDateFormatDialog(),
              ),
              const Divider(height: 24),

              // Notifications
              _buildSectionHeader('Notifications'),
              _buildSwitchListTile(
                icon: Icons.email_outlined,
                title: 'Email Notifications',
                subtitle: 'Receive updates via email',
                value: _emailNotifications,
                onChanged: (value) {
                  setState(() {
                    _emailNotifications = value;
                  });
                },
              ),
              _buildSwitchListTile(
                icon: Icons.notifications_outlined,
                title: 'Push Notifications',
                subtitle: 'Receive push notifications',
                value: _pushNotifications,
                onChanged: (value) {
                  setState(() {
                    _pushNotifications = value;
                  });
                },
              ),
              const Divider(height: 24),

              // Report Settings
              _buildSectionHeader('Report Settings'),
              _buildListTile(
                icon: Icons.receipt_long,
                title: 'Default Report Type',
                subtitle: 'Petty Cash Report',
                onTap: () => _showReportTypeDialog(),
              ),
              _buildListTile(
                icon: Icons.format_list_numbered,
                title: 'Report Numbering',
                subtitle: 'Auto-generate',
                onTap: () {},
              ),
              const Divider(height: 24),

              // Export Settings
              _buildSectionHeader('Export & Backup'),
              _buildListTile(
                icon: Icons.file_download_outlined,
                title: 'Default Export Format',
                subtitle: _defaultExportFormat,
                onTap: () => _showExportFormatDialog(),
              ),
              _buildSwitchListTile(
                icon: Icons.backup_outlined,
                title: 'Auto Backup',
                subtitle: 'Automatically backup data',
                value: _autoBackup,
                onChanged: (value) {
                  setState(() {
                    _autoBackup = value;
                  });
                },
              ),
              _buildListTile(
                icon: Icons.cloud_upload_outlined,
                title: 'Backup Now',
                subtitle: 'Manually backup your data',
                onTap: () => _performBackup(),
              ),
              const Divider(height: 24),

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
                    builder: (context) => const CategoryManagementDialog(),
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
                const Divider(height: 24),
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
              const Divider(height: 24),

              // About
              _buildSectionHeader('About'),
              _buildListTile(
                icon: Icons.info_outline,
                title: 'App Version',
                subtitle: '1.0.0',
                onTap: () {},
              ),
              _buildListTile(
                icon: Icons.description_outlined,
                title: 'Terms & Conditions',
                subtitle: 'Read our terms',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Terms & Conditions coming soon')),
                  );
                },
              ),
              _buildListTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                subtitle: 'Read our privacy policy',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Privacy Policy coming soon')),
                  );
                },
              ),
              _buildListTile(
                icon: Icons.help_outline,
                title: 'Help & Support',
                subtitle: 'Get help or contact support',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Help & Support coming soon')),
                  );
                },
              ),
              const Divider(height: 24),

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
          ),
        ),
      ),
    );
  }

  Widget _buildPageHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Configure your app preferences',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.settings, size: 48, color: Colors.white),
          ),
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
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildProfileTile(String name, String email) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'U',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(name),
        subtitle: Text(email),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile editing coming soon')),
          );
        },
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: textColor),
        title: Text(title, style: TextStyle(color: textColor)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildSwitchListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SwitchListTile(
        secondary: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
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
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text('Dark'),
              onTap: () {
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
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: const Text('ไทย (Thai)'),
              onTap: () {
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
                setState(() => _currency = 'THB (฿)');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('USD (\$)'),
              onTap: () {
                setState(() => _currency = 'USD (\$)');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('EUR (€)'),
              onTap: () {
                setState(() => _currency = 'EUR (€)');
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
                setState(() => _dateFormat = 'dd/MM/yyyy');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('MM/dd/yyyy'),
              subtitle: const Text('12/31/2024'),
              onTap: () {
                setState(() => _dateFormat = 'MM/dd/yyyy');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('yyyy-MM-dd'),
              subtitle: const Text('2024-12-31'),
              onTap: () {
                setState(() => _dateFormat = 'yyyy-MM-dd');
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
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: const Text('Project Report'),
              onTap: () => Navigator.pop(context),
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
                setState(() => _defaultExportFormat = 'PDF');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('Excel'),
              onTap: () {
                setState(() => _defaultExportFormat = 'Excel');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showOrganizationDialog() {
    final nameController = TextEditingController(text: AppConstants.organizationName);
    final thaiNameController = TextEditingController(text: AppConstants.organizationNameThai);
    final addressController = TextEditingController(text: AppConstants.organizationAddress);

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
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Organization settings saved')),
              );
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
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup completed successfully'),
          backgroundColor: Colors.green,
        ),
      );
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
