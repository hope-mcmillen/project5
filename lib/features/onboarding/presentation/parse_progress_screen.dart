import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/candidate_models.dart';
import '../../../ui/components/branded_page.dart';
import '../../../ui/components/error_banner.dart';
import '../../../ui/components/prism_upload_progress.dart';
import '../../../ui/components/shimmer_shape.dart';
import '../../../ui/theme/rr_tokens.dart';
import '../../profile/data/profile_repository.dart';
import '../data/resume_repository.dart';
import 'onboarding_sign_out.dart';
import 'resume_status_provider.dart';

class ParseProgressScreen extends ConsumerStatefulWidget {
  const ParseProgressScreen({super.key, required this.resumeId});
  final String resumeId;
  @override
  ConsumerState<ParseProgressScreen> createState() =>
      _ParseProgressScreenState();
}

class _ParseProgressScreenState extends ConsumerState<ParseProgressScreen> {
  bool _navigated = false, _manualBusy = false;
  String? _manualError;

  @override
  void didUpdateWidget(ParseProgressScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resumeId != widget.resumeId) _navigated = false;
  }

  String get _uploadRoute =>
      GoRouterState.of(context).uri.queryParameters['returnTo'] ==
          Routes.profileResume
      ? Routes.profileResume
      : Routes.candidateUpload;

  Future<void> _manual() async {
    if (_manualBusy) return;
    setState(() {
      _manualBusy = true;
      _manualError = null;
    });
    try {
      await ref.read(profileRepositoryProvider).createManualProfile();
      if (mounted) context.go(Routes.candidateReview);
    } catch (error) {
      if (mounted) {
        setState(
          () => _manualError = error is AppFailure
              ? error.message
              : 'We could not start your profile. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _manualBusy = false);
    }
  }

  static String _failureMessage(String? reason) => switch (reason) {
    'timeout' => 'Reading your resume took too long. Try another file or add your skills manually.',
    'unreadable_scan' => 'We could not read the text in this resume. Try a clearer file or add your skills manually.',
    'too_long' => 'This resume is too long to read. Try a shorter version or add your skills manually.',
    'budget_exceeded' => 'Resume reading is temporarily unavailable. You can add your skills manually.',
    'network' => 'We could not reach the server to read your resume. Check your connection and try again.',
    'invalid_file' => 'This file is not a PDF or DOCX we can read. Try another file or add your skills manually.',
    'not_candidate' => 'Only candidate accounts can read a resume.',
    _ => 'We could not read this resume. Try another file or add your skills manually.',
  };

  Widget _failure(String message, {bool retryStatus = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ErrorBanner(message: message),
      const SizedBox(height: RRSpace.lg),
      if (_manualError != null) ...[
        ErrorBanner(message: _manualError!),
        const SizedBox(height: RRSpace.lg),
      ],
      FilledButton(
        onPressed: _manualBusy ? null : () => context.go(_uploadRoute),
        child: const Text('Try another file'),
      ),
      const SizedBox(height: RRSpace.md),
      OutlinedButton(
        onPressed: _manualBusy ? null : _manual,
        child: Text(
          _manualBusy ? 'Preparing your profile…' : 'Add skills manually',
        ),
      ),
      if (retryStatus) ...[
        const SizedBox(height: RRSpace.md),
        TextButton(
          onPressed: _manualBusy
              ? null
              : () => ref.invalidate(resumeStatusProvider(widget.resumeId)),
          child: const Text('Retry progress'),
        ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(resumeStatusProvider(widget.resumeId));
    ref.listen(resumeStatusProvider(widget.resumeId), (previous, next) {
      if (next.asData?.value.status != ResumeStatus.ready || _navigated) return;
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(Routes.candidateReview);
      });
    });
    final resume = status.asData?.value;
    final text = Theme.of(context).textTheme;
    final Widget content;
    if (status.hasError) {
      final error = status.error;
      content = _failure(
        error is AppFailure && error.code == 'parse_timeout' ? error.message : 'We could not get your resume progress. Retry or choose another file.',
        retryStatus: true,
      );
    } else if (resume == null) {
      content = const Column(
        children: [
          ShimmerShape(),
          SizedBox(height: RRSpace.lg),
          Text('Getting your resume ready…'),
        ],
      );
    } else if (resume.status == ResumeStatus.failed) {
      content = _failure(_failureMessage(resume.failureReason));
    } else {
      const steps = [
        'Resume uploaded',
        'Reading your document',
        'Finding your experience',
        'Organizing your skills',
        'Ready to review',
      ];
      final index = switch (resume.status) {
        ResumeStatus.uploaded => 0,
        ResumeStatus.parsingLayout => 1,
        ResumeStatus.extracting => 2,
        ResumeStatus.normalizing => 3,
        _ => 4,
      };
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrismUploadProgress(status: resume.status),
          Semantics(
            liveRegion: true,
            child: Text(steps[index], style: text.titleLarge),
          ),
          const SizedBox(height: RRSpace.sm),
          Text(
            'Step ${index + 1} of ${steps.length}',
            style: text.bodyMedium?.copyWith(color: RRColors.inkMuted),
          ),
          const SizedBox(height: RRSpace.lg),
          LinearProgressIndicator(
            value: (index + 1) / steps.length,
            semanticsLabel:
                'Resume preparation, step ${index + 1} of ${steps.length}',
          ),
          const SizedBox(height: RRSpace.xl),
          for (final (step, label) in steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: RRSpace.lg),
              child: Row(
                children: [
                  Icon(
                    step < index
                        ? Icons.check_circle
                        : step == index
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: step <= index
                        ? RRColors.matchStrong
                        : RRColors.inkMuted,
                  ),
                  const SizedBox(width: RRSpace.md),
                  Expanded(
                    child: Text(
                      label,
                      style: text.bodyMedium?.copyWith(
                        fontWeight: step == index
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (ref.watch(resumeSimulationProvider))
            Text(
              'Demo mode · Reading is simulated. No resume data is sent to a server.',
              style: text.bodySmall?.copyWith(color: RRColors.inkMuted),
            ),
          const SizedBox(height: RRSpace.lg),
          OutlinedButton(
            onPressed: () => context.go(_uploadRoute),
            child: const Text('Back to resume'),
          ),
        ],
      );
    }
    return BrandedPage(
      title: 'Reading your resume',
      actions: const [OnboardingSignOutAction()],
      description: 'Follow each step as we prepare your experience for review.',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(RRSpace.xl),
          child: content,
        ),
      ),
    );
  }
}
