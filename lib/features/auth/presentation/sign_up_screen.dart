import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/models/app_role.dart';
import '../data/auth_repository.dart';
import '../domain/validators.dart';
import 'widgets/auth_layout.dart';

/// Sign up with email + password (≥ 8) or Google. The chosen role goes in
/// the sign-up metadata; Terms must be accepted (US-01, US-04).
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key, this.role});

  /// `candidate` or `recruiter` from `?role=`.
  final String? role;

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> with ActionStatus {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late AppRole _role =
      AppRole.values.asNameMap()[widget.role] ?? AppRole.candidate;
  bool _acceptedTerms = false;
  bool _showTermsError = false;
  bool _obscure = true;

  /// Set when the project requires email confirmation.
  bool _confirmationSent = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _showTermsError = !_acceptedTerms);
    if (!_form.currentState!.validate() || !_acceptedTerms) return;
    var signedIn = true;
    final ok = await run(() async {
      signedIn = await ref
          .read(authRepositoryProvider)
          .signUpWithEmail(
            email: _email.text,
            password: _password.text,
            role: _role,
          );
    });
    // When signed in, the router sends the user to their home.
    if (ok && !signedIn) setState(() => _confirmationSent = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_confirmationSent) {
      return AuthLayout(
        title: 'Check your email',
        subtitle:
            'We sent a confirmation link to ${_email.text.trim()}. '
            'Open it, then sign in.',
        children: [
          SubmitButton(
            label: 'Go to sign in',
            onPressed: () => context.go(Routes.signIn),
          ),
        ],
      );
    }

    final colors = Theme.of(context).colorScheme;
    return AuthLayout(
      title: 'Create your account',
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<AppRole>(
                segments: [
                  for (final role in AppRole.values)
                    ButtonSegment(
                      value: role,
                      label: Text(switch (role) {
                        AppRole.candidate => 'Candidate',
                        AppRole.recruiter => 'Recruiter',
                      }),
                    ),
                ],
                selected: {_role},
                onSelectionChanged: busy
                    ? null
                    : (roles) => setState(() => _role = roles.single),
              ),
              const SizedBox(height: 16),
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
                  helperText: 'At least 8 characters',
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                obscureText: _obscure,
                autofillHints: const [AutofillHints.newPassword],
                validator: AuthValidators.newPassword,
                onFieldSubmitted: (_) => _submit(),
                enabled: !busy,
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _acceptedTerms,
                onChanged: busy
                    ? null
                    : (value) => setState(() {
                        _acceptedTerms = value ?? false;
                        if (_acceptedTerms) _showTermsError = false;
                      }),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'I agree to the Terms of Service and Privacy Policy',
                ),
                subtitle: _showTermsError
                    ? Text(
                        'Accept the Terms to continue.',
                        style: TextStyle(color: colors.error),
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              ActionError(status),
              SubmitButton(
                label: 'Create account',
                loading: busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
        GoogleButton(
          onPressed: busy
              ? null
              : () => run(ref.read(authRepositoryProvider).signInWithGoogle),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.go(Routes.signIn),
          child: const Text('Have an account? Sign in'),
        ),
      ],
    );
  }
}
