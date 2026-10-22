import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/url_opener.dart';
import '../../../app/widgets/state_views.dart';
import '../data/board_repository.dart';

/// Opens a 10-minute signed resume link (`resume-url`).
Future<void> openResume(
  BuildContext context,
  WidgetRef ref,
  String applicationId,
) async {
  try {
    final url = await ref
        .read(boardRepositoryProvider)
        .resumeUrl(applicationId);
    final opened = await ref.read(urlOpenerProvider)(url);
    if (!opened && context.mounted) {
      showMessage(context, 'Couldn\'t open the resume.');
    }
  } catch (error) {
    if (context.mounted) showMessage(context, messageOf(error));
  }
}

/// Starts an email to [email] in the user's mail app.
Future<void> emailCandidate(
  BuildContext context,
  WidgetRef ref,
  String email,
) async {
  final opened = await ref.read(urlOpenerProvider)(
    Uri(scheme: 'mailto', path: email),
  );
  if (!opened && context.mounted) {
    showMessage(context, 'No email app found. The address is $email.');
  }
}
