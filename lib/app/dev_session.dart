import 'package:flutter/widgets.dart';

import '../core/models/app_role.dart';

/// Isolated routing state for candidate component previews and tests.
/// Both app entry points use auth providers and RouteSession instead.
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

class DevSessionScope extends InheritedWidget {
  const DevSessionScope({
    super.key,
    required this.session,
    required super.child,
  });
  final DevSession session;
  static DevSession? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DevSessionScope>()?.session;
  static DevSession of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DevSessionScope>()?.session ??
      devSession;
  @override
  bool updateShouldNotify(DevSessionScope oldWidget) =>
      oldWidget.session != session;
}
