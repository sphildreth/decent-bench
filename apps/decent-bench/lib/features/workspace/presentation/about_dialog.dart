import 'package:flutter/material.dart';

import '../../../app/app_metadata.dart';

class DecentBenchAboutDialog extends StatelessWidget {
  const DecentBenchAboutDialog({
    super.key,
    required this.onViewLicenses,
    required this.onClose,
  });

  final VoidCallback onViewLicenses;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final outlineColor = colorScheme.outlineVariant.withValues(
      alpha: isDark ? 0.45 : 0.75,
    );

    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border.all(color: outlineColor),
        ),
        child: SizedBox(
          width: 560,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 500;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _AboutHero(compact: compact),
                  Divider(height: 1, color: outlineColor),
                  const _AboutDetails(),
                  _AboutActions(
                    onViewLicenses: onViewLicenses,
                    onClose: onClose,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AboutHero extends StatelessWidget {
  const _AboutHero({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final logo = Image.asset(
      kDecentBenchLogoAsset,
      width: compact ? 132 : 154,
      height: compact ? 132 : 154,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Decent Bench logo',
    );
    final title = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: compact
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          kDecentBenchDisplayName,
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: textTheme.headlineMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.28),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: Text(
              'Version $kDecentBenchVersion',
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Classic desktop SQL workbench for DecentDB.',
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            colorScheme.surfaceContainerHigh,
            colorScheme.primaryContainer.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.18 : 0.34,
            ),
            colorScheme.surface,
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(28, compact ? 24 : 26, 28, 24),
        child: compact
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[logo, const SizedBox(height: 18), title],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  logo,
                  const SizedBox(width: 28),
                  Expanded(child: title),
                ],
              ),
      ),
    );
  }
}

class _AboutDetails extends StatelessWidget {
  const _AboutDetails();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children:
            const <Widget>[
                  _AboutTag(
                    icon: Icons.storage_rounded,
                    label: 'DecentDB-first',
                  ),
                  _AboutTag(
                    icon: Icons.lock_outline_rounded,
                    label: 'Local-first',
                  ),
                  _AboutTag(
                    icon: Icons.desktop_windows_rounded,
                    label: 'Desktop',
                  ),
                ]
                .map((tag) {
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: theme.brightness == Brightness.dark
                            ? 0.42
                            : 0.62,
                      ),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                    child: tag,
                  );
                })
                .toList(growable: false),
      ),
    );
  }
}

class _AboutTag extends StatelessWidget {
  const _AboutTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 7),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutActions extends StatelessWidget {
  const _AboutActions({required this.onViewLicenses, required this.onClose});

  final VoidCallback onViewLicenses;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          TextButton.icon(
            onPressed: onViewLicenses,
            icon: const Icon(Icons.description_outlined, size: 18),
            label: const Text('View licenses'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
