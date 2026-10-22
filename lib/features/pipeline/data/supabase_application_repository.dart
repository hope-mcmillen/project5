import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/candidate_models.dart';
import '../domain/interview_contact.dart';
import 'application_repository.dart';

/// Boundary kept separate so live refresh and errors can be tested offline.
abstract interface class ApplicationSource {
  Stream<void> changes();
  Future<List<Map<String, dynamic>>> applications();
  Future<List<Map<String, dynamic>>> events(String id);
  Future<Map<String, dynamic>> contact(String id);
  Future<void> withdraw(String id);
}

class SupabaseApplicationSource implements ApplicationSource {
  SupabaseApplicationSource(this.client, this.userId);
  final SupabaseClient client;
  final String? userId;
  @override
  Stream<void> changes() => userId == null
      ? Stream.value(null)
      : client
            .from('applications')
            .stream(primaryKey: ['id'])
            .eq('candidate_id', userId!)
            .map((_) {});
  @override
  Future<List<Map<String, dynamic>>> applications() async => userId == null
      ? []
      : await client
            .from('my_applications')
            .select()
            .order('updated_at', ascending: false);
  @override
  Future<List<Map<String, dynamic>>> events(String id) async => await client
      .from('status_events')
      .select()
      .eq('application_id', id)
      .order('created_at')
      .order('id');
  @override
  Future<Map<String, dynamic>> contact(String id) async =>
      Map<String, dynamic>.from(
        await client.rpc(
          'get_application_contact',
          params: {'p_application_id': id},
        ) as Map,
      );
  @override
  Future<void> withdraw(String id) async =>
      await client.rpc('withdraw', params: {'p_application_id': id});
}

class SupabaseApplicationRepository implements ApplicationRepository {
  SupabaseApplicationRepository(this.source);
  final ApplicationSource source;
  @override
  bool get isDemo => false;
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      final failure = AppFailure.from(error);
      throw switch (failure.code) {
        'not_owner' => const AppFailure(
          'not_owner',
          'This application is no longer available to your account.',
        ),
        'not_candidate' => const AppFailure(
          'not_candidate',
          'Sign in with a candidate account to manage applications.',
        ),
        'contact_not_available' => const AppFailure(
          'contact_not_available',
          'Recruiter contact details are not available for this application.',
        ),
        _ => failure,
      };
    }
  }

  @override
  Stream<List<Application>> watchMine() => Stream.multi((sink) {
    var disposed = false, loading = false, dirty = false, done = false;
    Future<void> refresh() async {
      dirty = true;
      if (loading) return;
      loading = true;
      // Serialize refreshes, coalescing bursts, so older responses cannot replace
      // newer statuses. A new event during a fetch always triggers another read.
      while (dirty && !disposed) {
        dirty = false;
        try {
          final rows = await source.applications();
          if (!disposed) {
            sink.add(
              List.unmodifiable(
                rows.map(Application.fromJson).toList()
                  ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
              ),
            );
          }
        } catch (error, stack) {
          if (!disposed) sink.addError(AppFailure.from(error), stack);
        }
      }
      loading = false;
      if (done && !disposed) sink.close();
    }

    final subscription = source.changes().listen(
      (_) => refresh(),
      onError: (Object error, StackTrace stack) {
        if (!disposed) sink.addError(AppFailure.from(error), stack);
      },
      onDone: () {
        done = true;
        if (!loading && !disposed) sink.close();
      },
    );
    sink.onCancel = () {
      disposed = true;
      return subscription.cancel();
    };
  });

  @override
  Future<Application> get(String id) => _guard(() async {
    final rows = await source.applications();
    final row = rows.where((r) => r['id'] == id).firstOrNull;
    if (row == null) {
      throw const AppFailure(
        'not_found',
        'This application is no longer available.',
      );
    }
    return Application.fromJson(row);
  });
  @override
  Future<List<StatusEvent>> statusEvents(String id) => _guard(
    () async => (await source.events(id)).map(StatusEvent.fromJson).toList(),
  );
  @override
  Future<InterviewContact> contact(String id) =>
      _guard(() async => InterviewContact.fromJson(await source.contact(id)));
  @override
  Future<void> withdraw(String id) => _guard(() => source.withdraw(id));
}
