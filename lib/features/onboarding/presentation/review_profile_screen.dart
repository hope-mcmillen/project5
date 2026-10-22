import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/models/candidate_models.dart';
import '../../../ui/components/branded_page.dart';
import '../../../ui/components/error_banner.dart';
import '../../../ui/components/shimmer_shape.dart';
import '../../../ui/components/skill_review_list.dart';
import '../../../ui/theme/rr_tokens.dart';
import 'review_controller.dart';
import 'skill_search_sheet.dart';

class ReviewProfileScreen extends ConsumerWidget {
  const ReviewProfileScreen({super.key});
  Future<void> _choose(
    BuildContext context,
    WidgetRef ref, {
    CandidateSkill? replacing,
  }) async {
    final choice = await showModalBottomSheet<SkillChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SkillSearchSheet(initialName: replacing?.rawName ?? ''),
    );
    if (choice != null && context.mounted) {
      ref
          .read(reviewControllerProvider.notifier)
          .choose(
            replacingId: replacing?.id,
            skill: choice.skill,
            name: choice.name,
          );
    }
  }

  void _evidence(BuildContext context, CandidateSkill skill) {
    final quote = skill.evidence;
    final index =
        quote?.toLowerCase().indexOf(skill.rawName.toLowerCase()) ?? -1;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.all(RRSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Evidence for ${skill.rawName}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: RRSpace.lg),
            if (quote == null || quote.isEmpty)
              const Text('No source snippet is available for this skill.')
            else
              Text.rich(
                TextSpan(
                  children: index < 0
                      ? [TextSpan(text: quote)]
                      : [
                          TextSpan(text: quote.substring(0, index)),
                          TextSpan(
                            text: quote.substring(
                              index,
                              index + skill.rawName.length,
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              backgroundColor: RRColors.deck,
                            ),
                          ),
                          TextSpan(
                            text: quote.substring(index + skill.rawName.length),
                          ),
                        ],
                ),
              ),
            const SizedBox(height: RRSpace.lg),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close evidence'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(reviewControllerProvider);
    final value = data.asData?.value;
    final controller = ref.read(reviewControllerProvider.notifier);
    return BrandedPage(
      title: 'Review your skills',
      description: 'Check the skills and experience found in your resume. Your changes are saved only when you confirm.',
      footer: value == null
          ? null
          : FilledButton.icon(
              icon: const Icon(Icons.check),
              label: Text(
                value.saving ? 'Confirming skills…' : 'Confirm skills',
              ),
              onPressed: value.saving
                  ? null
                  : () async {
                      final router = GoRouter.of(context);
                      final source = router.state.uri.path;
                      if (await controller.confirm() &&
                          context.mounted &&
                          router.state.uri.path == source) {
                        context.go(Routes.candidatePreferences);
                      }
                    },
            ),
      child: data.when(
        loading: () => const ShimmerShape(),
        error: (_, _) => Column(
          children: [
            const ErrorBanner(message: 'We could not load your skills.'),
            TextButton(
              onPressed: () => ref.invalidate(reviewControllerProvider),
              child: const Text('Retry skills'),
            ),
          ],
        ),
        data: (value) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (value.error != null) ...[
              ErrorBanner(message: value.error!),
              const SizedBox(height: RRSpace.lg),
            ],
            if (value.skills.isEmpty)
              const Padding(
                padding: EdgeInsets.all(RRSpace.lg),
                child: Text(
                  'No skills yet. Add the skills you want employers to see.',
                ),
              ),
            SkillReviewList(
              skills: value.skills,
              enabled: !value.saving,
              onRemove: controller.remove,
              onYears: controller.years,
              onRename: (id) => _choose(
                context,
                ref,
                replacing: value.skills.firstWhere((s) => s.id == id),
              ),
              onEvidence: (skill) => _evidence(context, skill),
            ),
            OutlinedButton.icon(
              onPressed: value.saving ? null : () => _choose(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add skill'),
            ),
            const SizedBox(height: RRSpace.lg),
            const Text(
              'Demo profile · Skills are synthetic until live resume parsing is connected.',
            ),
          ],
        ),
      ),
    );
  }
}
