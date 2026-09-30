import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/kanban_board.dart';
import '../services/kanban_board_service.dart';

/// Holds the Boards Home list plus the currently open board's lists and
/// cards, and coordinates all writes (create/reorder/move) through
/// [KanbanBoardService]. Cards are a subcollection per list, so this
/// provider fans out one cards subscription per visible list and keeps
/// them in sync as lists are added/removed.
class KanbanBoardProvider extends ChangeNotifier {
  KanbanBoardProvider({KanbanBoardService? service}) : _service = service ?? KanbanBoardService();

  final KanbanBoardService _service;

  // ---- Boards Home ---------------------------------------------------------

  List<KanbanBoard> _myBoards = [];
  bool _isLoadingBoards = false;
  String? _boardsError;
  StreamSubscription<List<KanbanBoard>>? _myBoardsSub;

  List<KanbanBoard> get myBoards => _myBoards;
  bool get isLoadingBoards => _isLoadingBoards;
  String? get boardsError => _boardsError;

  /// Call after showing [boardsError] to the user, so the same message
  /// doesn't reappear on the next unrelated rebuild.
  void clearBoardsError() {
    if (_boardsError == null) return;
    _boardsError = null;
    notifyListeners();
  }

  void loadBoardsForUser(String userId) {
    _isLoadingBoards = true;
    notifyListeners();
    _myBoardsSub?.cancel();
    _myBoardsSub = _service.watchBoardsForUser(userId).listen(
      (boards) {
        _myBoards = boards;
        _isLoadingBoards = false;
        _boardsError = null;
        notifyListeners();
      },
      onError: (e) {
        _boardsError = 'Could not load boards: $e';
        _isLoadingBoards = false;
        notifyListeners();
      },
    );
  }

  Future<String?> createBoard({
    required String title,
    required String description,
    required String ownerId,
  }) async {
    try {
      return await _service.createBoard(KanbanBoard(
        id: '',
        title: title,
        description: description,
        ownerId: ownerId,
        memberIds: [ownerId],
        createdAt: DateTime.now(),
      ));
    } catch (e) {
      _boardsError = 'Could not create board: $e';
      notifyListeners();
      return null;
    }
  }

