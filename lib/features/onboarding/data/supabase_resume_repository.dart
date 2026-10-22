import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/logging/app_log.dart';
import '../../../core/models/candidate_models.dart';
import 'resume_repository.dart';

/// [ResumeRepository] backed by B's `parse-resume` Edge Function.
///
/// The file is sent once and read in memory on the server; it is never
/// uploaded to Storage. Only the experiences and skills it finds are saved,
/// as a draft profile version. Progress arrives as server-sent events where
/// the platform streams responses; on web the steps arrive together when the
/// request finishes. Request errors end the parse as FAILED, so the progress
/// screen always offers "Try another file" and "Add skills manually".
class SupabaseResumeRepository implements ResumeRepository {
  SupabaseResumeRepository(this._client);

  final SupabaseClient _client;
  final Map<String, Resume> _resumes = {};
  final _updates = StreamController<Resume>.broadcast(sync: true);
  int _sequence = 0;

  @override
  Future<Resume> upload({
    required String filename,
    required Uint8List bytes,
    String? fileHash,
  }) async {
    // The function checks the JWT; a signed-out call ends FAILED (unauthorized).
    final userId = _client.auth.currentUser?.id ?? '';
    final id = 'parse-${DateTime.now().microsecondsSinceEpoch}-${++_sequence}';
    final resume = Resume(
      id: id,
      candidateId: userId,
      status: ResumeStatus.uploaded,
      fileHash: fileHash,
    );
    _resumes[id] = resume;
    unawaited(_parse(id, filename, bytes));
    return resume;
  }

  Future<void> _parse(String id, String filename, Uint8List bytes) async {
    // Sending the file is the start of reading it.
    _set(id, ResumeStatus.parsingLayout);
    try {
      final response = await _client.functions.invoke(
        'parse-resume',
        headers: {'Accept': 'text/event-stream'},
        files: [MultipartFile.fromBytes('file', bytes, filename: filename)],
      );
      final data = response.data;
      if (data is Map) {
        _apply(id, Map<String, dynamic>.from(data));
      } else if (data is Stream<List<int>>) {
        final lines = data
            .transform(utf8.decoder)
            .transform(const LineSplitter());
        await for (final line in lines) {
          if (!line.startsWith('data:')) continue;
          final event = jsonDecode(line.substring(5).trim());
          if (event is Map) _apply(id, Map<String, dynamic>.from(event));
        }
      }
      // The stream ended without a result (connection dropped mid-parse).
      if (!_finished(id)) {
        _set(id, ResumeStatus.failed, failureReason: 'network');
      }
    } catch (error) {
      if (_finished(id)) return;
      final code = AppFailure.from(error).code;
      _set(
        id,
        ResumeStatus.failed,
        failureReason: const {'function_error', 'unknown'}.contains(code)
            ? 'network'
            : code,
      );
    }
  }

  void _apply(String id, Map<String, dynamic> event) {
    final status = ResumeStatus.values
        .where((s) => s.toDb() == event['status'])
        .firstOrNull;
    if (status == null || _finished(id)) return;
    _set(
      id,
      status,
      failureReason: event['failure_reason'] as String?,
      profileVersionId: event['profile_version_id'] as String?,
    );
  }

  bool _finished(String id) => switch (_resumes[id]?.status) {
    ResumeStatus.ready || ResumeStatus.failed => true,
    _ => false,
  };

  void _set(
    String id,
    ResumeStatus status, {
    String? failureReason,
    String? profileVersionId,
  }) {
    final previous = _resumes[id];
    if (previous == null || _updates.isClosed) return;
    final resume = Resume(
      id: id,
      candidateId: previous.candidateId,
      status: status,
      fileHash: previous.fileHash,
      failureReason: status == ResumeStatus.failed
          ? failureReason ?? 'internal'
          : null,
      profileVersionId: profileVersionId,
    );
    _resumes[id] = resume;
    AppLog.event('resume', 'parse $id → ${status.toDb()}', {
      'failure_reason': ?resume.failureReason,
      'profile_version_id': ?profileVersionId,
    });
    _updates.add(resume);
  }

  @override
  Stream<Resume> watchStatus(String resumeId) => Stream.multi((sink) {
    final subscription = _updates.stream
        .where((r) => r.id == resumeId)
        .listen(sink.add, onError: sink.addError);
    final current = _resumes[resumeId];
    if (current == null) {
      sink.addError(const AppFailure('not_found'));
    } else {
      sink.add(current);
    }
    sink.onCancel = subscription.cancel;
  });

  Future<void> dispose() => _updates.close();
}
