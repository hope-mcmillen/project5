import '../../../core/errors/app_failure.dart';
import '../../../core/models/candidate_models.dart';
import '../../../core/testing/candidate_fixtures.dart';
import '../../../core/testing/fake_repository.dart';
import 'profile_repository.dart';

class FakeProfileRepository extends FakeRepository
    implements ProfileRepository {
  FakeProfileRepository({
    super.latency,
    ProfileVersion? version,
    List<Skill>? skills,
    bool seedData = true,
  }) : _version = version ?? (seedData ? CandidateFixtures.version : null),
       _skills = List.of(skills ?? CandidateFixtures.taxonomy);
  ProfileVersion? _version;
  final List<Skill> _skills;
  Preferences _preferences = Preferences();

  @override
  Future<ProfileVersion?> latestVersion() async {
    await call();
    return _version;
  }

  @override
  Future<ProfileVersion> createManualProfile() async {
    await call();
    final next = (_version?.version ?? 0) + 1;
    return _version = ProfileVersion(
      id: 'manual-$next',
      candidateId: CandidateFixtures.candidateId,
      version: next,
      source: ProfileSource.manual,
      confirmed: false,
      createdAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<ProfileVersion> createReviewDraft() async {
    final previous = _version;
    final draft = await createManualProfile();
    return _version = ProfileVersion.fromJson({
      ...draft.toJson(),
      'candidate_skills': [
        for (final skill in previous?.candidateSkills ?? <CandidateSkill>[])
          {...skill.toJson(), 'profile_version_id': draft.id},
      ],
      'total_years': previous?.totalYears,
    });
  }

  @override
  Future<void> confirm(String versionId, List<CandidateSkill> skills) async {
    await call();
    final version = _version;
    if (version == null || version.id != versionId) {
      throw const AppFailure('not_owner');
    }
    if (version.confirmed) throw const AppFailure('profile_already_confirmed');
    if (skills.length > 100 ||
        skills.any(
          (s) =>
              s.rawName.trim().isEmpty ||
              s.rawName.length > 120 ||
              (s.years != null && (s.years! < 0 || s.years! > 99.9)),
        ) ||
        skills
                .map((s) => s.skillId ?? s.rawName.trim().toLowerCase())
                .toSet()
                .length !=
            skills.length) {
      throw const AppFailure(
        'invalid_skills',
        'Check skill names and experience before confirming.',
      );
    }
    _version = ProfileVersion.fromJson({
      ...version.toJson(),
      'confirmed': true,
      'confirmed_at': DateTime.now().toUtc().toIso8601String(),
      'candidate_skills': skills.map((s) => s.toJson()).toList(),
    });
  }

  @override
  Future<Preferences> preferences() async {
    await call();
    return _preferences;
  }

  @override
  Future<void> savePreferences(Preferences preferences) async {
    await call();
    _preferences = preferences;
  }

  @override
  Future<List<Skill>> searchSkills(String query) async {
    await call();
    final term = query.trim().toLowerCase();
    return List.unmodifiable(
      _skills
          .where(
            (s) => [
              s.name,
              ...s.aliases,
            ].any((name) => name.toLowerCase().contains(term)),
          )
          .take(20),
    );
  }
}
