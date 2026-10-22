import 'package:flutter/material.dart';

import '../../core/models/application_status.dart';
import '../theme/rr_tokens.dart';
import 'rhombus_mark.dart';
import 'score_badge.dart';
import 'status_chip.dart';
import 'company_badge.dart';
import 'empty_state.dart';
import 'shimmer_shape.dart';

/// Debug-only component reference; no authentication or backend required.
class ComponentGallery extends StatelessWidget {
  const ComponentGallery({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Component gallery')),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: RRSpace.pageWidth),
        child: ListView(
          padding: const EdgeInsets.all(RRSpace.xl),
          children: [
            Text(
              'ResuRhombus',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: RRSpace.xl),
            Wrap(
              spacing: RRSpace.xl,
              runSpacing: RRSpace.lg,
              children: [
                for (final variant in RhombusVariant.values)
                  RhombusMark(variant: variant),
              ],
            ),
            const SizedBox(height: RRSpace.xl),
            Wrap(
              spacing: RRSpace.xl,
              runSpacing: RRSpace.lg,
              children: [
                for (final score in [92, 76, 58, 42]) ScoreBadge(score: score),
                for (final size in ScoreBadgeSize.values)
                  ScoreBadge(score: 87, size: size),
              ],
            ),
            const SizedBox(height: RRSpace.xl),
            Wrap(
              spacing: RRSpace.sm,
              runSpacing: RRSpace.sm,
              children: [
                for (final status in ApplicationStatus.values)
                  StatusChip(status: status),
                const CompanyBadge(verified: true),
                const CompanyBadge(verified: false),
              ],
            ),
            const SizedBox(height: RRSpace.xl),
            const ShimmerShape(),
            const SizedBox(height: RRSpace.xl),
            EmptyState(
              title: 'No applications yet',
              message: 'Explore a role to take your next step.',
              actionLabel: 'Explore roles',
              onAction: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    ),
  );
}
