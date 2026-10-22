/// Immutable job company data for candidate and recruiter screens.
class JobCompany {
  JobCompany({required this.id, required this.name, required this.verified});
  final String id;
  final String name;
  final bool verified;
  factory JobCompany.fromJson(Map<String, dynamic> json) => JobCompany(
    id: json['id'] as String,
    name: json['name'] as String,
    verified: json['verified'] as bool,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'verified': verified,
  };
}
