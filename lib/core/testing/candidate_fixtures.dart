import '../models/candidate_models.dart';
import 'seed_taxonomy.dart';

/// Synthetic contract-shaped records shared by candidate fakes and tests.
abstract final class CandidateFixtures {
  static const candidateId = '10000000-0000-0000-0000-000000000001';
  static const versionId = '30000000-0000-0000-0000-000000000001';
  static const jobId = '40000000-0000-0000-0000-000000000001';
  static final date = DateTime.utc(2026, 10, 22, 14);

  /// The fixed test skills first, then the rest of the seeded taxonomy.
  /// Ids are lowercase names.
  static List<Skill> get taxonomy {
    final fixed = [
      skill,
      for (final (id, name, category, aliases) in [
        ('dart', 'Dart', 'Languages', <String>[]),
        ('python', 'Python', 'Languages', ['py']),
        ('sql', 'SQL', 'Data', ['structured query language']),
        ('riverpod', 'Riverpod', 'Frameworks', <String>[]),
        ('git', 'Git', 'Tools', <String>[]),
        ('react', 'React', 'Frameworks', ['reactjs']),
      ])
        Skill(id: id, name: name, category: category, aliases: aliases),
    ];
    final names = {for (final s in fixed) s.name};
    return [
      ...fixed,
      for (final (name, category, aliases) in seedTaxonomy)
        if (!names.contains(name))
          Skill(
            id: name.toLowerCase(),
            name: name,
            category: category,
            aliases: aliases,
          ),
    ];
  }

  static List<JobCard> get deck => [
    for (final (i, title, remote, location, type, salary, sponsor, score) in [
      (
        1,
        'Mobile Engineer (Flutter)',
        'hybrid',
        'Baton Rouge, LA',
        'full_time',
        120000,
        false,
        92,
      ),
      (
        2,
        'Flutter Developer',
        'remote',
        'United States',
        'full_time',
        140000,
        true,
        84,
      ),
      (
        3,
        'Frontend Engineer',
        'onsite',
        'Austin, TX',
        'contract',
        110000,
        false,
        76,
      ),
      (
        4,
        'Junior App Developer',
        'remote',
        'United States',
        'part_time',
        70000,
        false,
        62,
      ),
      (
        5,
        'Software Engineering Intern',
        'onsite',
        'Baton Rouge, LA',
        'internship',
        50000,
        true,
        47,
      ),
    ])
      JobCard.fromJson({
        ...job.toJson(),
        'job_id': '41000000-0000-0000-0000-00000000000$i',
        'title': title,
        'company': {
          'id': 'demo-company-$i',
          'name': [
            'Pelican Path Health',
            'Northline Labs',
            'Cedar Studio',
            'Orbit Works',
            'Mosaic Tech',
          ][i - 1],
          'verified': i.isOdd,
        },
        'remote': remote,
        'location': location,
        'job_type': type,
        'salary_min': salary - 20000,
        'salary_max': salary,
        'sponsorship': sponsor,
        'match_score': score,
        'band': ScoreBand.fromScore(score).db,
        'top_matches': ['Flutter', 'Dart', 'Riverpod'],
        'gaps': i > 2 ? ['Accessibility', 'Kotlin'] : <String>[],
      }),
  ];

  static Skill get skill => Skill.fromJson({
    'id': 'flutter',
    'name': 'Flutter',
    'category': 'Frameworks',
    'aliases': ['flutter sdk'],
  });
  static CandidateSkill get candidateSkill => CandidateSkill.fromJson({
    'id': 'candidate-flutter',
    'profile_version_id': versionId,
    'skill_id': 'flutter',
    'raw_name': 'Flutter',
    'years': 3,
    'evidence': 'Built Flutter applications.',
    'source': 'ai',
  });
  static ProfileVersion get version => ProfileVersion.fromJson({
    'id': versionId,
    'candidate_id': candidateId,
    'resume_id': null,
    'version': 1,
    'source': 'manual',
    'confirmed': false,
    'confirmed_at': null,
    'total_years': 3,
    'education': [],
    'created_at': date.toIso8601String(),
    'candidate_skills': [candidateSkill.toJson()],
  });
  static BreakdownItem get breakdown => BreakdownItem.fromJson({
    'skill_id': 'flutter',
    'name': 'Flutter',
    'category': 'Frameworks',
    'required': true,
    'weight': 2,
    'min_years': 3,
    'candidate_years': 3,
    'matched_via': 'exact',
    'coverage': 1,
    'depth': 1,
    'score': 1,
  });
  static JobCard get job => JobCard.fromJson({
    'job_id': jobId,
    'title': 'Mobile Engineer (Flutter)',
    'company': {
      'id': 'demo-company',
      'name': 'Pelican Path Health',
      'verified': true,
    },
    'location': 'Baton Rouge, LA',
    'remote': 'hybrid',
    'job_type': 'full_time',
    'sponsorship': false,
    'salary_min': 95000,
    'salary_max': 120000,
    'published_at': date.toIso8601String(),
    'match_score': 92,
    'band': 'Strong',
    'top_matches': ['Flutter'],
    'gaps': [],
    'required_gaps': [],
    'breakdown': [breakdown.toJson()],
  });
  static List<Application> get applications => [
    for (final status in ApplicationStatus.values)
      Application.fromJson({
        'id': '50000000-0000-0000-0000-00000000000${status.index + 1}',
        'candidate_id': candidateId,
        'job_id': jobId,
        'profile_version_id': versionId,
        'status': status.toDb(),
        'match_score': 92,
        'breakdown': [breakdown.toJson()],
        'scoring_version': 'v2',
        'committed_at': date.toIso8601String(),
        'created_at': date.toIso8601String(),
        'updated_at': date.toIso8601String(),
        'job_title': 'Mobile Engineer (Flutter)',
        'company_name': 'Pelican Path Health',
        'company_verified': true,
      }),
  ];
}
