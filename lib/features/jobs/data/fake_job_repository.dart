import 'dart:async';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/job_status.dart';
import '../domain/job.dart';
import '../domain/job_summary.dart';
import '../domain/requirement.dart';
import 'job_repository.dart';

/// In-memory [JobRepository] with the contract's job id (API_CONTRACT §7.4)
/// and a tiny keyword "parser" standing in for `parse-job`.
class FakeJobRepository implements JobRepository {
  FakeJobRepository({
    this.latency = const Duration(milliseconds: 300),
    bool seedDemoJobs = true,
  }) {
    if (seedDemoJobs) {
      for (final job in demoJobs) {
        _jobs[job.id] = job;
      }
      _requirements[demoJobs.first.id] = [
        RequirementDraft(
          skill: skillByName('Flutter'),
          minYears: 2,
          evidence: 'We need 2+ years building production apps with Flutter.',
        ),
        RequirementDraft(skill: skillByName('Dart'), minYears: 2),
        RequirementDraft(
          skill: skillByName('Firebase'),
          required: false,
          weight: 1,
        ),
        RequirementDraft(
          skill: skillByName('Kubernetes'),
          required: false,
          weight: 1,
        ),
      ];
      _counts[demoJobs.first.id] = (3, 5);
    }
  }

  static const demoCompanyId = '20000000-0000-0000-0000-000000000001';

  static final demoJobs = [
    Job(
      id: '40000000-0000-0000-0000-000000000001',
      companyId: demoCompanyId,
      title: 'Flutter Developer',
      rawDescription:
          'Flutter Developer\nWe need 2+ years building production apps '
          'with Flutter. Dart is required too. Firebase is a plus.',
      parseStatus: ParseStatus.ready,
      status: JobStatus.open,
      location: 'Baton Rouge, LA',
      remote: RemoteType.hybrid,
      jobType: JobType.fullTime,
      salaryMin: 90000,
      salaryMax: 115000,
      publishedAt: DateTime.utc(2026, 10, 20, 14),
      expiresAt: DateTime.utc(2026, 12, 19, 14),
    ),
    const Job(
      id: '40000000-0000-0000-0000-000000000002',
      companyId: demoCompanyId,
      title: 'Backend Engineer',
      rawDescription: 'Backend Engineer\nPostgreSQL and Python required.',
      parseStatus: ParseStatus.pending,
      status: JobStatus.draft,
    ),
  ];

  /// A small slice of the taxonomy for the fake parser and skill search.
  static const taxonomy = [
    SkillRef(
      id: '70000000-0000-0000-0000-000000000001',
      name: 'Flutter',
      category: 'Frameworks',
    ),
    SkillRef(
      id: '70000000-0000-0000-0000-000000000002',
      name: 'Dart',
      category: 'Languages',
    ),
    SkillRef(
      id: '70000000-0000-0000-0000-000000000003',
      name: 'Firebase',
      category: 'Cloud/DevOps',
    ),
    SkillRef(
      id: '70000000-0000-0000-0000-000000000004',
      name: 'REST APIs',
      category: 'Tools',
    ),
    SkillRef(
      id: '70000000-0000-0000-0000-000000000005',
      name: 'PostgreSQL',
      category: 'Data',
    ),
    SkillRef(
      id: '70000000-0000-0000-0000-000000000006',
      name: 'Python',
      category: 'Languages',
    ),
    SkillRef(
      id: '70000000-0000-0000-0000-000000000007',
      name: 'Kubernetes',
      category: 'Cloud/DevOps',
    ),
    SkillRef(
      id: '70000000-0000-0000-0000-000000000008',
      name: 'Riverpod',
      category: 'Frameworks',
    ),
    SkillRef(
      id: '70000000-0000-0000-0000-000000000009',
      name: 'Git',
      category: 'Tools',
    ),
    SkillRef(
      id: '70000000-0000-0000-0000-000000000010',
      name: 'Swift',
      category: 'Languages',
    ),
    SkillRef(
      id: '70000000-0000-0000-0000-000000000011',
      name: 'Kotlin',
      category: 'Languages',
    ),
    SkillRef(
      id: '70000000-0000-0000-0000-000000000012',
      name: 'Docker',
      category: 'Cloud/DevOps',
    ),
    SkillRef(
      id: '70000000-0000-0000-0000-000000000013',
      name: 'TypeScript',
      category: 'Languages',
    ),
    SkillRef(
      id: '70000000-0000-0000-0000-000000000014',
      name: 'React',
      category: 'Frameworks',
    ),
    SkillRef(
      id: '70000000-0000-0000-0000-000000000015',
      name: 'SQL',
      category: 'Data',
    ),
    SkillRef(
      id: '70000000-0000-0000-0000-000000000016',
      name: 'AWS',
      category: 'Cloud/DevOps',
    ),
    SkillRef(
      id: '70000000-0000-0000-0000-000000000017',
      name: 'CI/CD',
      category: 'Cloud/DevOps',
    ),
    SkillRef(
      id: '70000000-0000-0000-0000-000000000018',
      name: 'Java',
      category: 'Languages',
    ),
    SkillRef(
      id: '70000000-0000-0000-0000-000000000019',
      name: 'GraphQL',
      category: 'Tools',
    ),
    SkillRef(
      id: '70000000-0000-0000-0000-000000000020',
      name: 'Figma',
      category: 'Tools',
    ),
  ];

