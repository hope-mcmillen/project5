import 'package:flutter/material.dart';

import '../../../app/dev_session.dart';
import '../../../app/routes.dart';
import '../../../core/models/app_role.dart';
import '../../../ui/scaffold/placeholder_page.dart';

/// Sign up: Email + password and Google sign-up. Passes the chosen role in sign-up metadata. Terms checkbox.
///
/// SCAFFOLD: placeholder body only. Replace it when implementing PL-09, PL-10.
class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key, this.role});

  final String? role;

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: 'Sign up',
      description: 'Email + password and Google sign-up. Passes the chosen role in sign-up metadata. Terms checkbox.',
      tasks: const ['PL-09', 'PL-10'],
      stories: const ['US-02'],
      params: {'Role': role ?? 'not chosen'},
      links: [
        PageLink(
          '[Fake] Create candidate account',
          Routes.deck,
          onBefore: () => devSession.signIn(AppRole.candidate),
        ),
        PageLink(
          '[Fake] Create recruiter account',
          Routes.jobs,
          onBefore: () => devSession.signIn(AppRole.recruiter),
        ),
        PageLink('Have an account? Sign in', Routes.signIn),
      ],
    );
  }
}
