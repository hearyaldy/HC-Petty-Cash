import 'package:hive_flutter/hive_flutter.dart';
import '../models/user.dart';
import '../models/petty_cash_report.dart';
import '../models/transaction.dart';
import '../models/enums.dart';

class StorageService {
  static const String usersBoxName = 'users';
  static const String reportsBoxName = 'reports';
  static const String transactionsBoxName = 'transactions';
  static const String settingsBoxName = 'settings';

  static Box<User>? _usersBox;
  static Box<PettyCashReport>? _reportsBox;
  static Box<Transaction>? _transactionsBox;
  static Box? _settingsBox;

  static Future<void> initialize() async {
    await Hive.initFlutter();

    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(UserAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(PettyCashReportAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(TransactionAdapter());
    }

    // Open boxes
    _usersBox = await Hive.openBox<User>(usersBoxName);
    _reportsBox = await Hive.openBox<PettyCashReport>(reportsBoxName);
    _transactionsBox = await Hive.openBox<Transaction>(transactionsBoxName);
    _settingsBox = await Hive.openBox(settingsBoxName);

    // Initialize with sample data if empty
    await _initializeSampleData();
  }

  static Future<void> _initializeSampleData() async {
    if (_usersBox!.isEmpty) {
      // Add sample admin user
      final admin = User(
        id: 'admin-001',
        name: 'Admin User',
        email: 'admin@company.com',
        role: UserRole.admin,
        department: 'Administration',
        createdAt: DateTime.now(),
        password: 'admin123', // In production, this should be hashed
      );
      await _usersBox!.put(admin.id, admin);

      // Add sample manager
      final manager = User(
        id: 'manager-001',
        name: 'John Manager',
        email: 'manager@company.com',
        role: UserRole.manager,
        department: 'Finance',
        createdAt: DateTime.now(),
        password: 'manager123',
      );
      await _usersBox!.put(manager.id, manager);

      // Add sample finance user
      final finance = User(
        id: 'finance-001',
        name: 'Jane Finance',
        email: 'finance@company.com',
        role: UserRole.finance,
        department: 'Finance',
        createdAt: DateTime.now(),
        password: 'finance123',
      );
      await _usersBox!.put(finance.id, finance);

      // Add sample requester
      final requester = User(
        id: 'user-001',
        name: 'Bob Requester',
        email: 'user@company.com',
        role: UserRole.requester,
        department: 'Operations',
        createdAt: DateTime.now(),
        password: 'user123',
      );
      await _usersBox!.put(requester.id, requester);
    }
  }

  // User operations
  static Box<User> get usersBox => _usersBox!;

  static List<User> getAllUsers() {
    return _usersBox!.values.toList();
  }

  static User? getUser(String id) {
    return _usersBox!.get(id);
  }

  static Future<void> saveUser(User user) async {
    await _usersBox!.put(user.id, user);
  }

  static Future<void> deleteUser(String id) async {
    await _usersBox!.delete(id);
  }

  // Report operations
  static Box<PettyCashReport> get reportsBox => _reportsBox!;

  static List<PettyCashReport> getAllReports() {
    return _reportsBox!.values.toList();
  }

  static PettyCashReport? getReport(String id) {
    return _reportsBox!.get(id);
  }

  static Future<void> saveReport(PettyCashReport report) async {
    await _reportsBox!.put(report.id, report);
  }

  static Future<void> deleteReport(String id) async {
    await _reportsBox!.delete(id);
  }

  // Transaction operations
  static Box<Transaction> get transactionsBox => _transactionsBox!;

  static List<Transaction> getAllTransactions() {
    return _transactionsBox!.values.toList();
  }

  static List<Transaction> getTransactionsByReportId(String reportId) {
    return _transactionsBox!.values
        .where((t) => t.reportId == reportId)
        .toList();
  }

  static Transaction? getTransaction(String id) {
    return _transactionsBox!.get(id);
  }

  static Future<void> saveTransaction(Transaction transaction) async {
    await _transactionsBox!.put(transaction.id, transaction);
  }

  static Future<void> deleteTransaction(String id) async {
    await _transactionsBox!.delete(id);
  }

  // Settings operations
  static Box get settingsBox => _settingsBox!;

  static dynamic getSetting(String key, {dynamic defaultValue}) {
    return _settingsBox!.get(key, defaultValue: defaultValue);
  }

  static Future<void> saveSetting(String key, dynamic value) async {
    await _settingsBox!.put(key, value);
  }

  static Future<void> deleteSetting(String key) async {
    await _settingsBox!.delete(key);
  }

  // Clear all data
  static Future<void> clearAllData() async {
    await _usersBox!.clear();
    await _reportsBox!.clear();
    await _transactionsBox!.clear();
    await _settingsBox!.clear();
    await _initializeSampleData();
  }

  // Close all boxes
  static Future<void> close() async {
    await _usersBox?.close();
    await _reportsBox?.close();
    await _transactionsBox?.close();
    await _settingsBox?.close();
  }
}
