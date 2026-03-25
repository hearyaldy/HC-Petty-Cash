import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart' show User, InventoryPermissions, SectionPermissions;
import '../../models/enums.dart';
import '../../models/organization.dart';
import '../../models/student_timesheet.dart';
import '../../services/firestore_service.dart';
import '../../services/organization_service.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';
import '../../utils/responsive_helper.dart';
import '../../utils/student_rate_config.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<User> _users = [];
  bool _isLoading = true;
  // Store student profiles in state to avoid Firestore web stream issues
  Map<String, StudentProfile> _studentProfiles = {};

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      debugPrint('UserManagement: Starting to load users...');
      final users = await _firestoreService.getAllUsers();
      debugPrint('UserManagement: Loaded ${users.length} users');
      for (final user in users) {
        debugPrint(
          '  - User: ${user.name} (${user.email}), role: ${user.role}',
        );
      }
      _users = users;

      // Load student profiles for student workers
      await _loadStudentProfiles();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('UserManagement: Error loading users: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading users: $e')));
      }
    }
  }

  Future<void> _loadStudentProfiles() async {
    try {
      final students = _users.where((u) => u.role == 'studentWorker').toList();
      final profiles = <String, StudentProfile>{};

      for (final student in students) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('student_profiles')
              .doc(student.id)
              .get(const GetOptions(source: Source.server));

          if (doc.exists) {
            profiles[student.id] = StudentProfile.fromFirestore(doc);
          }
        } catch (e) {
          debugPrint(
            'UserManagement: Error loading profile for ${student.id}: $e',
          );
        }
      }

      if (mounted) {
        setState(() {
          _studentProfiles = profiles;
        });
      }
    } catch (e) {
      debugPrint('UserManagement: Error loading student profiles: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            _buildWelcomeHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ResponsiveContainer(
                      child: _users.isEmpty
                          ? _buildEmptyState()
                          : _buildUserList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.purple.shade400, Colors.purple.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.shade200,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'User Management',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: [
                  _buildHeaderActionButton(
                    icon: Icons.person_add,
                    tooltip: 'Add User',
                    onPressed: () => _showAddUserDialog(),
                  ),
                  const SizedBox(width: 8),
                  _buildHeaderActionButton(
                    icon: Icons.refresh,
                    tooltip: 'Refresh',
                    onPressed: _loadUsers,
                  ),
                  const SizedBox(width: 8),
                  _buildHeaderActionButton(
                    icon: Icons.home_outlined,
                    tooltip: 'Home',
                    onPressed: () => context.go('/admin-hub'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.people, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Manage Users',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_users.length} users in system',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
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

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.purple.shade100, Colors.purple.shade200],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline,
                size: 64,
                color: Colors.purple.shade700,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No users found',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Get started by adding your first user',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.purple.shade400, Colors.purple.shade600],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showAddUserDialog(),
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_add, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Add First User',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserList() {
    // Group users by role
    final knownRoles = [
      'admin',
      'manager',
      'finance',
      'requester',
      'studentWorker',
    ];
    final admins = _users.where((u) => u.role == 'admin').toList();
    final managers = _users.where((u) => u.role == 'manager').toList();
    final finance = _users.where((u) => u.role == 'finance').toList();
    final requesters = _users.where((u) => u.role == 'requester').toList();
    final students = _users.where((u) => u.role == 'studentWorker').toList();
    // Catch users with unknown/old role values
    final others = _users.where((u) => !knownRoles.contains(u.role)).toList();

    return ListView(
      children: [
        // Debug info - total users loaded
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Total users: ${_users.length}',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ),
        if (admins.isNotEmpty) ...[
          _buildSectionHeader(
            'Admins',
            Icons.admin_panel_settings,
            Colors.purple,
            admins.length,
          ),
          ...admins.map((user) => _buildUserCard(user)),
        ],
        if (managers.isNotEmpty) ...[
          _buildSectionHeader(
            'Managers',
            Icons.verified_user,
            Colors.blue,
            managers.length,
          ),
          ...managers.map((user) => _buildUserCard(user)),
        ],
        if (finance.isNotEmpty) ...[
          _buildSectionHeader(
            'Finance',
            Icons.account_balance,
            Colors.teal,
            finance.length,
          ),
          ...finance.map((user) => _buildUserCard(user)),
        ],
        if (requesters.isNotEmpty) ...[
          _buildSectionHeader(
            'Requesters',
            Icons.person,
            Colors.green,
            requesters.length,
          ),
          ...requesters.map((user) => _buildUserCard(user)),
        ],
        if (students.isNotEmpty) ...[
          _buildSectionHeader(
            'Student Workers',
            Icons.school,
            Colors.orange,
            students.length,
          ),
          ...students.map(
            (user) => _buildStudentCard(user, _studentProfiles[user.id]),
          ),
        ],
        // Show users with unknown roles (for debugging)
        if (others.isNotEmpty) ...[
          _buildSectionHeader(
            'Other (Unknown Role)',
            Icons.help_outline,
            Colors.grey,
            others.length,
          ),
          ...others.map((user) => _buildUserCard(user)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(
    String title,
    IconData icon,
    Color color,
    int count,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [color.withValues(alpha: 0.1), Colors.transparent],
        ),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(User user, {double? hourlyRate, String? grade}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _getRoleGradientColors(user.role),
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _getRoleColor(user.role).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.email_outlined,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          user.email,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.business_outlined,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        user.department,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                  if (user.role == 'studentWorker') ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (grade != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getGradeColor(grade),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Grade $grade',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (hourlyRate != null) ...[
                          Icon(
                            Icons.attach_money,
                            size: 14,
                            color: Colors.orange.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${AppConstants.currencySymbol}${hourlyRate.toStringAsFixed(2)}/h',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _getRoleGradientColors(user.role),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: _getRoleColor(user.role).withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          UserRole.values
                              .firstWhere(
                                (e) => e.name == user.role.trim().toLowerCase(),
                                orElse: () => UserRole.requester,
                              )
                              .displayName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_hasAnyInventoryPermission(user))
                        _buildInventoryBadge(user),
                      if (_hasAnySectionPermission(user)) ...[
                        const SizedBox(width: 8),
                        _buildSectionBadge(user),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditUserDialog(user);
                } else if (value == 'delete') {
                  _confirmDeleteUser(user);
                } else if (value == 'rate') {
                  _showEditRateDialog(user, hourlyRate ?? 0.0);
                } else if (value == 'inventory') {
                  _showInventoryPermissionsDialog(user);
                } else if (value == 'sections') {
                  _showSectionPermissionsDialog(user);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: Colors.blue.shade600),
                      const SizedBox(width: 8),
                      const Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'inventory',
                  child: Row(
                    children: [
                      Icon(Icons.inventory_2, color: Colors.indigo.shade600),
                      const SizedBox(width: 8),
                      const Text('Inventory Access'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'sections',
                  child: Row(
                    children: [
                      Icon(Icons.tune, color: Colors.teal.shade600),
                      const SizedBox(width: 8),
                      const Text('Section Access'),
                    ],
                  ),
                ),
                if (user.role == 'studentWorker')
                  PopupMenuItem(
                    value: 'rate',
                    child: Row(
                      children: [
                        Icon(Icons.attach_money, color: Colors.orange.shade600),
                        const SizedBox(width: 8),
                        const Text('Manage Rate'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(User user, StudentProfile? profile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with avatar and basic info
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.orange.shade400, Colors.orange.shade600],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'S',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (profile?.grade != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getGradeColor(profile!.grade!),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Grade ${profile.grade}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.email_outlined,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              user.email,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit_user') {
                      _showEditUserDialog(user);
                    } else if (value == 'edit_profile') {
                      _showEditStudentProfileDialog(user, profile);
                    } else if (value == 'delete') {
                      _confirmDeleteUser(user);
                    } else if (value == 'inventory') {
                      _showInventoryPermissionsDialog(user);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit_user',
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            color: Colors.blue.shade600,
                          ),
                          const SizedBox(width: 8),
                          const Text('Edit User Info'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'edit_profile',
                      child: Row(
                        children: [
                          Icon(
                            Icons.school_outlined,
                            color: Colors.orange.shade600,
                          ),
                          const SizedBox(width: 8),
                          const Text('Edit Student Profile'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'inventory',
                      child: Row(
                        children: [
                          Icon(
                            Icons.inventory_2,
                            color: Colors.indigo.shade600,
                          ),
                          const SizedBox(width: 8),
                          const Text('Inventory Access'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            // Student details grid
            if (profile != null) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildStudentInfoItem(
                      Icons.badge,
                      'Student #',
                      profile.studentNumber,
                    ),
                  ),
                  Expanded(
                    child: _buildStudentInfoItem(
                      Icons.phone,
                      'Phone',
                      profile.phoneNumber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStudentInfoItem(
                      Icons.book,
                      'Course',
                      profile.course,
                    ),
                  ),
                  Expanded(
                    child: _buildStudentInfoItem(
                      Icons.school_outlined,
                      'Year',
                      profile.yearLevel,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStudentInfoItem(
                      Icons.language,
                      'Language',
                      profile.language ?? 'Not set',
                    ),
                  ),
                  Expanded(
                    child: _buildStudentInfoItem(
                      Icons.work_outline,
                      'Role',
                      profile.role ?? 'Not set',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Rate and Grade row
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hourly Rate',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${AppConstants.currencySymbol}${profile.hourlyRate.toStringAsFixed(2)}/hr',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.shade400,
                            Colors.orange.shade600,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.school, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Student Worker',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[600]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Student has not completed onboarding yet.',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStudentInfoItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              Text(
                value.isEmpty ? 'Not set' : value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _hasAnyInventoryPermission(User user) {
    // Admin always has full access
    if (user.role == 'admin') return true;
    final perms = user.inventoryPermissions;
    return perms.canView ||
        perms.canAdd ||
        perms.canEdit ||
        perms.canDelete ||
        perms.canCheckout;
  }

  Widget _buildInventoryBadge(User user) {
    final perms = user.inventoryPermissions;
    final isAdmin = user.role == 'admin';
    final permCount = isAdmin
        ? 5
        : [
            perms.canView,
            perms.canAdd,
            perms.canEdit,
            perms.canDelete,
            perms.canCheckout,
          ].where((p) => p).length;

    return Tooltip(
      message: isAdmin
          ? 'Full inventory access (Admin)'
          : 'Inventory: ${_getPermissionSummary(user)}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.indigo.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.indigo.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2,
              size: 12,
              color: Colors.indigo.shade600,
            ),
            const SizedBox(width: 4),
            Text(
              isAdmin ? 'Full' : '$permCount/5',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.indigo.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPermissionSummary(User user) {
    final perms = user.inventoryPermissions;
    final List<String> enabled = [];
    if (perms.canView) enabled.add('View');
    if (perms.canAdd) enabled.add('Add');
    if (perms.canEdit) enabled.add('Edit');
    if (perms.canDelete) enabled.add('Delete');
    if (perms.canCheckout) enabled.add('Checkout');
    return enabled.isEmpty ? 'No access' : enabled.join(', ');
  }

  List<Color> _getRoleGradientColors(String role) {
    switch (role) {
      case 'admin':
        return [Colors.purple.shade400, Colors.purple.shade600];
      case 'manager':
        return [Colors.blue.shade400, Colors.blue.shade600];
      case 'finance':
        return [Colors.teal.shade400, Colors.teal.shade600];
      case 'requester':
        return [Colors.green.shade400, Colors.green.shade600];
      case 'studentWorker':
        return [Colors.orange.shade400, Colors.orange.shade600];
      default:
        return [Colors.grey.shade400, Colors.grey.shade600];
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.purple;
      case 'manager':
        return Colors.blue;
      case 'finance':
        return Colors.teal;
      case 'requester':
        return Colors.green;
      case 'studentWorker':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Color _getGradeColor(String grade) {
    switch (grade.toUpperCase()) {
      case 'A':
        return Colors.green.shade600;
      case 'B':
        return Colors.blue.shade600;
      case 'C':
        return Colors.orange.shade600;
      case 'D':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  // Normalize old role values to new enum values
  String _normalizeRole(String role) {
    switch (role) {
      case 'requestor':
        return 'requester';
      case 'approver':
        return 'manager'; // Map old 'approver' to 'manager'
      default:
        // Check if it's a valid role, otherwise default to requester
        final validRoles = [
          'requester',
          'manager',
          'finance',
          'admin',
          'studentWorker',
        ];
        return validRoles.contains(role) ? role : 'requester';
    }
  }

  void _showAddUserDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final departmentController = TextEditingController();
    String selectedRole = 'requester';
    final formKey = GlobalKey<FormState>();
    bool obscurePassword = true;
    bool obscureConfirmPassword = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade400, Colors.purple.shade600],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.person_add,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Add New User'),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter an email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () =>
                            setState(() => obscurePassword = !obscurePassword),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirmPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () => setState(
                          () =>
                              obscureConfirmPassword = !obscureConfirmPassword,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm password';
                      }
                      if (value != passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: departmentController,
                    decoration: const InputDecoration(
                      labelText: 'Department',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a department';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.security),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'requester',
                        child: Text('Requester'),
                      ),
                      DropdownMenuItem(
                        value: 'manager',
                        child: Text('Manager'),
                      ),
                      DropdownMenuItem(
                        value: 'finance',
                        child: Text('Finance'),
                      ),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      DropdownMenuItem(
                        value: 'studentWorker',
                        child: Text('Student Worker'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedRole = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.amber.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You will need to re-enter your password after creating this user.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context);
                  await _addUser(
                    nameController.text.trim(),
                    emailController.text.trim(),
                    passwordController.text,
                    departmentController.text.trim(),
                    selectedRole,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add User'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditUserDialog(User user) {
    final nameController = TextEditingController(text: user.name);
    final emailController = TextEditingController(text: user.email);
    final departmentController = TextEditingController(text: user.department);
    // Normalize old role values to new ones
    String selectedRole = _normalizeRole(user.role);
    String? selectedOrganizationId = user.organizationId;
    String? selectedOrganizationName = user.organizationName;
    final formKey = GlobalKey<FormState>();
    final organizationService = OrganizationService();
    List<Organization> organizations = [];
    bool isLoadingOrgs = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Load organizations when dialog opens
          if (isLoadingOrgs) {
            organizationService.getAllOrganizations().then((orgs) {
              setState(() {
                organizations = orgs.where((o) => o.isActive).toList();
                isLoadingOrgs = false;
              });
            });
          }

          return AlertDialog(
            title: const Text('Edit User'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter an email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: departmentController,
                      decoration: const InputDecoration(
                        labelText: 'Department',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.business),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a department';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.security),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'requester',
                          child: Text('Requester'),
                        ),
                        DropdownMenuItem(
                          value: 'manager',
                          child: Text('Manager'),
                        ),
                        DropdownMenuItem(
                          value: 'finance',
                          child: Text('Finance'),
                        ),
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                        DropdownMenuItem(
                          value: 'studentWorker',
                          child: Text('Student Worker'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedRole = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // Organization dropdown for inventory access
                    isLoadingOrgs
                        ? const LinearProgressIndicator()
                        : DropdownButtonFormField<String?>(
                            initialValue: selectedOrganizationId,
                            decoration: const InputDecoration(
                              labelText: 'Organization (for Inventory)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.corporate_fare),
                              helperText: 'Determines which inventory the user can access',
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('No Organization (Admin sees all)'),
                              ),
                              ...organizations.map(
                                (org) => DropdownMenuItem<String?>(
                                  value: org.id,
                                  child: Text('${org.name} (${org.code})'),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                selectedOrganizationId = value;
                                selectedOrganizationName = value != null
                                    ? organizations
                                        .firstWhere((o) => o.id == value)
                                        .name
                                    : null;
                              });
                            },
                          ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context);
                    await _updateUser(
                      user.id,
                      nameController.text.trim(),
                      emailController.text.trim(),
                      departmentController.text.trim(),
                      selectedRole,
                      organizationId: selectedOrganizationId,
                      organizationName: selectedOrganizationName,
                    );
                  }
                },
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteUser(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteUser(user.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _addUser(
    String name,
    String email,
    String password,
    String department,
    String role,
  ) async {
    // Get current admin email before creating new user
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final adminEmail = authProvider.currentUser?.email;

    // Store references before async operations
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (adminEmail == null) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Error: Admin not logged in'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Track if loading dialog is showing
    bool isDialogShowing = false;

    void closeLoadingDialog() {
      if (isDialogShowing && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        isDialogShowing = false;
      }
    }

    try {
      // Show loading indicator
      if (mounted) {
        isDialogShowing = true;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => PopScope(
            canPop: false,
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Creating user...'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }

      // Convert role string to UserRole enum
      final userRole = UserRole.values.firstWhere(
        (e) => e.name == role,
        orElse: () => UserRole.requester,
      );

      debugPrint('Creating user with email: $email, role: ${userRole.name}');

      // Create new user with Firebase Auth (this will sign out admin)
      final userId = await authProvider.registerUser(
        email: email,
        password: password,
        name: name,
        role: userRole,
        department: department,
      );

      debugPrint('User created with ID: $userId');

      // Close loading dialog
      closeLoadingDialog();

      // Show success message and prompt for admin re-authentication
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('User created successfully! Please re-authenticate.'),
            backgroundColor: Colors.green,
          ),
        );

        // Show re-authentication dialog
        await _showReauthenticationDialog(adminEmail);
      }
    } catch (e, stackTrace) {
      debugPrint('Error creating user: $e');
      debugPrint('Stack trace: $stackTrace');

      // Close loading dialog if open
      closeLoadingDialog();

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error adding user: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
  }

  Future<void> _showReauthenticationDialog(String adminEmail) async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscurePassword = true;
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade400, Colors.purple.shade600],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lock_person,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Re-authenticate'),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User created successfully!',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Please enter your admin password to continue:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.email, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          adminEmail,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Your Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () =>
                          setState(() => obscurePassword = !obscurePassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    setState(() => isLoading = true);
                    try {
                      final authProvider = Provider.of<AuthProvider>(
                        context,
                        listen: false,
                      );
                      final navigator = Navigator.of(context);
                      final scaffoldMessenger = ScaffoldMessenger.of(context);

                      await authProvider.login(
                        adminEmail,
                        passwordController.text,
                      );

                      if (context.mounted) {
                        navigator.pop();
                      }

                      await _loadUsers();

                      if (mounted) {
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                            content: Text('Welcome back, Admin!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      setState(() => isLoading = false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Login failed: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade600,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Sign In'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateUser(
    String userId,
    String name,
    String email,
    String department,
    String role, {
    String? organizationId,
    String? organizationName,
  }) async {
    try {
      // Update user document directly to properly handle null organization values
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'name': name,
        'email': email,
        'department': department,
        'role': role,
        'organizationId': organizationId, // Can be null to clear
        'organizationName': organizationName, // Can be null to clear
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteUser(String userId) async {
    try {
      await _firestoreService.deleteUser(userId);
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEditRateDialog(User user, double currentRate) {
    final rateController = TextEditingController(
      text: currentRate.toStringAsFixed(2),
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.attach_money, color: Colors.orange.shade600),
            const SizedBox(width: 12),
            const Text('Edit Hourly Rate'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Student: ${user.name}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: rateController,
                decoration: InputDecoration(
                  labelText: 'Hourly Rate (${AppConstants.currencySymbol})',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: const OutlineInputBorder(),
                  hintText: 'Enter hourly rate',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter hourly rate';
                  }
                  final rate = double.tryParse(value);
                  if (rate == null || rate <= 0) {
                    return 'Please enter a valid rate';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final newRate = double.parse(rateController.text);
                Navigator.of(context).pop();
                await _updateStudentRate(user.id, newRate);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Update Rate'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStudentRate(String userId, double newRate) async {
    try {
      await FirebaseFirestore.instance
          .collection('student_profiles')
          .doc(userId)
          .update({
            'hourlyRate': newRate,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hourly rate updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating rate: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEditStudentProfileDialog(User user, StudentProfile? profile) {
    final formKey = GlobalKey<FormState>();
    final studentNumberController = TextEditingController(
      text: profile?.studentNumber ?? '',
    );
    final phoneNumberController = TextEditingController(
      text: profile?.phoneNumber ?? '',
    );
    final courseController = TextEditingController(text: profile?.course ?? '');
    String selectedYearLevel = profile?.yearLevel ?? '1st Year';
    String? selectedLanguage = profile?.language;
    String? selectedRole = profile?.role;
    String? selectedGrade = profile?.grade;

    final yearLevels = [
      '1st Year',
      '2nd Year',
      '3rd Year',
      '4th Year',
      'Graduate',
    ];
    final languages = [
      'Malay',
      'Thai',
      'Khmer',
      'Chinese',
      'English',
      'Lao',
      'Vietnamese',
      'Other',
    ];
    final roles = [
      'Video Editor',
      'Producer',
      'Content Creator',
      'Language Editor',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Calculate rate based on role and grade (use 'Other' as fallback)
          final rateRole = selectedRole ?? 'Other';
          double calculatedRate = StudentRateConfig.getRate(
            rateRole,
            selectedGrade,
          );

          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade400, Colors.orange.shade600],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.school,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Edit Student Profile',
                        style: TextStyle(fontSize: 18),
                      ),
                      Text(
                        user.name,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Student Number
                    TextFormField(
                      controller: studentNumberController,
                      decoration: InputDecoration(
                        labelText: 'Student Number *',
                        hintText: 'e.g., 2024-12345',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.badge),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter student number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Phone Number
                    TextFormField(
                      controller: phoneNumberController,
                      decoration: InputDecoration(
                        labelText: 'Phone Number *',
                        hintText: 'e.g., +1234567890',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Course
                    TextFormField(
                      controller: courseController,
                      decoration: InputDecoration(
                        labelText: 'Course/Program *',
                        hintText: 'e.g., Computer Science',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.book),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter course';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Year Level
                    DropdownButtonFormField<String>(
                      initialValue: selectedYearLevel,
                      decoration: InputDecoration(
                        labelText: 'Year Level *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.school_outlined),
                      ),
                      items: yearLevels
                          .map(
                            (year) => DropdownMenuItem(
                              value: year,
                              child: Text(year),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => selectedYearLevel = value!),
                    ),
                    const SizedBox(height: 16),
                    // Language
                    DropdownButtonFormField<String>(
                      initialValue: selectedLanguage,
                      decoration: InputDecoration(
                        labelText: 'Language',
                        hintText: 'Select language',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.language),
                      ),
                      items: languages
                          .map(
                            (lang) => DropdownMenuItem(
                              value: lang,
                              child: Text(lang),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => selectedLanguage = value),
                    ),
                    const SizedBox(height: 16),
                    // Role
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: InputDecoration(
                        labelText: 'Role',
                        hintText: 'Select role',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.work_outline),
                      ),
                      items: roles
                          .map(
                            (role) => DropdownMenuItem(
                              value: role,
                              child: Text(role),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => selectedRole = value),
                    ),
                    const SizedBox(height: 16),
                    // Grade
                    DropdownButtonFormField<String>(
                      initialValue: selectedGrade,
                      decoration: InputDecoration(
                        labelText: 'Grade',
                        hintText: 'Select grade',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.grade),
                      ),
                      items: StudentRateConfig.grades.map((grade) {
                        // Use selected role or 'Other' as fallback for rate display
                        final rateRole = selectedRole ?? 'Other';
                        final rate = StudentRateConfig.getRate(rateRole, grade);
                        return DropdownMenuItem(
                          value: grade,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Grade $grade'),
                              Text(
                                'THB ${rate.toStringAsFixed(0)}/hr',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => selectedGrade = value),
                    ),
                    const SizedBox(height: 16),
                    // Calculated Rate Display
                    if (selectedGrade != null && calculatedRate > 0)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calculate, color: Colors.green.shade700),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Calculated Hourly Rate',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                                Text(
                                  'THB ${calculatedRate.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade400, Colors.orange.shade600],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      if (formKey.currentState!.validate()) {
                        Navigator.pop(context);
                        await _updateStudentProfile(
                          user.id,
                          studentNumber: studentNumberController.text.trim(),
                          phoneNumber: phoneNumberController.text.trim(),
                          course: courseController.text.trim(),
                          yearLevel: selectedYearLevel,
                          language: selectedLanguage,
                          role: selectedRole,
                          grade: selectedGrade,
                          hourlyRate: calculatedRate > 0
                              ? calculatedRate
                              : profile?.hourlyRate ?? 0.0,
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Text(
                        'Save Changes',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateStudentProfile(
    String userId, {
    required String studentNumber,
    required String phoneNumber,
    required String course,
    required String yearLevel,
    String? language,
    String? role,
    String? grade,
    required double hourlyRate,
  }) async {
    try {
      final profileRef = FirebaseFirestore.instance
          .collection('student_profiles')
          .doc(userId);
      final profileDoc = await profileRef.get();

      if (profileDoc.exists) {
        // Update existing profile
        await profileRef.update({
          'studentNumber': studentNumber,
          'phoneNumber': phoneNumber,
          'course': course,
          'yearLevel': yearLevel,
          'language': language,
          'role': role,
          'grade': grade,
          'hourlyRate': hourlyRate,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new profile
        await profileRef.set({
          'userId': userId,
          'studentNumber': studentNumber,
          'phoneNumber': phoneNumber,
          'course': course,
          'yearLevel': yearLevel,
          'language': language,
          'role': role,
          'grade': grade,
          'hourlyRate': hourlyRate,
          'onboardedAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showInventoryPermissionsDialog(User user) {
    // Get current permissions
    bool canView = user.inventoryPermissions.canView;
    bool canAdd = user.inventoryPermissions.canAdd;
    bool canEdit = user.inventoryPermissions.canEdit;
    bool canDelete = user.inventoryPermissions.canDelete;
    bool canCheckout = user.inventoryPermissions.canCheckout;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade400, Colors.indigo.shade600],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.inventory_2,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Inventory Permissions',
                      style: TextStyle(fontSize: 18),
                    ),
                    Text(
                      user.name,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Admin note
                if (user.role == 'admin')
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.amber.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Admins automatically have full inventory access.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Quick actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            canView = true;
                            canAdd = true;
                            canEdit = true;
                            canDelete = true;
                            canCheckout = true;
                          });
                        },
                        icon: const Icon(Icons.check_circle, size: 16),
                        label: const Text('Grant All'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            canView = false;
                            canAdd = false;
                            canEdit = false;
                            canDelete = false;
                            canCheckout = false;
                          });
                        },
                        icon: const Icon(Icons.cancel, size: 16),
                        label: const Text('Revoke All'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                // Individual permissions
                _buildPermissionSwitch(
                  title: 'View Inventory',
                  subtitle: 'Can see equipment list and details',
                  icon: Icons.visibility,
                  value: canView,
                  onChanged: (val) => setState(() => canView = val),
                ),
                _buildPermissionSwitch(
                  title: 'Add Equipment',
                  subtitle: 'Can add new equipment to inventory',
                  icon: Icons.add_circle_outline,
                  value: canAdd,
                  onChanged: (val) => setState(() => canAdd = val),
                ),
                _buildPermissionSwitch(
                  title: 'Edit Equipment',
                  subtitle: 'Can modify existing equipment details',
                  icon: Icons.edit,
                  value: canEdit,
                  onChanged: (val) => setState(() => canEdit = val),
                ),
                _buildPermissionSwitch(
                  title: 'Delete Equipment',
                  subtitle: 'Can remove equipment from inventory',
                  icon: Icons.delete_outline,
                  value: canDelete,
                  onChanged: (val) => setState(() => canDelete = val),
                  isDanger: true,
                ),
                _buildPermissionSwitch(
                  title: 'Checkout Equipment',
                  subtitle: 'Can checkout/return equipment',
                  icon: Icons.assignment_return,
                  value: canCheckout,
                  onChanged: (val) => setState(() => canCheckout = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo.shade400, Colors.indigo.shade600],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    Navigator.pop(context);
                    await _updateInventoryPermissions(
                      user,
                      canView: canView,
                      canAdd: canAdd,
                      canEdit: canEdit,
                      canDelete: canDelete,
                      canCheckout: canCheckout,
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      'Save Permissions',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionSwitch({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isDanger = false,
  }) {
    final color = isDanger ? Colors.red : Colors.indigo;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: value ? color.withValues(alpha: 0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? color.withValues(alpha: 0.3) : Colors.grey.shade200,
        ),
      ),
      child: SwitchListTile(
        title: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: value ? color : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: value ? color.shade700 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(left: 28),
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeThumbColor: color,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }

  // ── Section permissions ────────────────────────────────────────────────────

  bool _hasAnySectionPermission(User user) {
    if (user.role == 'admin') return true;
    return user.sectionPermissions.hasAny;
  }

  Widget _buildSectionBadge(User user) {
    final isAdmin = user.role == 'admin';
    final count = isAdmin ? 10 : user.sectionPermissions.enabledCount;
    return Tooltip(
      message: isAdmin
          ? 'Full section access (Admin)'
          : '$count section permission(s) granted',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.teal.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.teal.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune, size: 12, color: Colors.teal.shade600),
            const SizedBox(width: 4),
            Text(
              isAdmin ? 'Full' : '$count/10',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSectionPermissionsDialog(User user) {
    final p = user.sectionPermissions;
    bool financeView = p.financeView;
    bool financeEdit = p.financeEdit;
    bool meetingsView = p.meetingsView;
    bool meetingsEdit = p.meetingsEdit;
    bool hrView = p.hrView;
    bool hrEdit = p.hrEdit;
    bool reportsView = p.reportsView;
    bool reportsEdit = p.reportsEdit;
    bool studentView = p.studentView;
    bool studentEdit = p.studentEdit;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal.shade400, Colors.teal.shade600],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Section Access', style: TextStyle(fontSize: 18)),
                    Text(
                      user.name,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (user.role == 'admin')
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.amber.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Admins automatically have full access to all sections.',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.amber.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Quick actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() {
                            financeView = financeEdit = true;
                            meetingsView = meetingsEdit = true;
                            hrView = hrEdit = true;
                            reportsView = reportsEdit = true;
                            studentView = studentEdit = true;
                          }),
                          icon: const Icon(Icons.check_circle, size: 16),
                          label: const Text('Grant All'),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green.shade700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() {
                            financeView = financeEdit = false;
                            meetingsView = meetingsEdit = false;
                            hrView = hrEdit = false;
                            reportsView = reportsEdit = false;
                            studentView = studentEdit = false;
                          }),
                          icon: const Icon(Icons.cancel, size: 16),
                          label: const Text('Revoke All'),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  // Finance
                  _buildSectionHeader2('Finance', Icons.account_balance_wallet,
                      Colors.green),
                  _buildViewEditRow(
                    canView: financeView,
                    canEdit: financeEdit,
                    color: Colors.green,
                    subtitle:
                        'Cash advance, petty cash, purchase requisitions, income',
                    onViewChanged: (v) => setState(() {
                      financeView = v;
                      if (!v) financeEdit = false;
                    }),
                    onEditChanged: (v) => setState(() {
                      financeEdit = v;
                      if (v) financeView = true;
                    }),
                  ),
                  const SizedBox(height: 8),
                  // Meetings
                  _buildSectionHeader2(
                      'Meetings', Icons.event_note, Colors.indigo),
                  _buildViewEditRow(
                    canView: meetingsView,
                    canEdit: meetingsEdit,
                    color: Colors.indigo,
                    subtitle: 'Meeting agenda, ADCOM minutes',
                    onViewChanged: (v) => setState(() {
                      meetingsView = v;
                      if (!v) meetingsEdit = false;
                    }),
                    onEditChanged: (v) => setState(() {
                      meetingsEdit = v;
                      if (v) meetingsView = true;
                    }),
                  ),
                  const SizedBox(height: 8),
                  // HR
                  _buildSectionHeader2('HR', Icons.people, Colors.deepPurple),
                  _buildViewEditRow(
                    canView: hrView,
                    canEdit: hrEdit,
                    color: Colors.deepPurple,
                    subtitle:
                        'Staff directory, salary & benefits, employment letters, annual leave',
                    onViewChanged: (v) => setState(() {
                      hrView = v;
                      if (!v) hrEdit = false;
                    }),
                    onEditChanged: (v) => setState(() {
                      hrEdit = v;
                      if (v) hrView = true;
                    }),
                  ),
                  const SizedBox(height: 8),
                  // Reports
                  _buildSectionHeader2(
                      'Reports', Icons.assessment, Colors.teal),
                  _buildViewEditRow(
                    canView: reportsView,
                    canEdit: reportsEdit,
                    color: Colors.teal,
                    subtitle: 'Traveling reports, project reports',
                    onViewChanged: (v) => setState(() {
                      reportsView = v;
                      if (!v) reportsEdit = false;
                    }),
                    onEditChanged: (v) => setState(() {
                      reportsEdit = v;
                      if (v) reportsView = true;
                    }),
                  ),
                  const SizedBox(height: 8),
                  // Student
                  _buildSectionHeader2(
                      'Student', Icons.school, Colors.orange),
                  _buildViewEditRow(
                    canView: studentView,
                    canEdit: studentEdit,
                    color: Colors.orange,
                    subtitle: 'Student management, timesheets',
                    onViewChanged: (v) => setState(() {
                      studentView = v;
                      if (!v) studentEdit = false;
                    }),
                    onEditChanged: (v) => setState(() {
                      studentEdit = v;
                      if (v) studentView = true;
                    }),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade400, Colors.teal.shade600],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    Navigator.pop(context);
                    await _updateSectionPermissions(
                      user,
                      SectionPermissions(
                        financeView: financeView,
                        financeEdit: financeEdit,
                        meetingsView: meetingsView,
                        meetingsEdit: meetingsEdit,
                        hrView: hrView,
                        hrEdit: hrEdit,
                        reportsView: reportsView,
                        reportsEdit: reportsEdit,
                        studentView: studentView,
                        studentEdit: studentEdit,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      'Save Permissions',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader2(String title, IconData icon, MaterialColor color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color.shade600),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: color.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewEditRow({
    required bool canView,
    required bool canEdit,
    required MaterialColor color,
    required String subtitle,
    required ValueChanged<bool> onViewChanged,
    required ValueChanged<bool> onEditChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (canView || canEdit)
            ? color.withValues(alpha: 0.05)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (canView || canEdit)
              ? color.withValues(alpha: 0.25)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildToggleChip(
                  label: 'View',
                  icon: Icons.visibility_outlined,
                  active: canView,
                  color: color,
                  onTap: () => onViewChanged(!canView),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildToggleChip(
                  label: 'Edit',
                  icon: Icons.edit_outlined,
                  active: canEdit,
                  color: color,
                  onTap: () => onEditChanged(!canEdit),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleChip({
    required String label,
    required IconData icon,
    required bool active,
    required MaterialColor color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.shade600 : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? color.shade600 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14,
                color: active ? Colors.white : Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateSectionPermissions(
      User user, SectionPermissions permissions) async {
    try {
      final updatedUser = user.copyWith(
        sectionPermissions: permissions,
        updatedAt: DateTime.now(),
      );
      await _firestoreService.updateUser(updatedUser);
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Section permissions updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating permissions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateInventoryPermissions(
    User user, {
    required bool canView,
    required bool canAdd,
    required bool canEdit,
    required bool canDelete,
    required bool canCheckout,
  }) async {
    try {
      final updatedUser = user.copyWith(
        inventoryPermissions: InventoryPermissions(
          canView: canView,
          canAdd: canAdd,
          canEdit: canEdit,
          canDelete: canDelete,
          canCheckout: canCheckout,
        ),
        updatedAt: DateTime.now(),
      );

      await _firestoreService.updateUser(updatedUser);
      await _loadUsers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inventory permissions updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating permissions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
