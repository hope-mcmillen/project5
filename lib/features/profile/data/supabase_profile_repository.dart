import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/candidate_models.dart';
import 'profile_repository.dart';

/// [ProfileRepository] backed by `profile_versions` (RLS: own rows only) and
/// A's profile RPCs. `confirm_profile` sets `candidates.active_version_id`,
/// which is what lets the route guard finish onboarding.
class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  static const _columns =
      'id, candidate_id, resume_id, version, source, confirmed, confirmed_at, '
      'total_years, education, created_at, '
      'candidate_skills(*), candidate_experiences(*)';

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const AppFailure('not_authenticated');
    return id;
  }

  Future<ProfileVersion> _version(String id) async => ProfileVersion.fromJson(
    await _client
        .from('profile_versions')
        .select(_columns)
        .eq('id', id)
        .single(),
  );

  @override
  Future<ProfileVersion?> latestVersion() => _guard(() async {
    final row = await _client
        .from('profile_versions')
        .select(_columns)
        .eq('candidate_id', _userId)
        .order('version', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : ProfileVersion.fromJson(row);
  });

  @override
  Future<ProfileVersion> createManualProfile() => _guard(() async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'create_manual_profile',
    );
    return ProfileVersion.fromJson(row);
  });

  @override
  Future<ProfileVersion> createReviewDraft() => _guard(() async {
    final row = await _client.rpc<Map<String, dynamic>>('create_review_draft');
    return _version(row['id'] as String);
  });

  @override
  Future<void> confirm(String versionId, List<CandidateSkill> skills) => _guard(
    () => _client.rpc<void>(
      'confirm_profile',
      params: {
        'p_version_id': versionId,
        'p_skills': [
          for (final s in skills)
            {
              'skill_id': s.skillId,
              'raw_name': s.rawName.trim(),
              'years': s.years,
              'evidence': s.evidence,
            },
        ],
      },
    ),
  );

  @override
  Future<Preferences> preferences() => _guard(() async {
    final row = await _client
        .from('candidates')
        .select('preferences')
        .eq('profile_id', _userId)
        .maybeSingle();
    final prefs = row?['preferences'];
    return prefs is Map
        ? Preferences.fromJson(Map<String, dynamic>.from(prefs))
        : Preferences();
  });

  @override
  Future<void> savePreferences(Preferences preferences) => _guard(
    () => _client.rpc<void>(
      'save_preferences',
      params: {'p_prefs': preferences.toJson()},
    ),
  );

  @override
  Future<List<Skill>> searchSkills(String query) => _guard(() async {
    // Strip PostgREST filter syntax characters from user input.
    final text = query.trim().replaceAll(RegExp(r'[,()*{}%\\."]'), ' ').trim();
    if (text.isEmpty) return const [];
    final rows = await _client
        .from('skills')
        .select('id, name, category, aliases')
        .or('name.ilike.%$text%,aliases.cs.{"${text.toLowerCase()}"}')
        .order('name')
        .limit(20);
    return List.unmodifiable(rows.map(Skill.fromJson));
  });
}
