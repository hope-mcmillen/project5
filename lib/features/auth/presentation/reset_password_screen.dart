import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/auth_repository.dart';
import '../domain/validators.dart';
import 'widgets/auth_layout.dart';

/// Set a new password, opened from the reset email
/// (`AuthChangeEvent.passwordRecovery`, US-05).
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen>
    with ActionStatus {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final ok = await run(
      () => ref.read(authRepositoryProvider).updatePassword(_password.text),
    );
    if (!ok || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Password updated.')));
    // The recovery session is a normal session; the router sends the user
    // home from '/'.
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Set a new password',
      showBack: false,
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _password,
                decoration: const InputDecoration(
                  labelText: 'New password',
                  helperText: 'At least 8 characters',
                ),
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                validator: AuthValidators.newPassword,
                enabled: !busy,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirm,
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                ),
                obscureText: true,
                validator: (value) =>
                    value != _password.text ? 'Passwords don\'t match.' : null,
                onFieldSubmitted: (_) => _submit(),
                enabled: !busy,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ActionError(status),
        SubmitButton(label: 'Save password', loading: busy, onPressed: _submit),
      ],
    );
  }
}
