import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/widgets/auth_layout.dart';
import '../data/company_repository.dart';
import '../domain/company_validators.dart';

/// Join company with an 8-character invite code → `join_company` (US-32).
class JoinCompanyScreen extends ConsumerStatefulWidget {
  const JoinCompanyScreen({super.key});

  @override
  ConsumerState<JoinCompanyScreen> createState() => _JoinCompanyScreenState();
}

class _JoinCompanyScreenState extends ConsumerState<JoinCompanyScreen>
    with ActionStatus {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final ok = await run(
      () => ref.read(companyRepositoryProvider).join(_code.text),
    );
    if (!ok) return;
    ref
      ..invalidate(myCompanyProvider)
      ..invalidate(profileProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuthLayout(
      accountMenu: true,
      title: 'Join company',
      subtitle: 'Enter the 8-character code a teammate shared with you.',
      children: [
        Form(
          key: _form,
          child: TextFormField(
            controller: _code,
            decoration: const InputDecoration(
              labelText: 'Invite code',
              hintText: 'ABCD2345',
            ),
            style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 4),
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(8),
              _UpperCaseFormatter(),
            ],
            validator: CompanyValidators.inviteCode,
            onFieldSubmitted: (_) => _submit(),
            enabled: !busy,
          ),
        ),
        const SizedBox(height: 20),
        ActionError(status),
        SubmitButton(label: 'Join', loading: busy, onPressed: _submit),
      ],
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}
