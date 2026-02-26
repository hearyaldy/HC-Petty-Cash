import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/organization.dart';

class OrganizationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'organizations';

  // Cache for organizations
  List<Organization>? _cachedOrganizations;
  DateTime? _cacheTime;
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Stream all organizations
  Stream<List<Organization>> organizationsStream() {
    return _firestore
        .collection(_collection)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      final organizations = snapshot.docs
          .map((doc) => Organization.fromFirestore(doc))
          .toList();
      _cachedOrganizations = organizations;
      _cacheTime = DateTime.now();
      return organizations;
    });
  }

  /// Stream only active organizations
  Stream<List<Organization>> activeOrganizationsStream() {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Organization.fromFirestore(doc))
          .toList();
    });
  }

  /// Get all organizations once (with caching)
  Future<List<Organization>> getAllOrganizations({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedOrganizations != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheDuration) {
      return _cachedOrganizations!;
    }

    final snapshot = await _firestore
        .collection(_collection)
        .orderBy('name')
        .get();

    _cachedOrganizations = snapshot.docs
        .map((doc) => Organization.fromFirestore(doc))
        .toList();
    _cacheTime = DateTime.now();

    return _cachedOrganizations!;
  }

  /// Get active organizations only
  Future<List<Organization>> getActiveOrganizations() async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .get();

    return snapshot.docs
        .map((doc) => Organization.fromFirestore(doc))
        .toList();
  }

  /// Get organization by ID
  Future<Organization?> getOrganizationById(String id) async {
    final doc = await _firestore.collection(_collection).doc(id).get();
    if (!doc.exists) return null;
    return Organization.fromFirestore(doc);
  }

  /// Get organization by code
  Future<Organization?> getOrganizationByCode(String code) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('code', isEqualTo: code.toUpperCase())
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return Organization.fromFirestore(snapshot.docs.first);
  }

  /// Create a new organization
  Future<Organization> createOrganization({
    required String name,
    required String code,
    String? description,
    String? address,
    String? contactEmail,
    String? contactPhone,
    String? logoUrl,
    String? createdBy,
  }) async {
    // Check if code already exists
    final existing = await getOrganizationByCode(code);
    if (existing != null) {
      throw Exception('Organization with code "$code" already exists');
    }

    final id = const Uuid().v4();
    final organization = Organization(
      id: id,
      name: name,
      code: code.toUpperCase(),
      description: description,
      address: address,
      contactEmail: contactEmail,
      contactPhone: contactPhone,
      logoUrl: logoUrl,
      isActive: true,
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );

    await _firestore.collection(_collection).doc(id).set(organization.toFirestore());
    _invalidateCache();

    return organization;
  }

  /// Update an organization
  Future<void> updateOrganization(Organization organization) async {
    final updated = organization.copyWith(updatedAt: DateTime.now());
    await _firestore
        .collection(_collection)
        .doc(organization.id)
        .update(updated.toFirestore());
    _invalidateCache();
  }

  /// Delete an organization (soft delete by setting isActive to false)
  Future<void> deactivateOrganization(String id) async {
    await _firestore.collection(_collection).doc(id).update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _invalidateCache();
  }

  /// Permanently delete an organization
  Future<void> deleteOrganization(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
    _invalidateCache();
  }

  /// Reactivate a deactivated organization
  Future<void> reactivateOrganization(String id) async {
    await _firestore.collection(_collection).doc(id).update({
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _invalidateCache();
  }

  /// Seed default organizations if none exist
  Future<void> seedDefaultOrganizations({String? createdBy}) async {
    final existing = await getAllOrganizations();
    if (existing.isNotEmpty) return;

    // Create Hope Channel Southeast Asia
    await createOrganization(
      name: 'Hope Channel Southeast Asia',
      code: 'HCSEA',
      description: 'Hope Channel Southeast Asia broadcasting organization',
      createdBy: createdBy,
    );

    // Create SEUM
    await createOrganization(
      name: 'SEUM',
      code: 'SEUM',
      description: 'Southeast Union Mission',
      createdBy: createdBy,
    );
  }

  /// Get organization count
  Future<int> getOrganizationCount() async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  /// Invalidate the cache
  void _invalidateCache() {
    _cachedOrganizations = null;
    _cacheTime = null;
  }
}
