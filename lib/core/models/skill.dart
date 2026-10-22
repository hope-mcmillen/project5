/// Immutable skill data for candidate and recruiter screens.
class Skill {
  Skill({
    required this.id,
    required this.name,
    required this.category,
    List<String> aliases = const [],
  }) : aliases = List.unmodifiable(aliases);
  final String id;
  final String name;
  final String category;
  final List<String> aliases;
  factory Skill.fromJson(Map<String, dynamic> json) => Skill(
    id: json['id'] as String,
    name: json['name'] as String,
    category: json['category'] as String,
    aliases: (json['aliases'] as List? ?? const [])
        .map((v) => v as String)
        .toList(),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'aliases': aliases.map((v) => v).toList(),
  };
}
