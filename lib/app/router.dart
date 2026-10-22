import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/models/app_role.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/reset_password_screen.dart';
import '../features/auth/presentation/role_choice_screen.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/auth/presentation/sign_up_screen.dart';
import '../features/auth/presentation/welcome_screen.dart';
import '../features/board/presentation/board_screen.dart';
import '../features/board/presentation/candidate_detail_screen.dart';
import '../features/board/presentation/interview_list_screen.dart';
import '../features/company/presentation/company_onboarding_screen.dart';
import '../features/company/presentation/company_settings_screen.dart';
import '../features/company/presentation/create_company_screen.dart';
import '../features/company/presentation/join_company_screen.dart';
import '../features/deck/presentation/deck_screen.dart';
import '../features/deep_dive/presentation/deep_dive_screen.dart';
import '../features/jobs/presentation/job_details_screen.dart';
import '../features/jobs/presentation/jobs_list_screen.dart';
import '../features/jobs/presentation/new_job_screen.dart';
import '../features/jobs/presentation/requirement_editor_screen.dart';
import '../features/onboarding/presentation/consent_screen.dart';
import '../features/onboarding/presentation/parse_progress_screen.dart';
import '../features/onboarding/presentation/preferences_screen.dart';
import '../features/onboarding/presentation/review_profile_screen.dart';
import '../features/onboarding/presentation/upload_resume_screen.dart';
import '../features/pipeline/presentation/application_detail_screen.dart';
import '../features/pipeline/presentation/pipeline_screen.dart';
import '../features/profile/presentation/candidate_profile_screen.dart';
import 'route_session.dart';
import 'routes.dart';
import 'shells.dart';
import 'splash_screen.dart';
import '../ui/components/component_gallery.dart';

/// Where a signed-in user belongs right now.
String homeFor(RouteSession session) => switch (session.role) {
  AppRole.candidate =>
    session.candidateOnboarded ? Routes.deck : Routes.candidateConsent,
  AppRole.recruiter =>
    session.recruiterHasCompany ? Routes.jobs : Routes.companyOnboarding,
  null => session.isSignedIn ? Routes.roleChoice : Routes.welcome,
};

/// Route guard (PRD A-5, PL-11). Returns a new location, or null to allow.
///
/// RLS remains the real enforcement; this guard is for UX only.
String? resolveRedirect(RouteSession session, Uri uri) {
  final path = uri.path;
  if (kDebugMode && path == Routes.componentGallery) return null;

  // Hold every location on the splash until the session is known, then
  // continue to where the user was going.
  if (session.status case SessionStatus.loading || SessionStatus.error) {
    if (path == Routes.splash) return null;
    return Uri(
      path: Routes.splash,
      queryParameters: {'from': uri.toString()},
    ).toString();
  }
  if (path == Routes.splash) {
    final from = uri.queryParameters['from'];
    final target = from == null || from.startsWith(Routes.splash) ? '/' : from;
    return resolveRedirect(session, Uri.parse(target)) ?? target;
  }

  final isPublic = Routes.publicPaths.contains(path);

  if (!session.isSignedIn) {
    if (path == Routes.recruiterAlias) {
      return '${Routes.welcome}?role=recruiter';
    }
    return isPublic ? null : Routes.welcome;
  }

  // A reset link signs the user in; keep them on the reset page until the
  // new password is saved.
  if (session.passwordRecovery) {
    return path == Routes.resetPassword ? null : Routes.resetPassword;
  }

  // Signed in without a role (first Google sign-in): role choice only.
  if (session.role == null) {
    return path == Routes.roleChoice ? null : Routes.roleChoice;
  }

  final home = homeFor(session);
  if (path == '/' || isPublic || path == Routes.roleChoice) return home;

  final isCandidateArea = path.startsWith('/c/');
  final isRecruiterArea = path.startsWith('/r/');

  if (session.role == AppRole.candidate) {
    if (isRecruiterArea) return home;
    if (!session.candidateOnboarded && !path.startsWith('/c/onboarding')) {
      return home;
    }
  }
  if (session.role == AppRole.recruiter) {
    if (isCandidateArea) return home;
    if (!session.recruiterHasCompany && !path.startsWith('/r/onboarding')) {
      return home;
    }
    if (session.recruiterHasCompany && path.startsWith('/r/onboarding')) {
      return home;
    }
  }
  return null;
}

/// Re-runs the route guard whenever the auth session, profile or recovery
/// state changes (`refreshListenable`).
class RouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

