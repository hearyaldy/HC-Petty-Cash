import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/enums.dart';
import '../utils/logger.dart';
import '../utils/validation.dart';

class FirebaseAuthService {
  // Use late initialization to avoid accessing Firebase before it's initialized
  firebase_auth.FirebaseAuth? _authInstance;
  firestore.FirebaseFirestore? _firestoreInstance;

  firebase_auth.FirebaseAuth get _auth {
    _authInstance ??= firebase_auth.FirebaseAuth.instance;
    return _authInstance!;
  }

  firestore.FirebaseFirestore get _firestore {
    _firestoreInstance ??= firestore.FirebaseFirestore.instance;
    return _firestoreInstance!;
  }

  User? _currentUser;

  // Flag to prevent auth state listener from interfering during login/registration
  bool _isAuthOperationInProgress = false;
  DateTime? _authOperationStartTime;

  // Timeout for auth operation flag (prevents stuck state)
  static const Duration _authOperationTimeout = Duration(seconds: 30);

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  // Check if auth operation is truly in progress (with timeout protection)
  bool get _isAuthOperationActive {
    if (!_isAuthOperationInProgress) return false;

    // If operation started more than 30 seconds ago, consider it stuck and reset
    if (_authOperationStartTime != null) {
      final elapsed = DateTime.now().difference(_authOperationStartTime!);
      if (elapsed > _authOperationTimeout) {
        debugPrint('DEBUG AUTH: Auth operation timeout - resetting flag');
        _isAuthOperationInProgress = false;
        _authOperationStartTime = null;
        return false;
      }
    }
    return true;
  }

  // Stream of auth state changes
  Stream<firebase_auth.User?> get authStateChanges => _auth.authStateChanges();

