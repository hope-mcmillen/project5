import 'candidate_enums.dart';

extension RemoteLabel on RemoteType {
  String get label => switch (this) {
    RemoteType.onsite => 'On-site',
    RemoteType.hybrid => 'Hybrid',
    RemoteType.remote => 'Remote',
  };
}

extension JobTypeLabel on JobType {
  String get label => switch (this) {
    JobType.fullTime => 'Full time',
    JobType.partTime => 'Part time',
    JobType.contract => 'Contract',
    JobType.internship => 'Internship',
  };
}

String formatMoney(int value) => value.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
  (m) => '${m[1]},',
);
