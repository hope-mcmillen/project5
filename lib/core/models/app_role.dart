/// The two account types (PRD §4, A-1). Mirrors `profiles.role` in Postgres.
enum AppRole {
  candidate,
  recruiter;

  String toDb() => name;
  static AppRole fromDb(String value) => values.byName(value);
}