  static SkillRef skillByName(String name) =>
      taxonomy.firstWhere((s) => s.name == name);

  final Duration latency;

  /// When set, the next call throws this failure instead of running.
  AppFailure? failNext;

  /// When set, `parse` reports `parse_status: FAILED` with this reason.
  String? failParseWith;

  final _jobs = <String, Job>{};
  final _requirements = <String, List<RequirementDraft>>{};
  final _counts = <String, (int newCount, int total)>{};
  final _changes = StreamController<Job>.broadcast();
  int _nextId = 100;

  Future<void> _call() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
  }

  Job _job(String id) =>
      _jobs[id] ?? (throw const AppFailure('job_not_found', 'Job not found.'));

  void _put(Job job) {
    _jobs[job.id] = job;
    _changes.add(job);
  }

  @override
  Future<List<JobSummary>> list() async {
    await _call();
    return [
      for (final job in _jobs.values)
        JobSummary(
          id: job.id,
          companyId: job.companyId,
          title: job.title,
          status: job.status,
          publishedAt: job.publishedAt,
          expiresAt: job.expiresAt,
          newCount: _counts[job.id]?.$1 ?? 0,
          totalCount: _counts[job.id]?.$2 ?? 0,
        ),
    ];
  }

  @override
  Future<Job> get(String id) async {
    await _call();
    return _job(id);
  }

  @override
  Future<String> createDraft(String rawDescription) async {
    await _call();
    final id =
        '40000000-0000-0000-0000-${(_nextId++).toString().padLeft(12, '0')}';
    _put(
      Job(
        id: id,
        companyId: demoCompanyId,
        rawDescription: rawDescription,
        parseStatus: ParseStatus.pending,
        status: JobStatus.draft,
      ),
    );
    return id;
  }

  @override
  Future<ParseJobResult> parse(String jobId) async {
    await _call();
    final job = _job(jobId);
    if (job.status != JobStatus.draft) {
      throw const AppFailure('job_not_draft');
    }
    final reason = failParseWith;
    if (reason != null) {
      failParseWith = null;
      _put(job.copyWith(parseStatus: ParseStatus.failed));
      return ParseJobResult(ready: false, failureReason: reason);
    }

    final text = job.rawDescription;
    final lower = text.toLowerCase();
    final sentences = text.split(RegExp(r'(?<=[.!?\n])\s*'));
    final preferred = RegExp(r'nice to have|preferred|a plus|bonus');
    final found = <RequirementDraft>[];
    for (final skill in taxonomy) {
      final name = skill.name.toLowerCase();
      final sentence = sentences.firstWhere(
        (s) => s.toLowerCase().contains(name),
        orElse: () => '',
      );
      if (sentence.isEmpty) continue;
      final required = !preferred.hasMatch(sentence.toLowerCase());
      found.add(
        RequirementDraft(
          skill: skill,
          required: required,
          weight: required ? 2 : 1,
          evidence: sentence.trim(),
        ),
      );
    }
    found.sort((a, b) => (b.required ? 1 : 0) - (a.required ? 1 : 0));
    final kept = <RequirementDraft>[];
    final trimmed = <RequirementDraft>[];
    for (final item in found) {
      final requiredCount = kept.where((r) => r.required).length;
      if (kept.length >= 15) {
        trimmed.add(item);
      } else if (item.required && requiredCount >= 8) {
        kept.add(item.copyWith(required: false, weight: 1));
      } else {
        kept.add(item);
      }
    }
    _requirements[jobId] = kept;
    final firstLine = text.trim().split('\n').first.trim();
    _put(
      job.copyWith(
        parseStatus: ParseStatus.ready,
        details: JobDetailsInput(
          title:
              job.title ??
              (firstLine.length <= 80 && firstLine.isNotEmpty
                  ? firstLine
                  : null),
          location: job.location,
          remote:
              job.remote ??
              (lower.contains('remote') ? RemoteType.remote : null),
          jobType: job.jobType,
          sponsorship: job.sponsorship,
          salaryMin: job.salaryMin,
          salaryMax: job.salaryMax,
        ),
      ),
    );
    return ParseJobResult(
      ready: true,
      requirements: kept,
      unmapped: [
        if (lower.contains('auth'))
          const UnmappedSkill(raw: 'Auth', evidence: 'Firebase Auth.'),
      ],
      trimmed: trimmed,
    );
  }

  @override
  Stream<Job> watch(String jobId) {
    // Subscribe to changes on listen, so nothing is lost before the first
    // value arrives.
    StreamSubscription<Job>? changes;
    late final StreamController<Job> controller;
    controller = StreamController<Job>(
      onListen: () {
        changes = _changes.stream
            .where((j) => j.id == jobId)
            .listen(controller.add);
        get(jobId).then(controller.add, onError: controller.addError);
      },
      onCancel: () => changes?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<List<RequirementDraft>> requirements(String jobId) async {
    await _call();
    _job(jobId);
    return List.of(_requirements[jobId] ?? const []);
  }

  @override
  Future<void> saveRequirements(
    String jobId,
    List<RequirementDraft> items,
  ) async {
    await _call();
    final job = _job(jobId);
    final required = items.where((r) => r.required).length;
    final ids = items.map((r) => r.skill.id).toSet();
    if (items.length > 15 || required > 8 || ids.length != items.length) {
      throw const AppFailure('invalid_requirements');
    }
    if (items.isEmpty && job.status != JobStatus.draft) {
      throw const AppFailure('invalid_requirements');
    }
    if (job.status == JobStatus.closed) {
      throw const AppFailure('invalid_transition');
    }
    _requirements[jobId] = List.of(items);
  }

  @override
  Future<void> update(String jobId, JobDetailsInput details) async {
    await _call();
    _put(_job(jobId).copyWith(details: details));
  }

  @override
  Future<void> setStatus(String id, JobStatus status) async {
    await _call();
    final job = _job(id);
    if (!allowedTransitions(job.status).contains(status)) {
      throw const AppFailure(
        'invalid_transition',
        'That status change isn\'t allowed.',
      );
    }
    if (status == JobStatus.open &&
        (job.parseStatus != ParseStatus.ready ||
            (job.title?.trim().isEmpty ?? true) ||
            (_requirements[id]?.isEmpty ?? true))) {
      throw const AppFailure('requirements_not_ready');
    }
    _put(job.copyWith(status: status));
  }

  @override
  Future<List<SkillRef>> searchSkills(String query) async {
    await _call();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return taxonomy.where((s) => s.name.toLowerCase().contains(q)).toList();
  }
}
