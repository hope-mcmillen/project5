import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../ui/components/branded_page.dart';
import '../../../ui/components/error_banner.dart';
import '../../../ui/theme/rr_tokens.dart';
import '../data/resume_repository.dart';
import 'upload_controller.dart';

class UploadResumeScreen extends ConsumerWidget {
  const UploadResumeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(uploadControllerProvider);
    final controller = ref.read(uploadControllerProvider.notifier);
    ref.listen(uploadControllerProvider, (previous, next) {
      final id = next.resumeId;
      if (id == null || id == previous?.resumeId) return;
      final router = GoRouter.of(context);
      final sourcePath = GoRouterState.of(context).uri.path;
      // Stateful tab branches can remain mounted while hidden. A completed
      // upload must not pull the user away from another page.
      if (router.state.uri.path != sourcePath) return;
      final fromProfile = sourcePath == Routes.profileResume;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted || router.state.uri.path != sourcePath) return;
        final target = Routes.parseProgress(id);
        context.go(
          fromProfile
              ? Uri(
                  path: target,
                  queryParameters: {'returnTo': Routes.profileResume},
                ).toString()
              : target,
        );
      });
    });
    final file = state.file;
    final text = Theme.of(context).textTheme;
    return BrandedPage(
      title: 'Upload your resume',
      preferMenuButton: true,
      description: 'Bring your experience into focus. Choose a PDF or Word resume, up to 5 MB.',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(RRSpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Icon(
                  Icons.upload_file_outlined,
                  size: RRSpace.xxxl,
                  color: RRColors.inkMuted,
                ),
              ),
              const SizedBox(height: RRSpace.lg),
              Text('Start with your experience', style: text.titleLarge),
              const SizedBox(height: RRSpace.sm),
              const Text(
                'We will read your resume so you can review your skills next.',
              ),
              const SizedBox(height: RRSpace.xl),
              if (file != null) ...[
                Container(
                  padding: const EdgeInsets.all(RRSpace.lg),
                  decoration: const BoxDecoration(
                    color: RRColors.canvas,
                    borderRadius: BorderRadius.all(RRRadius.md),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.description_outlined),
                      const SizedBox(width: RRSpace.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(file.name, style: text.titleMedium),
                            const SizedBox(height: RRSpace.xs),
                            Text(
                              '${file.extension.toUpperCase()} · ${(file.bytes.length / 1024).toStringAsFixed(1)} KB',
                              style: text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: RRSpace.lg),
              ],
              if (state.error != null) ...[
                ErrorBanner(message: state.error!),
                const SizedBox(height: RRSpace.lg),
              ],
              OutlinedButton.icon(
                onPressed: state.busy ? null : controller.chooseFile,
                icon: const Icon(Icons.folder_open_outlined),
                label: Text(
                  state.phase == UploadPhase.choosing
                      ? 'Opening file picker…'
                      : file == null
                      ? 'Choose file'
                      : 'Change file',
                ),
              ),
              const SizedBox(height: RRSpace.md),
              FilledButton.icon(
                onPressed: state.busy || file == null
                    ? null
                    : controller.upload,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Text(
                  state.phase == UploadPhase.uploading
                      ? 'Uploading resume…'
                      : 'Upload resume',
                ),
              ),
              if (state.phase == UploadPhase.uploading) ...[
                const SizedBox(height: RRSpace.lg),
                const LinearProgressIndicator(
                  semanticsLabel: 'Uploading your resume',
                ),
              ],
              const SizedBox(height: RRSpace.md),
              if (file != null || state.busy)
                OutlinedButton.icon(
                  onPressed: controller.cancel,
                  icon: const Icon(Icons.close),
                  label: Text(
                    state.phase == UploadPhase.uploading
                        ? 'Cancel upload'
                        : 'Cancel selection',
                  ),
                ),
              TextButton(
                onPressed: () {
                  controller.cancel();
                  context.go(Routes.deck);
                },
                child: const Text('Skip for now'),
              ),
              Text(
                'You can return to Resume from the menu whenever you are ready. '
                'Complete your profile before applying to jobs.',
                style: text.bodySmall?.copyWith(color: RRColors.inkMuted),
              ),
              const SizedBox(height: RRSpace.lg),
              Text(
                'PDF or DOCX · Maximum 5 MB',
                style: text.bodySmall?.copyWith(color: RRColors.inkMuted),
              ),
              if (ref.watch(resumeSimulationProvider)) ...[
                const SizedBox(height: RRSpace.sm),
                Text(
                  'Demo mode · Your file stays on this device. Reading is simulated.',
                  style: text.bodySmall?.copyWith(color: RRColors.inkMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
