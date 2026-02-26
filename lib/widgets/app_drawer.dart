import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/enums.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final isAdmin = authProvider.canManageUsers();
    final canApprove = authProvider.canApprove();
    final isStudentWorker = user?.roleEnum == UserRole.studentWorker;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(context, user),

          // MAIN NAVIGATION
          _buildSectionHeader('Main'),
          _buildDrawerItem(
            context,
            icon: Icons.dashboard,
            title: 'Admin Hub',
            route: '/admin-hub',
            iconColor: Colors.blue,
          ),

          if (!isStudentWorker) ...[
            // FINANCIAL REPORTS
            _buildSectionHeader('Financial Reports'),
            _buildDrawerItem(
              context,
              icon: Icons.receipt_long,
              title: 'Petty Cash Reports',
              route: '/reports',
              iconColor: Colors.green,
            ),
            _buildDrawerItem(
              context,
              icon: Icons.flight_takeoff,
              title: 'Traveling Reports',
              route: '/traveling-reports',
              iconColor: Colors.orange,
            ),
            _buildDrawerItem(
              context,
              icon: Icons.account_balance_wallet,
              title: 'Income Reports',
              route: '/income',
              iconColor: Colors.teal,
            ),
            _buildDrawerItem(
              context,
              icon: Icons.shopping_cart,
              title: 'Purchase Requisitions',
              route: '/purchase-requisitions',
              iconColor: Colors.purple,
            ),
            _buildDrawerItem(
              context,
              icon: Icons.request_quote,
              title: 'Cash Advances',
              route: '/cash-advances',
              iconColor: Colors.indigo,
            ),

            // INVENTORY MANAGEMENT
            _buildSectionHeader('Studio'),
            _buildDrawerItem(
              context,
              icon: Icons.inventory_2,
              title: 'Equipment Inventory',
              route: '/inventory',
              iconColor: Colors.blueGrey,
            ),

            // MEDIA PRODUCTION
            _buildSectionHeader('Media Production'),
            _buildDrawerItem(
              context,
              icon: Icons.video_library,
              title: 'Media Dashboard',
              route: '/media-dashboard',
              iconColor: Colors.pink,
            ),
            _buildDrawerItem(
              context,
              icon: Icons.movie_creation,
              title: 'Productions',
              route: '/media/productions',
              iconColor: Colors.deepPurple,
            ),
            _buildDrawerItem(
              context,
              icon: Icons.analytics,
              title: 'Engagement Data',
              route: '/media/engagement',
              iconColor: Colors.blue,
            ),
            _buildDrawerItem(
              context,
              icon: Icons.assessment,
              title: 'Annual Report',
              route: '/media/reports/annual',
              iconColor: Colors.orange,
            ),

            // TRANSACTIONS & APPROVALS
            if (canApprove) ...[
              _buildSectionHeader('Management'),
              _buildDrawerItem(
                context,
                icon: Icons.pending_actions,
                title: 'Pending Approvals',
                route: '/approvals',
                iconColor: Colors.amber,
                badge: true,
              ),
              _buildDrawerItem(
                context,
                icon: Icons.list_alt,
                title: 'All Transactions',
                route: '/transactions',
                iconColor: Colors.indigo,
              ),
            ],
          ],

          // STUDENT WORKER SECTION
          if (isStudentWorker) ...[
            _buildSectionHeader('Student'),
            _buildDrawerItem(
              context,
              icon: Icons.dashboard,
              title: 'Student Dashboard',
              route: '/student-dashboard',
              iconColor: Colors.cyan,
            ),
            _buildDrawerItem(
              context,
              icon: Icons.schedule,
              title: 'My Timesheets',
              route: '/student-report',
              iconColor: Colors.lightBlue,
            ),
            _buildDrawerItem(
              context,
              icon: Icons.person,
              title: 'My Profile',
              route: '/student-profile',
              iconColor: Colors.blueGrey,
            ),
          ] else ...[
            // REGULAR USER SECTION
            _buildDrawerItem(
              context,
              icon: Icons.person,
              title: 'My Profile',
              route: '/user-profile',
              iconColor: Colors.blueGrey,
            ),
            _buildDrawerItem(
              context,
              icon: Icons.badge,
              title: 'My Data',
              route: '/hr/my-data',
              iconColor: Colors.cyan,
            ),
            _buildDrawerItem(
              context,
              icon: Icons.work,
              title: 'HR Data Submission',
              route: '/hr/data-submission',
              iconColor: Colors.orange,
            ),
            _buildDrawerItem(
              context,
              icon: Icons.event_available,
              title: 'Annual Leave Request',
              route: '/hr/leave-request',
              iconColor: Colors.teal,
            ),
          ],

          // ADMIN SECTION
          if (isAdmin) ...[
            const Divider(thickness: 2),
            _buildSectionHeader('Administration'),

            // HR Management
            ExpansionTile(
              leading: Icon(Icons.people, color: Colors.deepPurple),
              title: const Text(
                'HR Management',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              children: [
                _buildSubMenuItem(
                  context,
                  icon: Icons.person_add,
                  title: 'Employee Onboarding',
                  route: '/hr/employee-onboarding',
                ),
                _buildSubMenuItem(
                  context,
                  icon: Icons.people,
                  title: 'HR Dashboard',
                  route: '/hr',
                ),
                _buildSubMenuItem(
                  context,
                  icon: Icons.event_available,
                  title: 'Leave Requests',
                  route: '/hr/leave-requests',
                ),
                _buildSubMenuItem(
                  context,
                  icon: Icons.badge,
                  title: 'Staff Records',
                  route: '/admin/staff',
                ),
                _buildSubMenuItem(
                  context,
                  icon: Icons.monetization_on,
                  title: 'Salary & Benefits',
                  route: '/admin/salary-benefits',
                ),
                _buildSubMenuItem(
                  context,
                  icon: Icons.document_scanner,
                  title: 'Employment Letters',
                  route: '/admin/employment-letter-template',
                ),
                _buildSubMenuItem(
                  context,
                  icon: Icons.manage_accounts,
                  title: 'System Users',
                  route: '/admin/users',
                ),
              ],
            ),

            // Student Management
            ExpansionTile(
              leading: Icon(Icons.school, color: Colors.lightBlue),
              title: const Text(
                'Student Management',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              children: [
                _buildSubMenuItem(
                  context,
                  icon: Icons.assignment,
                  title: 'Student Reports',
                  route: '/admin/student-reports',
                ),
                _buildSubMenuItem(
                  context,
                  icon: Icons.attach_money,
                  title: 'Payment Rates',
                  route: '/admin/payment-rates',
                ),
              ],
            ),

            // Financial Management
            ExpansionTile(
              leading: Icon(Icons.account_balance, color: Colors.green),
              title: const Text(
                'Financial Management',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              children: [
                _buildSubMenuItem(
                  context,
                  icon: Icons.trending_up,
                  title: 'Income Reports',
                  route: '/admin/income',
                ),
                _buildSubMenuItem(
                  context,
                  icon: Icons.flight,
                  title: 'Traveling Reports',
                  route: '/admin/traveling-reports',
                ),
              ],
            ),
          ],

          // SETTINGS & PROFILE
          const Divider(),
          _buildSectionHeader('Account'),
          _buildDrawerItem(
            context,
            icon: Icons.settings,
            title: 'Settings',
            route: '/settings',
            iconColor: Colors.grey,
          ),

          // LOGOUT
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              leading: Icon(Icons.logout, color: Colors.red[700]),
              title: Text(
                'Logout',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.red[700],
                ),
              ),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
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
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true && context.mounted) {
                  await context.read<AuthProvider>().logout();
                  if (context.mounted) {
                    context.go('/');
                  }
                }
              },
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context, dynamic user) {
    return UserAccountsDrawerHeader(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      currentAccountPicture: CircleAvatar(
        backgroundColor: Colors.white,
        child: Text(
          user?.name != null && user.name.isNotEmpty
              ? user.name[0].toUpperCase()
              : '?',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
      ),
      accountName: Text(
        user?.name ?? 'User',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      accountEmail: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(user?.email ?? ''),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              user?.role?.toUpperCase() ?? 'GUEST',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
    required Color iconColor,
    bool badge = false,
  }) {
    final currentRoute = GoRouterState.of(context).uri.path;
    final isSelected = currentRoute == route;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        selected: isSelected,
        selectedTileColor: iconColor.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: Stack(
          children: [
            Icon(icon, color: isSelected ? iconColor : Colors.grey[700]),
            if (badge)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                ),
              ),
          ],
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? iconColor : null,
          ),
        ),
        onTap: () {
          Navigator.pop(context);
          context.push(route);
        },
      ),
    );
  }

  Widget _buildSubMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
  }) {
    final currentRoute = GoRouterState.of(context).uri.path;
    final isSelected = currentRoute == route;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 72, right: 16),
      leading: Icon(icon, size: 20, color: Colors.grey[600]),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? Theme.of(context).primaryColor : null,
        ),
      ),
      selected: isSelected,
      selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.05),
      onTap: () {
        Navigator.pop(context);
        context.push(route);
      },
    );
  }
}
