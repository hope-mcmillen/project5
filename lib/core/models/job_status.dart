enum JobStatus {
  draft('DRAFT'),
  open('OPEN'),
  paused('PAUSED'),
  closed('CLOSED');

  const JobStatus(this.db);
  final String db;
  String toDb() => db;
  static JobStatus fromDb(String value) =>
      values.firstWhere((v) => v.db == value);
}
