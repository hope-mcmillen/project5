import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/url_opener.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/candidate_models.dart';
import '../../../ui/components/branded_page.dart';
import '../../../ui/components/error_banner.dart';
import '../../../ui/components/shimmer_shape.dart';
import '../../../ui/components/status_chip.dart';
import '../../../ui/components/pipeline_timeline.dart';
import '../../../ui/theme/rr_tokens.dart';
import '../data/application_repository.dart';
import '../domain/interview_contact.dart';
import 'pipeline_providers.dart';

class ApplicationDetailScreen extends ConsumerWidget {
  const ApplicationDetailScreen({super.key, required this.applicationId});
  final String applicationId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(myApplicationsProvider);
    final application = list.asData?.value
        .where((a) => a.id == applicationId)
        .firstOrNull;
    final action = ref.watch(withdrawalProvider(applicationId));
    return BrandedPage(
      title: 'Application',
      description: ref.watch(applicationRepositoryProvider).isDemo
          ? 'Review this application and its progress. Local demo data.'
          : 'Follow your application and reach your recruiter.',
      footer: application != null && canWithdraw(application)
          ? OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: RRColors.pass),
              onPressed: action.isLoading
                  ? null
                  : () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialog) => AlertDialog(
                          title: const Text('Withdraw application?'),
                          content: Text(
                            'Withdraw your application for ${application.jobTitle ?? 'this role'}? It will remain in your history as withdrawn.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialog, false),
                              child: const Text('Keep application'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(dialog, true),
                              child: const Text('Withdraw'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && context.mounted) {
                        await ref
                            .read(withdrawalProvider(applicationId).notifier)
                            .withdraw();
                      }
                    },
              icon: const Icon(Icons.undo),
              label: Text(
                action.isLoading ? 'Withdrawing…' : 'Withdraw application',
              ),
            )
          : null,
      child: list.when(
        loading: () => const ShimmerShape(height: 200),
        error: (_, _) => Column(
          children: [
            const ErrorBanner(message: 'We could not load this application.'),
            TextButton(
              onPressed: () => ref.invalidate(myApplicationsProvider),
              child: const Text('Retry application'),
            ),
          ],
        ),
        data: (_) {
          if (application == null) {
            return Column(
              children: [
                const Text('This application is no longer available.'),
                TextButton(
                  onPressed: () => context.go(Routes.pipeline),
                  child: const Text('Back to applications'),
                ),
              ],
            );
          }
          final revision = (
            id: applicationId,
            updatedAt: application.updatedAt,
            status: application.status,
          );
          final timeline = ref.watch(applicationTimelineProvider(revision));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (action.hasError) ...[
                ErrorBanner(message: AppFailure.from(action.error!).message),
                const SizedBox(height: RRSpace.lg),
              ],
              Text(
                application.jobTitle ?? 'Job application',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: RRSpace.sm),
              Text(application.companyName ?? 'Company'),
              const SizedBox(height: RRSpace.md),
              Semantics(
                liveRegion: true,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: StatusChip(status: application.status),
                ),
              ),
              const SizedBox(height: RRSpace.sm),
              Text(
                'Applied ${applicationDate(context, application.createdAt)}',
              ),
              if (hasNoResponse(application, DateTime.now()))
                const Padding(
                  padding: EdgeInsets.only(top: RRSpace.md),
                  child: Text(
                    'No response yet. The recruiter has not reviewed your application.',
                  ),
                ),
              const SizedBox(height: RRSpace.xl),
              if (application.status ==
                  ApplicationStatus.interviewRequested) ...[
                _InterviewContact(revision: revision),
                const SizedBox(height: RRSpace.xl),
              ],
              Text(
                'Application timeline',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: RRSpace.lg),
              AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : RRMotion.medium,
                child: timeline.when(
                  loading: () => const ShimmerShape(height: 120),
                  error: (_, _) => Column(
                    children: [
                      const ErrorBanner(
                        message: 'We could not load the timeline.',
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(
                          applicationTimelineProvider(revision),
                        ),
                        child: const Text('Retry timeline'),
                      ),
                    ],
                  ),
                  data: (events) => PipelineTimeline(
                    key: ValueKey(revision),
                    application: application,
                    events: events,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InterviewContact extends ConsumerWidget {
  const _InterviewContact({required this.revision});
  final ApplicationRevision revision;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: Padding(
      padding: const EdgeInsets.all(RRSpace.lg),
      child: ref
          .watch(interviewContactProvider(revision))
          .when(
            loading: () => const ShimmerShape(height: 120),
            error: (error, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ErrorBanner(
                  message:
                      error is AppFailure &&
                          error.code == 'contact_not_available'
                      ? 'Recruiter contact details are not available for this application.'
                      : 'We could not load the recruiter contact details.',
                ),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(interviewContactProvider(revision)),
                  child: const Text('Retry contact details'),
                ),
              ],
            ),
            data: (contact) => _contact(context, ref, contact),
          ),
    ),
  );
  Widget _contact(
    BuildContext context,
    WidgetRef ref,
    InterviewContact contact,
  ) {
    final email = contact.email?.trim();
    final validEmail =
        email != null && RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Interview contact',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: RRSpace.md),
        SelectableText(
          contact.name?.trim().isNotEmpty == true ? contact.name! : 'Recruiter',
        ),
        if (validEmail)
          SelectableText(email)
        else
          const Text('No recruiter email address is available yet.'),
        if (contact.note?.trim().isNotEmpty == true) ...[
          const SizedBox(height: RRSpace.lg),
          Text(
            'Recruiter note',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SelectableText(contact.note!),
        ],
        const SizedBox(height: RRSpace.lg),
        Wrap(
          spacing: RRSpace.md,
          runSpacing: RRSpace.sm,
          children: [
            OutlinedButton.icon(
              onPressed: !validEmail
                  ? null
                  : () async {
                      try {
                        await Clipboard.setData(ClipboardData(text: email));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Recruiter email copied.'),
                            ),
                          );
                        }
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Could not copy the email address.',
                              ),
                            ),
                          );
                        }
                      }
                    },
              icon: const Icon(Icons.copy),
              label: const Text('Copy email'),
            ),
            FilledButton.icon(
              onPressed: !validEmail
                  ? null
                  : () async {
                      try {
                        final opened = await ref.read(urlOpenerProvider)(
                          Uri(scheme: 'mailto', path: email),
                        );
                        if (!opened) throw const AppFailure('no_email_app');
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Could not open an email app. Copy the address instead.',
                              ),
                            ),
                          );
                        }
                      }
                    },
              icon: const Icon(Icons.email_outlined),
              label: const Text('Email recruiter'),
            ),
          ],
        ),
      ],
    );
  }
}
