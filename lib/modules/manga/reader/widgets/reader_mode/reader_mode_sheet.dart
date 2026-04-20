import 'package:flutter/material.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/modules/manga/reader/utils/reader_option_utils.dart';
import 'package:mangayomi/providers/l10n_providers.dart';

class ReaderModeSheet {
  static const List<ReaderMode> _orderedModes = [
    ReaderMode.ltr,
    ReaderMode.rtl,
    ReaderMode.vertical,
    ReaderMode.webtoon,
    ReaderMode.verticalContinuous,
    ReaderMode.horizontalContinuous,
    ReaderMode.horizontalContinuousRTL,
  ];

  static Future<void> show({
    required BuildContext context,
    required ReaderMode currentMode,
    required ReaderMode defaultMode,
    required ValueChanged<ReaderMode> onApply,
  }) async {
    ReaderMode selectedMode = currentMode;

    await showModalBottomSheet<void>(
      context: context,
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width),
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final theme = Theme.of(context);
            final scheme = theme.colorScheme;
            final sheetColor =
                theme.bottomSheetTheme.backgroundColor ??
                theme.scaffoldBackgroundColor.withValues(alpha: 0.98);
            final selectedBg = scheme.primaryContainer;
            final selectedFg = scheme.onPrimaryContainer;
            final unselectedBg = scheme.surfaceContainerHighest.withValues(
              alpha: 0.55,
            );
            final unselectedFg = scheme.onSurface;
            final borderColor = scheme.outlineVariant.withValues(alpha: 0.45);

            const itemWidth = 140.0;
            const contentWidth = itemWidth * 2 + 40;

            return SafeArea(
              top: false,
              bottom: false,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.pop(dialogContext),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        color: sheetColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(22),
                        ),
                        border: Border.all(color: borderColor),
                      ),
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                      child: SizedBox(
                        width: contentWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Center(
                              child: Container(
                                width: 32,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: scheme.outlineVariant.withValues(
                                    alpha: 0.7,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.l10n.reading_mode,
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              alignment: WrapAlignment.start,
                              children: [
                                for (final mode in _orderedModes)
                                  _ReaderModeTile(
                                    width: itemWidth,
                                    mode: mode,
                                    selected: selectedMode == mode,
                                    selectedBg: selectedBg,
                                    selectedFg: selectedFg,
                                    unselectedBg: unselectedBg,
                                    unselectedFg: unselectedFg,
                                    borderColor: borderColor,
                                    primaryColor: scheme.primary,
                                    onTap: () => setState(() {
                                      selectedMode = mode;
                                    }),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                OutlinedButton(
                                  onPressed: () => setState(() {
                                    selectedMode = defaultMode;
                                  }),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: scheme.onSurface,
                                    side: BorderSide(color: borderColor),
                                    minimumSize: const Size(0, 36),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 0,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  child: Text(context.l10n.reset),
                                ),
                                const Spacer(),
                                FilledButton.icon(
                                  onPressed: () {
                                    Navigator.pop(dialogContext);
                                    onApply(selectedMode);
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: scheme.primary,
                                    foregroundColor: scheme.onPrimary,
                                    minimumSize: const Size(0, 40),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 0,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                  ),
                                  label: Text(context.l10n.ok),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ReaderModePreview extends StatelessWidget {
  const _ReaderModePreview({
    required this.mode,
    required this.selected,
    required this.foreground,
    required this.background,
  });

  final ReaderMode mode;
  final bool selected;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final fg = foreground;

    return SizedBox(
      width: 28,
      height: 22,
      child: Stack(children: _previewMarks(fg)),
    );
  }

  List<Widget> _previewMarks(Color fg) {
    return switch (mode) {
      ReaderMode.ltr => [
        Positioned.fill(
          child: Align(
            child: Icon(Icons.arrow_forward_rounded, color: fg, size: 16),
          ),
        ),
      ],
      ReaderMode.rtl => [
        Positioned.fill(
          child: Align(
            child: Icon(Icons.arrow_back_rounded, color: fg, size: 14),
          ),
        ),
      ],
      ReaderMode.vertical => [
        Positioned.fill(
          child: Align(
            child: Icon(Icons.arrow_downward_rounded, color: fg, size: 16),
          ),
        ),
      ],
      ReaderMode.webtoon => [
        Positioned.fill(
          child: Row(
            children: [
              Icon(Icons.arrow_downward_rounded, color: fg, size: 14),
              Icon(Icons.arrow_downward_rounded, color: fg, size: 14),
            ],
          ),
        ),
      ],
      ReaderMode.verticalContinuous => [
        Positioned.fill(
          child: Row(
            children: [
              Icon(Icons.arrow_downward_rounded, color: fg, size: 14),
              Icon(Icons.arrow_downward_rounded, color: fg, size: 14),
            ],
          ),
        ),
        Positioned(top: 16, left: 0, right: 0, child: _gapLine(fg)),
      ],
      //
      ReaderMode.horizontalContinuous => [
        Positioned.fill(
          child: Row(
            children: [
              Icon(Icons.arrow_forward_rounded, color: fg, size: 14),
              Icon(Icons.arrow_forward_rounded, color: fg, size: 14),
            ],
          ),
        ),
      ],
      ReaderMode.horizontalContinuousRTL => [
        Positioned.fill(
          child: Row(
            children: [
              Icon(Icons.arrow_back_rounded, color: fg, size: 14),
              Icon(Icons.arrow_back_rounded, color: fg, size: 14),
            ],
          ),
        ),
      ],
    };
  }

  Widget _gapLine(Color color) {
    return Container(
      height: 2,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

class _ReaderModeTile extends StatelessWidget {
  const _ReaderModeTile({
    required this.width,
    required this.mode,
    required this.selected,
    required this.selectedBg,
    required this.selectedFg,
    required this.unselectedBg,
    required this.unselectedFg,
    required this.borderColor,
    required this.primaryColor,
    required this.onTap,
  });

  final double width;
  final ReaderMode mode;
  final bool selected;
  final Color selectedBg;
  final Color selectedFg;
  final Color unselectedBg;
  final Color unselectedFg;
  final Color borderColor;
  final Color primaryColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? selectedBg : unselectedBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? primaryColor.withValues(alpha: 0.45)
                  : borderColor,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ReaderModePreview(
                mode: mode,
                selected: selected,
                foreground: selected ? selectedFg : unselectedFg,
                background: Colors.transparent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  getReaderModeName(mode, context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? selectedFg : unselectedFg,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
