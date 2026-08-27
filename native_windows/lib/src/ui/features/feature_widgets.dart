import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/runtime/backend_supervisor.dart';
import '../app_theme.dart';

class FeaturePageHeader extends StatelessWidget {
  const FeaturePageHeader({
    required this.eyebrow,
    required this.title,
    required this.detail,
    this.trailing,
    super.key,
  });

  final String eyebrow;
  final String title;
  final String detail;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 720;
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (eyebrow.isNotEmpty) ...<Widget>[
              Text(
                eyebrow,
                style: const TextStyle(
                  color: AppPalette.cyan,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 5),
            Text(detail),
          ],
        );
        if (trailing == null) {
          return copy;
        }
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[copy, const SizedBox(height: 16), trailing!],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(child: copy),
            const SizedBox(width: 18),
            trailing!,
          ],
        );
      },
    );
  }
}

class FeaturePanel extends StatelessWidget {
  const FeaturePanel({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? AppPalette.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.panel),
        side: const BorderSide(color: AppPalette.outline),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class FeatureWarning extends StatelessWidget {
  const FeatureWarning({required this.message, this.error = false, super.key});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error ? AppPalette.red : AppPalette.amber;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            error ? Icons.error_outline : Icons.warning_amber_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(message, style: TextStyle(color: color, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class FeatureFailure extends StatelessWidget {
  const FeatureFailure({
    required this.title,
    required this.error,
    required this.onRetry,
    super.key,
  });

  final String title;
  final Object? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.cloud_off_outlined,
                color: AppPalette.red,
                size: 38,
              ),
              const SizedBox(height: 15),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(featureErrorText(error), textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => unawaited(onRetry()),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry this section'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeatureProgress extends StatelessWidget {
  const FeatureProgress({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(height: 15),
          Text(label),
        ],
      ),
    );
  }
}

class FeatureBadge extends StatelessWidget {
  const FeatureBadge({
    required this.label,
    this.color = AppPalette.textMuted,
    super.key,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.23)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class FeatureMetricCard extends StatelessWidget {
  const FeatureMetricCard({
    required this.label,
    required this.value,
    required this.footnote,
    required this.icon,
    required this.color,
    super.key,
  });

  final String label;
  final String value;
  final String footnote;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FeaturePanel(
      child: SizedBox(
        height: 112,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: AppPalette.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              footnote,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppPalette.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> showFeatureConfirmation(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppPalette.red)
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

String featureErrorText(Object? error) {
  if (error is ApiException) {
    return error.message;
  }
  if (error is BackendStartupException) {
    return error.message;
  }
  return error?.toString() ?? 'Unknown local error';
}
