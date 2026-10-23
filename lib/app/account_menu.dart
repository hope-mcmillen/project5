import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/errors/app_failure.dart';
import '../features/auth/data/auth_repository.dart';
import '../ui/components/collage.dart';
import '../ui/theme/rr_tokens.dart';
import 'dev_session.dart';
import 'routes.dart';

/// Signs out and lands on Welcome. Shared by the account menu, both
/// drawers, Profile, Company and onboarding so every exit behaves the same.
///
/// The router and messenger are captured first: once the session ends the
/// route guard may dispose the calling screen before `signOut` returns.
Future<void> signOutToWelcome(BuildContext context, WidgetRef ref) async {
  final router = GoRouter.maybeOf(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final dev = DevSessionScope.maybeOf(context);
  try {
    await ref.read(authRepositoryProvider).signOut();
  } catch (error) {
    final message = error is AppFailure
        ? error.message
        : AppFailure.from(error).message;
    messenger?.showSnackBar(SnackBar(content: Text(message)));
    return;
  }
  dev?.signOut();
  router?.go(Routes.welcome);
}

enum _AccountAction { profile, company, signOut }

/// Avatar button for every signed-in app bar: who is signed in, a shortcut to
/// Profile (candidate) or Company (recruiter), and Sign out.
class AccountMenuButton extends ConsumerWidget {
  const AccountMenuButton({super.key});

  static const signOutKey = Key('account-menu-sign-out');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(right: RRSpace.sm),
      child: PopupMenuButton<_AccountAction>(
        tooltip: 'Account',
        position: PopupMenuPosition.under,
        onSelected: (action) => switch (action) {
          _AccountAction.profile => context.go(Routes.candidateProfile),
          _AccountAction.company => context.go(Routes.companySettings),
          _AccountAction.signOut => signOutToWelcome(context, ref),
        },
        itemBuilder: (context) {
          final path = GoRouter.maybeOf(context)?.state.uri.path ?? '';
          final onboarding =
              path.startsWith('/c/onboarding') ||
              path.startsWith(Routes.companyOnboarding);
          final email = _email(ref);
          return [
            if (email != null)
              PopupMenuItem<_AccountAction>(
                enabled: false,
                child: Text(
                  email,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: RRColors.inkMuted),
                ),
              ),
            if (!onboarding && path.startsWith('/c/'))
              const PopupMenuItem(
                value: _AccountAction.profile,
                child: ListTile(
                  leading: Icon(Icons.person_outline),
                  title: Text('Profile'),
                ),
              ),
            if (!onboarding && path.startsWith('/r/'))
              const PopupMenuItem(
                value: _AccountAction.company,
                child: ListTile(
                  leading: Icon(Icons.apartment_outlined),
                  title: Text('Company'),
                ),
              ),
            const PopupMenuItem(
              key: signOutKey,
              value: _AccountAction.signOut,
              child: ListTile(
                leading: Icon(Icons.logout),
                title: Text('Sign out'),
              ),
            ),
          ];
        },
        child: const SizedBox.square(
          dimension: RRSpace.xxxl,
          child: Center(
            child: CollageTile(
              color: RRColors.lemon,
              shape: TileShape.circle,
              width: RRSpace.xxl + RRSpace.xs,
              height: RRSpace.xxl + RRSpace.xs,
              padding: EdgeInsets.zero,
              child: Icon(Icons.person, color: RRColors.ink, size: RRSpace.xl),
            ),
          ),
        ),
      ),
    );
  }

  /// Best effort: previews and tests may have no auth backend.
  static String? _email(WidgetRef ref) {
    try {
      return ref.read(authRepositoryProvider).currentUser?.email;
    } catch (_) {
      return null;
    }
  }
}

/// "Sign out" row pinned to the bottom of both navigation drawers.
class DrawerSignOutTile extends ConsumerWidget {
  const DrawerSignOutTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    leading: const Icon(Icons.logout),
    title: const Text('Sign out'),
    onTap: () {
      Navigator.pop(context);
      signOutToWelcome(context, ref);
    },
  );
}
