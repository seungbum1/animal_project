class AdminUser {
  final String id;
  final String name;
  final String? birth;
  final String username;
  final String? petName;
  final int? petAge;
  final String? petGender;
  final String? petSpecies;
  final String? hospital;

  AdminUser({
    required this.id,
    required this.name,
    required this.username,
    this.birth,
    this.petName,
    this.petAge,
    this.petGender,
    this.petSpecies,
    this.hospital,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'],
      name: json['name'],
      username: json['username'],
      birth: json['birth'],
      petName: json['petName'],
      petAge: json['petAge'],
      petGender: json['petGender'],
      petSpecies: json['petSpecies'],
      hospital: json['hospital'],
    );
  }
}