/// The app's router, driven by the auth providers.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = RouterRefresh();
  ref
    ..listen(authStateProvider, (_, _) => refresh.refresh())
    ..listen(profileProvider, (_, _) => refresh.refresh())
    ..listen(passwordRecoveryProvider, (_, _) => refresh.refresh());
  final router = buildRouter(
    session: () => RouteSession.read(ref),
    refreshListenable: refresh,
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

/// Builds the router. [session] is read on every navigation; tests pass a
/// fixed one.
GoRouter buildRouter({
  required RouteSession Function() session,
  Listenable? refreshListenable,
  String initialLocation = Routes.splash,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: refreshListenable,
    redirect: (context, state) => resolveRedirect(session(), state.uri),
    errorBuilder: (context, state) => NotFoundScreen(uri: state.uri),
    routes: [
      if (kDebugMode)
        GoRoute(
          path: Routes.componentGallery,
          builder: (_, _) => const ComponentGallery(),
        ),
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // ---------- Public ----------
      GoRoute(
        path: Routes.welcome,
        builder: (context, state) =>
            WelcomeScreen(preselectedRole: state.uri.queryParameters['role']),
      ),
      GoRoute(
        path: Routes.roleChoice,
        builder: (context, state) => const RoleChoiceScreen(),
      ),
      GoRoute(
        path: Routes.signUp,
        builder: (context, state) =>
            SignUpScreen(role: state.uri.queryParameters['role']),
      ),
      GoRoute(
        path: Routes.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: Routes.resetPassword,
        builder: (context, state) => const ResetPasswordScreen(),
      ),

      // ---------- Candidate onboarding ----------
      GoRoute(
        path: Routes.candidateConsent,
        builder: (context, state) => const ConsentScreen(),
      ),
      GoRoute(
        path: Routes.candidateUpload,
        builder: (context, state) => const UploadResumeScreen(),
      ),
      GoRoute(
        path: Routes.candidateParseProgress,
        builder: (context, state) =>
            ParseProgressScreen(resumeId: state.pathParameters['resumeId']!),
      ),
      GoRoute(
        path: Routes.candidateReview,
        builder: (context, state) => const ReviewProfileScreen(),
      ),
      GoRoute(
        path: Routes.candidatePreferences,
        builder: (context, state) => const PreferencesScreen(),
      ),

      // ---------- Candidate tabs ----------
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            CandidateShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.deck,
                builder: (context, state) => const DeckScreen(),
                routes: [
                  GoRoute(
                    path: 'job/:jobId',
                    builder: (context, state) =>
                        DeepDiveScreen(jobId: state.pathParameters['jobId']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.pipeline,
                builder: (context, state) => const PipelineScreen(),
                routes: [
                  GoRoute(
                    path: ':applicationId',
                    builder: (context, state) => ApplicationDetailScreen(
                      applicationId: state.pathParameters['applicationId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.candidateProfile,
                builder: (context, state) => const CandidateProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'preferences',
                    builder: (context, state) =>
                        const PreferencesScreen(editing: true),
                  ),
                  GoRoute(
                    path: 'resume',
                    builder: (context, state) => const UploadResumeScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // ---------- Recruiter onboarding ----------
      GoRoute(
        path: Routes.companyOnboarding,
        builder: (context, state) => const CompanyOnboardingScreen(),
        routes: [
          GoRoute(
            path: 'create',
            builder: (context, state) => const CreateCompanyScreen(),
          ),
          GoRoute(
            path: 'join',
            builder: (context, state) => const JoinCompanyScreen(),
          ),
        ],
      ),

      // ---------- Recruiter tabs ----------
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            RecruiterShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.jobs,
                builder: (context, state) => const JobsListScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const NewJobScreen(),
                  ),
                  GoRoute(
                    path: ':jobId/requirements',
                    builder: (context, state) => RequirementEditorScreen(
                      jobId: state.pathParameters['jobId']!,
                    ),
                  ),
                  GoRoute(
                    path: ':jobId/details',
                    builder: (context, state) =>
                        JobDetailsScreen(jobId: state.pathParameters['jobId']!),
                  ),
                  GoRoute(
                    path: ':jobId/board',
                    builder: (context, state) => BoardScreen(
                      jobId: state.pathParameters['jobId']!,
                      query: state.uri.queryParameters,
                    ),
                    routes: [
                      GoRoute(
                        path: ':applicationId',
                        builder: (context, state) => CandidateDetailScreen(
                          jobId: state.pathParameters['jobId']!,
                          applicationId: state.pathParameters['applicationId']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.interviews,
                builder: (context, state) => const InterviewListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.companySettings,
                builder: (context, state) => const CompanySettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
