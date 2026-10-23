import '../../../app/employer_menu.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../data/company_repository.dart';
import '../domain/company.dart';
import 'widgets/company_badge.dart';
import '../../../app/account_menu.dart';

/// Company tab: company info and verified badge, invite codes for owners
/// (generate, copy, revoke) and sign out (RC-18, US-31, US-33).
class CompanySettingsScreen extends ConsumerWidget {
  const CompanySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(myCompanyProvider);
    return Scaffold(
      appBar: AppBar(
        leading: EmployerMenuScope.button(context),
        title: const Text('Company'),
        actions: const [AccountMenuButton()],
      ),
      body: switch (membership) {
        AsyncValue(:final value?) => _Content(membership: value),
        AsyncValue(hasError: true, isLoading: false) => _ErrorState(
          message: 'We couldn\'t load your company.',
          onRetry: () => ref.invalidate(myCompanyProvider),
        ),
        AsyncValue(isLoading: true) => const _LoadingState(),
        _ => const Center(child: Text('You aren\'t part of a company yet.')),
      },
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.membership});

  final CompanyMembership membership;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = _CompanyCard(membership: membership);
    final signOut = Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: () => signOutToWelcome(context, ref),
        icon: const Icon(Icons.logout),
        label: const Text('Sign out'),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 360,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [info, const SizedBox(height: 16), signOut],
                  ),
                ),
                const SizedBox(width: 24),
                if (membership.isOwner) const Expanded(child: _InviteSection()),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            info,
            if (membership.isOwner) ...[
              const SizedBox(height: 24),
              const _InviteSection(),
            ],
            const SizedBox(height: 24),
            signOut,
          ],
        );
      },
    );
  }
}

class _CompanyCard extends ConsumerWidget {
  const _CompanyCard({required this.membership});

  final CompanyMembership membership;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final company = membership.company;
    final logoUrl = ref
        .watch(companyRepositoryProvider)
        .logoUrl(company.logoPath);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CompanyLogo(name: company.name, url: logoUrl),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(company.name, style: theme.textTheme.titleLarge),
                  if (company.website != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      company.website!,
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  CompanyBadge(verified: company.verified),
                  const SizedBox(height: 8),
                  Text(
                    membership.isOwner
                        ? 'You\'re the owner'
                        : 'You\'re a member',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Owner-only invite code list with Generate, Copy and Revoke.
class _InviteSection extends ConsumerStatefulWidget {
  const _InviteSection();

  @override
  ConsumerState<_InviteSection> createState() => _InviteSectionState();
}

class _InviteSectionState extends ConsumerState<_InviteSection> {
  bool _generating = false;

  /// Replaces any visible message, so quick actions don't queue up.
  void _show(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  String _messageOf(Object error) =>
      error is AppFailure ? error.message : AppFailure.from(error).message;

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final code = await ref.read(companyRepositoryProvider).createInvite();
      ref.invalidate(invitesProvider);
      _show('Code $code is ready to share.');
    } catch (error) {
      _show(_messageOf(error));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    _show('Copied $code');
  }

  Future<void> _revoke(String code) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Revoke $code?'),
        content: const Text(
          'Nobody will be able to join with this code anymore. Teammates who '
          'already joined stay in the company.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(companyRepositoryProvider).revokeInvite(code);
      ref.invalidate(invitesProvider);
      _show('Revoked $code');
    } catch (error) {
      _show(_messageOf(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final invites = ref.watch(invitesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            Text('Invite codes', style: theme.textTheme.titleMedium),
            FilledButton.icon(
              onPressed: _generating ? null : _generate,
              icon: _generating
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: const Text('Generate code'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Codes last 7 days and work up to 10 times.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        switch (invites) {
          AsyncValue(:final value?) when value.isEmpty => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No codes yet. Generate one to invite a teammate.',
              textAlign: TextAlign.center,
            ),
          ),
          AsyncValue(:final value?) => Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (i, invite) in value.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  _InviteRow(
                    invite: invite,
                    onCopy: () => _copy(invite.code),
                    onRevoke: () => _revoke(invite.code),
                  ),
                ],
              ],
            ),
          ),
          AsyncValue(hasError: true) => _ErrorState(
            message: 'We couldn\'t load your invite codes.',
            onRetry: () => ref.invalidate(invitesProvider),
          ),
          _ => const _LoadingState(rows: 2),
        },
      ],
    );
  }
}

class _InviteRow extends StatelessWidget {
  const _InviteRow({
    required this.invite,
    required this.onCopy,
    required this.onRevoke,
  });

  final CompanyInvite invite;
  final VoidCallback onCopy;
  final VoidCallback onRevoke;

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String get _status {
    final now = DateTime.now().toUtc();
    if (invite.revokedAt != null) return 'Revoked';
    if (!invite.expiresAt.isAfter(now)) return 'Expired';
    if (invite.uses >= invite.maxUses) return 'Used up';
    final expires = invite.expiresAt.toLocal();
    return 'Expires ${_months[expires.month - 1]} ${expires.day} · '
        'used ${invite.uses} of ${invite.maxUses}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = invite.isActive(DateTime.now().toUtc());
    return ListTile(
      title: SelectableText(
        invite.code,
        style: theme.textTheme.titleMedium?.copyWith(
          letterSpacing: 2,
          fontFeatures: const [FontFeature.tabularFigures()],
          decoration: active ? null : TextDecoration.lineThrough,
        ),
      ),
      subtitle: Text(_status),
      trailing: active
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Copy ${invite.code}',
                  icon: const Icon(Icons.copy),
                  onPressed: onCopy,
                ),
                IconButton(
                  tooltip: 'Revoke ${invite.code}',
                  icon: const Icon(Icons.block),
                  onPressed: onRevoke,
                ),
              ],
            )
          : null,
    );
  }
}

/// Content-shaped placeholder boxes while loading.
class _LoadingState extends StatelessWidget {
  const _LoadingState({this.rows = 1});

  final int rows;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Semantics(
      label: 'Loading',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var i = 0; i < rows; i++)
              Container(
                height: 72,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
