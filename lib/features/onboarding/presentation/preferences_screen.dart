import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/dev_session.dart';
import '../../../app/routes.dart';
import '../../../core/models/candidate_models.dart';
import '../../../core/models/display_labels.dart';
import '../../../ui/components/branded_page.dart';
import '../../../ui/components/error_banner.dart';
import '../../../ui/components/shimmer_shape.dart';
import '../../../ui/theme/rr_tokens.dart';
import 'preferences_controller.dart';

class PreferencesScreen extends ConsumerStatefulWidget {
  const PreferencesScreen({super.key, this.editing = false});
  final bool editing;
  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends ConsumerState<PreferencesScreen> {
  final _location = TextEditingController();
  @override
  void dispose() {
    _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(preferencesControllerProvider);
    final value = state.asData?.value;
    final controller = ref.read(preferencesControllerProvider.notifier);
    final text = Theme.of(context).textTheme;
    return BrandedPage(
      title: 'Job preferences',
      description: 'Choose the locations and work arrangements that fit your next move. Empty choices mean no restriction.',
      footer: value == null
          ? null
          : FilledButton(
              onPressed: value.saving
                  ? null
                  : () async {
                      if (_location.text.trim().isNotEmpty &&
                          !controller.addLocation(_location.text)) {
                        return;
                      }
                      _location.clear();
                      final router = GoRouter.of(context);
                      final source = router.state.uri.path;
                      final session = DevSessionScope.of(context);
                      if (await controller.save() &&
                          context.mounted &&
                          router.state.uri.path == source) {
                        if (!widget.editing) {
                          session.completeCandidateOnboarding();
                        }
                        if (context.mounted) {
                          context.go(
                            widget.editing
                                ? Routes.candidateProfile
                                : Routes.deck,
                          );
                        }
                      }
                    },
              child: Text(
                value.saving
                    ? 'Saving preferences…'
                    : widget.editing
                    ? 'Save preferences'
                    : 'Start swiping',
              ),
            ),
      child: state.when(
        loading: () => const ShimmerShape(),
        error: (_, _) => Column(
          children: [
            const ErrorBanner(message: 'We could not load your preferences.'),
            TextButton(
              onPressed: () => ref.invalidate(preferencesControllerProvider),
              child: const Text('Retry preferences'),
            ),
          ],
        ),
        data: (value) {
          final prefs = value.preferences;
          final disabled = value.saving;
          final salaryMax = math.max(
            300000.0,
            ((prefs.salaryMin ?? 0) / 50000).ceil() * 50000.0,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (value.error != null) ...[
                ErrorBanner(message: value.error!),
                const SizedBox(height: RRSpace.lg),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(RRSpace.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Where you want to work', style: text.titleLarge),
                      const SizedBox(height: RRSpace.lg),
                      TextField(
                        controller: _location,
                        enabled: !disabled,
                        maxLength: 120,
                        decoration: InputDecoration(
                          labelText: 'Add location',
                          hintText: 'Baton Rouge, LA',
                          suffixIcon: IconButton(
                            tooltip: 'Add location',
                            onPressed: disabled
                                ? null
                                : () {
                                    if (controller.addLocation(
                                      _location.text,
                                    )) {
                                      _location.clear();
                                    }
                                  },
                            icon: const Icon(Icons.add),
                          ),
                        ),
                        onSubmitted: disabled
                            ? null
                            : (v) {
                                if (controller.addLocation(v)) {
                                  _location.clear();
                                }
                              },
                      ),
                      Wrap(
                        spacing: RRSpace.sm,
                        runSpacing: RRSpace.sm,
                        children: [
                          for (final location in prefs.locations ?? <String>[])
                            InputChip(
                              label: Text(location),
                              onDeleted: disabled
                                  ? null
                                  : () => controller.set(
                                      'locations',
                                      prefs.locations!
                                          .where((v) => v != location)
                                          .toList(),
                                    ),
                            ),
                        ],
                      ),
                      const SizedBox(height: RRSpace.lg),
                      Text('Work arrangement', style: text.titleMedium),
                      const SizedBox(height: RRSpace.sm),
                      Wrap(
                        spacing: RRSpace.sm,
                        runSpacing: RRSpace.sm,
                        children: [
                          for (final remote in RemoteType.values)
                            FilterChip(
                              label: Text(remote.label),
                              selected: prefs.remote?.contains(remote) ?? false,
                              onSelected: disabled
                                  ? null
                                  : (_) =>
                                        controller.toggle('remote', remote.db),
                            ),
                        ],
                      ),
                      const SizedBox(height: RRSpace.sm),
                      const Text(
                        'Fully remote roles can appear regardless of your location choices.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: RRSpace.lg),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(RRSpace.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Type of role', style: text.titleLarge),
                      const SizedBox(height: RRSpace.lg),
                      Wrap(
                        spacing: RRSpace.sm,
                        runSpacing: RRSpace.sm,
                        children: [
                          for (final type in JobType.values)
                            FilterChip(
                              label: Text(type.label),
                              selected: prefs.jobTypes?.contains(type) ?? false,
                              onSelected: disabled
                                  ? null
                                  : (_) =>
                                        controller.toggle('job_types', type.db),
                            ),
                        ],
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('I need employer sponsorship'),
                        subtitle: const Text(
                          'Show only roles offering sponsorship.',
                        ),
                        value: prefs.needsSponsorship ?? false,
                        onChanged: disabled
                            ? null
                            : (v) => controller.set('needs_sponsorship', v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: RRSpace.lg),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(RRSpace.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Set a minimum salary'),
                        value: prefs.salaryMin != null,
                        onChanged: disabled
                            ? null
                            : (v) => controller.set(
                                'salary_min',
                                v ? 70000 : null,
                              ),
                      ),
                      if (prefs.salaryMin != null) ...[
                        Text(
                          'Minimum annual salary: USD ${formatMoney(prefs.salaryMin!)}',
                          style: text.titleMedium,
                        ),
                        Slider(
                          value: prefs.salaryMin!.toDouble(),
                          max: salaryMax,
                          divisions: (salaryMax / 5000).round(),
                          semanticFormatterCallback: (v) =>
                              '${formatMoney(v.round())} US dollars a year',
                          label: formatMoney(prefs.salaryMin!),
                          onChanged: disabled
                              ? null
                              : (v) => controller.set('salary_min', v.round()),
                        ),
                        const Text(
                          'Roles without salary information are excluded when you set a minimum.',
                        ),
                      ],
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Include lower-match roles'),
                        subtitle: const Text(
                          'Also show roles below a 50% match.',
                        ),
                        value: prefs.includeStretch ?? false,
                        onChanged: disabled
                            ? null
                            : (v) => controller.set('include_stretch', v),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
