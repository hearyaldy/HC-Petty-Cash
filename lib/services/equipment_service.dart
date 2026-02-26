import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/equipment.dart';

class EquipmentService {
  // Singleton pattern
  static final EquipmentService _instance = EquipmentService._internal();
  factory EquipmentService() => _instance;
  EquipmentService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String equipmentCollection = 'equipment';
  static const String checkoutsCollection = 'equipment_checkouts';

  // In-memory cache
  List<Equipment>? _cachedEquipment;
  DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(minutes: 5);

  // Cache invalidation flag
  bool _cacheInvalidated = false;

  /// Check if cache is valid
  bool get _isCacheValid {
    if (_cachedEquipment == null || _cacheTimestamp == null) return false;
    if (_cacheInvalidated) return false;
    return DateTime.now().difference(_cacheTimestamp!) < _cacheDuration;
  }

  /// Invalidate cache (call after create/update/delete operations)
  void invalidateCache() {
    _cacheInvalidated = true;
    _cachedEquipment = null;
    _cacheTimestamp = null;
    debugPrint('DEBUG EQUIPMENT: Cache invalidated');
  }

  // ========== EQUIPMENT CRUD ==========

  /// Create a new equipment record
  Future<String> createEquipment(Equipment equipment) async {
    try {
      final docRef = await _firestore
          .collection(equipmentCollection)
          .add(equipment.toFirestore());
      invalidateCache(); // Invalidate cache after create
      debugPrint('Debug: Created equipment: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating equipment: $e');
      rethrow;
    }
  }

  /// Update existing equipment
  Future<void> updateEquipment(Equipment equipment) async {
    try {
      await _firestore
          .collection(equipmentCollection)
          .doc(equipment.id)
          .update(equipment.toFirestore());
      invalidateCache(); // Invalidate cache after update
      debugPrint('Debug: Updated equipment: ${equipment.id}');
    } catch (e) {
      debugPrint('Error updating equipment: $e');
      rethrow;
    }
  }

  /// Delete equipment
  Future<void> deleteEquipment(String equipmentId) async {
    try {
      await _firestore
          .collection(equipmentCollection)
          .doc(equipmentId)
          .delete();
      invalidateCache(); // Invalidate cache after delete
      debugPrint('Debug: Deleted equipment: $equipmentId');
    } catch (e) {
      debugPrint('Error deleting equipment: $e');
      rethrow;
    }
  }

