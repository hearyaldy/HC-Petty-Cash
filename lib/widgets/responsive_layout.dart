import 'package:flutter/material.dart';
import '../utils/responsive_helper.dart';

/// Main layout wrapper that provides responsive navigation structure
class ResponsiveLayout extends StatelessWidget {
  final Widget child;
  final String currentRoute;
  final String? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool showNavigation;

  const ResponsiveLayout({
    super.key,
    required this.child,
    required this.currentRoute,
    this.title,
    this.actions,
    this.floatingActionButton,
    this.showNavigation = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!showNavigation) {
      return _buildStandaloneLayout(context);
    }

    if (ResponsiveHelper.isDesktop(context)) {
      return _buildDesktopLayout(context);
    } else {
      return _buildMobileTabletLayout(context);
    }
  }

  Widget _buildStandaloneLayout(BuildContext context) {
    return Scaffold(
      appBar: title != null
          ? AppBar(title: Text(title!), actions: actions)
          : null,
      body: child,
      floatingActionButton: floatingActionButton,
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Desktop sidebar navigation
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
            child: _buildNavigationDrawer(context, isDesktop: true),
          ),
          // Main content area
          Expanded(
            child: Column(
              children: [
                if (title != null || actions != null)
                  _buildDesktopAppBar(context),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }

  Widget _buildMobileTabletLayout(BuildContext context) {
    return Scaffold(
      appBar: title != null
          ? AppBar(
              title: Text(
                title!,
                style: ResponsiveHelper.getResponsiveTextTheme(
                  context,
                ).titleLarge,
              ),
              actions: actions,
              elevation: ResponsiveHelper.isTablet(context) ? 1 : 0,
            )
          : null,
      drawer: _buildNavigationDrawer(context),
      body: child,
      bottomNavigationBar: _buildBottomNavigation(context),
      floatingActionButton: floatingActionButton,
    );
  }

  Widget _buildDesktopAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: ResponsiveHelper.getResponsiveTextTheme(
                context,
              ).titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
          ],
          if (actions != null) ...actions!,
        ],
      ),
    );
  }

  Widget _buildNavigationDrawer(
    BuildContext context, {
    bool isDesktop = false,
  }) {
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
        // Header
        Container(
          padding: EdgeInsets.all(isDesktop ? 24 : 16),
          width: double.infinity,
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
                child: Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: isDesktop ? 24 : 32,
                ),
              ),
              SizedBox(height: isDesktop ? 12 : 16),
              Text(
                'Petty Cash Manager',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isDesktop ? 18 : 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Financial Management',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: isDesktop ? 14 : 16,
                ),
              ),
            ],
          ),
        ),

        // Navigation items
        Expanded(
          child: ListView(
            padding: EdgeInsets.symmetric(
              vertical: 8,
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
          // Add navigation logic here
        },
      ),
    );
  }

  Widget? _buildBottomNavigation(BuildContext context) {
    if (ResponsiveHelper.isDesktop(context)) {
      return null;
    }

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
            _showMoreOptions(context);
          } else {
            // Add navigation logic here
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
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Approvals'),
              onTap: () {
                Navigator.pop(context);
                // Add navigation logic here
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('Admin'),
              onTap: () {
                Navigator.pop(context);
                // Add navigation logic here
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                // Add navigation logic here
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
