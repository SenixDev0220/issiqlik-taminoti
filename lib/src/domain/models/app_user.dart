enum UserRole { admin, coAdmin, member }

enum UserStatus { active, pending, blocked }

class AppUser {
  final String id;
  final String login;
  final String firstName;
  final String lastName;
  final String phone;
  final String position;
  final String photoUrl;
  final UserRole role;
  final UserStatus status;
  final List<String> boilerhouseIds;

  const AppUser({
    required this.id,
    required this.login,
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.position = '',
    this.photoUrl = '',
    required this.role,
    required this.status,
    this.boilerhouseIds = const [],
  });

  String get fullName => '$firstName $lastName';

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    return '$f$l'.toUpperCase();
  }

  AppUser copyWith({
    String? id,
    String? login,
    String? firstName,
    String? lastName,
    String? phone,
    String? position,
    String? photoUrl,
    UserRole? role,
    UserStatus? status,
    List<String>? boilerhouseIds,
  }) {
    return AppUser(
      id: id ?? this.id,
      login: login ?? this.login,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      position: position ?? this.position,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      status: status ?? this.status,
      boilerhouseIds: boilerhouseIds ?? this.boilerhouseIds,
    );
  }
}
