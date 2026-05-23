import 'membership_dto.dart';

/// Usuário autenticado.
class UserDto {
  const UserDto({
    required this.id,
    required this.email,
    required this.name,
    required this.memberships,
    this.type,
    this.isPlatformAdmin = false,
  });

  final String id;
  final String email;
  final String name;
  final List<MembershipDto> memberships;

  /// Tipo do usuário no back (ex.: `internal`, `resident`). Opcional.
  final String? type;

  /// `true` se o usuário é admin da plataforma (acesso total ao back-office).
  final bool isPlatformAdmin;

  factory UserDto.fromJson(Map<String, dynamic> json) {
    final raw = json['memberships'];
    final memberships = raw is List
        ? raw
              .map(
                (item) =>
                    MembershipDto.fromJson(item as Map<String, dynamic>),
              )
              .toList()
        : const <MembershipDto>[];
    return UserDto(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      memberships: memberships,
      type: json['type'] as String?,
      isPlatformAdmin: (json['isPlatformAdmin'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'email': email,
    'name': name,
    'memberships': memberships.map((m) => m.toJson()).toList(),
    if (type != null) 'type': type,
    'isPlatformAdmin': isPlatformAdmin,
  };
}
