import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:project5/app/app.dart';
import 'package:project5/app/dev_session.dart';
import 'package:project5/app/routes.dart';
import 'package:project5/core/models/candidate_models.dart';
import 'package:project5/core/testing/candidate_fixtures.dart';
import 'package:project5/features/profile/data/fake_profile_repository.dart';
import 'package:project5/features/profile/data/profile_repository.dart';
import 'package:project5/ui/components/experience_list.dart';

import '../../support/fake_scope.dart';

void main() {
  test('dates read as months, years, or Present', () {
    expect(ExperienceList.month('2022-03'), 'Mar 2022');
    expect(ExperienceList.month('2022'), '2022');
    expect(ExperienceList.month('present'), 'Present');
    expect(ExperienceList.month(null), isNull);
  });

  testWidgets('Review shows the experiences read from the resume', (
    tester,
  ) async {
    final parsed = ProfileVersion.fromJson({
      ...CandidateFixtures.version.toJson(),
      'source': 'resume',
      'candidate_experiences': [
        {
          'id': 'e-1',
          'profile_version_id': CandidateFixtures.versionId,
          'sort_order': 0,
          'kind': 'job',
          'title': 'Mobile Developer',
          'organization': 'Bayou Apps',
          'start_month': '2022-03',
          'end_month': 'present',
          'highlights': ['Built a field-inspection app in Flutter.'],
          'skills_used': ['Flutter'],
          'evidence': 'Mobile Developer, Bayou Apps',
        },
      ],
    });
    final session = DevSession()
      ..signIn(AppRole.candidate)
      ..completeCandidateOnboarding();
    addTearDown(session.dispose);
    await tester.pumpWidget(
      fakeScope(
        ResuRhombusApp(session: session),
        overrides: [
          profileRepositoryProvider.overrideWithValue(
            FakeProfileRepository(latency: Duration.zero, version: parsed),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go(Routes.candidateReview);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Mobile Developer'), 200);
    expect(find.text('Experience from your resume'), findsOneWidget);
    expect(find.text('Job · Bayou Apps · Mar 2022 – Present'), findsOneWidget);
    expect(
      find.text('Built a field-inspection app in Flutter.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
