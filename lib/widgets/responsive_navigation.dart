import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/responsive_helper.dart';

/// Responsive navigation widget that adapts to different screen sizes
class ResponsiveNavigation extends StatelessWidget {
  final Widget child;
  final String currentRoute;

  const ResponsiveNavigation({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    if (ResponsiveHelper.isDesktop(context)) {
      return _buildDesktopLayout(context);
    } else if (ResponsiveHelper.isTablet(context)) {
      return _buildTabletLayout(context);
    } else {
      return _buildMobileLayout(context);
    }
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Permanent navigation drawer for desktop
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: _buildNavigationItems(context, isDesktop: true),
          ),
          // Main content
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return Scaffold(
      drawer: Drawer(width: 280, child: _buildNavigationItems(context)),
      body: child,
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      drawer: Drawer(child: _buildNavigationItems(context)),
      body: child,
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  Widget _buildNavigationItems(BuildContext context, {bool isDesktop = false}) {
    final navigationItems = [
      _NavigationItem(
        icon: Icons.dashboard,
        label: 'Dashboard',
        route: '/dashboard',
      ),
      _NavigationItem(
        icon: Icons.description,
        label: 'Reports',
        route: '/reports',
      ),
      _NavigationItem(
        icon: Icons.receipt_long,
        label: 'Transactions',
        route: '/transactions',
      ),
      _NavigationItem(
        icon: Icons.check_circle_outline,
        label: 'Approvals',
        route: '/approvals',
      ),
      _NavigationItem(
        icon: Icons.people_outline,
        label: 'Admin',
        route: '/admin',
      ),
      _NavigationItem(
        icon: Icons.settings,
        label: 'Settings',
        route: '/settings',
      ),
    ];

    return Column(
      children: [
        if (isDesktop) ...[
          // Desktop header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.blue.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Petty Cash',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Manager',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          // Mobile/Tablet header
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.blue.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Petty Cash Manager',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Financial Management',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
        // Navigation items
        Expanded(
          child: ListView(
            padding: EdgeInsets.symmetric(
              vertical: isDesktop ? 8 : 0,
              horizontal: isDesktop ? 12 : 0,
            ),
            children: navigationItems
                .map(
                  (item) =>
                      _buildNavigationTile(context, item, isDesktop: isDesktop),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationTile(
    BuildContext context,
    _NavigationItem item, {
    bool isDesktop = false,
  }) {
    final isSelected = currentRoute.startsWith(item.route);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isDesktop ? 8 : 0, vertical: 2),
      child: ListTile(
        leading: Icon(
          item.icon,
          color: isSelected ? Colors.blue.shade600 : Colors.grey.shade600,
        ),
        title: Text(
          item.label,
          style: TextStyle(
            color: isSelected ? Colors.blue.shade600 : Colors.grey.shade800,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        selectedTileColor: Colors.blue.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isDesktop ? 8 : 0),
        ),
        onTap: () {
          if (!isDesktop) {
            Navigator.of(context).pop();
          }
          context.go(item.route);
        },
      ),
    );
  }

  Widget? _buildBottomNavigationBar(BuildContext context) {
    final items = [
      _BottomNavItem(
        icon: Icons.dashboard,
        label: 'Dashboard',
        route: '/dashboard',
      ),
      _BottomNavItem(
        icon: Icons.description,
        label: 'Reports',
        route: '/reports',
      ),
      _BottomNavItem(
        icon: Icons.receipt_long,
        label: 'Transactions',
        route: '/transactions',
      ),
      _BottomNavItem(
        icon: Icons.check_circle_outline,
        label: 'Approvals',
        route: '/approvals',
      ),
      _BottomNavItem(icon: Icons.more_horiz, label: 'More', route: '/more'),
    ];

    int selectedIndex = 0;
    for (int i = 0; i < items.length; i++) {
      if (currentRoute.startsWith(items[i].route)) {
        selectedIndex = i;
        break;
      }
    }

    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: selectedIndex.clamp(0, items.length - 1),
      selectedItemColor: Colors.blue.shade600,
      unselectedItemColor: Colors.grey.shade600,
      selectedFontSize: 12,
      unselectedFontSize: 12,
      items: items
          .map(
            (item) => BottomNavigationBarItem(
              icon: Icon(item.icon),
              label: item.label,
            ),
          )
          .toList(),
      onTap: (index) {
        if (index < items.length) {
          if (items[index].route == '/more') {
            // Show more options
            _showMoreOptions(context);
          } else {
            context.go(items[index].route);
          }
        }
      },
    );
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('Admin'),
              onTap: () {
                Navigator.pop(context);
                context.go('/admin');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                context.go('/settings');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationItem {
  final IconData icon;
  final String label;
  final String route;

  _NavigationItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}

class _BottomNavItem {
  final IconData icon;
  final String label;
  final String route;

  _BottomNavItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}
