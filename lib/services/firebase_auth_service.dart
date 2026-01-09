import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import '../models/user.dart';
import '../models/enums.dart';
import '../utils/logger.dart';
import '../utils/validation.dart';

class FirebaseAuthService {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final firestore.FirebaseFirestore _firestore =
      firestore.FirebaseFirestore.instance;

  User? _currentUser;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

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
    try {
      // Sanitize inputs
      final sanitizedEmail = ValidationUtils.sanitizeString(email);
      final sanitizedPassword = ValidationUtils.sanitizeString(password);
      final sanitizedName = ValidationUtils.sanitizeString(name);
      final sanitizedDepartment = ValidationUtils.sanitizeString(department);

      print('DEBUG AUTH: Creating Firebase Auth user');
      // Create Firebase Auth user
      final credential = await _auth.createUserWithEmailAndPassword(
        email: sanitizedEmail,
        password: sanitizedPassword,
      );

      final userId = credential.user!.uid;
      print('DEBUG AUTH: User created with ID: $userId');

      // Create user document in Firestore
      final user = User(
        id: userId,
        name: sanitizedName,
        email: sanitizedEmail,
        role: role.name,
        department: sanitizedDepartment,
        createdAt: DateTime.now(),
      );

      print('DEBUG AUTH: Saving user to Firestore');
      await _firestore.collection('users').doc(user.id).set(user.toFirestore());
      print('DEBUG AUTH: User saved to Firestore');

      // Load the newly created user data
      print('DEBUG AUTH: Initializing user data');
      await initialize();
      print('DEBUG AUTH: User data initialized');

      return userId;
    } on firebase_auth.FirebaseAuthException catch (e) {
      AppLogger.severe('Registration error: ${e.code} - ${e.message}');
      print('DEBUG AUTH: Firebase auth error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e, stackTrace) {
      AppLogger.severe('Unexpected registration error: $e');
      print('DEBUG AUTH: Unexpected error: $e');
      print('DEBUG AUTH: Stack trace: $stackTrace');
      throw 'An unexpected error occurred: $e';
    }
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
    _currentUser = null;
  }

  // Load user data from Firestore
  Future<void> _loadUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _currentUser = User.fromFirestore(doc);
      } else {
        AppLogger.warning('User document not found for UID: $uid');
        throw 'User profile not found';
      }
    } catch (e) {
      AppLogger.severe('Error loading user data: $e');
      rethrow;
    }
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
}
