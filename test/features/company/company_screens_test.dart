import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:project5/app/app.dart';
import 'package:project5/app/fake_overrides.dart';
import 'package:project5/app/routes.dart';
import 'package:project5/core/errors/app_failure.dart';
import 'package:project5/core/models/app_role.dart';
import 'package:project5/features/auth/data/fake_auth_repository.dart';
import 'package:project5/features/company/data/fake_company_repository.dart';
import 'package:project5/features/company/data/logo_picker.dart';
import 'package:project5/features/company/domain/company.dart';
import 'package:project5/features/company/domain/logo_image.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeCompanyRepository companies;
  PickedLogo? nextLogo;

  setUp(() {
    auth = FakeAuthRepository(latency: Duration.zero);
    companies = FakeCompanyRepository(auth: auth, latency: Duration.zero);
    nextLogo = null;
  });
  tearDown(() => auth.dispose());

  Future<GoRouter> pumpApp(WidgetTester tester, {double width = 400}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: noAutomaticRetry,
        overrides: [
          ...fakeRepositoryOverrides(auth: auth, companies: companies),
          logoPickerProvider.overrideWithValue(() async => nextLogo),
        ],
        child: const ResuRhombusApp(),
      ),
    );
    await tester.pumpAndSettle();
    return GoRouter.of(tester.element(find.byType(Scaffold).first));
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Finder text(String label) => find.text(label).last;

  Future<void> signUpRecruiter() => auth.signUpWithEmail(
    email: 'owner@new.test',
    password: 'password1',
    role: AppRole.recruiter,
  );

  Future<void> signInDemoOwner() => auth.signInWithEmail(
    email: FakeAuthRepository.demoRecruiterEmail,
    password: FakeAuthRepository.demoPassword,
  );

  group('logo checks', () {
    test('accepts PNG, JPEG and WebP by magic bytes', () {
      expect(
        LogoImage.contentTypeOf(
          Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0]),
        ),
        'image/png',
      );
      expect(
        LogoImage.contentTypeOf(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0])),
        'image/jpeg',
      );
      expect(
        LogoImage.contentTypeOf(
          Uint8List.fromList('RIFF\x00\x00\x00\x00WEBP'.codeUnits),
        ),
        'image/webp',
      );
      expect(
        LogoImage.validate(Uint8List.fromList('GIF89a'.codeUnits)),
        isNotNull,
      );
      expect(LogoImage.validate(Uint8List(LogoImage.maxBytes + 1)), isNotNull);
    });
  });

  testWidgets('a new recruiter creates a company and lands on Jobs', (
    tester,
  ) async {
    await signUpRecruiter();
    final router = await pumpApp(tester);
    expect(router.state.uri.path, Routes.companyOnboarding);

    await tap(tester, text('Create a company'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Website (optional)'),
      'not a url',
    );
    await tap(tester, text('Create company'));
    expect(find.text('Enter your company\'s name.'), findsOneWidget);
    expect(
      find.text('Enter a full URL, like https://example.com'),
      findsOneWidget,
    );

    nextLogo = (
      name: 'logo.gif',
      bytes: Uint8List.fromList('GIF89a'.codeUnits),
    );
    await tap(tester, text('Add logo'));
    expect(find.text('Use a PNG, JPEG or WebP image.'), findsOneWidget);

    nextLogo = (name: 'logo.png', bytes: base64Decode(_onePixelPng));
    await tap(tester, text('Add logo'));
    expect(find.text('Change logo'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Company name'),
      'Prism Co',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Website (optional)'),
      'https://prism.example.test',
    );
    await tap(tester, text('Create company'));

    expect(router.state.uri.path, Routes.jobs);
    final membership = await companies.myCompany();
    expect(membership?.company.name, 'Prism Co');
    expect(membership?.company.logoPath, '${membership?.company.id}/logo.png');
    expect(membership?.isOwner, isTrue);
  });

  testWidgets('joining uppercases the code and maps invalid_invite', (
    tester,
  ) async {
    await signUpRecruiter();
    final router = await pumpApp(tester);
    await tap(tester, text('Join with an invite code'));

    final field = find.widgetWithText(TextFormField, 'Invite code');
    await tester.enterText(field, 'zzzzzzzz');
    expect(find.text('ZZZZZZZZ'), findsOneWidget);
    await tap(tester, text('Join'));
    expect(
      find.text('That invite code is invalid, expired, or used up.'),
      findsOneWidget,
    );

    await tester.enterText(field, 'abcd2345');
    await tap(tester, text('Join'));
    expect(router.state.uri.path, Routes.jobs);
    expect((await companies.myCompany())?.role, CompanyRole.member);
  });

  testWidgets('owners generate, copy and revoke invite codes', (tester) async {
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await signInDemoOwner();
    final router = await pumpApp(tester);
    router.go(Routes.companySettings);
    await tester.pumpAndSettle();

    expect(find.text('Rhombus Labs'), findsOneWidget);
    expect(find.text('Unverified'), findsOneWidget);
    expect(find.text(FakeCompanyRepository.demoInviteCode), findsOneWidget);

    await tap(tester, text('Generate code'));
    final invites = await companies.invites();
    expect(invites, hasLength(2));
    final code = invites.first.code;
    expect(find.text(code), findsOneWidget);

    await tap(tester, find.byTooltip('Copy $code'));
    expect(find.text('Copied $code'), findsOneWidget);
    expect(clipboard, code);

    await tap(tester, find.byTooltip('Revoke $code'));
    expect(find.text('Revoke $code?'), findsOneWidget);
    await tap(tester, find.widgetWithText(FilledButton, 'Revoke'));
    expect(
      (await companies.invites()).first.isActive(DateTime.now().toUtc()),
      isFalse,
    );
    expect(find.text('Revoked'), findsOneWidget);
    expect(find.byTooltip('Revoke $code'), findsNothing);
  });

  testWidgets('members see the company but not invite codes', (tester) async {
    await signUpRecruiter();
    await companies.join(FakeCompanyRepository.demoInviteCode);
    final router = await pumpApp(tester, width: 1280);
    router.go(Routes.companySettings);
    await tester.pumpAndSettle();

    expect(find.text('Rhombus Labs'), findsWidgets); // page + rail
    expect(find.text('You\'re a member'), findsOneWidget);
    expect(find.text('Invite codes'), findsNothing);

    await tap(tester, text('Sign out'));
    expect(router.state.uri.path, Routes.welcome);
  });

  testWidgets('a failed load shows Retry', (tester) async {
    await signInDemoOwner();
    companies.failNext = const AppFailure('unknown');
    final router = await pumpApp(tester);
    router.go(Routes.companySettings);
    await tester.pumpAndSettle();
    expect(find.text('We couldn\'t load your company.'), findsOneWidget);

    await tap(tester, text('Retry'));
    expect(find.text('Rhombus Labs'), findsOneWidget);
  });
}

/// A valid 1×1 transparent PNG.
const _onePixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
