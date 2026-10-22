/// Mirrors the Postgres `application_status` enum (SCHEMA.md §3).
enum ApplicationStatus {
  applied('APPLIED'),
  underReview('UNDER_REVIEW'),
  interviewRequested('INTERVIEW_REQUESTED'),
  notSelected('NOT_SELECTED'),
  withdrawn('WITHDRAWN'),
  jobClosed('JOB_CLOSED');

  const ApplicationStatus(this.db);

  /// The exact Postgres value.
  final String db;

  String toDb() => db;

  static ApplicationStatus fromDb(String value) =>
      values.firstWhere((s) => s.db == value);
}
