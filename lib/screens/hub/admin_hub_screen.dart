import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../utils/responsive_helper.dart';

class AdminHubScreen extends StatefulWidget {
  const AdminHubScreen({super.key});

  @override
  State<AdminHubScreen> createState() => _AdminHubScreenState();
}

class _AdminHubScreenState extends State<AdminHubScreen> {
  // Counts for badges
  int _pendingApprovals = 0;
  int _pendingStudentReports = 0;
  int _equipmentCheckedOut = 0;
  int _pendingActionItems = 0;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    try {
      // Load pending approvals count
      final reportsQuery = await FirebaseFirestore.instance
          .collection('reports')
          .where('status', isEqualTo: 'submitted')
          .get();

      final transactionsQuery = await FirebaseFirestore.instance
          .collection('transactions')
          .where('status', isEqualTo: 'submitted')
          .get();

      // Load pending student reports
      final studentReportsQuery = await FirebaseFirestore.instance
          .collection('student_monthly_reports')
          .where('status', isEqualTo: 'submitted')
          .get();

      // Load checked out equipment count
      final equipmentQuery = await FirebaseFirestore.instance
          .collection('equipment')
          .where('status', isEqualTo: 'checkedOut')
          .get();

      // Load pending meeting action items
      final actionItemsQuery = await FirebaseFirestore.instance
          .collection('meeting_action_items')
          .where('status', whereIn: ['pending', 'inProgress'])
          .get();

      if (mounted) {
        setState(() {
          _pendingApprovals =
              reportsQuery.docs.length + transactionsQuery.docs.length;
          _pendingStudentReports = studentReportsQuery.docs.length;
          _equipmentCheckedOut = equipmentQuery.docs.length;
          _pendingActionItems = actionItemsQuery.docs.length;
        });
      }
    } catch (e) {
      // Silently handle errors - badges will show 0
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final isAdmin = user?.role == 'admin';
    final canApprove = authProvider.canApprove();
    final hubTitle = isAdmin ? 'Admin Hub' : 'Staff Hub';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadCounts,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ResponsiveContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  // Welcome Header
                  _buildWelcomeHeader(user?.name ?? 'Admin', authProvider),
                  const SizedBox(height: 24),

                  // Main Section Cards
                  _buildSectionGrid(context, isAdmin, canApprove),

                  const SizedBox(height: 24),

                  // Quick Actions
                  _buildQuickActionsSection(context),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader(String userName, AuthProvider authProvider) {
    final hour = DateTime.now().hour;
    String greeting;
    IconData greetingIcon;
    final isAdmin = authProvider.currentUser?.role == 'admin';
    final hubTitle = isAdmin ? 'Admin Hub' : 'Staff Hub';

    if (hour < 12) {
      greeting = 'Good Morning';
      greetingIcon = Icons.wb_sunny;
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
      greetingIcon = Icons.wb_cloudy;
    } else {
      greeting = 'Good Evening';
      greetingIcon = Icons.nightlight_round;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.orange.shade400, Colors.orange.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.shade200,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top action bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                hubTitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: [
                  _buildHeaderActionButton(
                    icon: Icons.refresh,
                    tooltip: 'Refresh',
                    onPressed: _loadCounts,
                  ),
                  const SizedBox(width: 8),
                  _buildHeaderActionButton(
                    icon: Icons.settings,
                    tooltip: 'Settings',
                    onPressed: () => context.push('/settings'),
                  ),
                  const SizedBox(width: 8),
                  _buildHeaderActionButton(
                    icon: Icons.logout,
                    tooltip: 'Logout',
                    onPressed: () async {
                      await authProvider.logout();
                      if (context.mounted) {
                        context.go('/');
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Content row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(greetingIcon, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Welcome to HCSEA Data and Financial Management System',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
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

  Widget _buildSectionGrid(
    BuildContext context,
    bool isAdmin,
    bool canApprove,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 900 ? 4 : (screenWidth > 600 ? 2 : 2);

    final sections = <_SectionCard>[
      _SectionCard(
        title: 'Finance',
        subtitle: 'Reports, Transactions & Vouchers',
        icon: Icons.account_balance_wallet,
        color: Colors.blue,
        route: '/finance-dashboard',
        badge: _pendingApprovals > 0 ? _pendingApprovals : null,
        badgeColor: Colors.red,
      ),
      _SectionCard(
        title: 'Student Labor',
        subtitle: 'Timesheets, Reports & Rates',
        icon: Icons.school,
        color: Colors.orange,
        route: '/student-labor-dashboard',
        badge: _pendingStudentReports > 0 ? _pendingStudentReports : null,
        badgeColor: Colors.orange,
        visible: isAdmin,
      ),
      _SectionCard(
        title: 'HR Management',
        subtitle: 'Staff, Salary & Benefits',
        icon: Icons.people,
        color: Colors.green,
        route: '/hr-dashboard',
        visible: isAdmin,
      ),
      _SectionCard(
        title: 'My HR Data',
        subtitle: 'View and update your profile',
        icon: Icons.badge,
        color: Colors.teal,
        route: '/hr/my-data',
        visible: !isAdmin,
      ),
      _SectionCard(
        title: 'Annual Leave',
        subtitle: 'Request your leave',
        icon: Icons.event_available,
        color: Colors.teal,
        route: '/hr/leave-request',
        visible: !isAdmin,
      ),
      _SectionCard(
        title: 'Inventory',
        subtitle: 'Equipment & Assets',
        icon: Icons.inventory_2,
        color: Colors.purple,
        route: '/inventory-dashboard',
        badge: _equipmentCheckedOut > 0 ? _equipmentCheckedOut : null,
        badgeColor: Colors.purple,
        badgeLabel: 'Out',
      ),
      _SectionCard(
        title: 'Meetings',
        subtitle: 'Meetings, Agendas & Minutes',
        icon: Icons.groups,
        color: Colors.indigo,
        route: '/meetings-dashboard',
        badge: _pendingActionItems > 0 ? _pendingActionItems : null,
        badgeColor: Colors.indigo,
        badgeLabel: 'Actions',
        visible: isAdmin,
      ),
    ];

    final visibleSections = sections.where((s) => s.visible).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: visibleSections.length,
      itemBuilder: (context, index) {
        final section = visibleSections[index];
        return _buildSectionCard(context, section);
      },
    );
  }

  Widget _buildSectionCard(BuildContext context, _SectionCard section) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(section.route),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: section.color.withValues(alpha: 0.1),
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
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: section.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(section.icon, color: section.color, size: 28),
                  ),
                  if (section.badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: section.badgeColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${section.badge}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          if (section.badgeLabel != null) ...[
                            const SizedBox(width: 4),
                            Text(
                              section.badgeLabel!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                section.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                section.subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Open',
                    style: TextStyle(
                      color: section.color,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward, color: section.color, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildQuickActionChip(
                context,
                icon: Icons.add_chart,
                label: 'New Report',
                route: '/reports/new',
                color: Colors.blue,
              ),
              _buildQuickActionChip(
                context,
                icon: Icons.receipt_long,
                label: 'New Transaction',
                route: '/transactions',
                color: Colors.green,
              ),
              _buildQuickActionChip(
                context,
                icon: Icons.approval,
                label: 'Approvals',
                route: '/approvals',
                color: Colors.orange,
              ),
              _buildQuickActionChip(
                context,
                icon: Icons.person_add,
                label: 'Add Staff',
                route: '/admin/staff/add',
                color: Colors.purple,
              ),
              _buildQuickActionChip(
                context,
                icon: Icons.inventory,
                label: 'Equipment',
                route: '/inventory',
                color: Colors.teal,
              ),
              _buildQuickActionChip(
                context,
                icon: Icons.flight_takeoff,
                label: 'Travel Report',
                route: '/traveling/new',
                color: Colors.indigo,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
    required Color color,
  }) {
    return ActionChip(
      avatar: Icon(icon, color: color, size: 18),
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.1),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w500),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      onPressed: () => context.push(route),
    );
  }
}

class _SectionCard {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;
  final int? badge;
  final Color badgeColor;
  final String? badgeLabel;
  final bool visible;

  _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
    this.badge,
    this.badgeColor = Colors.red,
    this.badgeLabel,
    this.visible = true,
  });
}
