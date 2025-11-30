// admin_user.dart
class AdminUser {
  final String id;
  final String name;
  final String email;
  final String? role;
  final String? birthDate;
  final String? petName;
  final int? petAge;
  final String? petGender;
  final String? petSpecies;

  AdminUser({
    required this.id,
    required this.name,
    required this.email,
    this.role,
    this.birthDate,
    this.petName,
    this.petAge,
    this.petGender,
    this.petSpecies,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json["_id"] ?? "",
      name: json["name"] ?? "",
      email: json["email"] ?? "",
      role: json["role"],
      birthDate: json["birthDate"],
      petName: json["petProfile"]?["name"],
      petAge: json["petProfile"]?["age"],
      petGender: json["petProfile"]?["gender"],
      petSpecies: json["petProfile"]?["species"],
    );
  }
}
