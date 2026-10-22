class InterviewContact {
  const InterviewContact({this.name, this.email, this.note});
  final String? name, email, note;
  factory InterviewContact.fromJson(Map<String, dynamic> json) =>
      InterviewContact(
        name: json['name'] as String?,
        email: json['email'] as String?,
        note: json['note'] as String?,
      );
}