  Future<bool> archiveBoard(String boardId) async {
    try {
      await _service.archiveBoard(boardId);
      return true;
    } catch (e) {
      _boardsError = 'Could not archive board: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteBoard(String boardId) async {
    try {
      await _service.deleteBoard(boardId);
      return true;
    } catch (e) {
      _boardsError = 'Could not delete board: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> addMember(String boardId, String userId) async {
    try {
      await _service.addMember(boardId, userId);
      return true;
    } catch (e) {
      _boardsError = 'Could not add member: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeMember(String boardId, String userId) async {
    try {
      await _service.removeMember(boardId, userId);
      return true;
    } catch (e) {
      _boardsError = 'Could not remove member: $e';
      notifyListeners();
      return false;
    }
  }

  // ---- Open board ------------------------------------------------------------

  String? _openBoardId;
  KanbanBoard? _board;
  List<KanbanList> _lists = [];
  final Map<String, List<KanbanCard>> _cardsByListId = {};
  bool _isLoadingBoard = false;
  String? _boardError;

  StreamSubscription<KanbanBoard?>? _boardSub;
  StreamSubscription<List<KanbanList>>? _listsSub;
  final Map<String, StreamSubscription<List<KanbanCard>>> _cardSubs = {};

  KanbanBoard? get board => _board;
  List<KanbanList> get lists => _lists;
  bool get isLoadingBoard => _isLoadingBoard;
  String? get boardError => _boardError;

  /// Call after showing [boardError] to the user, so the same message
  /// doesn't reappear on the next unrelated rebuild.
  void clearBoardError() {
    if (_boardError == null) return;
    _boardError = null;
    notifyListeners();
  }

  List<KanbanCard> cardsFor(String listId) => _cardsByListId[listId] ?? const [];

  void openBoard(String boardId) {
    if (_openBoardId == boardId) return;
    _closeBoard();
    _openBoardId = boardId;
    _isLoadingBoard = true;
    notifyListeners();

    _boardSub = _service.watchBoard(boardId).listen((board) {
      _board = board;
      notifyListeners();
    });

    _listsSub = _service.watchLists(boardId).listen(
      (lists) {
        _lists = lists;
        _isLoadingBoard = false;
        _boardError = null;
        _syncCardSubscriptions(boardId, lists);
        notifyListeners();
      },
      onError: (e) {
        _boardError = 'Could not load board: $e';
        _isLoadingBoard = false;
        notifyListeners();
      },
    );
  }

  void _syncCardSubscriptions(String boardId, List<KanbanList> lists) {
    final currentListIds = lists.map((l) => l.id).toSet();

    // Drop subscriptions for lists that no longer exist.
    final staleIds = _cardSubs.keys.where((id) => !currentListIds.contains(id)).toList();
    for (final id in staleIds) {
      _cardSubs.remove(id)?.cancel();
      _cardsByListId.remove(id);
    }

    // Subscribe to any newly-added lists.
    for (final list in lists) {
      if (_cardSubs.containsKey(list.id)) continue;
      _cardSubs[list.id] = _service.watchCards(boardId, list.id).listen((cards) {
        _cardsByListId[list.id] = cards;
        notifyListeners();
      });
    }
  }

  void _closeBoard() {
    _boardSub?.cancel();
    _listsSub?.cancel();
    for (final sub in _cardSubs.values) {
      sub.cancel();
    }
    _cardSubs.clear();
    _cardsByListId.clear();
    _board = null;
    _lists = [];
    _openBoardId = null;
  }

  void closeBoard() {
    _closeBoard();
    notifyListeners();
  }

  // ---- List writes -----------------------------------------------------------

  Future<bool> createList(String boardId, String title) async {
    try {
      final order = _lists.isEmpty ? KanbanOrder.first() : KanbanOrder.after(_lists.last.order);
      await _service.createList(boardId, KanbanList(id: '', title: title, order: order, createdAt: DateTime.now()));
      return true;
    } catch (e) {
      _boardError = 'Could not add list: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> renameList(String boardId, String listId, String title) async {
    try {
      await _service.renameList(boardId, listId, title);
      return true;
    } catch (e) {
      _boardError = 'Could not rename list: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteList(String boardId, String listId) async {
    try {
      await _service.deleteList(boardId, listId);
      return true;
    } catch (e) {
      _boardError = 'Could not delete list: $e';
      notifyListeners();
      return false;
    }
  }

  /// Reorders [listId] to sit between [prevListId] and [nextListId]
  /// (either may be null for the start/end of the row).
  Future<bool> reorderList(String boardId, String listId, {String? prevListId, String? nextListId}) async {
    final prevOrder = prevListId == null ? null : _lists.firstWhere((l) => l.id == prevListId).order;
    final nextOrder = nextListId == null ? null : _lists.firstWhere((l) => l.id == nextListId).order;
    try {
      await _service.reorderList(boardId, listId, KanbanOrder.between(prevOrder, nextOrder));
      return true;
    } catch (e) {
      _boardError = 'Could not reorder list: $e';
      notifyListeners();
      return false;
    }
  }

  // ---- Card writes -----------------------------------------------------------

  Future<bool> createCard({
    required String boardId,
    required String listId,
    required String title,
    required String createdBy,
  }) async {
    try {
      final existing = cardsFor(listId);
      final order = existing.isEmpty ? KanbanOrder.first() : KanbanOrder.after(existing.last.order);
      final now = DateTime.now();
      await _service.createCard(
        boardId,
        listId,
        KanbanCard(
          id: '',
          title: title,
          description: '',
          assigneeIds: const [],
          dueDate: null,
          labels: const [],
          order: order,
          checklist: const [],
          attachmentUrls: const [],
          createdBy: createdBy,
          createdAt: now,
          updatedAt: now,
        ),
      );
      return true;
    } catch (e) {
      _boardError = 'Could not add card: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateCard(String boardId, String listId, KanbanCard card) async {
    try {
      await _service.updateCard(boardId, listId, card.copyWith(updatedAt: DateTime.now()));
      return true;
    } catch (e) {
      _boardError = 'Could not save card: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCard(String boardId, String listId, String cardId) async {
    try {
      await _service.deleteCard(boardId, listId, cardId);
      return true;
    } catch (e) {
      _boardError = 'Could not delete card: $e';
      notifyListeners();
      return false;
    }
  }

  /// Reorders/moves [card] to sit between [prevCardId] and [nextCardId]
  /// inside [toListId] — same list for a within-list reorder, a
  /// different list for a cross-list move.
  Future<bool> moveCard({
    required String boardId,
    required String fromListId,
    required String toListId,
    required KanbanCard card,
    String? prevCardId,
    String? nextCardId,
  }) async {
    final targetCards = cardsFor(toListId);
    final prevOrder = prevCardId == null
        ? null
        : targetCards.firstWhere((c) => c.id == prevCardId, orElse: () => card).order;
    final nextOrder = nextCardId == null
        ? null
        : targetCards.firstWhere((c) => c.id == nextCardId, orElse: () => card).order;
    final newOrder = KanbanOrder.between(prevOrder, nextOrder);

    try {
      if (fromListId == toListId) {
        await _service.reorderCard(boardId, toListId, card.id, newOrder);
      } else {
        await _service.moveCardToList(
          boardId: boardId,
          fromListId: fromListId,
          toListId: toListId,
          card: card,
          newOrder: newOrder,
        );
      }
      return true;
    } catch (e) {
      _boardError = 'Could not move card: $e';
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _myBoardsSub?.cancel();
    _closeBoard();
    super.dispose();
  }
}
