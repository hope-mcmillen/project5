/// Immutable education data for candidate and recruiter screens.
class Education {
  Education({required this.level, required this.field});
  final String level;
  final String field;
  factory Education.fromJson(Map<String, dynamic> json) =>
      Education(level: json['level'] as String, field: json['field'] as String);
  Map<String, dynamic> toJson() => {'level': level, 'field': field};
}