  /// Get equipment by ID
  Future<Equipment?> getEquipmentById(String equipmentId) async {
    try {
      final doc = await _firestore
          .collection(equipmentCollection)
          .doc(equipmentId)
          .get();
      if (doc.exists) {
        return Equipment.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting equipment: $e');
      rethrow;
    }
  }

  /// Stream all equipment
  Stream<List<Equipment>> getAllEquipment() {
    return _firestore
        .collection(equipmentCollection)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          debugPrint('DEBUG EQUIPMENT: Got ${snapshot.docs.length} documents');
          final List<Equipment> result = [];
          for (final doc in snapshot.docs) {
            try {
              debugPrint('DEBUG EQUIPMENT: Parsing doc ${doc.id}');
              final data = doc.data();
              debugPrint('DEBUG EQUIPMENT: Data keys: ${data.keys.toList()}');
              debugPrint(
                'DEBUG EQUIPMENT: createdAt type: ${data['createdAt']?.runtimeType}',
              );
              debugPrint(
                'DEBUG EQUIPMENT: createdAt value: ${data['createdAt']}',
              );
              final equipment = Equipment.fromFirestore(doc);
              result.add(equipment);
              debugPrint(
                'DEBUG EQUIPMENT: Successfully parsed ${equipment.name}',
              );
            } catch (e, stack) {
              debugPrint(
                'DEBUG EQUIPMENT ERROR: Failed to parse doc ${doc.id}: $e',
              );
              debugPrint('DEBUG EQUIPMENT STACK: $stack');
            }
          }
          debugPrint('DEBUG EQUIPMENT: Returning ${result.length} items');
          return result;
        });
  }

  /// Stream equipment by organization
  Stream<List<Equipment>> getEquipmentByOrganization(String organizationId) {
    return _firestore
        .collection(equipmentCollection)
        .where('organizationId', isEqualTo: organizationId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          debugPrint('DEBUG EQUIPMENT: Got ${snapshot.docs.length} documents for org $organizationId');
          final List<Equipment> result = [];
          for (final doc in snapshot.docs) {
            try {
              final equipment = Equipment.fromFirestore(doc);
              result.add(equipment);
            } catch (e) {
              debugPrint('DEBUG EQUIPMENT ERROR: Failed to parse doc ${doc.id}: $e');
            }
          }
          return result;
        });
  }

  /// Get equipment by organization once (with optional caching)
  Future<List<Equipment>> getEquipmentByOrganizationOnce(
    String organizationId, {
    bool forceRefresh = false,
  }) async {
    try {
      debugPrint('DEBUG EQUIPMENT: Fetching equipment for org $organizationId');
      final snapshot = await _firestore
          .collection(equipmentCollection)
          .where('organizationId', isEqualTo: organizationId)
          .orderBy('name')
          .get();

      final List<Equipment> result = [];
      for (final doc in snapshot.docs) {
        try {
          final equipment = Equipment.fromFirestore(doc);
          result.add(equipment);
        } catch (e) {
          debugPrint('DEBUG EQUIPMENT ERROR: Failed to parse doc ${doc.id}: $e');
        }
      }

      debugPrint('DEBUG EQUIPMENT: Found ${result.length} items for org $organizationId');
      return result;
    } catch (e) {
      debugPrint('Error getting equipment by organization: $e');
      rethrow;
    }
  }

  /// Update equipment organization assignment
  Future<void> updateEquipmentOrganization(
    String equipmentId,
    String organizationId,
    String organizationName,
  ) async {
    try {
      await _firestore.collection(equipmentCollection).doc(equipmentId).update({
        'organizationId': organizationId,
        'organizationName': organizationName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      invalidateCache();
      debugPrint('Debug: Updated equipment $equipmentId to org $organizationId');
    } catch (e) {
      debugPrint('Error updating equipment organization: $e');
      rethrow;
    }
  }

  /// Bulk update equipment organization (for migration)
  Future<void> bulkUpdateOrganization(
    List<String> equipmentIds,
    String organizationId,
    String organizationName,
  ) async {
    try {
      final batch = _firestore.batch();
      for (final id in equipmentIds) {
        final ref = _firestore.collection(equipmentCollection).doc(id);
        batch.update(ref, {
          'organizationId': organizationId,
          'organizationName': organizationName,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      invalidateCache();
      debugPrint('Debug: Bulk updated ${equipmentIds.length} equipment to org $organizationId');
    } catch (e) {
      debugPrint('Error bulk updating equipment organization: $e');
      rethrow;
    }
  }

  /// Assign all existing equipment without organization to a default organization
  Future<int> assignUnassignedEquipment(
    String organizationId,
    String organizationName,
  ) async {
    try {
      // Get ALL equipment and filter client-side for those without organizationId
      // This handles both: field is null AND field doesn't exist
      final snapshot = await _firestore
          .collection(equipmentCollection)
          .get();

      // Filter for documents where organizationId is missing, null, or empty
      final unassignedDocs = snapshot.docs.where((doc) {
        final data = doc.data();
        final orgId = data['organizationId'];
        return orgId == null || (orgId is String && orgId.isEmpty);
      }).toList();

      if (unassignedDocs.isEmpty) {
        debugPrint('DEBUG EQUIPMENT: No unassigned equipment found');
        return 0;
      }

      debugPrint('DEBUG EQUIPMENT: Found ${unassignedDocs.length} unassigned equipment');

      // Firestore batch limit is 500 operations, so we need to batch in chunks
      int count = 0;
      for (var i = 0; i < unassignedDocs.length; i += 500) {
        final batch = _firestore.batch();
        final chunk = unassignedDocs.skip(i).take(500);

        for (final doc in chunk) {
          batch.update(doc.reference, {
            'organizationId': organizationId,
            'organizationName': organizationName,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          count++;
        }
        await batch.commit();
      }

      invalidateCache();

      debugPrint('DEBUG EQUIPMENT: Assigned $count equipment to org $organizationId');
      return count;
    } catch (e) {
      debugPrint('Error assigning unassigned equipment: $e');
      rethrow;
    }
  }

  /// Get all equipment once (not a stream) - WITH CACHING
  Future<List<Equipment>> getAllEquipmentOnce({
    bool forceRefresh = false,
  }) async {
    // Return cached data if valid and not forcing refresh
    if (!forceRefresh && _isCacheValid) {
      debugPrint(
        'DEBUG EQUIPMENT: Returning ${_cachedEquipment!.length} items from cache',
      );
      return List.from(_cachedEquipment!);
    }

    try {
      debugPrint('DEBUG EQUIPMENT: Fetching all equipment from Firestore...');
      final snapshot = await _firestore
          .collection(equipmentCollection)
          .orderBy('name')
          .get(const GetOptions(source: Source.serverAndCache));

      debugPrint('DEBUG EQUIPMENT: Got ${snapshot.docs.length} documents');
      final List<Equipment> result = [];
      for (final doc in snapshot.docs) {
        try {
          final equipment = Equipment.fromFirestore(doc);
          result.add(equipment);
        } catch (e) {
          debugPrint(
            'DEBUG EQUIPMENT ERROR: Failed to parse doc ${doc.id}: $e',
          );
        }
      }

      // Update cache
      _cachedEquipment = result;
      _cacheTimestamp = DateTime.now();
      _cacheInvalidated = false;

      debugPrint('DEBUG EQUIPMENT: Cached ${result.length} items');
      return List.from(result);
    } catch (e) {
      debugPrint('Error getting all equipment: $e');
      // If we have stale cache, return it on error
      if (_cachedEquipment != null) {
        debugPrint('DEBUG EQUIPMENT: Returning stale cache on error');
        return List.from(_cachedEquipment!);
      }
      rethrow;
    }
  }

  /// Stream equipment by category
  Stream<List<Equipment>> getEquipmentByCategory(String category) {
    return _firestore
        .collection(equipmentCollection)
        .where('category', isEqualTo: category)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Equipment.fromFirestore(doc))
              .toList();
        });
  }

  /// Stream equipment by status
  Stream<List<Equipment>> getEquipmentByStatus(EquipmentStatus status) {
    return _firestore
        .collection(equipmentCollection)
        .where('status', isEqualTo: status.name)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Equipment.fromFirestore(doc))
              .toList();
        });
  }

  /// Stream available equipment
  Stream<List<Equipment>> getAvailableEquipment() {
    return getEquipmentByStatus(EquipmentStatus.available);
  }

  /// Stream checked out equipment
  Stream<List<Equipment>> getCheckedOutEquipment() {
    return getEquipmentByStatus(EquipmentStatus.checkedOut);
  }

  /// Get equipment count by status
  Future<Map<EquipmentStatus, int>> getEquipmentCountByStatus() async {
    try {
      final snapshot = await _firestore.collection(equipmentCollection).get();
      final counts = <EquipmentStatus, int>{};

      for (var status in EquipmentStatus.values) {
        counts[status] = 0;
      }

      for (var doc in snapshot.docs) {
        final status = EquipmentStatus.fromString(doc.data()['status']);
        counts[status] = (counts[status] ?? 0) + 1;
      }

      return counts;
    } catch (e) {
      debugPrint('Error getting equipment counts: $e');
      rethrow;
    }
  }

  /// Search equipment by name or serial number
  Future<List<Equipment>> searchEquipment(String searchTerm) async {
    try {
      // Get all equipment and filter locally (Firestore doesn't support full-text search)
      final snapshot = await _firestore.collection(equipmentCollection).get();
      final searchLower = searchTerm.toLowerCase();

      return snapshot.docs.map((doc) => Equipment.fromFirestore(doc)).where((
        equipment,
      ) {
        return equipment.name.toLowerCase().contains(searchLower) ||
            (equipment.serialNumber?.toLowerCase().contains(searchLower) ??
                false) ||
            (equipment.brand?.toLowerCase().contains(searchLower) ?? false) ||
            (equipment.model?.toLowerCase().contains(searchLower) ?? false) ||
            (equipment.assetTag?.toLowerCase().contains(searchLower) ?? false);
      }).toList();
    } catch (e) {
      debugPrint('Error searching equipment: $e');
      rethrow;
    }
  }

  // ========== CHECKOUT OPERATIONS ==========

  /// Check out equipment
  Future<String> checkOutEquipment({
    required String equipmentId,
    required String userId,
    required String userName,
    DateTime? expectedReturnDate,
    String? purpose,
    String? notes,
    required EquipmentCondition conditionAtCheckout,
  }) async {
    try {
      // Get the equipment first
      final equipment = await getEquipmentById(equipmentId);
      if (equipment == null) {
        throw Exception('Equipment not found');
      }
      if (equipment.status != EquipmentStatus.available) {
        throw Exception('Equipment is not available for checkout');
      }

      // Create checkout record
      final checkout = EquipmentCheckout(
        id: '', // Will be set by Firestore
        equipmentId: equipmentId,
        checkedOutBy: userId,
        checkedOutByName: userName,
        checkedOutAt: DateTime.now(),
        expectedReturnDate: expectedReturnDate,
        purpose: purpose,
        notes: notes,
        conditionAtCheckout: conditionAtCheckout,
      );

      final checkoutRef = await _firestore
          .collection(checkoutsCollection)
          .add(checkout.toFirestore());

      // Update equipment status
      await _firestore.collection(equipmentCollection).doc(equipmentId).update({
        'status': EquipmentStatus.checkedOut.name,
        'currentCheckoutId': checkoutRef.id,
        'currentHolderId': userId,
        'currentHolderName': userName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      invalidateCache(); // Invalidate cache after checkout
      debugPrint('Debug: Checked out equipment $equipmentId to $userName');
      return checkoutRef.id;
    } catch (e) {
      debugPrint('Error checking out equipment: $e');
      rethrow;
    }
  }

  /// Check in (return) equipment
  Future<void> checkInEquipment({
    required String equipmentId,
    required String checkoutId,
    required String returnedBy,
    required String returnedByName,
    required EquipmentCondition conditionAtReturn,
    String? notes,
  }) async {
    try {
      // Update checkout record
      await _firestore.collection(checkoutsCollection).doc(checkoutId).update({
        'returnedAt': FieldValue.serverTimestamp(),
        'returnedBy': returnedBy,
        'returnedByName': returnedByName,
        'conditionAtReturn': conditionAtReturn.name,
        if (notes != null) 'notes': FieldValue.arrayUnion([notes]),
      });

      // Update equipment status
      await _firestore.collection(equipmentCollection).doc(equipmentId).update({
        'status': EquipmentStatus.available.name,
        'condition': conditionAtReturn.name,
        'currentCheckoutId': null,
        'currentHolderId': null,
        'currentHolderName': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      invalidateCache(); // Invalidate cache after check-in
      debugPrint('Debug: Checked in equipment $equipmentId');
    } catch (e) {
      debugPrint('Error checking in equipment: $e');
      rethrow;
    }
  }

  /// Get checkout history for equipment
  Stream<List<EquipmentCheckout>> getEquipmentCheckoutHistory(
    String equipmentId,
  ) {
    return _firestore
        .collection(checkoutsCollection)
        .where('equipmentId', isEqualTo: equipmentId)
        .orderBy('checkedOutAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => EquipmentCheckout.fromFirestore(doc))
              .toList();
        });
  }

  /// Get current checkout for equipment
  Future<EquipmentCheckout?> getCurrentCheckout(String equipmentId) async {
    try {
      final equipment = await getEquipmentById(equipmentId);
      if (equipment?.currentCheckoutId == null) {
        return null;
      }

      final doc = await _firestore
          .collection(checkoutsCollection)
          .doc(equipment!.currentCheckoutId)
          .get();

      if (doc.exists) {
        return EquipmentCheckout.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting current checkout: $e');
      rethrow;
    }
  }

  /// Get all checkouts for a user
  Stream<List<EquipmentCheckout>> getUserCheckouts(String userId) {
    return _firestore
        .collection(checkoutsCollection)
        .where('checkedOutBy', isEqualTo: userId)
        .where('returnedAt', isNull: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => EquipmentCheckout.fromFirestore(doc))
              .toList();
        });
  }

  /// Get all active checkouts
  Stream<List<EquipmentCheckout>> getActiveCheckouts() {
    return _firestore
        .collection(checkoutsCollection)
        .where('returnedAt', isNull: true)
        .orderBy('checkedOutAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => EquipmentCheckout.fromFirestore(doc))
              .toList();
        });
  }

  /// Get overdue checkouts
  Future<List<EquipmentCheckout>> getOverdueCheckouts() async {
    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection(checkoutsCollection)
          .where('returnedAt', isNull: true)
          .get();

      return snapshot.docs
          .map((doc) => EquipmentCheckout.fromFirestore(doc))
          .where((checkout) {
            return checkout.expectedReturnDate != null &&
                checkout.expectedReturnDate!.isBefore(now);
          })
          .toList();
    } catch (e) {
      debugPrint('Error getting overdue checkouts: $e');
      rethrow;
    }
  }

  // ========== MAINTENANCE ==========

  /// Mark equipment for maintenance
  Future<void> markForMaintenance(String equipmentId, String? reason) async {
    try {
      await _firestore.collection(equipmentCollection).doc(equipmentId).update({
        'status': EquipmentStatus.maintenance.name,
        'notes': reason != null
            ? FieldValue.arrayUnion(['Maintenance: $reason'])
            : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      invalidateCache();
      debugPrint('Debug: Equipment $equipmentId marked for maintenance');
    } catch (e) {
      debugPrint('Error marking equipment for maintenance: $e');
      rethrow;
    }
  }

  /// Mark equipment available after maintenance
  Future<void> markAvailable(
    String equipmentId,
    EquipmentCondition condition,
  ) async {
    try {
      await _firestore.collection(equipmentCollection).doc(equipmentId).update({
        'status': EquipmentStatus.available.name,
        'condition': condition.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      invalidateCache();
      debugPrint('Debug: Equipment $equipmentId marked available');
    } catch (e) {
      debugPrint('Error marking equipment available: $e');
      rethrow;
    }
  }

  /// Retire equipment
  Future<void> retireEquipment(String equipmentId, String? reason) async {
    try {
      await _firestore.collection(equipmentCollection).doc(equipmentId).update({
        'status': EquipmentStatus.retired.name,
        'notes': reason != null
            ? FieldValue.arrayUnion(['Retired: $reason'])
            : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      invalidateCache();
      debugPrint('Debug: Equipment $equipmentId retired');
    } catch (e) {
      debugPrint('Error retiring equipment: $e');
      rethrow;
    }
  }

  // ========== STATISTICS ==========

  /// Get inventory statistics - uses cache when available
  Future<Map<String, dynamic>> getInventoryStats({String? organizationId}) async {
    try {
      // Use cached data if available, otherwise fetch
      List<Equipment> equipment;
      if (organizationId != null) {
        equipment = await getEquipmentByOrganizationOnce(organizationId);
      } else {
        equipment = await getAllEquipmentOnce();
      }

      final statusCounts = <String, int>{};
      final categoryCounts = <String, int>{};
      double totalValue = 0;

      for (var item in equipment) {
        // Status counts
        final statusKey = item.status.displayName;
        statusCounts[statusKey] = (statusCounts[statusKey] ?? 0) + 1;

        // Category counts
        categoryCounts[item.category] =
            (categoryCounts[item.category] ?? 0) + 1;

        // Total value
        if (item.purchasePrice != null) {
          totalValue += item.purchasePrice!;
        }
      }

      return {
        'total': equipment.length,
        'available': statusCounts['Available'] ?? 0,
        'checkedOut': statusCounts['Checked Out'] ?? 0,
        'maintenance': statusCounts['Under Maintenance'] ?? 0,
        'retired': statusCounts['Retired'] ?? 0,
        'statusCounts': statusCounts,
        'categoryCounts': categoryCounts,
        'totalValue': totalValue,
      };
    } catch (e) {
      debugPrint('Error getting inventory stats: $e');
      rethrow;
    }
  }
}
