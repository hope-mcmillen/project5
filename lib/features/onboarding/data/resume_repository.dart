import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/candidate_models.dart';

abstract interface class ResumeRepository {
  Future<Resume> upload({
    required String filename,
    required Uint8List bytes,
    String? fileHash,
  });
  Stream<Resume> watchStatus(String resumeId);
}

/// The UI labels simulated reading explicitly. Real integrations leave this false.
final resumeSimulationProvider = Provider<bool>((ref) => false);

final resumeRepositoryProvider = Provider<ResumeRepository>(
  (ref) => throw UnimplementedError(
    'ResumeRepository: use main_fake.dart until C5.',
  ),
);
