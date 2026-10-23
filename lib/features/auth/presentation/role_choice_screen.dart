import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_role.dart';
import '../data/auth_repository.dart';
import 'widgets/auth_layout.dart';
import 'widgets/role_choice_card.dart';

/// Choose your role: signed-in users with no role yet, e.g. after a first
/// Google sign-in (US-02). Calls `set_initial_role` once.
class RoleChoiceScreen extends ConsumerStatefulWidget {
  const RoleChoiceScreen({super.key});

  @override
  ConsumerState<RoleChoiceScreen> createState() => _RoleChoiceScreenState();
}

class _RoleChoiceScreenState extends ConsumerState<RoleChoiceScreen>
    with ActionStatus {
  AppRole? _role;

  Future<void> _submit() async {
    final role = _role!;
    final ok = await run(
      () => ref.read(authRepositoryProvider).setInitialRole(role),
    );
    // The router moves on once the profile shows the new role.
    if (ok) ref.invalidate(profileProvider);
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      accountMenu: true,
      title: 'How will you use ResuRhombus?',
      subtitle: 'You can\'t change this later.',
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
                ActionError(status),
                SubmitButton(
                  label: 'Continue',
                  loading: busy,
                  onPressed: _role == null ? null : _submit,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => ref.read(authRepositoryProvider).signOut(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
