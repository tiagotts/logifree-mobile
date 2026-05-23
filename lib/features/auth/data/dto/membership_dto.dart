/// Membership do usuário em um condomínio.
class MembershipDto {
  const MembershipDto({
    required this.condominiumId,
    required this.condominiumSlug,
    required this.condominiumName,
    required this.roleId,
    required this.roleName,
    this.permissions = const <String>[],
  });

  final String condominiumId;
  final String condominiumSlug;
  final String condominiumName;
  final String roleId;
  final String roleName;
  final List<String> permissions;

  factory MembershipDto.fromJson(Map<String, dynamic> json) {
    final rawPermissions = json['permissions'];
    final permissions = rawPermissions is List
        ? rawPermissions.map((p) => p as String).toList()
        : const <String>[];
    return MembershipDto(
      condominiumId: json['condominiumId'] as String,
      condominiumSlug: json['condominiumSlug'] as String,
      condominiumName: json['condominiumName'] as String,
      roleId: json['roleId'] as String,
      roleName: json['roleName'] as String,
      permissions: permissions,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'condominiumId': condominiumId,
    'condominiumSlug': condominiumSlug,
    'condominiumName': condominiumName,
    'roleId': roleId,
    'roleName': roleName,
    'permissions': permissions,
  };
}
