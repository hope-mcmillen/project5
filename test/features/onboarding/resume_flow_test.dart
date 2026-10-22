import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:project5/app/app.dart';
import 'package:project5/app/dev_session.dart';
import 'package:project5/app/routes.dart';
import 'package:project5/core/errors/app_failure.dart';
import 'package:project5/core/models/candidate_models.dart';
import 'package:project5/features/onboarding/data/fake_resume_repository.dart';
import 'package:project5/features/onboarding/data/resume_picker.dart';
import 'package:project5/features/onboarding/data/resume_repository.dart';
import 'package:project5/features/onboarding/domain/resume_file.dart';
import 'package:project5/features/onboarding/presentation/upload_controller.dart';
import 'package:project5/features/onboarding/presentation/resume_status_provider.dart';
import 'package:project5/features/profile/data/fake_profile_repository.dart';
import 'package:project5/features/profile/data/profile_repository.dart';
import 'package:project5/ui/components/prism_upload_progress.dart';

import '../../support/fake_scope.dart';

ResumeFile validFile() => ResumeFile.fromBytes(
  name: 'resume.pdf',
  bytes: Uint8List.fromList('%PDF-1.7 demo'.codeUnits),
);

void main() {
  test('cancel ignores a late file selection', () async {
    final picked = Completer<ResumeFile?>();
    final container = ProviderContainer(
      overrides: [resumePickerProvider.overrideWithValue(() => picked.future)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(uploadControllerProvider, (_, _) {});
    addTearDown(subscription.close);
    final controller = container.read(uploadControllerProvider.notifier);
    final pending = controller.chooseFile();
    controller.cancel();
    picked.complete(validFile());
    await pending;
    expect(container.read(uploadControllerProvider).file, isNull);
    expect(container.read(uploadControllerProvider).busy, isFalse);
  });

  test('cancel ignores an upload completing after cancellation', () async {
    final repo = FakeResumeRepository(
      latency: const Duration(milliseconds: 20),
    );
    addTearDown(repo.dispose);
    final container = ProviderContainer(
      overrides: [
        resumePickerProvider.overrideWithValue(() async => validFile()),
        resumeRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(uploadControllerProvider, (_, _) {});
    addTearDown(subscription.close);
    final controller = container.read(uploadControllerProvider.notifier);
    await controller.chooseFile();
    final pending = controller.upload();
    controller.cancel();
    await pending;
    final state = container.read(uploadControllerProvider);
    expect(state.resumeId, isNull);
    expect(state.file, isNull);
    expect(state.busy, isFalse);
    expect(state.error, isNull);
  });

  test(
    'picker cancellation is quiet and repeated requests do not overlap',
    () async {
      final picked = Completer<ResumeFile?>();
      var calls = 0;
      final container = ProviderContainer(
        overrides: [
          resumePickerProvider.overrideWithValue(() {
            calls++;
            return picked.future;
          }),
        ],
      );
      addTearDown(container.dispose);
      final keepAlive = container.listen(uploadControllerProvider, (_, _) {});
      addTearDown(keepAlive.close);
      final controller = container.read(uploadControllerProvider.notifier);
      final pending = controller.chooseFile();
      await controller.chooseFile();
      expect(calls, 1);
      picked.complete(null);
      await pending;
      final state = container.read(uploadControllerProvider);
      expect(state.file, isNull);
      expect(state.error, isNull);
      expect(state.busy, isFalse);
    },
  );

  test('upload sends the file hash, can fail, and can be retried', () async {
    final repo = FakeResumeRepository(latency: Duration.zero);
    addTearDown(repo.dispose);
    final container = ProviderContainer(
      overrides: [
        resumePickerProvider.overrideWithValue(() async => validFile()),
        resumeRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    final keepAlive = container.listen(uploadControllerProvider, (_, _) {});
    addTearDown(keepAlive.close);
    final controller = container.read(uploadControllerProvider.notifier);
    await controller.chooseFile();
    repo.failNext = const AppFailure('network', 'Upload failed. Try again.');
    await controller.upload();
    expect(
      container.read(uploadControllerProvider).error,
      'Upload failed. Try again.',
    );
    await controller.upload();
    final id = container.read(uploadControllerProvider).resumeId!;
    expect((await repo.watchStatus(id).first).fileHash, validFile().fileHash);
  });

  test(
    'invalid selection produces an inline error without uploading',
    () async {
      final container = ProviderContainer(
        overrides: [
          resumePickerProvider.overrideWithValue(
            () async =>
                ResumeFile.fromBytes(name: 'bad.pdf', bytes: Uint8List(10)),
          ),
        ],
      );
      addTearDown(container.dispose);
      final keepAlive = container.listen(uploadControllerProvider, (_, _) {});
      addTearDown(keepAlive.close);
      await container.read(uploadControllerProvider.notifier).chooseFile();
      expect(
        container.read(uploadControllerProvider).error,
        contains('contents do not match'),
      );
      expect(container.read(uploadControllerProvider).file, isNull);
    },
  );

  Future<GoRouter> openResume(
    WidgetTester tester,
    FakeResumeRepository repo, {
    List<Override> overrides = const [],
  }) async {
    final session = DevSession()
      ..signIn(AppRole.candidate)
      ..completeCandidateOnboarding();
    addTearDown(session.dispose);
    await tester.pumpWidget(
      fakeScope(
        ResuRhombusApp(session: session),
        overrides: [
          resumeRepositoryProvider.overrideWithValue(repo),
          resumePickerProvider.overrideWithValue(() async => validFile()),
          ...overrides,
        ],
      ),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.go(Routes.profileResume);
    await tester.pumpAndSettle();
    return router;
  }

  Future<String> selectAndUpload(WidgetTester tester, GoRouter router) async {
    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();
    expect(find.text('resume.pdf'), findsOneWidget);
    await tester.ensureVisible(find.text('Upload resume'));
    await tester.tap(find.text('Upload resume'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(router.state.uri.path, contains('/c/onboarding/progress/'));
    return router.state.pathParameters['resumeId']!;
  }

  testWidgets('skip resume opens the deck and the sidebar can reopen Resume', (
    tester,
  ) async {
    final repo = FakeResumeRepository(latency: Duration.zero);
    addTearDown(repo.dispose);
    final router = await openResume(tester, repo);
    await tester.ensureVisible(find.text('Skip for now'));
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, Routes.deck);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, Routes.profileResume);
    expect(find.byTooltip('Open navigation menu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'selection, reading stages, and ready status reach Review automatically',
    (tester) async {
      final repo = FakeResumeRepository(latency: Duration.zero);
      addTearDown(repo.dispose);
      final router = await openResume(tester, repo);
      final upload = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Upload resume'),
      );
      expect(upload.onPressed, isNull);
      final id = await selectAndUpload(tester, router);
      expect(find.byType(PrismUploadProgress), findsOneWidget);
      for (final (status, label) in [
        (ResumeStatus.parsingLayout, 'Reading your document'),
        (ResumeStatus.extracting, 'Finding your experience'),
        (ResumeStatus.normalizing, 'Organizing your skills'),
      ]) {
        repo.setStatus(id, status);
        await tester.pump();
        expect(find.text(label), findsWidgets);
      }
      repo.setStatus(id, ResumeStatus.ready);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, Routes.candidateReview);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed parsing creates a manual draft before opening Review', (
    tester,
  ) async {
    final repo = FakeResumeRepository(latency: Duration.zero);
    final profiles = FakeProfileRepository(latency: Duration.zero);
    addTearDown(repo.dispose);
    final router = await openResume(
      tester,
      repo,
      overrides: [profileRepositoryProvider.overrideWithValue(profiles)],
    );
    final id = await selectAndUpload(tester, router);
    repo.setStatus(id, ResumeStatus.failed, failureReason: 'unreadable_scan');
    await tester.pumpAndSettle();
    expect(find.textContaining('clearer file'), findsOneWidget);
    profiles.failNext = const AppFailure(
      'offline',
      'Could not start your profile. Try again.',
    );
    await tester.ensureVisible(find.text('Add skills manually'));
    await tester.tap(find.text('Add skills manually'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not start your profile. Try again.'),
      findsOneWidget,
    );
    expect(router.state.uri.path, Routes.parseProgress(id));
    await tester.ensureVisible(find.text('Add skills manually'));
    await tester.tap(find.text('Add skills manually'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, Routes.candidateReview);
    expect((await profiles.latestVersion())!.source, ProfileSource.manual);
  });

  testWidgets('invalid file feedback leaves Upload disabled', (tester) async {
    final repo = FakeResumeRepository(latency: Duration.zero);
    addTearDown(repo.dispose);
    await openResume(
      tester,
      repo,
      overrides: [
        resumePickerProvider.overrideWithValue(
          () async => throw const AppFailure(
            'file_too_large',
            'This file is over 5 MB. Choose a smaller resume.',
          ),
        ),
      ],
    );
    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();
    expect(find.textContaining('over 5 MB'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Upload resume'),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'stalled parsing has a hard timeout and keeps the Profile resume route',
    (tester) async {
      final repo = FakeResumeRepository(latency: Duration.zero);
      addTearDown(repo.dispose);
      final router = await openResume(
        tester,
        repo,
        overrides: [
          resumeParseTimeoutProvider.overrideWithValue(
            const Duration(milliseconds: 500),
          ),
        ],
      );
      await selectAndUpload(tester, router);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.textContaining('took too long'), findsOneWidget);
      await tester.tap(find.text('Try another file'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, Routes.profileResume);
      expect(find.byTooltip('Open navigation menu'), findsOneWidget);
    },
  );

  testWidgets('leaving during upload does not navigate after completion', (
    tester,
  ) async {
    final repo = FakeResumeRepository(latency: const Duration(seconds: 1));
    addTearDown(repo.dispose);
    final router = await openResume(tester, repo);
    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Upload resume'));
    await tester.tap(find.text('Upload resume'));
    await tester.pump();
    router.go(Routes.pipeline);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    expect(router.state.uri.path, Routes.pipeline);
    expect(tester.takeException(), isNull);
  });
}
