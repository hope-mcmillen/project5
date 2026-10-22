import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/candidate_models.dart';
import '../data/application_repository.dart';
import '../domain/interview_contact.dart';

final myApplicationsProvider = StreamProvider.autoDispose<List<Application>>(
  (ref) => ref.watch(applicationRepositoryProvider).watchMine(),
  retry: noAutomaticRetry,
);

typedef ApplicationRevision = ({
  String id,
  DateTime updatedAt,
  ApplicationStatus status,
});
final applicationTimelineProvider = FutureProvider.autoDispose
    .family<List<StatusEvent>, ApplicationRevision>(
      (ref, revision) =>
          ref.watch(applicationRepositoryProvider).statusEvents(revision.id),
      retry: noAutomaticRetry,
    );
final interviewContactProvider = FutureProvider.autoDispose
    .family<InterviewContact, ApplicationRevision>(
      (ref, revision) =>
          ref.watch(applicationRepositoryProvider).contact(revision.id),
      retry: noAutomaticRetry,
    );

bool canWithdraw(Application application) => {
  ApplicationStatus.applied,
  ApplicationStatus.underReview,
  ApplicationStatus.interviewRequested,
}.contains(application.status);
bool hasNoResponse(Application application, DateTime now) =>
    application.status == ApplicationStatus.applied &&
    now.toUtc().difference(application.createdAt.toUtc()) >=
        const Duration(days: 21);

final withdrawalProvider = NotifierProvider.autoDispose
    .family<WithdrawalController, AsyncValue<void>, String>(
      WithdrawalController.new,
    );

class WithdrawalController extends Notifier<AsyncValue<void>> {
  WithdrawalController(this.id);
  final String id;
  @override
  AsyncValue<void> build() => const AsyncData(null);
  Future<void> withdraw() async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    try {
      await ref.read(applicationRepositoryProvider).withdraw(id);
      if (!ref.mounted) return;
      state = const AsyncData(null);
      // Refresh even if the socket is reconnecting or a notification is delayed.
      ref.invalidate(myApplicationsProvider);
    } catch (error, stack) {
      if (ref.mounted) state = AsyncError(AppFailure.from(error), stack);
    }
  }
}
