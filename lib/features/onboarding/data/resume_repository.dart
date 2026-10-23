import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/candidate_models.dart';
import '../../../core/supabase/supabase_providers.dart';
import 'supabase_resume_repository.dart';

abstract interface class ResumeRepository {
  /// Starts reading the file. The returned resume's progress comes from
  /// [watchStatus]; the file itself is never stored.
  Future<Resume> upload({
    required String filename,
    required Uint8List bytes,
    String? fileHash,
  });
  Stream<Resume> watchStatus(String resumeId);
}

/// The UI labels simulated reading explicitly. Real integrations leave this false.
final resumeSimulationProvider = Provider<bool>((ref) => false);

/// Kept for the whole session: a parse keeps running while the user moves
/// between the upload and progress screens. Fake mode overrides this.
final resumeRepositoryProvider = Provider<ResumeRepository>((ref) {
  final repository = SupabaseResumeRepository(
    ref.watch(supabaseClientProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});
