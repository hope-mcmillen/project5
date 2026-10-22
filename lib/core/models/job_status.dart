/// Mirrors the Postgres `job_status` enum (SCHEMA.md §3).
enum JobStatus {
  draft('DRAFT'),
  open('OPEN'),
  paused('PAUSED'),
  closed('CLOSED');

  const JobStatus(this.db);

  /// The exact Postgres value.
  final String db;

  String toDb() => db;

  static JobStatus fromDb(String value) =>
      values.firstWhere((s) => s.db == value);
}
