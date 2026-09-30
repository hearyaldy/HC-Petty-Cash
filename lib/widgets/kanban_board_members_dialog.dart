import 'package:flutter/material.dart';

import '../models/user.dart' as app_user;
import '../services/firestore_service.dart';

/// Manage a board's members: remove existing ones, add from the org's
/// full user directory. [canManage] gates whether add/remove controls
/// show at all — read-only members just see the list.
Future<void> showKanbanBoardMembersDialog(
  BuildContext context, {
  required List<String> memberIds,
  required String ownerId,
  required bool canManage,
  required Future<void> Function(String userId) onAdd,
  required Future<void> Function(String userId) onRemove,
}) {
  return showDialog(
    context: context,
    builder: (context) => _MembersDialog(
      memberIds: memberIds,
      ownerId: ownerId,
      canManage: canManage,
      onAdd: onAdd,
      onRemove: onRemove,
    ),
  );
}

class _MembersDialog extends StatefulWidget {
  final List<String> memberIds;
  final String ownerId;
  final bool canManage;
  final Future<void> Function(String userId) onAdd;
  final Future<void> Function(String userId) onRemove;

  const _MembersDialog({
    required this.memberIds,
    required this.ownerId,
    required this.canManage,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  State<_MembersDialog> createState() => _MembersDialogState();
}

class _MembersDialogState extends State<_MembersDialog> {
  final _firestoreService = FirestoreService();
  List<app_user.User> _allUsers = [];
  bool _isLoading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await _firestoreService.getAllUsers();
      if (mounted) setState(() { _allUsers = users; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = _allUsers.where((u) => widget.memberIds.contains(u.id)).toList();
    final nonMembers = _allUsers
        .where((u) => !widget.memberIds.contains(u.id))
        .where((u) => u.name.toLowerCase().contains(_search.toLowerCase()) ||
            u.email.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Board Members', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: members.map((u) {
                          final isOwner = u.id == widget.ownerId;
                          return ListTile(
                            leading: CircleAvatar(child: Text(_initials(u.name))),
                            title: Text(u.name),
                            subtitle: Text(isOwner ? 'Owner' : u.email),
                            trailing: (widget.canManage && !isOwner)
                                ? IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    onPressed: () async {
                                      await widget.onRemove(u.id);
                                    },
                                  )
                                : null,
                          );
                        }).toList(),
                      ),
                    ),
                    if (widget.canManage) ...[
                      const Divider(),
                      TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search staff to add…',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _search = v),
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          children: nonMembers.take(30).map((u) {
                            return ListTile(
                              leading: CircleAvatar(child: Text(_initials(u.name))),
                              title: Text(u.name),
                              subtitle: Text(u.email),
                              trailing: IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () async {
                                  await widget.onAdd(u.id);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}
