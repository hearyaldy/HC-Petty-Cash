import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
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
    final hasMeetingsAccess = isAdmin || (user?.sectionPermissions.meetingsView ?? false);

    return Drawer(
      child: Column(
        children: [
          _buildDrawerHeader(context, user),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              children: [
                // ── Dashboard ───────────────────────────────────────────
                if (!isStudentWorker)
                  _buildNavItem(
                    context,
                    icon: Icons.dashboard_rounded,
                    title: isAdmin ? 'Admin Hub' : 'Main Hub',
                    route: '/admin-hub',
                    color: const Color(0xFF2563EB),
                  ),

                if (!isStudentWorker) ...[
                  const SizedBox(height: 4),

                  // ── Finance ─────────────────────────────────────────
                  _buildSection(
                    context,
                    icon: Icons.account_balance_wallet,
                    title: 'Finance',
                    color: const Color(0xFF2563EB),
                    items: [
                      _NavItem(Icons.dashboard_outlined, 'Finance Hub', '/finance-dashboard'),
                      _NavItem(Icons.receipt_long, 'Petty Cash Reports', '/reports'),
                      _NavItem(Icons.flight_takeoff, 'Traveling Reports', '/traveling-reports'),
                      _NavItem(Icons.trending_up, 'Income Reports', '/income'),
                      _NavItem(Icons.shopping_cart_outlined, 'Purchase Requisitions', '/purchase-requisitions'),
                      _NavItem(Icons.account_balance_wallet_outlined, 'Cash Advances', '/cash-advances'),
                      _NavItem(Icons.receipt_long_outlined, 'Expense Claims', '/expense-claims'),
                      _NavItem(Icons.compare_arrows_outlined, 'Internal Debit Notes', '/internal-debit-notes'),
                      if (canApprove)
                        _NavItem(Icons.pending_actions, 'Pending Approvals', '/approvals', badge: true),
                      if (canApprove)
                        _NavItem(Icons.list_alt, 'All Transactions', '/transactions'),
                    ],
                  ),

                  // ── Meetings ────────────────────────────────────────
                  if (hasMeetingsAccess)
                    _buildSection(
                      context,
                      icon: Icons.groups,
                      title: 'Meetings',
                      color: const Color(0xFF4F46E5),
                      items: [
                        _NavItem(Icons.dashboard_outlined, 'Meetings Dashboard', '/meetings-dashboard'),
                        _NavItem(Icons.list, 'All Meetings', '/meetings'),
                        _NavItem(Icons.checklist, 'Action Items', '/meetings/action-items'),
                      ],
                    ),

                  // ── Media Production ────────────────────────────────
                  _buildSection(
                    context,
                    icon: Icons.video_library,
                    title: 'Media Production',
                    color: const Color(0xFFEC4899),
                    items: [
                      _NavItem(Icons.dashboard_outlined, 'Media Dashboard', '/media-dashboard'),
                      _NavItem(Icons.movie_creation, 'Productions', '/media/productions'),
                      _NavItem(Icons.analytics, 'Engagement Data', '/media/engagement'),
                      _NavItem(Icons.assessment, 'Annual Report', '/media/reports/annual'),
                    ],
                  ),

                  // ── Inventory ───────────────────────────────────────
                  _buildSection(
                    context,
                    icon: Icons.inventory_2,
                    title: 'Inventory',
                    color: const Color(0xFF7C3AED),
                    items: [
                      _NavItem(Icons.inventory_2_outlined, 'Equipment Inventory', '/inventory'),
                    ],
                  ),

                  // ── Admin-only sections ─────────────────────────────
                  if (isAdmin) ...[
                    // Student Labor
                    _buildSection(
                      context,
                      icon: Icons.school,
                      title: 'Student Labor',
                      color: const Color(0xFFD97706),
                      items: [
                        _NavItem(Icons.dashboard_outlined, 'Student Dashboard', '/student-labor-dashboard'),
                        _NavItem(Icons.assignment, 'Student Reports', '/admin/student-reports'),
                        _NavItem(Icons.attach_money, 'Payment Rates', '/admin/payment-rates'),
                      ],
                    ),

                    // HR Management
                    _buildSection(
                      context,
                      icon: Icons.people,
                      title: 'HR Management',
                      color: const Color(0xFF059669),
                      items: [
                        _NavItem(Icons.dashboard_outlined, 'HR Dashboard', '/hr'),
                        _NavItem(Icons.person_add, 'Employee Onboarding', '/hr/employee-onboarding'),
                        _NavItem(Icons.event_available, 'Leave Requests', '/hr/leave-requests'),
                        _NavItem(Icons.badge, 'Staff Records', '/admin/staff'),
                        _NavItem(Icons.monetization_on, 'Salary & Benefits', '/admin/salary-benefits'),
                        _NavItem(Icons.document_scanner, 'Employment Letters', '/admin/employment-letter-template'),
                        _NavItem(Icons.manage_accounts, 'System Users', '/admin/users'),
                      ],
                    ),

                    // Financial Admin
                    _buildSection(
                      context,
                      icon: Icons.account_balance,
                      title: 'Admin Finance',
                      color: const Color(0xFF0D9488),
                      items: [
                        _NavItem(Icons.trending_up, 'Income Reports', '/admin/income'),
                        _NavItem(Icons.flight, 'Traveling Reports', '/admin/traveling-reports'),
                      ],
                    ),

                    // Meetings Admin
                    _buildSection(
                      context,
                      icon: Icons.meeting_room,
                      title: 'Admin Meetings',
                      color: const Color(0xFF6366F1),
                      items: [
                        _NavItem(Icons.article, 'AdCom Agendas', '/admin/adcom-agendas'),
                      ],
                    ),

                    // MI Surveys
                    _buildSection(
                      context,
                      icon: Icons.poll_outlined,
                      title: 'MI Surveys',
                      color: const Color(0xFF0D9488),
                      items: [
                        _NavItem(Icons.poll_outlined, 'Survey Management', '/admin/surveys'),
                      ],
                    ),
                  ],

                  // ── Personal (non-admin staff) ───────────────────────
                  _buildSection(
                    context,
                    icon: Icons.badge,
                    title: 'My Data',
                    color: const Color(0xFF0D9488),
                    items: [
                      _NavItem(Icons.person, 'My Profile', '/user-profile'),
                      _NavItem(Icons.badge_outlined, 'My HR Data', '/hr/my-data'),
                      _NavItem(Icons.work_outline, 'HR Data Submission', '/hr/data-submission'),
                      _NavItem(Icons.event_available, 'Annual Leave Request', '/hr/leave-request'),
                    ],
                  ),
                ],

                // ── Student Worker ───────────────────────────────────
                if (isStudentWorker)
                  _buildSection(
                    context,
                    icon: user?.workerType == 'volunteer'
                        ? Icons.volunteer_activism
                        : Icons.school,
                    title: user?.workerType == 'volunteer'
                        ? 'Volunteer'
                        : 'Student',
                    color: const Color(0xFF0891B2),
                    items: [
                      _NavItem(Icons.dashboard_outlined, 'Student Dashboard', '/student-dashboard'),
                      _NavItem(Icons.schedule, 'My Timesheets', '/student-reports'),
                      _NavItem(Icons.person, 'My Profile', '/student-profile'),
                    ],
                  ),

                const Divider(height: 24),

                // ── Account ─────────────────────────────────────────
                _buildExternalLinkItem(
                  context,
                  icon: Icons.public,
                  title: 'View Public Site',
                  url: 'https://hopechannel.asia/',
                  color: Colors.grey,
                ),
                _buildNavItem(
                  context,
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  route: '/settings',
                  color: Colors.grey,
                ),
                _buildLogoutItem(context, authProvider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section tile (collapsible) ────────────────────────────────────────────

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required List<_NavItem> items,
  }) {
    final currentRoute = GoRouterState.of(context).uri.path;
    final isAnyChildActive = items.any((i) => currentRoute == i.route);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: isAnyChildActive,
            tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            childrenPadding: const EdgeInsets.only(bottom: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: isAnyChildActive ? color.withValues(alpha: 0.05) : null,
            collapsedBackgroundColor: Colors.transparent,
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 17, color: color),
            ),
            title: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isAnyChildActive ? FontWeight.w700 : FontWeight.w600,
                color: isAnyChildActive ? color : null,
              ),
            ),
            children: items.map((item) => _buildSubItem(context, item, color)).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildSubItem(BuildContext context, _NavItem item, Color sectionColor) {
    final currentRoute = GoRouterState.of(context).uri.path;
    final isSelected = currentRoute == item.route;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: ListTile(
        dense: true,
        selected: isSelected,
        selectedTileColor: sectionColor.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              item.icon,
              size: 18,
              color: isSelected ? sectionColor : Colors.grey[500],
            ),
            if (item.badge == true)
              Positioned(
                right: -3,
                top: -3,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
        title: Text(
          item.title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? sectionColor : null,
          ),
        ),
        onTap: () {
          Navigator.pop(context);
          context.push(item.route);
        },
      ),
    );
  }

  // ── Top-level nav item (non-collapsible) ─────────────────────────────────

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
    required Color color,
  }) {
    final currentRoute = GoRouterState.of(context).uri.path;
    final isSelected = currentRoute == route;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        selected: isSelected,
        selectedTileColor: color.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? color : null,
          ),
        ),
        onTap: () {
          Navigator.pop(context);
          context.push(route);
        },
      ),
    );
  }

  // ── External link (opens outside the app, e.g. the public landing page) ──

  Widget _buildExternalLinkItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String url,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        trailing: Icon(Icons.open_in_new, size: 15, color: Colors.grey.shade400),
        onTap: () {
          Navigator.pop(context);
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        },
      ),
    );
  }

  // ── Logout ───────────────────────────────────────────────────────────────

  Widget _buildLogoutItem(BuildContext context, AuthProvider authProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.logout, size: 17, color: Colors.red),
        ),
        title: const Text(
          'Logout',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red),
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
            await authProvider.logout();
            if (context.mounted) context.go('/');
          }
        },
      ),
    );
  }

  // ── Drawer header ─────────────────────────────────────────────────────────

  Widget _buildDrawerHeader(BuildContext context, dynamic user) {
    final cs = Theme.of(context).colorScheme;
    final initials = user?.name != null && (user.name as String).isNotEmpty
        ? (user.name as String).trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join()
        : '?';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? 'User',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  user?.email ?? '',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    user?.role?.toUpperCase() ?? 'GUEST',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final String title;
  final String route;
  final bool badge;

  const _NavItem(this.icon, this.title, this.route, {this.badge = false});
}
