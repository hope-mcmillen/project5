import 'package:flutter_riverpod/misc.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/fake_auth_repository.dart';
import '../features/board/data/board_repository.dart';
import '../features/board/data/fake_board_repository.dart';
import '../features/company/data/company_repository.dart';
import '../features/company/data/fake_company_repository.dart';
import '../features/jobs/data/fake_job_repository.dart';
import '../features/jobs/data/job_repository.dart';

/// Provider overrides that run the whole app on in-memory fakes (RC-03).
///
/// Shared by `main_fake.dart` and widget tests. Candidate-side fakes (C1)
/// belong in this list too.
List<Override> fakeRepositoryOverrides({FakeAuthRepository? auth}) {
  final fakeAuth = auth ?? FakeAuthRepository();
  return [
    authRepositoryProvider.overrideWithValue(fakeAuth),
    companyRepositoryProvider.overrideWithValue(
      FakeCompanyRepository(auth: fakeAuth),
    ),
    jobRepositoryProvider.overrideWithValue(FakeJobRepository()),
    boardRepositoryProvider.overrideWithValue(FakeBoardRepository()),
  ];
}
