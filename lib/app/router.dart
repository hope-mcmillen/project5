import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';

import '../ui/components/component_gallery.dart';

import '../core/models/app_role.dart';
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
import 'dev_session.dart';
import 'routes.dart';
import 'shells.dart';

/// Where a signed-in user belongs right now.
String homeFor(DevSession session) => switch (session.role) {
  AppRole.candidate =>
    session.candidateOnboarded ? Routes.deck : Routes.candidateConsent,
  AppRole.recruiter =>
    session.recruiterHasCompany ? Routes.jobs : Routes.companyOnboarding,
  null => Routes.welcome,
};

/// Route guard (PRD A-5). Returns a new location, or null to allow.
///
/// SCAFFOLD: reads the fake [DevSession]. The rules stay the same when
/// PL-11 swaps in Supabase auth + `profiles.role`. RLS remains the real
/// enforcement; this guard is for UX only.
String? resolveRedirect(DevSession session, Uri uri) {
  final path = uri.path;
  if (kDebugMode && path == '/dev/gallery') return null;
  final isPublic =
      Routes.publicPaths.contains(path) || path == Routes.roleChoice;

  if (!session.isSignedIn) {
    if (path == Routes.recruiterAlias) {
      return '${Routes.welcome}?role=recruiter';
    }
    return isPublic ? null : Routes.welcome;
  }

  final home = homeFor(session);
  if (path == '/' || isPublic) return home;

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
  }
  return null;
}

GoRouter buildRouter(DevSession session) {
  return GoRouter(
    initialLocation: Routes.welcome,
    refreshListenable: session,
    redirect: (context, state) => resolveRedirect(session, state.uri),
    errorBuilder: (context, state) => NotFoundScreen(uri: state.uri),
    routes: [
      if (kDebugMode)
        GoRoute(
          path: '/dev/gallery',
          builder: (context, state) => const ComponentGallery(),
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
                    builder: (context, state) =>
                        BoardScreen(jobId: state.pathParameters['jobId']!),
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
