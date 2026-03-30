import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/responsive_helper.dart';

class MeetingMembersScreen extends StatefulWidget {
  const MeetingMembersScreen({super.key});

  @override
  State<MeetingMembersScreen> createState() => _MeetingMembersScreenState();
}

class _MeetingMembersScreenState extends State<MeetingMembersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveContainer(
            padding: ResponsiveHelper.getScreenPadding(context).copyWith(
              top: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildTabBar(),
                const SizedBox(height: 12),
                _buildTabContent(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade600, Colors.indigo.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => context.pop(),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => context.go('/admin-hub'),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.home_outlined, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.people_alt, size: 36, color: Colors.white),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Committee Members',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Manage ADCOM & Board member lists',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
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

  Widget _buildTabBar() {
    return Container(
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
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.indigo.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.indigo.shade200),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.indigo,
        unselectedLabelColor: Colors.grey[600],
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        tabs: const [
          Tab(text: 'HC ADCOM'),
          Tab(text: 'HC Board'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) {
            if (_tabController.index == 0) {
              return _MemberListSection(
                type: 'adcom',
                color: Colors.blue,
                label: 'HC ADCOM Member',
              );
            } else {
              return _MemberListSection(
                type: 'board',
                color: Colors.purple,
                label: 'HC Board Member',
              );
            }
          },
        ),
      ],
    );
  }
}

class _MemberListSection extends StatelessWidget {
  final String type;
  final Color color;
  final String label;

  const _MemberListSection({
    required this.type,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('meeting_committee_members')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
          );
        }

        final docs = (snapshot.data?.docs ?? [])
            .where((d) => (d.data() as Map<String, dynamic>)['type'] == type)
            .toList()
          ..sort((a, b) {
            final aOrder = ((a.data() as Map<String, dynamic>)['order'] as int?) ?? 0;
            final bOrder = ((b.data() as Map<String, dynamic>)['order'] as int?) ?? 0;
            return aOrder.compareTo(bOrder);
          });

        return Column(
          children: [
            // Add button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showAddEditDialog(context, null, type, docs.length),
                icon: Icon(Icons.person_add, color: color),
                label: Text('Add $label', style: TextStyle(color: color)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: color),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (docs.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        'No $label added yet',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
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
                child: Column(
                  children: docs.asMap().entries.map((entry) {
                    final index = entry.key;
                    final doc = entry.value;
                    final data = doc.data() as Map<String, dynamic>;
                    final isLast = index == docs.length - 1;
                    return _buildMemberTile(
                      context,
                      doc.id,
                      data,
                      isLast,
                      color,
                      type,
                      docs.length,
                    );
                  }).toList(),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMemberTile(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
    bool isLast,
    Color color,
    String type,
    int totalCount,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Text(
            (data['name'] as String? ?? '?')[0].toUpperCase(),
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          data['name'] as String? ?? '',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          [
            if ((data['role'] as String?)?.isNotEmpty == true) data['role'],
            if ((data['organization'] as String?)?.isNotEmpty == true)
              data['organization'],
          ].join(' · '),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit_outlined, size: 18, color: color),
              tooltip: 'Edit',
              onPressed: () => _showAddEditDialog(context, MapEntry(docId, data), type, totalCount),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(context, docId, data['name'] ?? ''),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEditDialog(
    BuildContext context,
    MapEntry<String, Map<String, dynamic>>? existing,
    String type,
    int currentCount,
  ) {
    showDialog(
      context: context,
      builder: (_) => _AddEditMemberDialog(
        existing: existing,
        type: type,
        nextOrder: existing == null ? currentCount : (existing.value['order'] as int? ?? 0),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String docId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Remove "$name" from the list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance
                  .collection('meeting_committee_members')
                  .doc(docId)
                  .delete();
            },
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _AddEditMemberDialog extends StatefulWidget {
  final MapEntry<String, Map<String, dynamic>>? existing;
  final String type;
  final int nextOrder;

  const _AddEditMemberDialog({
    required this.existing,
    required this.type,
    required this.nextOrder,
  });

  @override
  State<_AddEditMemberDialog> createState() => _AddEditMemberDialogState();
}

class _AddEditMemberDialogState extends State<_AddEditMemberDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _roleController;
  late final TextEditingController _orgController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.existing?.value ?? {};
    _nameController = TextEditingController(text: data['name'] as String? ?? '');
    _roleController = TextEditingController(text: data['role'] as String? ?? '');
    _orgController = TextEditingController(text: data['organization'] as String? ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _orgController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final payload = {
        'name': name,
        'role': _roleController.text.trim(),
        'organization': _orgController.text.trim(),
        'type': widget.type,
        'order': widget.nextOrder,
      };
      if (widget.existing != null) {
        await FirebaseFirestore.instance
            .collection('meeting_committee_members')
            .doc(widget.existing!.key)
            .update(payload);
      } else {
        await FirebaseFirestore.instance
            .collection('meeting_committee_members')
            .add(payload);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final color = widget.type == 'board' ? Colors.purple : Colors.blue;

    return AlertDialog(
      title: Text(
        isEdit ? 'Edit Member' : 'Add Member',
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: !isEdit,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _roleController,
              decoration: const InputDecoration(
                labelText: 'Role / Position',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
                hintText: 'e.g. Chair, Secretary, Treasurer',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _orgController,
              decoration: const InputDecoration(
                labelText: 'Organization',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
                hintText: 'e.g. HC, SEUM, MAUM',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: color),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  isEdit ? 'Save' : 'Add',
                  style: const TextStyle(color: Colors.white),
                ),
        ),
      ],
    );
  }
}
