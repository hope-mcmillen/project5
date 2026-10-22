/// Database enum values shared by both frontends (C1).
enum ResumeStatus {
  uploaded('UPLOADED'),
  parsingLayout('PARSING_LAYOUT'),
  extracting('EXTRACTING'),
  normalizing('NORMALIZING'),
  ready('READY'),
  failed('FAILED');

  const ResumeStatus(this.db);
  final String db;
  String toDb() => db;
  static ResumeStatus fromDb(String value) =>
      values.firstWhere((v) => v.db == value);
}

enum PassReason {
  location('location'),
  salary('salary'),
  stack('stack'),
  seniority('seniority'),
  company('company');

  const PassReason(this.db);
  final String db;
  String toDb() => db;
  static PassReason fromDb(String value) =>
      values.firstWhere((v) => v.db == value);
}

enum RemoteType {
  onsite('onsite'),
  hybrid('hybrid'),
  remote('remote');

  const RemoteType(this.db);
  final String db;
  String toDb() => db;
  static RemoteType fromDb(String value) =>
      values.firstWhere((v) => v.db == value);
}

enum JobType {
  fullTime('full_time'),
  partTime('part_time'),
  contract('contract'),
  internship('internship');

  const JobType(this.db);
  final String db;
  String toDb() => db;
  static JobType fromDb(String value) =>
      values.firstWhere((v) => v.db == value);
}

enum SkillSource {
  ai('ai'),
  user('user');

  const SkillSource(this.db);
  final String db;
  String toDb() => db;
  static SkillSource fromDb(String value) =>
      values.firstWhere((v) => v.db == value);
}

enum ProfileSource {
  resume('resume'),
  manual('manual');

  const ProfileSource(this.db);
  final String db;
  String toDb() => db;
  static ProfileSource fromDb(String value) =>
      values.firstWhere((v) => v.db == value);
}

enum SwipeDirection {
  left('left'),
  right('right');

  const SwipeDirection(this.db);
  final String db;
  String toDb() => db;
  static SwipeDirection fromDb(String value) =>
      values.firstWhere((v) => v.db == value);
}

enum MatchedVia {
  exact('exact'),
  related('related'),
  none('none');

  const MatchedVia(this.db);
  final String db;
  String toDb() => db;
  static MatchedVia fromDb(String value) =>
      values.firstWhere((v) => v.db == value);
}

enum ScoreBand {
  strong('Strong'),
  good('Good'),
  stretch('Stretch'),
  low('Low');

  const ScoreBand(this.db);
  final String db;
  String toDb() => db;
  static ScoreBand fromDb(String value) =>
      values.firstWhere((v) => v.db == value);
  static ScoreBand fromScore(int score) {
    if (score < 0 || score > 100) throw RangeError.range(score, 0, 100);
    return score >= 85
        ? strong
        : score >= 70
        ? good
        : score >= 50
        ? stretch
        : low;
  }
}
