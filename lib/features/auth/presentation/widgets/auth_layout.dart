import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';

/// Loading/error state for a screen's one-shot actions (submit, Google).
mixin ActionStatus<T extends StatefulWidget> on State<T> {
  AsyncValue<void> status = const AsyncData(null);

  bool get busy => status.isLoading;

  /// Runs [action], tracking its state. Returns true on success. A
  /// cancelled sign-in is not an error.
  Future<bool> run(Future<void> Function() action) async {
    setState(() => status = const AsyncLoading());
    var result = await AsyncValue.guard(action);
    if (!mounted) return false;
    final error = result.error;
    if (error is AppFailure && error.code == 'cancelled') {
      result = const AsyncData(null);
    }
    setState(() => status = result);
    return !result.hasError;
  }
}

/// Centered, single-column layout shared by every auth page.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.showBack = true,
    this.maxWidth = 440,
  });

  final double maxWidth;
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: showBack ? AppBar() : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.headlineMedium,
                    // The page title doubles as the screen's heading.
                    semanticsLabel: title,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(subtitle!, style: theme.textTheme.bodyLarge),
                  ],
                  const SizedBox(height: 24),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A full-width primary button that shows a spinner while [loading].
class SubmitButton extends StatelessWidget {
  const SubmitButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      child: loading
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}

/// Inline error from the last failed action, shown above the submit button.
class ActionError extends StatelessWidget {
  const ActionError(this.status, {super.key});

  final AsyncValue<void> status;

  @override
  Widget build(BuildContext context) {
    final error = status.error;
    if (error == null) return const SizedBox.shrink();
    final message = error is AppFailure ? error.message : '$error';
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        liveRegion: true,
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colors.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: TextStyle(color: colors.error)),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Continue with Google", with a divider above it.
class GoogleButton extends StatelessWidget {
  const GoogleButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('or'),
              ),
              Expanded(child: Divider()),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          icon: const Icon(Icons.g_mobiledata, size: 28),
          label: const Text('Continue with Google'),
        ),
      ],
    );
  }
}
