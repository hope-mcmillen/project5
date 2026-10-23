import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/widgets/auth_layout.dart';
import '../data/company_repository.dart';
import '../data/logo_picker.dart';
import '../domain/company_validators.dart';
import '../domain/logo_image.dart';

/// Create company: name, optional website and logo → `create_company`
/// (US-30). The caller becomes the owner; the router then opens Jobs.
class CreateCompanyScreen extends ConsumerStatefulWidget {
  const CreateCompanyScreen({super.key});

  @override
  ConsumerState<CreateCompanyScreen> createState() =>
      _CreateCompanyScreenState();
}

class _CreateCompanyScreenState extends ConsumerState<CreateCompanyScreen>
    with ActionStatus {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _website = TextEditingController();
  Uint8List? _logo;
  String? _logoError;

  @override
  void dispose() {
    _name.dispose();
    _website.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picked = await ref.read(logoPickerProvider)();
    if (picked == null || !mounted) return;
    final error = LogoImage.validate(picked.bytes);
    setState(() {
      _logoError = error;
      if (error == null) _logo = picked.bytes;
    });
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final website = _website.text.trim();
    final ok = await run(
      () => ref
          .read(companyRepositoryProvider)
          .create(
            name: _name.text,
            website: website.isEmpty ? null : website,
            logo: _logo,
          ),
    );
    if (!ok) return;
    // The new recruiters row moves the router on to Jobs.
    ref
      ..invalidate(myCompanyProvider)
      ..invalidate(profileProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return AuthLayout(
      accountMenu: true,
      title: 'Create company',
      subtitle: 'Candidates see this name and logo on your jobs.',
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 64,
                height: 64,
                color: colors.surfaceContainerHighest,
                child: _logo == null
                    ? Icon(Icons.image_outlined, color: colors.outline)
                    : Image.memory(
                        _logo!,
                        fit: BoxFit.cover,
                        semanticLabel: 'Selected logo',
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: busy ? null : _pickLogo,
                        child: Text(_logo == null ? 'Add logo' : 'Change logo'),
                      ),
                      if (_logo != null)
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => setState(() => _logo = null),
                          child: const Text('Remove'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _logoError ?? 'Optional · PNG, JPEG or WebP, up to 5 MB',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _logoError == null ? null : colors.error,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Company name'),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                maxLength: 120,
                validator: CompanyValidators.name,
                enabled: !busy,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _website,
                decoration: const InputDecoration(
                  labelText: 'Website (optional)',
                  hintText: 'https://example.com',
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
                validator: CompanyValidators.website,
                onFieldSubmitted: (_) => _submit(),
                enabled: !busy,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ActionError(status),
        SubmitButton(
          label: 'Create company',
          loading: busy,
          onPressed: _submit,
        ),
      ],
    );
  }
}
