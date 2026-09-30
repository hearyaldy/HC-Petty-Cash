import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../models/kanban_board.dart';
import '../../models/user.dart' as app_user;
import '../../providers/auth_provider.dart';
import '../../providers/kanban_board_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/kanban_label_colors.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/kanban_board_members_dialog.dart';
import '../../widgets/kanban_card_detail_sheet.dart';

class _DraggedCard {
  final KanbanCard card;
  final String fromListId;
  const _DraggedCard(this.card, this.fromListId);
}

/// Plain [Draggable] claims the gesture on the very first pointer move,
/// which can beat a child [InkWell]'s tap recognizer and make cards stop
/// opening on click — a real regression we hit. [LongPressDraggable]
/// waits before claiming the gesture, so a quick click still resolves as
/// a tap; we just shorten that wait on mouse/desktop/web so drag still
/// feels immediate there, while touch keeps the full delay so a drag
/// doesn't hijack list scrolling.
Duration get _dragStartDelay =>
    (kIsWeb ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux)
        ? const Duration(milliseconds: 120)
        : kLongPressTimeout;

Widget _dragHandle<T extends Object>({
  required T data,
  required Widget feedback,
  required Widget child,
  Widget? childWhenDragging,
}) {
  return LongPressDraggable<T>(
    data: data,
    delay: _dragStartDelay,
    feedback: feedback,
    childWhenDragging: childWhenDragging,
    child: child,
  );
}

String _initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

/// A single board: horizontal columns (lists) of draggable cards.
/// Supports dragging cards within/between lists and reordering the lists
/// themselves, gated per-user by [_BoardDetailScreenState]'s permission
/// helpers (mirrors the Kanban spec's role table, §2).
class BoardDetailScreen extends StatefulWidget {
  final String boardId;

  const BoardDetailScreen({super.key, required this.boardId});

  @override
  State<BoardDetailScreen> createState() => _BoardDetailScreenState();
}

class _BoardDetailScreenState extends State<BoardDetailScreen> {
  late final KanbanBoardProvider _provider;
  final _firestoreService = FirestoreService();
  List<app_user.User> _allUsers = [];

  Map<String, app_user.User> get _usersById => {for (final u in _allUsers) u.id: u};

  @override
  void initState() {
    super.initState();
    _provider = context.read<KanbanBoardProvider>();
    _provider.openBoard(widget.boardId);
    _firestoreService.getAllUsers().then((users) {
      if (mounted) setState(() => _allUsers = users);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _provider.closeBoard();
    super.dispose();
  }

  // ---- Permissions (Kanban spec §2, adjusted: manager & finance are
  // separate UserRole values in this app, not one combined role) ----------

  app_user.User? get _currentUser => context.read<AuthProvider>().currentUser;

  bool get _isPrivileged {
    final role = _currentUser?.roleEnum;
    return role == UserRole.manager || role == UserRole.finance || role == UserRole.admin;
  }

  bool _isOwner(KanbanBoard board) => _currentUser != null && board.ownerId == _currentUser!.id;

  bool _canManageBoard(KanbanBoard board) => _isOwner(board) || _isPrivileged;

  bool _canManageLists(KanbanBoard board) =>
      _currentUser?.roleEnum != UserRole.studentWorker; // Requester and above

  bool _canEditCard(KanbanBoard board, KanbanCard card) {
    if (_canManageBoard(board)) return true;
    final uid = _currentUser?.id;
    return uid != null && card.assigneeIds.contains(uid);
  }

  Future<void> _addList() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New List'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'List title')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (title != null && title.isNotEmpty) {
      await _provider.createList(widget.boardId, title);
    }
  }

  Future<void> _addCard(String listId, String title) async {
    if (title.trim().isEmpty || _currentUser == null) return;
    await _provider.createCard(boardId: widget.boardId, listId: listId, title: title.trim(), createdBy: _currentUser!.id);
  }

