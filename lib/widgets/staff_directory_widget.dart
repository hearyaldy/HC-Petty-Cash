import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/staff.dart';
import '../models/enums.dart';
import '../services/staff_service.dart';

class StaffDirectoryWidget extends StatefulWidget {
  final bool showHeader;
  final int maxItems;

  const StaffDirectoryWidget({
    super.key,
    this.showHeader = true,
    this.maxItems = 6,
  });

  @override
  State<StaffDirectoryWidget> createState() => _StaffDirectoryWidgetState();
}

class _StaffDirectoryWidgetState extends State<StaffDirectoryWidget> {
  final StaffService _staffService = StaffService();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showHeader) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.people, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 8),
                      const Text(
                        'Staff Directory',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => context.push('/admin/staff'),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('View All'),
                  ),
                ],
              ),
              const Divider(),
            ],
            StreamBuilder<List<Staff>>(
              stream: _staffService.getActiveStaff(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('Error: ${snapshot.error}'),
                    ),
                  );
                }

                final allStaff = snapshot.data ?? [];
                final staffToShow = allStaff.take(widget.maxItems).toList();

                if (staffToShow.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No active staff members',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    // Staff count summary
                    _buildStaffSummary(allStaff),
                    const SizedBox(height: 12),
                    // Staff grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _getCrossAxisCount(context),
                        childAspectRatio: 0.95,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: staffToShow.length,
                      itemBuilder: (context, index) {
                        return _buildStaffCard(staffToShow[index]);
                      },
                    ),
                    if (allStaff.length > widget.maxItems) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          '+${allStaff.length - widget.maxItems} more staff members',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffSummary(List<Staff> allStaff) {
    final roleCount = <UserRole, int>{};
    for (final staff in allStaff) {
      roleCount[staff.role] = (roleCount[staff.role] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
            'Total',
            allStaff.length.toString(),
            Icons.people,
            Colors.blue,
          ),
          _buildSummaryItem(
            'Admins',
            roleCount[UserRole.admin]?.toString() ?? '0',
            Icons.admin_panel_settings,
            Colors.purple,
          ),
          _buildSummaryItem(
            'Managers',
            roleCount[UserRole.manager]?.toString() ?? '0',
            Icons.supervisor_account,
            Colors.orange,
          ),
          _buildSummaryItem(
            'Finance',
            roleCount[UserRole.finance]?.toString() ?? '0',
            Icons.account_balance,
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String count,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              count,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildStaffCard(Staff staff) {
    return InkWell(
      onTap: () => context.push('/admin/staff/details/${staff.id}'),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 140;
            final isTiny = constraints.maxWidth < 90 || constraints.maxHeight < 90;
            final avatarRadius = isTiny ? 16.0 : (isCompact ? 20.0 : 28.0);
            final nameFontSize = isCompact ? 12.0 : 14.0;
            final positionFontSize = isCompact ? 10.0 : 12.0;
            final roleFontSize = isCompact ? 9.0 : 10.0;
            final spacingLarge = isCompact ? 4.0 : 8.0;
            final spacingSmall = isCompact ? 1.0 : 2.0;
            final spacingMid = isCompact ? 2.0 : 4.0;

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: avatarRadius,
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  backgroundImage: staff.photoUrl != null
                      ? NetworkImage(staff.photoUrl!)
                      : null,
                  child: staff.photoUrl == null
                      ? Text(
                          staff.fullName.isNotEmpty
                              ? staff.fullName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: isCompact ? 16 : 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        )
                      : null,
                ),
                SizedBox(height: isTiny ? 2 : spacingLarge),
                Text(
                  staff.fullName,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: nameFontSize),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                if (!isTiny) ...[
                  SizedBox(height: spacingSmall),
                  Text(
                    staff.position,
                    style: TextStyle(fontSize: positionFontSize, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacingMid),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: isCompact ? 6 : 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getRoleColor(staff.role).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      staff.role.displayName,
                      style: TextStyle(
                        fontSize: roleFontSize,
                        fontWeight: FontWeight.w600,
                        color: _getRoleColor(staff.role),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.purple;
      case UserRole.manager:
        return Colors.orange;
      case UserRole.finance:
        return Colors.green;
      case UserRole.requester:
        return Colors.blue;
      case UserRole.studentWorker:
        return Colors.cyan;
    }
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return 1;
    if (width > 1200) return 6;
    if (width > 900) return 4;
    if (width > 600) return 3;
    return 2;
  }
}
