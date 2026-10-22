import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/candidate_models.dart';

abstract interface class ApplicationRepository {
  Stream<List<Application>> watchMine();
  Future<Application> get(String id);
  Future<List<StatusEvent>> statusEvents(String applicationId);
  Future<void> withdraw(String id);
}

final applicationRepositoryProvider = Provider<ApplicationRepository>(
  (ref) => throw UnimplementedError(
    'ApplicationRepository: use main_fake.dart until C10.',
  ),
);
