import 'package:flutter/material.dart';

import '../../../app/dev_session.dart';
import '../../../app/routes.dart';
import '../../../core/models/app_role.dart';
import '../../../ui/scaffold/placeholder_page.dart';

/// Sign in: Email + password and Google sign-in. Router sends each role to its home.
///
/// SCAFFOLD: placeholder body only. Replace it when implementing PL-09, PL-10.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: 'Sign in',
      description: 'Email + password and Google sign-in. Router sends each role to its home.',
      tasks: const ['PL-09', 'PL-10'],
      stories: const ['US-02', 'US-03'],
      links: [
        PageLink(
          '[Fake] Sign in as candidate',
          Routes.deck,
          onBefore: () => devSession.signIn(AppRole.candidate),
        ),
        PageLink(
          '[Fake] Sign in as recruiter',
          Routes.jobs,
          onBefore: () => devSession.signIn(AppRole.recruiter),
        ),
        PageLink(
          'Forgot password?',
          Routes.forgotPassword,
          mode: LinkMode.push,
        ),
        PageLink('New here? Get started', Routes.welcome),
      ],
    );
  }
}
