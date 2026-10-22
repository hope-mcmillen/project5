import 'package:flutter/material.dart';

import '../../core/models/job_card.dart' as model;
import '../../core/models/display_labels.dart';
import '../theme/rr_tokens.dart';
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
          color: RRColors.deck,
          child: InkWell(
            borderRadius: const BorderRadius.all(RRRadius.lg),
            onTap: onDetails,
            child: ListView(
              padding: const EdgeInsets.all(RRSpace.xl),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const RhombusMark(size: RRSpace.xl, color: RRColors.ink),
                    const SizedBox(width: RRSpace.sm),
                    Expanded(
                      child: Text(job.company.name, style: text.titleMedium),
                    ),
                    const SizedBox(width: RRSpace.sm),
                    ScoreBadge(
                      score: job.matchScore,
                      size: ScoreBadgeSize.small,
                    ),
                  ],
                ),
                if (!job.company.verified)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: CompanyBadge(verified: false),
                  ),
                const SizedBox(height: RRSpace.lg),
                Text(job.title, style: text.headlineSmall),
                const SizedBox(height: RRSpace.lg),
                _Meta(
                  icon: Icons.location_on_outlined,
                  text:
                      '${job.location ?? 'Location not listed'} · ${job.remote.label}',
                ),
                _Meta(icon: Icons.work_outline, text: job.jobType.label),
                _Meta(icon: Icons.payments_outlined, text: salary),
                if (job.sponsorship)
                  const _Meta(
                    icon: Icons.public,
                    text: 'Sponsorship available',
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
                        label: Text(skill),
                        backgroundColor: RRColors.surface,
                      ),
                  ],
                ),
                if (job.gaps.isNotEmpty) ...[
                  const SizedBox(height: RRSpace.md),
                  Text('Skills to grow', style: text.titleMedium),
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
                          backgroundColor: RRColors.surface,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: RRSpace.lg),
                TextButton.icon(
                  onPressed: onDetails,
                  icon: const Icon(Icons.info_outline),
                  label: const Text('View match details'),
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
