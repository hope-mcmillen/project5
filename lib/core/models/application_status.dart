/// Mirrors the database application_status enum.
enum ApplicationStatus {
  applied('APPLIED'),
  underReview('UNDER_REVIEW'),
  interviewRequested('INTERVIEW_REQUESTED'),
  notSelected('NOT_SELECTED'),
  withdrawn('WITHDRAWN'),
  jobClosed('JOB_CLOSED');

  const ApplicationStatus(this.db);
  final String db;
  String toDb() => db;
  static ApplicationStatus fromDb(String value) =>
      values.firstWhere((v) => v.db == value);
}
