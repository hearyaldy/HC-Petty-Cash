import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/kanban_board.dart';

/// Firestore access for the Boards module: `boards/{boardId}`, with
/// `lists` and `lists/{listId}/cards` as nested subcollections so
/// security rules and queries stay scoped to a single board.
class KanbanBoardService {
  KanbanBoardService({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String boardsCollection = 'boards';

  CollectionReference<Map<String, dynamic>> get _boards => _db.collection(boardsCollection);

  CollectionReference<Map<String, dynamic>> _lists(String boardId) =>
      _boards.doc(boardId).collection('lists');

  CollectionReference<Map<String, dynamic>> _cards(String boardId, String listId) =>
      _lists(boardId).doc(listId).collection('cards');

  // ---- Boards ------------------------------------------------------------

  Stream<List<KanbanBoard>> watchBoardsForUser(String userId) {
    return _boards
        .where('memberIds', arrayContains: userId)
        .where('archived', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.map(KanbanBoard.fromFirestore).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  Future<KanbanBoard?> getBoard(String boardId) async {
    final doc = await _boards.doc(boardId).get();
    return doc.exists ? KanbanBoard.fromFirestore(doc) : null;
  }

  Stream<KanbanBoard?> watchBoard(String boardId) {
    return _boards.doc(boardId).snapshots().map((doc) => doc.exists ? KanbanBoard.fromFirestore(doc) : null);
  }

  Future<String> createBoard(KanbanBoard board) async {
    final ref = await _boards.add(board.toFirestore());
    return ref.id;
  }

  Future<void> updateBoard(KanbanBoard board) {
    return _boards.doc(board.id).update(board.toFirestore());
  }

  Future<void> archiveBoard(String boardId) {
    return _boards.doc(boardId).update({'archived': true});
  }

  Future<void> addMember(String boardId, String userId) {
    return _boards.doc(boardId).update({
      'memberIds': FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> removeMember(String boardId, String userId) {
    return _boards.doc(boardId).update({
      'memberIds': FieldValue.arrayRemove([userId]),
    });
  }

  /// Deletes a board and every list/card beneath it. Firestore does not
  /// cascade-delete subcollections, so this walks the tree explicitly.
  Future<void> deleteBoard(String boardId) async {
    final listsSnap = await _lists(boardId).get();
    for (final listDoc in listsSnap.docs) {
      final cardsSnap = await _cards(boardId, listDoc.id).get();
      final batch = _db.batch();
      for (final cardDoc in cardsSnap.docs) {
        batch.delete(cardDoc.reference);
      }
      batch.delete(listDoc.reference);
      await batch.commit();
    }
    await _boards.doc(boardId).delete();
  }

  // ---- Lists ---------------------------------------------------------------

  Stream<List<KanbanList>> watchLists(String boardId) {
    return _lists(boardId)
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs.map(KanbanList.fromFirestore).toList());
  }

  Future<String> createList(String boardId, KanbanList list) async {
    final ref = await _lists(boardId).add(list.toFirestore());
    return ref.id;
  }

  Future<void> renameList(String boardId, String listId, String title) {
    return _lists(boardId).doc(listId).update({'title': title});
  }

  Future<void> reorderList(String boardId, String listId, double order) {
    return _lists(boardId).doc(listId).update({'order': order});
  }

  Future<void> deleteList(String boardId, String listId) async {
    final cardsSnap = await _cards(boardId, listId).get();
    final batch = _db.batch();
    for (final cardDoc in cardsSnap.docs) {
      batch.delete(cardDoc.reference);
    }
    batch.delete(_lists(boardId).doc(listId));
    await batch.commit();
  }

  // ---- Cards ---------------------------------------------------------------

  Stream<List<KanbanCard>> watchCards(String boardId, String listId) {
    return _cards(boardId, listId)
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs.map(KanbanCard.fromFirestore).toList());
  }

  Future<String> createCard(String boardId, String listId, KanbanCard card) async {
    final ref = await _cards(boardId, listId).add(card.toFirestore());
    return ref.id;
  }

  Future<void> updateCard(String boardId, String listId, KanbanCard card) {
    return _cards(boardId, listId).doc(card.id).update(card.toFirestore());
  }

  Future<void> deleteCard(String boardId, String listId, String cardId) {
    return _cards(boardId, listId).doc(cardId).delete();
  }

  /// Reorders a card within the same list.
  Future<void> reorderCard(String boardId, String listId, String cardId, double order) {
    return _cards(boardId, listId).doc(cardId).update({'order': order});
  }

  /// Moves a card to a different list. Firestore subcollection docs are
  /// path-addressed, so a cross-list move is a copy-then-delete rather
  /// than a field update.
  Future<void> moveCardToList({
    required String boardId,
    required String fromListId,
    required String toListId,
    required KanbanCard card,
    required double newOrder,
  }) async {
    final movedCard = card.copyWith(order: newOrder, updatedAt: DateTime.now());
    final batch = _db.batch();
    batch.set(_cards(boardId, toListId).doc(card.id), movedCard.toFirestore());
    batch.delete(_cards(boardId, fromListId).doc(card.id));
    await batch.commit();
  }
}
