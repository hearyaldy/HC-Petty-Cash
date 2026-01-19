import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../providers/report_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/user.dart';
import '../../models/enums.dart';
import '../../models/student_timesheet.dart';
import '../../utils/responsive_helper.dart';
import '../../utils/student_rate_config.dart';
import '../../utils/constants.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<User> _users = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    _users = await FirestoreService().getAllUsers();

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (!authProvider.canManageUsers()) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 80, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Access Denied',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'You do not have permission to access this page',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add),
            onPressed: _showAddTransactionQuickAction,
            tooltip: 'Quick Add Transaction',
          ),
          IconButton(
            icon: const Icon(Icons.attach_money),
            onPressed: () => context.push('/admin/payment-rates'),
            tooltip: 'Student Payment Rates',
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: () => context.push('/admin/income'),
            tooltip: 'Income Reports',
          ),
          IconButton(
            icon: const Icon(Icons.flight_takeoff),
            onPressed: () => context.push('/admin/traveling-reports'),
            tooltip: 'Traveling Reports',
          ),
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () => context.go('/dashboard'),
            tooltip: 'Home',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddUserDialog,
            tooltip: 'Add User',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveContainer(child: _buildUsersList()),
    );
  }

  Future<void> _showAddTransactionQuickAction() async {
    final reportProvider = context.read<ReportProvider>();
    if (reportProvider.reports.isEmpty) {
      await reportProvider.loadReports();
      if (!mounted) return;
    }

    final openReports = reportProvider.reports
        .where((r) => r.statusEnum != ReportStatus.closed)
        .toList();

    if (openReports.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No open reports available.')),
      );
      return;
    }

    final selectedId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Transaction to Report'),
        content: SizedBox(
          width: 420,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: openReports.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final report = openReports[index];
              return ListTile(
                leading: const Icon(Icons.receipt_long),
                title: Text(report.reportNumber),
                subtitle: Text(report.department),
                trailing: Chip(
                  label: Text(report.statusEnum.displayName),
                  backgroundColor: Colors.blue.shade50,
                  labelStyle: const TextStyle(fontSize: 11),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
                onTap: () => Navigator.of(context).pop(report.id),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedId != null && mounted) {
      context.push('/reports/$selectedId', extra: {'action': 'addTransaction'});
    }
  }

  Widget _buildUsersList() {
    if (_users.isEmpty) {
      return const Center(child: Text('No users found'));
    }

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

  Widget _buildUserCard(User user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(user.role.toUserRole()),
          child: Text(
            user.name[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          user.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(user.email),
            const SizedBox(height: 4),
            Chip(
              label: Text(
                UserRole.values
                    .firstWhere(
                      (e) => e.name == user.role.trim().toLowerCase(),
                      orElse: () => UserRole.requester,
                    )
                    .displayName,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              backgroundColor: _getRoleColor(user.role.toUserRole()),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _showEditUserDialog(user);
            } else if (value == 'delete') {
              _showDeleteConfirmation(user);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Edit'),
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
        isThreeLine: true,
      ),
    );
  }

  Widget _buildStudentCard(User user, StudentProfile? profile) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orange,
                  radius: 24,
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'S',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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
                      Text(
                        user.email,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
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
                      _showDeleteConfirmation(user);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit_user',
                      child: Row(
                        children: [
                          Icon(Icons.person_outline, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Edit User Info'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit_profile',
                      child: Row(
                        children: [
                          Icon(Icons.school_outlined, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Edit Student Profile'),
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
            if (profile != null) ...[
              const Divider(height: 24),
              // Student details grid
              Row(
                children: [
                  Expanded(child: _buildInfoItem(Icons.badge, 'Student #', profile.studentNumber)),
                  Expanded(child: _buildInfoItem(Icons.phone, 'Phone', profile.phoneNumber)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildInfoItem(Icons.book, 'Course', profile.course)),
                  Expanded(child: _buildInfoItem(Icons.school_outlined, 'Year', profile.yearLevel)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildInfoItem(Icons.language, 'Language', profile.language ?? 'Not set')),
                  Expanded(child: _buildInfoItem(Icons.work_outline, 'Role', profile.role ?? 'Not set')),
                ],
              ),
              const SizedBox(height: 12),
              // Rate display
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.attach_money, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Text(
                          '${AppConstants.currencySymbol}${profile.hourlyRate.toStringAsFixed(2)}/hr',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                    Chip(
                      label: const Text('Student Worker', style: TextStyle(color: Colors.white, fontSize: 11)),
                      backgroundColor: Colors.orange,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ] else ...[
              const Divider(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[600]),
                    const SizedBox(width: 12),
                    const Text('Student has not completed onboarding yet.'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
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

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.purple;
      case UserRole.manager:
        return Colors.blue;
      case UserRole.finance:
        return Colors.green;
      case UserRole.requester:
        return Colors.orange;
      case UserRole.studentWorker:
        return Colors.deepOrange;
    }
  }

  Future<void> _showAddUserDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final departmentController = TextEditingController();
    UserRole selectedRole = UserRole.requester;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Add User',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: Form(
                  key: formKey,
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
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
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
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
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
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
                        controller: departmentController,
                        decoration: const InputDecoration(
                          labelText: 'Department',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a department';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<UserRole>(
                        value: selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(),
                        ),
                        items: UserRole.values.map((role) {
                          return DropdownMenuItem(
                            value: role,
                            child: Text(role.displayName),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) selectedRole = value;
                        },
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () async {
                              if (formKey.currentState!.validate()) {
                                final authProvider = context
                                    .read<AuthProvider>();
                                await authProvider.registerUser(
                                  email: emailController.text,
                                  password: passwordController.text,
                                  name: nameController.text,
                                  role: selectedRole,
                                  department: departmentController.text,
                                );
                                await _loadUsers();

                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('User added successfully'),
                                    ),
                                  );
                                }
                              }
                            },
                            child: const Text('Add User'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditUserDialog(User user) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: user.name);
    final emailController = TextEditingController(text: user.email);
    final departmentController = TextEditingController(text: user.department);
    UserRole selectedRole = user.role.toUserRole();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Edit User',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: Form(
                  key: formKey,
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
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
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
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
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a department';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<UserRole>(
                        value: selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(),
                        ),
                        items: UserRole.values.map((role) {
                          return DropdownMenuItem(
                            value: role,
                            child: Text(role.displayName),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) selectedRole = value;
                        },
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () async {
                              if (formKey.currentState!.validate()) {
                                final updated = user.copyWith(
                                  name: nameController.text,
                                  email: emailController.text,
                                  department: departmentController.text,
                                  role: selectedRole.name,
                                  updatedAt: DateTime.now(),
                                );

                                await FirestoreService().updateUser(updated);
                                await _loadUsers();

                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'User updated successfully',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            child: const Text('Save Changes'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmation(User user) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.red, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Delete User',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              'Are you sure you want to delete ${user.name}?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    await FirestoreService().deleteUser(user.id);
                    await _loadUsers();

                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('User deleted successfully'),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Delete User'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
          final rateRole = selectedRole ?? 'Other';
          double calculatedRate = StudentRateConfig.getRate(rateRole, selectedGrade);

          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange,
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
                  children: [
                    TextFormField(
                      controller: studentNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Student Number *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: courseController,
                      decoration: const InputDecoration(
                        labelText: 'Course *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.book),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedYearLevel,
                      decoration: const InputDecoration(
                        labelText: 'Year Level',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                      items: yearLevels.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                      onChanged: (v) => setState(() => selectedYearLevel = v!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedLanguage,
                      decoration: const InputDecoration(
                        labelText: 'Language',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.language),
                      ),
                      items: languages.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                      onChanged: (v) => setState(() => selectedLanguage = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.work_outline),
                      ),
                      items: roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: (v) => setState(() => selectedRole = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedGrade,
                      decoration: const InputDecoration(
                        labelText: 'Grade',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.grade),
                      ),
                      items: StudentRateConfig.grades.map((g) {
                        final rate = StudentRateConfig.getRate(rateRole, g);
                        return DropdownMenuItem(
                          value: g,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Grade $g'),
                              Text('THB ${rate.toStringAsFixed(0)}/hr', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => selectedGrade = v),
                    ),
                    if (selectedGrade != null && calculatedRate > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calculate, color: Colors.green.shade700),
                            const SizedBox(width: 12),
                            Text(
                              'Rate: THB ${calculatedRate.toStringAsFixed(2)}',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Save', style: TextStyle(color: Colors.white)),
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
        await profileRef.update({
          'studentNumber': studentNumber,
          'phoneNumber': phoneNumber,
          'course': course,
          'yearLevel': yearLevel,
          'language': language,
          'role': role,
          'grade': grade,
          'hourlyRate': hourlyRate,
        });
      } else {
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

      // Update hourly rate in all draft/submitted monthly reports for this student
      if (hourlyRate > 0) {
        await _updateStudentReportsRate(userId, hourlyRate);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student profile updated'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateStudentReportsRate(String userId, double newRate) async {
    try {
      // Get ALL reports for this student (regardless of status)
      final reportsQuery = await FirebaseFirestore.instance
          .collection('student_monthly_reports')
          .where('studentId', isEqualTo: userId)
          .get();

      // Update each report with new rate and recalculate total
      final batch = FirebaseFirestore.instance.batch();

      for (final doc in reportsQuery.docs) {
        final data = doc.data();
        final totalHours = (data['totalHours'] ?? 0.0).toDouble();
        final newTotalAmount = totalHours * newRate;

        batch.update(doc.reference, {
          'hourlyRate': newRate,
          'totalAmount': newTotalAmount,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Also update ALL individual timesheets (regardless of status)
      final timesheetsQuery = await FirebaseFirestore.instance
          .collection('student_timesheets')
          .where('studentId', isEqualTo: userId)
          .get();

      for (final doc in timesheetsQuery.docs) {
        final data = doc.data();
        final totalHours = (data['totalHours'] ?? 0.0).toDouble();
        final newTotalAmount = totalHours * newRate;

        batch.update(doc.reference, {
          'hourlyRate': newRate,
          'totalAmount': newTotalAmount,
        });
      }

      await batch.commit();
    } catch (e) {
      print('Error updating student reports rate: $e');
    }
  }
}
