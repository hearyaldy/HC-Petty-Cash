import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../utils/responsive_helper.dart';

class HrManagementScreen extends StatefulWidget {
  const HrManagementScreen({super.key});

  @override
  State<HrManagementScreen> createState() => _HrManagementScreenState();
}

class _HrManagementScreenState extends State<HrManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          // Modern SliverAppBar with gradient
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.purple.shade600,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.purple.shade700,
                      Colors.purple.shade500,
                      Colors.pink.shade400,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.people_alt,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'HR Management',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Manage employee onboarding, profiles, and HR processes',
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
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.home_outlined),
                onPressed: () => context.go('/dashboard'),
                tooltip: 'Home',
              ),
            ],
          ),
          // Content
          SliverToBoxAdapter(
            child: ResponsiveContainer(
              child: Padding(
                padding: ResponsiveHelper.getScreenPadding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildHrCards(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHrCards() {
    final hrOptions = [
      {
        'title': 'Employee Onboarding',
        'subtitle': 'Add new employees to the system',
        'icon': Icons.person_add,
        'gradient': [Colors.blue.shade400, Colors.blue.shade600],
        'route': '/hr/employee-onboarding',
      },
      {
        'title': 'HR Data Submissions',
        'subtitle': 'Review submitted HR data',
        'icon': Icons.assignment,
        'gradient': [Colors.indigo.shade400, Colors.indigo.shade600],
        'route': '/hr/data-submissions',
      },
      {
        'title': 'Staff Management',
        'subtitle': 'View and manage all staff members',
        'icon': Icons.people,
        'gradient': [Colors.green.shade400, Colors.green.shade600],
        'route': '/admin/staff',
      },
      {
        'title': 'Salary & Benefits',
        'subtitle': 'Manage compensation packages',
        'icon': Icons.monetization_on,
        'gradient': [Colors.teal.shade400, Colors.teal.shade600],
        'route': '/admin/salary-benefits',
      },
      {
        'title': 'HR Documents',
        'subtitle': 'Manage employee documents',
        'icon': Icons.file_copy,
        'gradient': [Colors.orange.shade400, Colors.orange.shade600],
        'route': '/admin/staff',
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: ResponsiveHelper.isDesktop(context) ? 3 : 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: ResponsiveHelper.isDesktop(context) ? 1.3 : 1.2,
      ),
      itemCount: hrOptions.length,
      itemBuilder: (context, index) {
        final option = hrOptions[index];
        return _buildHrCard(
          title: option['title'] as String,
          subtitle: option['subtitle'] as String,
          icon: option['icon'] as IconData,
          gradient: option['gradient'] as List<Color>,
          route: option['route'] as String,
        );
      },
    );
  }

  Widget _buildHrCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required String route,
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push(route),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: gradient[0].withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: gradient[0].withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.arrow_forward,
                        color: gradient[0],
                        size: 16,
                      ),
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
