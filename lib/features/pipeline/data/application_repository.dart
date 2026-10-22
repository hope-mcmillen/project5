import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/candidate_models.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/interview_contact.dart';
import 'supabase_application_repository.dart';

abstract interface class ApplicationRepository {
  bool get isDemo;
  Stream<List<Application>> watchMine();
  Future<Application> get(String id);
  Future<List<StatusEvent>> statusEvents(String applicationId);
  Future<void> withdraw(String id);
  Future<InterviewContact> contact(String applicationId);
}

final applicationRepositoryProvider = Provider<ApplicationRepository>((ref) {
  final userId = ref.watch(currentUserIdProvider).value;
  return SupabaseApplicationRepository(
    SupabaseApplicationSource(ref.watch(supabaseClientProvider), userId),
  );
});
