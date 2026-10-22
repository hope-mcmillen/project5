import 'application_status.dart';

/// Immutable status event data for candidate and recruiter screens.
class StatusEvent {
  StatusEvent({
    required this.id,
    required this.applicationId,
    this.fromStatus,
    required this.toStatus,
    this.actorId,
    required this.createdAt,
  });
  final int id;
  final String applicationId;
  final ApplicationStatus? fromStatus;
  final ApplicationStatus toStatus;
  final String? actorId;
  final DateTime createdAt;
  factory StatusEvent.fromJson(Map<String, dynamic> json) => StatusEvent(
    id: (json['id'] as num).toInt(),
    applicationId: json['application_id'] as String,
    fromStatus: json['from_status'] == null
        ? null
        : ApplicationStatus.fromDb(json['from_status'] as String),
    toStatus: ApplicationStatus.fromDb(json['to_status'] as String),
    actorId: json['actor_id'] == null ? null : json['actor_id'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'application_id': applicationId,
    'from_status': fromStatus?.toDb(),
    'to_status': toStatus.toDb(),
    'actor_id': actorId,
    'created_at': createdAt.toIso8601String(),
  };
}
