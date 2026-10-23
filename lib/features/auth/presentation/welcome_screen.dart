import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/models/app_role.dart';
import 'widgets/auth_layout.dart';
import '../../../ui/components/collage.dart';
import '../../../ui/theme/rr_tokens.dart';
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
      hero: const WelcomeCollage(),
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

/// The Welcome hero: butting colour tiles in the collage language, with the
/// rhombus and triangle kept from the original brand.
class WelcomeCollage extends StatelessWidget {
  const WelcomeCollage({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => TileMosaic(
      cell: constraints.maxWidth >= 600 ? 96 : 64,
      rows: const [
        [
          TileSpec(
            color: RRColors.violet,
            flex: 2,
            label: 'match.',
            labelColor: RRColors.surface,
          ),
          TileSpec(
            color: RRColors.lemon,
            shape: TileShape.circle,
            motif: TileMotif.rhombus,
          ),
          TileSpec(
            color: RRColors.deck,
            shape: TileShape.halfRight,
            motif: TileMotif.ring,
            motifColor: RRColors.lemon,
          ),
        ],
        [
          TileSpec(color: RRColors.lemon, motif: TileMotif.arrow),
          TileSpec(
            color: RRColors.pink,
            shape: TileShape.pill,
            flex: 3,
            motif: TileMotif.squiggle,
          ),
        ],
        [
          TileSpec(
            color: RRColors.deck,
            shape: TileShape.halfBottom,
            motif: TileMotif.triangle,
          ),
          TileSpec(
            color: RRColors.canvas,
            motif: TileMotif.asterisk,
            motifColor: RRColors.violet,
          ),
          TileSpec(
            color: RRColors.match,
            shape: TileShape.leaf,
            flex: 2,
            label: 'apply.',
            labelColor: RRColors.surface,
          ),
        ],
      ],
    ),
  );
}
