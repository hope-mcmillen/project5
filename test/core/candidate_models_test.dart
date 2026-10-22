import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:project5/core/models/candidate_models.dart';
import 'package:project5/core/testing/candidate_fixtures.dart';

void main() {
  test('contract data survives JSON wire round trips', () {
    final cases =
        <
          (
            Map<String, dynamic>,
            Map<String, dynamic> Function(Map<String, dynamic>),
          )
        >[
          (CandidateFixtures.skill.toJson(), (j) => Skill.fromJson(j).toJson()),
          (
            CandidateFixtures.candidateSkill.toJson(),
            (j) => CandidateSkill.fromJson(j).toJson(),
          ),
          (
            CandidateFixtures.version.toJson(),
            (j) => ProfileVersion.fromJson(j).toJson(),
          ),
          (CandidateFixtures.job.toJson(), (j) => JobCard.fromJson(j).toJson()),
          for (final application in CandidateFixtures.applications)
            (application.toJson(), (j) => Application.fromJson(j).toJson()),
          (
            {
              'locations': ['Baton Rouge, LA'],
              'remote': ['remote', 'hybrid'],
              'job_types': ['full_time'],
              'needs_sponsorship': false,
              'salary_min': 70000,
              'include_stretch': false,
            },
            (j) => Preferences.fromJson(j).toJson(),
          ),
          (
            {
              'id': 1,
              'application_id': 'application',
              'from_status': null,
              'to_status': 'APPLIED',
              'actor_id': null,
              'created_at': '2026-10-22T14:00:00.000Z',
            },
            (j) => StatusEvent.fromJson(j).toJson(),
          ),
          (
            {
              'application_id': 'application',
              'handle': '◆ 4F2A',
              'match_score': 92,
              'band': 'Strong',
              'total_years': 3.0,
              'top_skills': ['Flutter'],
              'gaps': [],
              'status': 'APPLIED',
              'committed_at': '2026-10-22T14:00:00.000Z',
            },
            (j) => CandidateTile.fromJson(j).toJson(),
          ),
          (
            {
              'id': 'user',
              'role': null,
              'display_name': null,
              'terms_accepted_at': null,
            },
            (j) => Profile.fromJson(j).toJson(),
          ),
          (
            {
              'id': 'resume',
              'candidate_id': 'user',
              'storage_path': 'user/resume.pdf',
              'status': 'FAILED',
              'failure_reason': 'timeout',
            },
            (j) => Resume.fromJson(j).toJson(),
          ),
        ];
    for (final (json, roundTrip) in cases) {
      expect(
        roundTrip(jsonDecode(jsonEncode(json)) as Map<String, dynamic>),
        json,
      );
    }
    expect(Preferences.fromJson({}).toJson(), isEmpty);
  });
  test('score boundaries, nullable years, and immutable lists', () {
    for (final (score, band) in [
      (0, ScoreBand.low),
      (49, ScoreBand.low),
      (50, ScoreBand.stretch),
      (69, ScoreBand.stretch),
      (70, ScoreBand.good),
      (84, ScoreBand.good),
      (85, ScoreBand.strong),
      (100, ScoreBand.strong),
    ]) {
      expect(ScoreBand.fromScore(score), band);
    }
    expect(() => ScoreBand.fromScore(101), throwsRangeError);
    final skill = CandidateSkill.fromJson({
      ...CandidateFixtures.candidateSkill.toJson(),
      'years': null,
      'skill_id': null,
    });
    expect(skill.years, isNull);
    expect(skill.skillId, isNull);
    expect(
      () => CandidateFixtures.job.gaps.add('change'),
      throwsUnsupportedError,
    );
    expect(
      () => CandidateFixtures.version.candidateSkills.clear(),
      throwsUnsupportedError,
    );
  });
  test('database enums round trip', () {
    for (final status in ResumeStatus.values) {
      expect(ResumeStatus.fromDb(status.toDb()), status);
    }
    for (final status in ApplicationStatus.values) {
      expect(ApplicationStatus.fromDb(status.toDb()), status);
    }
    for (final reason in PassReason.values) {
      expect(PassReason.fromDb(reason.toDb()), reason);
    }
    for (final remote in RemoteType.values) {
      expect(RemoteType.fromDb(remote.toDb()), remote);
    }
    for (final type in JobType.values) {
      expect(JobType.fromDb(type.toDb()), type);
    }
  });
}
