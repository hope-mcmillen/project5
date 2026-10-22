import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/models/app_role.dart';
import 'widgets/auth_layout.dart';
import 'widgets/role_choice_card.dart';

/// Welcome: pick "I'm looking for a job" or "I'm hiring", then sign up
/// (PRD §4, US-01). `?role=recruiter` (the `/recruiter` link) preselects.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, this.preselectedRole});

  final String? preselectedRole;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late AppRole? _role = AppRole.values.asNameMap()[widget.preselectedRole];

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Welcome to ResuRhombus',
      subtitle: 'Matches built on skills. How will you use it?',
      showBack: false,
      maxWidth: 720,
      children: [
        RoleChoicePicker(
          selected: _role,
          onChanged: (role) => setState(() => _role = role),
        ),
        const SizedBox(height: 24),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SubmitButton(
                  label: 'Continue',
                  onPressed: _role == null
                      ? null
                      : () =>
                            context.go('${Routes.signUp}?role=${_role!.name}'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.push(Routes.signIn),
                  child: const Text('I already have an account · Sign in'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
