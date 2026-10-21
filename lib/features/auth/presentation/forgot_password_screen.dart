import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../data/auth_repository.dart';
import '../domain/validators.dart';
import 'widgets/auth_layout.dart';

/// Forgot password: emails a reset link (US-05). The confirmation is the
/// same whether or not the account exists.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen>
    with ActionStatus {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final ok = await run(
      () => ref.read(authRepositoryProvider).resetPassword(_email.text),
    );
    if (ok) setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return AuthLayout(
        title: 'Check your email',
        subtitle:
            'If an account exists for ${_email.text.trim()}, a reset link '
            'is on its way.',
        children: [
          SubmitButton(
            label: 'Back to sign in',
            onPressed: () => context.go(Routes.signIn),
          ),
        ],
      );
    }
    return AuthLayout(
      title: 'Forgot password',
      subtitle: 'We\'ll email you a link to set a new one.',
      children: [
        Form(
          key: _form,
          child: TextFormField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: AuthValidators.email,
            onFieldSubmitted: (_) => _submit(),
            enabled: !busy,
          ),
        ),
        const SizedBox(height: 16),
        ActionError(status),
        SubmitButton(
          label: 'Send reset link',
          loading: busy,
          onPressed: _submit,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.go(Routes.signIn),
          child: const Text('Back to sign in'),
        ),
      ],
    );
  }
}
