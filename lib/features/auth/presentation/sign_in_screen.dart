import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../data/auth_repository.dart';
import '../domain/validators.dart';
import 'widgets/auth_layout.dart';

/// Sign in with email + password or Google. The router then sends each
/// role to its own home (US-02, US-03).
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> with ActionStatus {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await run(
      () => ref
          .read(authRepositoryProvider)
          .signInWithEmail(email: _email.text, password: _password.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Sign in',
      subtitle: 'Welcome back.',
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  validator: AuthValidators.email,
                  enabled: !busy,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.password],
                  validator: AuthValidators.password,
                  onFieldSubmitted: (_) => _submit(),
                  enabled: !busy,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push(Routes.forgotPassword),
                    child: const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height: 8),
                ActionError(status),
                SubmitButton(
                  label: 'Sign in',
                  loading: busy,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
        GoogleButton(
          onPressed: busy
              ? null
              : () => run(ref.read(authRepositoryProvider).signInWithGoogle),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.go(Routes.welcome),
          child: const Text('New here? Get started'),
        ),
      ],
    );
  }
}
