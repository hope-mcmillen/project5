import 'package:flutter/foundation.dart';

import '../core/models/app_role.dart';

/// SCAFFOLD ONLY: an in-memory stand-in for the signed-in user, so the
/// routing can be clicked through before real auth exists.
///
/// TODO(PL-09, PL-11): replace with Supabase auth state + `profiles` lookup
/// (Riverpod providers), and delete this file.
class DevSession extends ChangeNotifier {
  AppRole? _role;
  bool _candidateOnboarded = false;
  bool _recruiterHasCompany = false;

  AppRole? get role => _role;
  bool get isSignedIn => _role != null;
  bool get candidateOnboarded => _candidateOnboarded;
  bool get recruiterHasCompany => _recruiterHasCompany;

  void signIn(AppRole role) {
    _role = role;
    notifyListeners();
  }

  void signOut() {
    _role = null;
    _candidateOnboarded = false;
    _recruiterHasCompany = false;
    notifyListeners();
  }

  void completeCandidateOnboarding() {
    _candidateOnboarded = true;
    notifyListeners();
  }

  void completeCompanyOnboarding() {
    _recruiterHasCompany = true;
    notifyListeners();
  }
}

/// Single app-wide instance for the scaffold.
final devSession = DevSession();
