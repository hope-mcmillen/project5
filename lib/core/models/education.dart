/// Immutable education data for candidate and recruiter screens.
///
/// Either part can be missing when a resume states only the degree or only
/// the field.
class Education {
  Education({required this.level, required this.field});
  final String? level;
  final String? field;
  factory Education.fromJson(Map<String, dynamic> json) => Education(
    level: json['level'] as String?,
    field: json['field'] as String?,
  );
  Map<String, dynamic> toJson() => {'level': level, 'field': field};
}
