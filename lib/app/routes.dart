/// Every route path in the app, in one place.
///
/// Candidate routes live under `/c`, recruiter routes under `/r` (PRD §4, A-5).
/// Paths with `:params` have a helper that fills them in.
abstract final class Routes {
  /// Shown while the session loads; `?from=` holds the requested location.
  static const splash = '/splash';

  // Public (signed-out) routes
  static const welcome = '/welcome';
  static const recruiterAlias = '/recruiter'; // pre-selects "I'm hiring" (A-2)
  // Signed-in OAuth users with no role yet (US-02)
  static const roleChoice = '/welcome/role';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up'; // ?role=candidate|recruiter
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';

  // Candidate onboarding (PRD §5.1)
  static const candidateConsent = '/c/onboarding/consent';
  static const candidateUpload = '/c/onboarding/upload';
  static const candidateParseProgress = '/c/onboarding/progress/:resumeId';
  static String parseProgress(String resumeId) =>
      '/c/onboarding/progress/$resumeId';
  static const candidateReview = '/c/onboarding/review';
  static const candidatePreferences = '/c/onboarding/preferences';

  // Candidate shell tabs
  static const deck = '/c/deck';
  static const deepDive = '/c/deck/job/:jobId';
  static String deepDiveFor(String jobId) => '/c/deck/job/$jobId';
  static const pipeline = '/c/pipeline';
  static const applicationDetail = '/c/pipeline/:applicationId';
  static String applicationDetailFor(String id) => '/c/pipeline/$id';
  static const candidateProfile = '/c/profile';
  static const profilePreferences = '/c/profile/preferences';
  static const profileResume = '/c/profile/resume';

  // Recruiter onboarding (PRD §4)
  static const companyOnboarding = '/r/onboarding';
  static const createCompany = '/r/onboarding/create';
  static const joinCompany = '/r/onboarding/join';

  // Recruiter shell tabs
  static const jobs = '/r/jobs';
  static const newJob = '/r/jobs/new';
  static const jobRequirements = '/r/jobs/:jobId/requirements';
  static String jobRequirementsFor(String jobId) =>
      '/r/jobs/$jobId/requirements';
  static const jobDetails = '/r/jobs/:jobId/details';
  static String jobDetailsFor(String jobId) => '/r/jobs/$jobId/details';
  static const board = '/r/jobs/:jobId/board';
  static String boardFor(String jobId) => '/r/jobs/$jobId/board';
  static const candidateDetail = '/r/jobs/:jobId/board/:applicationId';
  static String candidateDetailFor(String jobId, String applicationId) =>
      '/r/jobs/$jobId/board/$applicationId';
  static const interviews = '/r/interviews';
  static const companySettings = '/r/company';

  static const publicPaths = {
    welcome,
    recruiterAlias,
    signIn,
    signUp,
    forgotPassword,
    resetPassword,
  };
}

/// Placeholder ids used by scaffold links until real data exists.
abstract final class DemoIds {
  static const job = 'demo-job-1';
  static const application = 'demo-app-1';
  static const resume = 'demo-resume-1';
}
