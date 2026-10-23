import '../../../app/employer_menu.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/widgets/state_views.dart';
import '../data/job_repository.dart';
import '../domain/job.dart';
import 'requirements_controller.dart';
import '../../../app/account_menu.dart';
import '../../../ui/components/collage.dart';

/// New job: paste a description (≤ 20k chars). Creating it inserts a DRAFT
/// job, invokes `parse-job` and watches `jobs.parse_status` over Realtime,
/// then opens the requirement editor (RC-08, US-34).
class NewJobScreen extends ConsumerStatefulWidget {
  const NewJobScreen({super.key});

  static const maxLength = 20000;
  static const minLength = 50;

  @override
  ConsumerState<NewJobScreen> createState() => _NewJobScreenState();
}

enum _Stage { editing, saving, reading, failed }

class _NewJobScreenState extends ConsumerState<NewJobScreen> {
  final _text = TextEditingController();
  _Stage _stage = _Stage.editing;
  String? _error;
  String? _jobId;
  StreamSubscription<Job>? _watch;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _watch?.cancel();
    _text.dispose();
    super.dispose();
  }

  String? get _validation {
    final length = _text.text.trim().length;
    if (length == 0) return null;
    if (length < NewJobScreen.minLength) {
      return 'Paste the full description (at least '
          '${NewJobScreen.minLength} characters).';
    }
    return null;
  }

  bool get _canSubmit =>
      _text.text.trim().length >= NewJobScreen.minLength &&
      _text.text.length <= NewJobScreen.maxLength;

  Future<void> _submit() async {
    final repo = ref.read(jobRepositoryProvider);
    setState(() {
      _stage = _Stage.saving;
      _error = null;
    });
    try {
      _jobId ??= await repo.createDraft(_text.text.trim());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.editing;
        _error = messageOf(error);
      });
      return;
    }
    await _read();
  }

  /// Runs parse-job on the draft and also listens for its status, so a
  /// dropped connection still finishes once the job turns READY.
  Future<void> _read() async {
    final jobId = _jobId!;
    final repo = ref.read(jobRepositoryProvider);
    // Read before awaiting: this screen may be gone when parse returns.
    final results = ref.read(parseResultsProvider.notifier);
    setState(() {
      _stage = _Stage.reading;
      _error = null;
    });
    _watch ??= repo.watch(jobId).listen((job) {
      if (job.parseStatus == ParseStatus.ready) _finish();
    }, onError: (_) {});
    try {
      final result = await repo.parse(jobId);
      results.put(jobId, result);
      if (result.ready) {
        _finish();
      } else if (mounted) {
        setState(() {
          _stage = _Stage.failed;
          _error = switch (result.failureReason) {
            'timeout' => 'Reading the description took too long.',
            'budget_exceeded' =>
              'Today\'s AI budget is used up. Try again tomorrow, or add '
                  'the requirements by hand.',
            _ => 'We couldn\'t read that description.',
          };
        });
      }
    } catch (error) {
      if (!mounted || _done) return;
      setState(() {
        _stage = _Stage.failed;
        _error = messageOf(error);
      });
    }
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    ref.invalidate(jobsProvider);
    context.pushReplacement(Routes.jobRequirementsFor(_jobId!));
  }

  /// The description box takes this share of the space above the buttons,
  /// so on short screens (a phone with the keyboard up, or large text) there
  /// is always page left over to scroll, and it never overflows.
  static const _fieldShare = 0.8;
  static const _fieldMinHeight = 160.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = _stage == _Stage.saving || _stage == _Stage.reading;
    final length = _text.text.length;
    final header = HeadlineTile(
      headline: 'post.',
      motif: TileMotif.arrow,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Paste the job description', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'We\'ll pull out the title, details and skills. You\'ll '
            'review everything before it goes live.',
          ),
        ],
      ),
    );
    // Fills the space it's given and scrolls its own text, so a long paste
    // never pushes the buttons off screen.
    final field = TextField(
      controller: _text,
      enabled: !busy,
      expands: true,
      minLines: null,
      maxLines: null,
      textAlignVertical: TextAlignVertical.top,
      maxLength: NewJobScreen.maxLength,
      keyboardType: TextInputType.multiline,
      decoration: InputDecoration(
        alignLabelWithHint: true,
        labelText: 'Job description',
        errorText: _validation,
      ),
      buildCounter:
          (context, {required currentLength, required isFocused, maxLength}) =>
              Text(
                '${_thousands(length)} / '
                '${_thousands(NewJobScreen.maxLength)}',
                semanticsLabel:
                    '$length of ${NewJobScreen.maxLength} characters',
              ),
    );
    final actions = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            if (_stage == _Stage.failed && _jobId != null)
              OutlinedButton(
                onPressed: () =>
                    context.pushReplacement(Routes.jobRequirementsFor(_jobId!)),
                child: const Text('Add skills by hand'),
              ),
            FilledButton.icon(
              onPressed: busy || !_canSubmit
                  ? null
                  : (_stage == _Stage.failed ? _read : _submit),
              icon: _stage == _Stage.saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _stage == _Stage.failed ? 'Try again' : 'Read description',
              ),
            ),
          ],
        ),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        actions: [
          ?EmployerMenuScope.button(context),
          const AccountMenuButton(),
        ],
        title: const Text('New job'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: switch (_stage) {
            _Stage.reading => _Reading(onLeave: () => context.go(Routes.jobs)),
            // The buttons sit below the scrolling area, so they stay visible
            // (and above the keyboard) however long the description is.
            _ => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      children: [
                        header,
                        const SizedBox(height: 16),
                        SizedBox(
                          height: math.max(
                            _fieldMinHeight,
                            constraints.maxHeight * _fieldShare,
                          ),
                          child: field,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: actions,
                ),
              ],
            ),
          },
        ),
      ),
    );
  }
}

String _thousands(int n) => n.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
  (m) => '${m[1]},',
);

class _Reading extends StatelessWidget {
  const _Reading({required this.onLeave});

  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 220,
              child: LinearProgressIndicator(
                semanticsLabel: 'Reading the job description',
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Reading the description…',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'This takes up to 20 seconds. You can leave; the draft is saved '
              'in your jobs list.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: onLeave, child: const Text('Back to jobs')),
          ],
        ),
      ),
    );
  }
}
