import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user.dart';
import '../../models/enums.dart';
import '../../models/student_timesheet.dart';
import '../../services/firestore_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _firestoreService.getAllUsers();
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading users: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.purple.shade400, Colors.purple.shade600],
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
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveContainer(
              child: _users.isEmpty ? _buildEmptyState() : _buildUserList(),
            ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.purple.shade400, Colors.purple.shade600],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showAddUserDialog(),
            borderRadius: BorderRadius.circular(24),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_add, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Add User',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
              color: Colors.grey.withOpacity(0.1),
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
                    color: Colors.purple.withOpacity(0.3),
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
    final admins = _users.where((u) => u.role == 'admin').toList();
    final approvers = _users.where((u) => u.role == 'approver').toList();
    final requestors = _users.where((u) => u.role == 'requestor').toList();
    final students = _users.where((u) => u.role == 'studentWorker').toList();

    return ListView(
      children: [
        if (admins.isNotEmpty) ...[
          _buildSectionHeader('Admins', Icons.admin_panel_settings, Colors.purple, admins.length),
          ...admins.map((user) => _buildUserCard(user)),
        ],
        if (approvers.isNotEmpty) ...[
          _buildSectionHeader('Approvers', Icons.verified_user, Colors.blue, approvers.length),
          ...approvers.map((user) => _buildUserCard(user)),
        ],
        if (requestors.isNotEmpty) ...[
          _buildSectionHeader('Requestors', Icons.person, Colors.green, requestors.length),
          ...requestors.map((user) => _buildUserCard(user)),
        ],
        if (students.isNotEmpty) ...[
          _buildSectionHeader('Student Workers', Icons.school, Colors.orange, students.length),
          ...students.map((user) => StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('student_profiles')
                .doc(user.id)
                .snapshots(),
            builder: (context, snapshot) {
              StudentProfile? profile;
              if (snapshot.hasData && snapshot.data!.exists) {
                profile = StudentProfile.fromFirestore(snapshot.data!);
              }
              return _buildStudentCard(user, profile);
            },
          )),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color, int count) {
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [color.withValues(alpha: 0.1), Colors.transparent],
        ),
        border: Border(
          left: BorderSide(color: color, width: 4),
        ),
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
            color: Colors.grey.withOpacity(0.1),
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
                    color: _getRoleColor(user.role).withOpacity(0.3),
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                          color: _getRoleColor(user.role).withOpacity(0.3),
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
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                          Icon(Icons.email_outlined, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              user.email,
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
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
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit_user',
                      child: Row(
                        children: [
                          Icon(Icons.person_outline, color: Colors.blue.shade600),
                          const SizedBox(width: 8),
                          const Text('Edit User Info'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'edit_profile',
                      child: Row(
                        children: [
                          Icon(Icons.school_outlined, color: Colors.orange.shade600),
                          const SizedBox(width: 8),
                          const Text('Edit Student Profile'),
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
                  Expanded(child: _buildStudentInfoItem(Icons.badge, 'Student #', profile.studentNumber)),
                  Expanded(child: _buildStudentInfoItem(Icons.phone, 'Phone', profile.phoneNumber)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildStudentInfoItem(Icons.book, 'Course', profile.course)),
                  Expanded(child: _buildStudentInfoItem(Icons.school_outlined, 'Year', profile.yearLevel)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildStudentInfoItem(Icons.language, 'Language', profile.language ?? 'Not set')),
                  Expanded(child: _buildStudentInfoItem(Icons.work_outline, 'Role', profile.role ?? 'Not set')),
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
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.orange.shade400, Colors.orange.shade600],
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
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Color> _getRoleGradientColors(String role) {
    switch (role) {
      case 'admin':
        return [Colors.purple.shade400, Colors.purple.shade600];
      case 'approver':
        return [Colors.blue.shade400, Colors.blue.shade600];
      case 'requestor':
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
      case 'approver':
        return Colors.blue;
      case 'requestor':
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

  void _showAddUserDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final departmentController = TextEditingController();
    String selectedRole = 'requestor';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add New User'),
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
                    value: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.security),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'requestor',
                        child: Text('Requestor'),
                      ),
                      DropdownMenuItem(
                        value: 'approver',
                        child: Text('Approver'),
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
                    departmentController.text.trim(),
                    selectedRole,
                  );
                }
              },
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
    String selectedRole = user.role;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
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
                    value: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.security),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'requestor',
                        child: Text('Requestor'),
                      ),
                      DropdownMenuItem(
                        value: 'approver',
                        child: Text('Approver'),
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
                  );
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
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
    String department,
    String role,
  ) async {
    try {
      final user = User(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        email: email,
        department: department,
        role: role,
        createdAt: DateTime.now(),
      );
      await _firestoreService.saveUser(user);
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateUser(
    String userId,
    String name,
    String email,
    String department,
    String role,
  ) async {
    try {
      final existingUser = _users.firstWhere((u) => u.id == userId);
      final updatedUser = existingUser.copyWith(
        name: name,
        email: email,
        department: department,
        role: role,
      );
      await _firestoreService.updateUser(updatedUser);
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
    final studentNumberController = TextEditingController(text: profile?.studentNumber ?? '');
    final phoneNumberController = TextEditingController(text: profile?.phoneNumber ?? '');
    final courseController = TextEditingController(text: profile?.course ?? '');
    String selectedYearLevel = profile?.yearLevel ?? '1st Year';
    String? selectedLanguage = profile?.language;
    String? selectedRole = profile?.role;
    String? selectedGrade = profile?.grade;

    final yearLevels = ['1st Year', '2nd Year', '3rd Year', '4th Year', 'Graduate'];
    final languages = ['Malay', 'Thai', 'Khmer', 'Chinese', 'English', 'Lao', 'Vietnamese', 'Other'];
    final roles = ['Video Editor', 'Producer', 'Content Creator', 'Language Editor', 'Other'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Calculate rate based on role and grade (use 'Other' as fallback)
          final rateRole = selectedRole ?? 'Other';
          double calculatedRate = StudentRateConfig.getRate(rateRole, selectedGrade);

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
                  child: const Icon(Icons.school, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Edit Student Profile', style: TextStyle(fontSize: 18)),
                      Text(
                        user.name,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.normal),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                      value: selectedYearLevel,
                      decoration: InputDecoration(
                        labelText: 'Year Level *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.school_outlined),
                      ),
                      items: yearLevels.map((year) => DropdownMenuItem(value: year, child: Text(year))).toList(),
                      onChanged: (value) => setState(() => selectedYearLevel = value!),
                    ),
                    const SizedBox(height: 16),
                    // Language
                    DropdownButtonFormField<String>(
                      value: selectedLanguage,
                      decoration: InputDecoration(
                        labelText: 'Language',
                        hintText: 'Select language',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.language),
                      ),
                      items: languages.map((lang) => DropdownMenuItem(value: lang, child: Text(lang))).toList(),
                      onChanged: (value) => setState(() => selectedLanguage = value),
                    ),
                    const SizedBox(height: 16),
                    // Role
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: InputDecoration(
                        labelText: 'Role',
                        hintText: 'Select role',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.work_outline),
                      ),
                      items: roles.map((role) => DropdownMenuItem(value: role, child: Text(role))).toList(),
                      onChanged: (value) => setState(() => selectedRole = value),
                    ),
                    const SizedBox(height: 16),
                    // Grade
                    DropdownButtonFormField<String>(
                      value: selectedGrade,
                      decoration: InputDecoration(
                        labelText: 'Grade',
                        hintText: 'Select grade',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => selectedGrade = value),
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
                                  style: TextStyle(fontSize: 12, color: Colors.green.shade700),
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
                          hourlyRate: calculatedRate > 0 ? calculatedRate : profile?.hourlyRate ?? 0.0,
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text(
                        'Save Changes',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
      final profileRef = FirebaseFirestore.instance.collection('student_profiles').doc(userId);
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
}