  // Initialize and load current user data from Firestore
  Future<void> initialize() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      await _loadUserData(firebaseUser.uid);
    }
  }

  // Login with email and password
  Future<bool> login(String email, String password) async {
    _isAuthOperationInProgress = true;
    _authOperationStartTime = DateTime.now();
    try {
      // Sanitize inputs
      final sanitizedEmail = ValidationUtils.sanitizeString(email);
      final sanitizedPassword = ValidationUtils.sanitizeString(password);

      final credential = await _auth.signInWithEmailAndPassword(
        email: sanitizedEmail,
        password: sanitizedPassword,
      );
      await _loadUserData(credential.user!.uid);
      return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      AppLogger.severe('Login error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      AppLogger.severe('Unexpected login error: $e');
      throw 'An unexpected error occurred';
    } finally {
      _isAuthOperationInProgress = false;
      _authOperationStartTime = null;
    }
  }

  // Register new user - returns userId on success, throws on failure
  Future<String?> registerUser({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    required String department,
  }) async {
    _isAuthOperationInProgress = true;
    _authOperationStartTime = DateTime.now();
    try {
      // Sanitize inputs
      final sanitizedEmail = ValidationUtils.sanitizeString(email);
      final sanitizedPassword = ValidationUtils.sanitizeString(password);
      final sanitizedName = ValidationUtils.sanitizeString(name);
      final sanitizedDepartment = ValidationUtils.sanitizeString(department);

      debugPrint('DEBUG AUTH: Creating Firebase Auth user');
      // Create Firebase Auth user
      final credential = await _auth.createUserWithEmailAndPassword(
        email: sanitizedEmail,
        password: sanitizedPassword,
      );

      final userId = credential.user!.uid;
      debugPrint('DEBUG AUTH: User created with ID: $userId');

      // Create user document in Firestore
      final user = User(
        id: userId,
        name: sanitizedName,
        email: sanitizedEmail,
        role: role.name,
        department: sanitizedDepartment,
        createdAt: DateTime.now(),
      );

      debugPrint('DEBUG AUTH: Saving user to Firestore');
      await _firestore.collection('users').doc(user.id).set(user.toFirestore());
      debugPrint('DEBUG AUTH: User saved to Firestore');

      // Note: We don't call initialize() here because:
      // 1. When admin creates a user, they will re-authenticate as admin afterward
      // 2. The auth state listener will handle loading user data when needed
      // 3. Calling initialize() here was causing hangs due to conflicting auth state updates

      return userId;
    } on firebase_auth.FirebaseAuthException catch (e) {
      AppLogger.severe('Registration error: ${e.code} - ${e.message}');
      debugPrint('DEBUG AUTH: Firebase auth error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e, stackTrace) {
      AppLogger.severe('Unexpected registration error: $e');
      debugPrint('DEBUG AUTH: Unexpected error: $e');
      debugPrint('DEBUG AUTH: Stack trace: $stackTrace');
      throw 'An unexpected error occurred: $e';
    } finally {
      _isAuthOperationInProgress = false;
      _authOperationStartTime = null;
    }
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
    _currentUser = null;
  }

  // Load user data from Firestore
  // throwOnNotFound: if false, missing document won't throw (useful for auth state listener)
  Future<bool> _loadUserData(String uid, {bool throwOnNotFound = true}) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _currentUser = User.fromFirestore(doc);
        return true;
      } else {
        AppLogger.warning('User document not found for UID: $uid');
        _currentUser = null;
        if (throwOnNotFound) {
          throw 'User profile not found';
        }
        return false;
      }
    } catch (e) {
      AppLogger.severe('Error loading user data: $e');
      if (throwOnNotFound) {
        rethrow;
      }
      return false;
    }
  }

  // Try to load user data silently (for auth state listener)
  // Returns true if user data was loaded, false otherwise
  // Skips if an auth operation (login/register) is already in progress
  Future<bool> tryLoadUserData() async {
    // Don't interfere if login or registration is in progress (with timeout protection)
    if (_isAuthOperationActive) {
      debugPrint(
        'DEBUG AUTH: Skipping tryLoadUserData - auth operation in progress',
      );
      return false;
    }

    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      return await _loadUserData(firebaseUser.uid, throwOnNotFound: false);
    }
    return false;
  }

  // Update user profile
  Future<bool> updateUserProfile(User user) async {
    try {
      final updatedUser = user.copyWith(updatedAt: DateTime.now());
      await _firestore
          .collection('users')
          .doc(user.id)
          .update(updatedUser.toFirestore());
      _currentUser = updatedUser;
      return true;
    } catch (e) {
      AppLogger.severe('Update user error: $e');
      return false;
    }
  }

  // Change password (requires current password for reauthentication)
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw 'No authenticated user found';
      }

      // Reauthenticate with current password
      final credential = firebase_auth.EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Update to new password
      await user.updatePassword(newPassword);
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Permission checks
  bool hasRole(UserRole role) => _currentUser?.roleEnum == role;

  bool canApprove() {
    if (_currentUser == null) return false;
    return _currentUser!.roleEnum == UserRole.manager ||
        _currentUser!.roleEnum == UserRole.finance ||
        _currentUser!.roleEnum == UserRole.admin;
  }

  bool canManageUsers() => _currentUser?.roleEnum == UserRole.admin;

  bool canCreateReports() => _currentUser != null;

  bool canCreatePurchaseRequisitions() {
    if (_currentUser == null) return false;
    // Only allow certain roles to create purchase requisitions
    return _currentUser!.roleEnum == UserRole.manager ||
        _currentUser!.roleEnum == UserRole.finance ||
        _currentUser!.roleEnum == UserRole.admin;
  }

  bool canCreateTravelingReports() {
    // Any authenticated user can create traveling reports
    return _currentUser != null;
  }

  // Inventory permission checks
  bool canViewInventory() {
    if (_currentUser == null) return false;
    // Admins always have full access
    if (_currentUser!.roleEnum == UserRole.admin) return true;
    // Check user-specific permissions
    return _currentUser!.inventoryPermissions.canView;
  }

  bool canAddInventory() {
    if (_currentUser == null) return false;
    // Admins always have full access
    if (_currentUser!.roleEnum == UserRole.admin) return true;
    // Check user-specific permissions
    return _currentUser!.inventoryPermissions.canAdd;
  }

  bool canEditInventory() {
    if (_currentUser == null) return false;
    // Admins always have full access
    if (_currentUser!.roleEnum == UserRole.admin) return true;
    // Check user-specific permissions
    return _currentUser!.inventoryPermissions.canEdit;
  }

  bool canDeleteInventory() {
    if (_currentUser == null) return false;
    // Admins always have full access
    if (_currentUser!.roleEnum == UserRole.admin) return true;
    // Check user-specific permissions
    return _currentUser!.inventoryPermissions.canDelete;
  }

  bool canCheckoutInventory() {
    if (_currentUser == null) return false;
    // Admins always have full access
    if (_currentUser!.roleEnum == UserRole.admin) return true;
    // Check user-specific permissions
    return _currentUser!.inventoryPermissions.canCheckout;
  }

  // Error handling
  String _handleAuthException(firebase_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'invalid-credential':
        return 'Invalid credentials. Please check your email and password.';
      default:
        return e.message ?? 'Authentication error occurred';
    }
  }

  // Get current Firebase user
  firebase_auth.User? get firebaseUser => _auth.currentUser;

  // Fetch user by ID from Firestore
  Future<User?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return User.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      AppLogger.severe('Error fetching user by ID: $e');
      return null;
    }
  }
}
