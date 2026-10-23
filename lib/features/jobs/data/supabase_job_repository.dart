import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/job_status.dart';
import '../domain/job.dart';
import '../domain/job_summary.dart';
import '../domain/requirement.dart';
import 'job_repository.dart';

/// [JobRepository] backed by the `jobs` tables, the A8 job RPCs and B's
/// `parse-job` Edge Function.
class SupabaseJobRepository implements JobRepository {
  SupabaseJobRepository(this._client);

  final SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<List<JobSummary>> list() => _guard(() async {
    // security_invoker view: RLS limits it to the caller's company.
    final rows = await _client
        .from('company_jobs_overview')
        .select()
        .order('published_at', ascending: false, nullsFirst: true);
    return rows.map(JobSummary.fromJson).toList();
  });

  @override
  Future<Job> get(String id) => _guard(() async {
    final row = await _client
        .from('jobs')
        .select(Job.columns)
        .eq('id', id)
        .maybeSingle();
    if (row == null) throw const AppFailure('job_not_found', 'Job not found.');
    return Job.fromJson(row);
  });

  @override
  Future<String> createDraft(String rawDescription) => _guard(() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const AppFailure('not_authenticated');
    final companyId = await _client.rpc<String?>('my_company_id');
    if (companyId == null) throw const AppFailure('not_recruiter');
    final row = await _client
        .from('jobs')
        .insert({
          'company_id': companyId,
          'created_by': userId,
          'raw_description': rawDescription,
        })
        .select('id')
        .single();
    return row['id'] as String;
  });

  @override
  Future<ParseJobResult> parse(String jobId) => _guard(() async {
    final response = await _client.functions.invoke(
      'parse-job',
      body: {'job_id': jobId},
    );
    return ParseJobResult.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  });

  @override
  Stream<Job> watch(String jobId) {
    RealtimeChannel? channel;
    late final StreamController<Job> controller;
    controller = StreamController<Job>(
      onListen: () async {
        channel = _client
            .channel('job:$jobId')
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'jobs',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'id',
                value: jobId,
              ),
              callback: (payload) =>
                  controller.add(Job.fromJson(payload.newRecord)),
            )
            .subscribe();
        try {
          controller.add(await get(jobId));
        } catch (error) {
          controller.addError(error);
        }
      },
      onCancel: () async {
        final current = channel;
        if (current != null) await _client.removeChannel(current);
      },
    );
    return controller.stream;
  }

  @override
  Future<List<RequirementDraft>> requirements(String jobId) => _guard(() async {
    final rows = await _client
        .from('job_requirements')
        .select(
          'skill_id, required, min_years, weight, evidence, '
          'skills(name, category)',
        )
        .eq('job_id', jobId)
        .order('required', ascending: false);
    return rows.map(RequirementDraft.fromJson).toList();
  });

  @override
  Future<void> saveRequirements(String jobId, List<RequirementDraft> items) =>
      _guard(
        () => _client.rpc<void>(
          'save_requirements',
          params: {
            'p_job_id': jobId,
            'p_requirements': [for (final item in items) item.toRpc()],
          },
        ),
      );

  @override
  Future<void> update(String jobId, JobDetailsInput details) => _guard(
    () => _client.from('jobs').update(details.toJson()).eq('id', jobId),
  );

  @override
  Future<void> setStatus(String id, JobStatus status) => _guard(
    () => _client.rpc<void>(
      'set_job_status',
      params: {'p_job_id': id, 'p_status': status.toDb()},
    ),
  );

  @override
  Future<void> deleteDraft(String jobId) => _guard(
    () => _client.rpc<void>('delete_draft_job', params: {'p_job_id': jobId}),
  );

  @override
  Future<List<SkillRef>> searchSkills(String query) => _guard(() async {
    // Strip PostgREST filter syntax characters from user input.
    final text = query.trim().replaceAll(RegExp(r'[,()*{}%\\."]'), ' ').trim();
    if (text.isEmpty) return const [];
    final rows = await _client
        .from('skills')
        .select('id, name, category')
        .or('name.ilike.%$text%,aliases.cs.{"${text.toLowerCase()}"}')
        .order('name')
        .limit(20);
    return rows.map(SkillRef.fromJson).toList();
  });
}
