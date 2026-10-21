import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project5/app/app.dart';
import 'package:project5/app/fake_overrides.dart';
import 'package:project5/features/auth/data/auth_repository.dart';
import 'package:project5/features/auth/data/fake_auth_repository.dart';
import 'package:project5/features/board/data/board_repository.dart';
import 'package:project5/features/board/data/fake_board_repository.dart';
import 'package:project5/features/company/data/company_repository.dart';
import 'package:project5/features/company/data/fake_company_repository.dart';
import 'package:project5/features/jobs/data/fake_job_repository.dart';
import 'package:project5/features/jobs/data/job_repository.dart';

void main() {
  test('fake overrides replace every recruiter-side repository', () {
    final auth = FakeAuthRepository(latency: Duration.zero);
    final container = ProviderContainer(
      overrides: fakeRepositoryOverrides(auth: auth),
    );
    addTearDown(container.dispose);

    expect(container.read(authRepositoryProvider), same(auth));
    final companies = container.read(companyRepositoryProvider);
    expect(companies, isA<FakeCompanyRepository>());
    expect((companies as FakeCompanyRepository).auth, same(auth));
    expect(container.read(jobRepositoryProvider), isA<FakeJobRepository>());
    expect(container.read(boardRepositoryProvider), isA<FakeBoardRepository>());
  });

  testWidgets('the app starts on fake data', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeRepositoryOverrides(),
        child: const ResuRhombusApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Welcome'), findsWidgets);
  });
}
