import 'package:flutter/material.dart';

import '../../core/models/job_card.dart' as model;
import '../../core/models/display_labels.dart';
import '../theme/rr_tokens.dart';
import 'collage.dart';
import 'company_badge.dart';
import 'rhombus_mark.dart';
import 'score_badge.dart';

class JobCardView extends StatelessWidget {
  const JobCardView({
    super.key,
    required this.job,
    required this.onDetails,
    this.dragProgress = 0,
  });
  final model.JobCard job;
  final VoidCallback onDetails;
  final double dragProgress;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final salary = job.salaryMin == null && job.salaryMax == null
        ? 'Salary not listed'
        : 'USD ${job.salaryMin == null ? 'Up to' : formatMoney(job.salaryMin!)}${job.salaryMin != null && job.salaryMax != null ? ' – ' : ' '}${job.salaryMax == null ? 'and above' : formatMoney(job.salaryMax!)} / year';
    return Stack(
      fit: StackFit.expand,
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onDetails,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Sky header tile: who and what, in the collage language.
                Container(
                  color: RRColors.deck,
                  padding: const EdgeInsets.fromLTRB(
                    RRSpace.xl,
                    RRSpace.xl,
                    RRSpace.lg,
                    RRSpace.xl,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const RhombusMark(
                                  size: RRSpace.lg,
                                  variant: RhombusVariant.filled,
                                  color: RRColors.ink,
                                ),
                                const SizedBox(width: RRSpace.sm),
                                Expanded(
                                  child: Text(
                                    job.company.name,
                                    style: text.titleMedium,
                                  ),
                                ),
                              ],
                            ),
                            if (!job.company.verified)
                              const CompanyBadge(verified: false),
                            const SizedBox(height: RRSpace.sm),
                            Text(job.title, style: text.headlineSmall),
                          ],
                        ),
                      ),
                      const SizedBox(width: RRSpace.sm),
                      const CollageTile(
                        color: RRColors.lemon,
                        shape: TileShape.circle,
                        motif: TileMotif.asterisk,
                        width: RRSpace.xxl,
                        height: RRSpace.xxl,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(RRSpace.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ScoreBadge(
                            score: job.matchScore,
                            size: ScoreBadgeSize.small,
                          ),
                          const SizedBox(width: RRSpace.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _Meta(
                                  icon: Icons.location_on_outlined,
                                  text:
                                      '${job.location ?? 'Location not listed'} · ${job.remote.label}',
                                ),
                                _Meta(
                                  icon: Icons.work_outline,
                                  text: job.jobType.label,
                                ),
                                _Meta(
                                  icon: Icons.payments_outlined,
                                  text: salary,
                                ),
                                if (job.sponsorship)
                                  const _Meta(
                                    icon: Icons.public,
                                    text: 'Sponsorship available',
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: RRSpace.lg),
                      Text('Your matched skills', style: text.titleMedium),
                      const SizedBox(height: RRSpace.sm),
                      Wrap(
                        spacing: RRSpace.sm,
                        runSpacing: RRSpace.sm,
                        children: [
                          for (final skill in job.topMatches.take(3))
                            Chip(
                              avatar: const Icon(
                                Icons.check,
                                color: RRColors.matchStrong,
                                size: RRSpace.lg,
                              ),
                              label: Text(skill),
                              backgroundColor: RRColors.match.withValues(
                                alpha: .14,
                              ),
                            ),
                        ],
                      ),
                      if (job.gaps.isNotEmpty) ...[
                        const SizedBox(height: RRSpace.md),
                        Text('Skills to grow', style: text.titleMedium),
                        const SizedBox(height: RRSpace.sm),
                        Wrap(
                          spacing: RRSpace.sm,
                          runSpacing: RRSpace.sm,
                          children: [
                            for (final gap in job.gaps.take(2))
                              Chip(
                                avatar: const Icon(
                                  Icons.remove_circle_outline,
                                  color: RRColors.pass,
                                  size: RRSpace.lg,
                                ),
                                label: Text('Missing: $gap'),
                                backgroundColor: RRColors.canvas,
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: RRSpace.md),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: onDetails,
                          icon: const Icon(Icons.info_outline),
                          label: const Text('View match details'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        ExcludeSemantics(
          child: IgnorePointer(child: SwipeStamp(progress: dragProgress)),
        ),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: RRSpace.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: RRSpace.xl, color: RRColors.ink),
        const SizedBox(width: RRSpace.sm),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class SwipeStamp extends StatelessWidget {
  const SwipeStamp({super.key, required this.progress});
  final double progress;
  @override
  Widget build(BuildContext context) {
    final alpha = progress.abs().clamp(0.0, 1.0);
    final apply = progress >= 0;
    final color = (apply ? RRColors.matchStrong : RRColors.pass).withValues(
      alpha: alpha,
    );
    return Align(
      alignment: apply ? Alignment.topLeft : Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(RRSpace.xl),
        child: Transform.rotate(
          angle: apply ? -RRMotion.diagonal : RRMotion.diagonal,
          child: Container(
            padding: const EdgeInsets.all(RRSpace.md),
            decoration: BoxDecoration(
              color: RRColors.surface.withValues(alpha: alpha * .95),
              border: Border.all(color: color, width: 3),
              borderRadius: const BorderRadius.all(RRRadius.md),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(apply ? Icons.check : Icons.close, color: color),
                const SizedBox(width: RRSpace.sm),
                Text(
                  apply ? 'APPLY' : 'PASS',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
