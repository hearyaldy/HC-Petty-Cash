import 'storage_service.dart';
import '../models/user.dart';
import '../models/enums.dart';

class AuthService {
  User? _currentUser;

  User? get currentUser => _currentUser;

  bool get isAuthenticated => _currentUser != null;

  /// Simple login (in production, use proper password hashing)
  Future<bool> login(String email, String password) async {
    try {
      final users = StorageService.getAllUsers();
      final user = users.firstWhere(
        (u) => u.email == email && u.password == password,
        orElse: () => throw Exception('Invalid credentials'),
      );

      _currentUser = user;
      await StorageService.saveSetting('currentUserId', user.id);
      return true;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  /// Restore user session from storage
  Future<bool> restoreSession() async {
    try {
      final userId = StorageService.getSetting('currentUserId');
      if (userId != null) {
        final user = StorageService.getUser(userId);
        if (user != null) {
          _currentUser = user;
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Restore session error: $e');
      return false;
    }
  }

  /// Logout current user
  Future<void> logout() async {
    _currentUser = null;
    await StorageService.deleteSetting('currentUserId');
  }

  /// Register new user (admin only in production)
  Future<bool> register(User user) async {
    try {
      await StorageService.saveUser(user);
      return true;
    } catch (e) {
      print('Register error: $e');
      return false;
    }
  }

  /// Update current user
  Future<bool> updateCurrentUser(User user) async {
    try {
      await StorageService.saveUser(user);
      _currentUser = user;
      return true;
    } catch (e) {
      print('Update user error: $e');
      return false;
    }
  }

  /// Check if current user has a specific role
  bool hasRole(UserRole role) {
    return _currentUser?.role == role;
  }

  /// Check if current user can approve transactions
  bool canApprove() {
    return _currentUser?.role == UserRole.manager ||
        _currentUser?.role == UserRole.finance ||
        _currentUser?.role == UserRole.admin;
  }

  /// Check if current user can manage users
  bool canManageUsers() {
    return _currentUser?.role == UserRole.admin;
  }

  /// Check if current user can create reports
  bool canCreateReports() {
    return _currentUser != null; // All authenticated users can create reports
  }
}
