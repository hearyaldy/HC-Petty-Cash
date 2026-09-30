import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../models/kanban_board.dart';
import '../../providers/auth_provider.dart';
import '../../providers/kanban_board_provider.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/app_drawer.dart';

class _StatData {
  final String title;
  final String value;
  final IconData icon;
  final List<Color> gradient;

  _StatData({required this.title, required this.value, required this.icon, required this.gradient});
}

/// Boards Home — every board the signed-in user is a member of, styled
/// to match the rest of the app's list screens (cs.primary top bar,
/// gradient header banner, stat cards, filter chips).
class BoardsHomeScreen extends StatefulWidget {
  const BoardsHomeScreen({super.key});

  @override
  State<BoardsHomeScreen> createState() => _BoardsHomeScreenState();
}

enum _BoardsFilter { all, mine, shared }

class _BoardsHomeScreenState extends State<BoardsHomeScreen> {
  _BoardsFilter _filter = _BoardsFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBoards());
  }

  void _loadBoards() {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId != null) {
      context.read<KanbanBoardProvider>().loadBoardsForUser(userId);
    }
  }

  Future<void> _showCreateBoardDialog() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Board'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Board title'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description (optional)'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (created != true || !mounted) return;

    final userId = context.read<AuthProvider>().currentUser!.id;
    final boardId = await context.read<KanbanBoardProvider>().createBoard(
          title: titleController.text.trim(),
          description: descController.text.trim(),
          ownerId: userId,
        );

    if (boardId != null && mounted) {
      context.push('/boards/$boardId');
    }
  }

  List<KanbanBoard> _applyFilter(List<KanbanBoard> boards, String? userId) {
    switch (_filter) {
      case _BoardsFilter.mine:
        return boards.where((b) => b.ownerId == userId).toList();
      case _BoardsFilter.shared:
        return boards.where((b) => b.ownerId != userId).toList();
      case _BoardsFilter.all:
        return boards;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final boardsProvider = context.watch<KanbanBoardProvider>();
    final canCreate = authProvider.currentUser?.roleEnum != UserRole.studentWorker;

    // Only snackbar-surface errors once boards have already loaded once —
    // an initial load failure is shown inline in the body instead.
    if (boardsProvider.boardsError != null && boardsProvider.myBoards.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final message = boardsProvider.boardsError;
        boardsProvider.clearBoardsError();
        if (message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
          );
        }
      });
    }

    return Scaffold(
      appBar: _buildTopBar(context, canCreate),
      drawer: const AppDrawer(),
      body: _buildBody(context, boardsProvider, authProvider),
    );
  }

  PreferredSizeWidget _buildTopBar(BuildContext context, bool canCreate) {
    final cs = Theme.of(context).colorScheme;
    final maxWidth = ResponsiveHelper.getMaxContentWidth(context);
    final hPad = ResponsiveHelper.getScreenPadding(context).horizontal / 2;

    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: BoxDecoration(
          color: cs.primary,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: kToolbarHeight,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: Row(
                    children: [
                      Builder(
                        builder: (ctx) => IconButton(
                          icon: const Icon(Icons.menu, color: Colors.white),
                          tooltip: 'Menu',
                          onPressed: () => Scaffold.of(ctx).openDrawer(),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Center(
                          child: Text('HC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('HC Task Board', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                            Text(
                              'Plan and track work with your team',
                              style: TextStyle(color: Colors.white70, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                        tooltip: 'Refresh',
                        onPressed: _loadBoards,
                      ),
                      if (canCreate)
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 20),
                          tooltip: 'New Board',
                          onPressed: _showCreateBoardDialog,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, KanbanBoardProvider provider, AuthProvider authProvider) {
    final contentPadding = ResponsiveHelper.getScreenPadding(context);
    final maxWidth = ResponsiveHelper.getMaxContentWidth(context);
    final userId = authProvider.currentUser?.id;
    final boards = provider.myBoards;
    final filtered = _applyFilter(boards, userId);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(left: contentPadding.left, right: contentPadding.right, top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderBanner(context, boards, userId),
                    const SizedBox(height: 16),
                    _buildStatCards(context, boards, userId),
                    const SizedBox(height: 24),
                    _buildFilterChips(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            if (provider.isLoadingBoards)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (provider.boardsError != null && boards.isEmpty)
              SliverFillRemaining(child: Center(child: Text(provider.boardsError!, style: const TextStyle(color: Colors.red))))
            else if (filtered.isEmpty)
              SliverFillRemaining(child: _buildEmptyState(context))
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(contentPadding.left, 0, contentPadding.right, 24),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: ResponsiveHelper.getGridCrossAxisCount(context, minItemWidth: 260, maxColumns: 4),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.4,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final board = filtered[index];
                      return _BoardCard(
                        title: board.title,
                        description: board.description,
                        memberCount: board.memberIds.length,
                        isOwner: board.ownerId == userId,
                        onTap: () => context.push('/boards/${board.id}'),
                      );
                    },
                    childCount: filtered.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBanner(BuildContext context, List<KanbanBoard> boards, String? userId) {
    final cs = Theme.of(context).colorScheme;
    final owned = boards.where((b) => b.ownerId == userId).length;
    final shared = boards.length - owned;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary.withValues(alpha: 0.85), cs.primary],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 4)),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 760;
          final stats = [('Total', '${boards.length}'), ('Owned', '$owned'), ('Shared', '$shared')];

          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('HC Task Board', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                'Plan, assign, and track work across the team',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 12),
              ),
            ],
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                const SizedBox(height: 16),
                Wrap(spacing: 12, runSpacing: 12, children: stats.map((s) => _buildBannerStat(s.$1, s.$2, compact: true)).toList()),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: titleBlock),
              const SizedBox(width: 20),
              Row(
                children: [
                  for (var i = 0; i < stats.length; i++) ...[
                    if (i > 0) const SizedBox(width: 20),
                    _buildBannerStat(stats[i].$1, stats[i].$2),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBannerStat(String label, String value, {bool compact = false}) {
    final child = Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(value, style: TextStyle(color: Colors.white, fontSize: compact ? 20 : 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontSize: 10)),
      ],
    );

    if (!compact) return child;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: child,
    );
  }

  Widget _buildStatCards(BuildContext context, List<KanbanBoard> boards, String? userId) {
    final owned = boards.where((b) => b.ownerId == userId).length;
    final shared = boards.length - owned;
    final totalMembers = boards.fold<int>(0, (sum, b) => sum + b.memberIds.length);

    final stats = [
      _StatData(title: 'Total Boards', value: '${boards.length}', icon: Icons.dashboard_customize, gradient: [Colors.blue.shade400, Colors.blue.shade600]),
      _StatData(title: 'Boards I Own', value: '$owned', icon: Icons.star_outline, gradient: [Colors.purple.shade400, Colors.purple.shade600]),
      _StatData(title: 'Shared With Me', value: '$shared', icon: Icons.groups_outlined, gradient: [Colors.orange.shade400, Colors.orange.shade600]),
      _StatData(title: 'Total Memberships', value: '$totalMembers', icon: Icons.people_outline, gradient: [Colors.green.shade400, Colors.green.shade600]),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: ResponsiveHelper.isMobile(context) ? 2 : 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: stat.gradient),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: stat.gradient[0].withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(stat.icon, color: Colors.white, size: 28),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stat.value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text(stat.title, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9))),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChips() {
    final options = [
      (_BoardsFilter.all, 'All'),
      (_BoardsFilter.mine, 'My Boards'),
      (_BoardsFilter.shared, 'Shared With Me'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((o) {
          final isSelected = _filter == o.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(o.$2),
              selected: isSelected,
              onSelected: (_) => setState(() => _filter = o.$1),
              selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
              checkmarkColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final message = switch (_filter) {
      _BoardsFilter.mine => 'You haven\'t created any boards yet.',
      _BoardsFilter.shared => 'No boards have been shared with you yet.',
      _BoardsFilter.all => 'Boards you create or get added to will show up here.',
    };

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.dashboard_customize_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('No boards yet', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _BoardCard extends StatelessWidget {
  final String title;
  final String description;
  final int memberCount;
  final bool isOwner;
  final VoidCallback onTap;

  const _BoardCard({
    required this.title,
    required this.description,
    required this.memberCount,
    required this.isOwner,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: ResponsiveHelper.getCardElevation(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ResponsiveHelper.getBorderRadius(context))),
      child: InkWell(
        borderRadius: BorderRadius.circular(ResponsiveHelper.getBorderRadius(context)),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.dashboard_customize, color: Theme.of(context).colorScheme.primary),
                  const Spacer(),
                  if (isOwner)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Owner',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  description.isEmpty ? 'No description' : description,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                children: [
                  Icon(Icons.people_outline, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text('$memberCount member${memberCount == 1 ? '' : 's'}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
