import 'package:hive/hive.dart';
import 'enums.dart';

part 'user.g.dart';

@HiveType(typeId: 0)
class User extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name;

  @HiveField(2)
  late String email;

  @HiveField(3)
  late String roleIndex;

  @HiveField(4)
  late String department;

  @HiveField(5)
  late DateTime createdAt;

  @HiveField(6)
  String? password; // For local auth (hashed)

  User({
    required this.id,
    required this.name,
    required this.email,
    UserRole? role,
    required this.department,
    required this.createdAt,
    this.password,
  }) {
    if (role != null) {
      roleIndex = role.index.toString();
    }
  }

  UserRole get role => UserRole.values[int.parse(roleIndex)];

  set role(UserRole value) {
    roleIndex = value.index.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.name,
      'department': department,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.requester,
      ),
      department: json['department'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
