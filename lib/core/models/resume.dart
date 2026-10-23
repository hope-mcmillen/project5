import 'candidate_enums.dart';

/// A resume being read, for the parse progress screen.
///
/// New uploads are read in memory and never stored, so [storagePath] is only
/// set for seed data and older uploads. [profileVersionId] is the draft a
/// READY parse saved.
class Resume {
  Resume({
    required this.id,
    required this.candidateId,
    this.storagePath,
    required this.status,
    this.failureReason,
    this.fileHash,
    this.profileVersionId,
  });
  final String id;
  final String candidateId;
  final String? storagePath;
  final ResumeStatus status;
  final String? failureReason;
  final String? fileHash;
  final String? profileVersionId;
  factory Resume.fromJson(Map<String, dynamic> json) => Resume(
    id: json['id'] as String,
    candidateId: json['candidate_id'] as String,
    storagePath: json['storage_path'] as String?,
    status: ResumeStatus.fromDb(json['status'] as String),
    fileHash: json['file_hash'] as String?,
    failureReason: json['failure_reason'] == null
        ? null
        : json['failure_reason'] as String,
    profileVersionId: json['profile_version_id'] as String?,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'candidate_id': candidateId,
    'storage_path': storagePath,
    'status': status.toDb(),
    'failure_reason': failureReason,
    if (fileHash != null) 'file_hash': fileHash,
    if (profileVersionId != null) 'profile_version_id': profileVersionId,
  };
}