  Future<void> _renameList(KanbanList list) async {
    final controller = TextEditingController(text: list.title);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename List'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (title != null && title.isNotEmpty) {
      await _provider.renameList(widget.boardId, list.id, title);
    }
  }

  Future<void> _deleteList(KanbanList list) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete list?'),
        content: Text('"${list.title}" and all its cards will be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _provider.deleteList(widget.boardId, list.id);
    }
  }

  void _openCard(KanbanBoard board, KanbanCard card, String listId) {
    final canEdit = _canEditCard(board, card);
    final boardMembers = _allUsers.where((u) => board.memberIds.contains(u.id)).toList();
    showKanbanCardDetailSheet(
      context,
      card: card,
      boardMembers: boardMembers,
      canEdit: canEdit,
      onSave: (updated) => _provider.updateCard(widget.boardId, listId, updated),
      onDelete: () => _provider.deleteCard(widget.boardId, listId, card.id),
    );
  }

  Future<void> _showMembers(KanbanBoard board) {
    return showKanbanBoardMembersDialog(
      context,
      memberIds: board.memberIds,
      ownerId: board.ownerId,
      canManage: _canManageBoard(board),
      onAdd: (userId) => _provider.addMember(board.id, userId),
      onRemove: (userId) => _provider.removeMember(board.id, userId),
    );
  }

  Future<void> _archiveBoard(KanbanBoard board) async {
    final ok = await _provider.archiveBoard(board.id);
    if (ok && mounted) context.pop();
  }

  Future<void> _confirmDeleteBoard(KanbanBoard board) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete board?'),
        content: Text('"${board.title}" and everything on it will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final ok = await _provider.deleteBoard(board.id);
      if (ok && mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthProvider>();
    final provider = context.watch<KanbanBoardProvider>();
    final board = provider.board;

    // boardError also covers failures *after* the board has loaded (a
    // rejected card/list write, for example) — those don't fit the
    // loading/empty state in _buildBody, so surface them as a snackbar
    // instead of letting them fail silently.
    if (provider.boardError != null && board != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final message = provider.boardError;
        provider.clearBoardError();
        if (message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
          );
        }
      });
    }

    return Scaffold(
      appBar: _buildTopBar(context, provider, board),
      drawer: const AppDrawer(),
      body: SafeArea(child: _buildBody(context, provider, board)),
    );
  }

  PreferredSizeWidget _buildTopBar(BuildContext context, KanbanBoardProvider provider, KanbanBoard? board) {
    final cs = Theme.of(context).colorScheme;
    final maxWidth = ResponsiveHelper.getMaxContentWidth(context);
    final hPad = ResponsiveHelper.getScreenPadding(context).horizontal / 2;
    final listCount = provider.lists.length;

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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              board?.title ?? 'Board',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              board == null ? 'Loading…' : '$listCount list${listCount == 1 ? '' : 's'} · ${board.memberIds.length} member${board.memberIds.length == 1 ? '' : 's'}',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      if (board != null) ...[
                        IconButton(
                          icon: const Icon(Icons.people_outline, color: Colors.white, size: 20),
                          tooltip: 'Members',
                          onPressed: () => _showMembers(board),
                        ),
                        if (_canManageBoard(board))
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.white),
                            onSelected: (value) {
                              if (value == 'archive') {
                                _archiveBoard(board);
                              }
                              if (value == 'delete') {
                                _confirmDeleteBoard(board);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'archive', child: Text('Archive board')),
                              PopupMenuItem(value: 'delete', child: Text('Delete board')),
                            ],
                          ),
                      ],
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

  Widget _buildBody(BuildContext context, KanbanBoardProvider provider, KanbanBoard? board) {
    final cs = Theme.of(context).colorScheme;

    if (provider.isLoadingBoard || board == null) {
      if (provider.boardError != null) {
        return Center(child: Text(provider.boardError!, style: const TextStyle(color: Colors.red)));
      }
      return const Center(child: CircularProgressIndicator());
    }

    final lists = provider.lists;
    final canManageLists = _canManageLists(board);
    final screenPadding = ResponsiveHelper.getScreenPadding(context);

    return Container(
      width: double.infinity,
      height: double.infinity,
      // Trello-style tinted board canvas, distinct from the app's plain
      // background so the working surface reads as its own space.
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary.withValues(alpha: 0.10), cs.primary.withValues(alpha: 0.04)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: screenPadding.left),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final list in lists) ...[
                _ListColumnDropZone(
                  onAccept: (dragged) => _provider.reorderList(
                    board.id,
                    dragged.id,
                    prevListId: lists.indexOf(list) > 0 ? lists[lists.indexOf(list) - 1].id : null,
                    nextListId: list.id,
                  ),
                  canManageLists: canManageLists,
                ),
                _ListColumn(
                  key: ValueKey(list.id),
                  board: board,
                  list: list,
                  cards: provider.cardsFor(list.id),
                  usersById: _usersById,
                  canManageLists: canManageLists,
                  canEditCard: (card) => _canEditCard(board, card),
                  onOpenCard: (card) => _openCard(board, card, list.id),
                  onAddCard: (title) => _addCard(list.id, title),
                  onRename: () => _renameList(list),
                  onDelete: () => _deleteList(list),
                  onMoveCard: (dragged, prevCardId, nextCardId) => _provider.moveCard(
                    boardId: board.id,
                    fromListId: dragged.fromListId,
                    toListId: list.id,
                    card: dragged.card,
                    prevCardId: prevCardId,
                    nextCardId: nextCardId,
                  ),
                ),
              ],
              if (lists.isNotEmpty)
                _ListColumnDropZone(
                  onAccept: (dragged) => _provider.reorderList(
                    board.id,
                    dragged.id,
                    prevListId: lists.last.id,
                    nextListId: null,
                  ),
                  canManageLists: canManageLists,
                ),
              if (canManageLists)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: SizedBox(
                    width: 272,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _addList,
                      icon: const Icon(Icons.add),
                      label: const Text('Add another list'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thin vertical drop zone between columns for reordering lists.
/// Invisible when list reordering isn't allowed for this user.
class _ListColumnDropZone extends StatelessWidget {
  final void Function(KanbanList dragged) onAccept;
  final bool canManageLists;

  const _ListColumnDropZone({required this.onAccept, required this.canManageLists});

  @override
  Widget build(BuildContext context) {
    if (!canManageLists) return const SizedBox(width: 4);
    return DragTarget<KanbanList>(
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidateData, rejectedData) {
        return Container(
          width: candidateData.isNotEmpty ? 12 : 8,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: candidateData.isNotEmpty ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3) : null,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      },
    );
  }
}

class _ListColumn extends StatefulWidget {
  final KanbanBoard board;
  final KanbanList list;
  final List<KanbanCard> cards;
  final Map<String, app_user.User> usersById;
  final bool canManageLists;
  final bool Function(KanbanCard card) canEditCard;
  final void Function(KanbanCard card) onOpenCard;
  final void Function(String title) onAddCard;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final void Function(_DraggedCard dragged, String? prevCardId, String? nextCardId) onMoveCard;

  const _ListColumn({
    super.key,
    required this.board,
    required this.list,
    required this.cards,
    required this.usersById,
    required this.canManageLists,
    required this.canEditCard,
    required this.onOpenCard,
    required this.onAddCard,
    required this.onRename,
    required this.onDelete,
    required this.onMoveCard,
  });

  @override
  State<_ListColumn> createState() => _ListColumnState();
}

class _ListColumnState extends State<_ListColumn> {
  bool _composing = false;
  final _composerController = TextEditingController();
  final _composerFocus = FocusNode();
  final _cardsScrollController = ScrollController();

  @override
  void didUpdateWidget(covariant _ListColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A newly-added card lands at the end of the list, which can be
    // scrolled out of view — auto-scroll so the save is visibly obvious
    // rather than looking like it silently did nothing.
    if (widget.cards.length > oldWidget.cards.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_cardsScrollController.hasClients) return;
        _cardsScrollController.animateTo(
          _cardsScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _composerController.dispose();
    _composerFocus.dispose();
    _cardsScrollController.dispose();
    super.dispose();
  }

  void _startComposing() {
    setState(() => _composing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _composerFocus.requestFocus());
  }

  void _submitComposer() {
    final title = _composerController.text.trim();
    if (title.isNotEmpty) {
      widget.onAddCard(title);
      _composerController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) => _composerFocus.requestFocus());
    } else {
      setState(() => _composing = false);
    }
  }

  void _cancelComposing() {
    _composerController.clear();
    setState(() => _composing = false);
  }

  Widget _dragFeedback(Widget child, {double width = 260}) => Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(width: width, child: child),
      );

  Widget _buildCardTile(BuildContext context, KanbanCard card) {
    final tile = _CardTile(card: card, usersById: widget.usersById, onTap: () => widget.onOpenCard(card));
    if (!widget.canEditCard(card)) return tile;

    return _dragHandle<_DraggedCard>(
      data: _DraggedCard(card, widget.list.id),
      feedback: _dragFeedback(Padding(padding: const EdgeInsets.all(8), child: tile)),
      // A faded copy of the card's own text/labels read as the info had
      // vanished rather than "this card moved" — show an empty ghost
      // slot instead (same footprint, via the invisible tile beneath it,
      // so the list doesn't jump) while the real content follows the cursor.
      childWhenDragging: Stack(
        children: [
          Opacity(opacity: 0, child: tile),
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.4), width: 1.5),
              ),
            ),
          ),
        ],
      ),
      child: tile,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cards = widget.cards;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(widget.list.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), overflow: TextOverflow.ellipsis),
          ),
          if (cards.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              margin: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(20)),
              child: Text('${cards.length}', style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          if (widget.canManageLists)
            PopupMenuButton<String>(
              iconSize: 18,
              onSelected: (value) {
                if (value == 'rename') widget.onRename();
                if (value == 'delete') widget.onDelete();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(value: 'delete', child: Text('Delete list')),
              ],
            ),
        ],
      ),
    );

    return Container(
      width: 272,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          widget.canManageLists
              ? _dragHandle<KanbanList>(data: widget.list, feedback: _dragFeedback(header, width: 272), child: header)
              : header,
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 560),
              child: ListView.builder(
                controller: _cardsScrollController,
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: cards.length + 1,
                itemBuilder: (context, index) {
                  final prevCardId = index > 0 ? cards[index - 1].id : null;
                  final nextCardId = index < cards.length ? cards[index].id : null;

                  return DragTarget<_DraggedCard>(
                    onWillAcceptWithDetails: (details) => widget.canEditCard(details.data.card),
                    onAcceptWithDetails: (details) => widget.onMoveCard(details.data, prevCardId, nextCardId),
                    builder: (context, candidateData, rejectedData) {
                      return Column(
                        children: [
                          if (candidateData.isNotEmpty)
                            Container(
                              height: 4,
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(2)),
                            ),
                          if (index < cards.length) _buildCardTile(context, cards[index]),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: _composing
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _composerController,
                        focusNode: _composerFocus,
                        autofocus: true,
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: 'Enter a title for this card…',
                          isDense: true,
                          filled: true,
                          fillColor: cs.surface,
                          contentPadding: const EdgeInsets.all(10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                        onSubmitted: (_) => _submitComposer(),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          FilledButton(onPressed: _submitComposer, child: const Text('Add card')),
                          IconButton(icon: const Icon(Icons.close), onPressed: _cancelComposing),
                        ],
                      ),
                    ],
                  )
                : InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _startComposing,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                      child: Row(
                        children: [
                          Icon(Icons.add, size: 18, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text('Add a card', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  final KanbanCard card;
  final Map<String, app_user.User> usersById;
  final VoidCallback onTap;

  const _CardTile({required this.card, required this.usersById, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isOverdue = card.dueDate != null && card.dueDate!.isBefore(now);
    final assignees = card.assigneeIds.map((id) => usersById[id]).whereType<app_user.User>().toList();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 1,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (card.labels.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: card.labels
                        .map((l) => Container(
                              width: 32,
                              height: 8,
                              decoration: BoxDecoration(color: kanbanLabelColor(l), borderRadius: BorderRadius.circular(4)),
                            ))
                        .toList(),
                  ),
                ),
              Text(card.title, style: const TextStyle(fontSize: 14)),
              if (card.checklist.isNotEmpty || card.dueDate != null || assignees.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (card.dueDate != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: isOverdue ? Colors.red.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.schedule, size: 12, color: isOverdue ? Colors.red.shade700 : Colors.grey.shade700),
                              const SizedBox(width: 3),
                              Text(
                                '${card.dueDate!.month}/${card.dueDate!.day}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isOverdue ? Colors.red.shade700 : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (card.checklist.isNotEmpty) ...[
                        Icon(Icons.checklist, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 2),
                        Text(
                          '${card.checklist.where((c) => c.done).length}/${card.checklist.length}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                      const Spacer(),
                      if (assignees.isNotEmpty) _AssigneeStack(users: assignees),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssigneeStack extends StatelessWidget {
  final List<app_user.User> users;
  static const int _maxShown = 3;

  const _AssigneeStack({required this.users});

  @override
  Widget build(BuildContext context) {
    final shown = users.take(_maxShown).toList();
    final overflow = users.length - shown.length;

    return SizedBox(
      height: 22,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              right: i * 14,
              child: _avatar(context, _initialsOf(shown[i].name)),
            ),
          if (overflow > 0)
            Positioned(
              right: shown.length * 14,
              child: _avatar(context, '+$overflow'),
            ),
        ],
      ),
    );
  }

  Widget _avatar(BuildContext context, String text) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.primary,
        border: Border.all(color: Theme.of(context).colorScheme.surface, width: 1.5),
      ),
      child: Center(
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
