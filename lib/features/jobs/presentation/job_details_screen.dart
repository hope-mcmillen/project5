import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/widgets/state_views.dart';
import '../../../core/models/job_status.dart';
import '../data/job_repository.dart';
import '../domain/job.dart';
import 'job_actions.dart';
import 'widgets/job_status_chip.dart';

/// Job details: title, location, remote, job type, sponsorship and salary,
/// pre-filled from parse-job, plus publish / pause / close (RC-10, RC-11,
/// US-36). These are the hard filters that decide who sees the job.
class JobDetailsScreen extends ConsumerWidget {
  const JobDetailsScreen({super.key, required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = ref.watch(jobProvider(jobId));
    return Scaffold(
      appBar: AppBar(title: const Text('Job details')),
      body: switch (job) {
        AsyncValue(:final value?) => _DetailsForm(
          key: ValueKey(value.id),
          job: value,
        ),
        AsyncValue(:final error?) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(jobProvider(jobId)),
        ),
        _ => const LoadingBlocks(count: 6, height: 56),
      },
    );
  }
}

class _DetailsForm extends ConsumerStatefulWidget {
  const _DetailsForm({super.key, required this.job});

  final Job job;

  @override
  ConsumerState<_DetailsForm> createState() => _DetailsFormState();
}

class _DetailsFormState extends ConsumerState<_DetailsForm> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.job.title);
  late final _location = TextEditingController(text: widget.job.location);
  late final _salaryMin = TextEditingController(
    text: widget.job.salaryMin?.toString(),
  );
  late final _salaryMax = TextEditingController(
    text: widget.job.salaryMax?.toString(),
  );
  late RemoteType? _remote = widget.job.remote;
  late JobType? _jobType = widget.job.jobType;
  late bool _sponsorship = widget.job.sponsorship;
  bool _busy = false;

  bool get _readOnly => widget.job.status == JobStatus.closed;

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _salaryMin.dispose();
    _salaryMax.dispose();
    super.dispose();
  }

  int? _int(TextEditingController c) =>
      c.text.trim().isEmpty ? null : int.tryParse(c.text.trim());

  String? _validateMax(String? _) {
    final min = _int(_salaryMin);
    final max = _int(_salaryMax);
    if (min != null && max != null && max < min) {
      return 'Max must be at least the min.';
    }
    return null;
  }

  JobDetailsInput get _input => JobDetailsInput(
    title: _title.text.trim(),
    location: _location.text.trim().isEmpty ? null : _location.text.trim(),
    remote: _remote,
    jobType: _jobType,
    sponsorship: _sponsorship,
    salaryMin: _int(_salaryMin),
    salaryMax: _int(_salaryMax),
  );

  /// Saves the form; returns true on success.
  Future<bool> _save({bool quiet = false}) async {
    if (!_form.currentState!.validate()) return false;
    setState(() => _busy = true);
    try {
      await ref.read(jobRepositoryProvider).update(widget.job.id, _input);
      ref.invalidate(jobsProvider);
      if (mounted && !quiet) showMessage(context, 'Details saved.');
      return true;
    } catch (error) {
      if (mounted) showMessage(context, messageOf(error));
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeStatus(JobStatus to) async {
    if (to == JobStatus.open && !await _save(quiet: true)) return;
    if (!mounted) return;
    setState(() => _busy = true);
    final ok = await changeJobStatus(
      context,
      ref,
      jobId: widget.job.id,
      title: _title.text.trim().isEmpty ? 'this job' : _title.text.trim(),
      to: to,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok && to == JobStatus.open) context.go(Routes.jobs);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final job = widget.job;
    final transitions = allowedTransitions(job.status).toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final digits = [FilteringTextInputFormatter.digitsOnly];

    return Form(
      key: _form,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  JobStatusChip(status: job.status),
                  if (job.status != JobStatus.closed)
                    TextButton.icon(
                      onPressed: () =>
                          context.push(Routes.jobRequirementsFor(job.id)),
                      icon: const Icon(Icons.checklist),
                      label: const Text('Requirements'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                enabled: !_readOnly,
                decoration: const InputDecoration(labelText: 'Job title'),
                maxLength: 200,
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Add a title.' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _location,
                enabled: !_readOnly,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  hintText: 'Baton Rouge, LA',
                ),
              ),
              const SizedBox(height: 16),
              Text('Work setting', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final remote in RemoteType.values)
                    ChoiceChip(
                      label: Text(remote.label),
                      selected: _remote == remote,
                      onSelected: _readOnly
                          ? null
                          : (on) =>
                                setState(() => _remote = on ? remote : null),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<JobType>(
                initialValue: _jobType,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Job type'),
                items: [
                  for (final type in JobType.values)
                    DropdownMenuItem(value: type, child: Text(type.label)),
                ],
                onChanged: _readOnly
                    ? null
                    : (type) => setState(() => _jobType = type),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Visa sponsorship available'),
                subtitle: const Text(
                  'Off: only candidates who don\'t need sponsorship see it.',
                ),
                value: _sponsorship,
                onChanged: _readOnly
                    ? null
                    : (on) => setState(() => _sponsorship = on),
              ),
              const SizedBox(height: 8),
              Text('Salary (USD per year)', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _salaryMin,
                      enabled: !_readOnly,
                      decoration: const InputDecoration(labelText: 'Min'),
                      keyboardType: TextInputType.number,
                      inputFormatters: digits,
                      onChanged: (_) => _form.currentState?.validate(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _salaryMax,
                      enabled: !_readOnly,
                      decoration: const InputDecoration(labelText: 'Max'),
                      keyboardType: TextInputType.number,
                      inputFormatters: digits,
                      validator: _validateMax,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (!_readOnly)
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    for (final to in transitions)
                      if (to == JobStatus.open)
                        FilledButton(
                          onPressed: _busy ? null : () => _changeStatus(to),
                          child: Text(
                            job.status == JobStatus.draft
                                ? 'Save and publish'
                                : 'Resume',
                          ),
                        )
                      else
                        OutlinedButton(
                          onPressed: _busy ? null : () => _changeStatus(to),
                          child: Text(actionLabel(to)),
                        ),
                    OutlinedButton(
                      onPressed: _busy ? null : _save,
                      child: Text(
                        job.status == JobStatus.draft
                            ? 'Save draft'
                            : 'Save changes',
                      ),
                    ),
                  ],
                )
              else
                const Text('This job is closed.'),
            ],
          ),
        ),
      ),
    );
  }
}
