import 'candidate_enums.dart';

/// Immutable resume data for candidate and recruiter screens.
class Resume {
  Resume({
    required this.id,
    required this.candidateId,
    required this.storagePath,
    required this.status,
    this.failureReason,
    this.fileHash,
  });
  final String id;
  final String candidateId;
  final String storagePath;
  final ResumeStatus status;
  final String? failureReason;
  final String? fileHash;
  factory Resume.fromJson(Map<String, dynamic> json) => Resume(
    id: json['id'] as String,
    candidateId: json['candidate_id'] as String,
    storagePath: json['storage_path'] as String,
    status: ResumeStatus.fromDb(json['status'] as String),
    fileHash: json['file_hash'] as String?,
    failureReason: json['failure_reason'] == null
        ? null
        : json['failure_reason'] as String,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'candidate_id': candidateId,
    'storage_path': storagePath,
    'status': status.toDb(),
    'failure_reason': failureReason,
    if (fileHash != null) 'file_hash': fileHash,
  };
}
