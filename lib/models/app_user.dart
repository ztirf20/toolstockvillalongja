import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { owner, staff }

extension UserRoleX on UserRole {
  String get label => this == UserRole.owner ? 'Owner' : 'Staff';
}

class AppUser {
  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final bool active;

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
  });

  bool get isOwner => role == UserRole.owner;

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return AppUser(
      uid: d.id,
      name: (m['name'] as String?) ?? 'User',
      email: (m['email'] as String?) ?? '',
      role: m['role'] == 'owner' ? UserRole.owner : UserRole.staff,
      active: (m['active'] as bool?) ?? true,
    );
  }
}