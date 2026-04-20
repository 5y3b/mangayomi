import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/modules/manga/reader/utils/reader_option_utils.dart';
import 'package:mangayomi/providers/l10n_providers.dart';
import 'package:mangayomi/utils/extensions/build_context_extensions.dart';
import 'package:mangayomi/modules/more/settings/reader/providers/reader_state_provider.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class ReaderScreen extends ConsumerWidget {
  const ReaderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defaultReadingMode = ref.watch(defaultReadingModeStateProvider);
    final animatePageTransitions = ref.watch(
      animatePageTransitionsStateProvider,
    );
    final doubleTapAnimationSpeed = ref.watch(
      doubleTapAnimationSpeedStateProvider,
    );
    final pagePreloadAmount = ref.watch(pagePreloadAmountStateProvider);
    final scaleType = ref.watch(scaleTypeStateProvider);
    final backgroundColor = ref.watch(backgroundColorStateProvider);
    final usePageTapZones = ref.watch(usePageTapZonesStateProvider);
    final fullScreenReader = ref.watch(fullScreenReaderStateProvider);

    final cropBorders = ref.watch(cropBordersStateProvider);
    final keepScreenOn = ref.watch(keepScreenOnReaderStateProvider);
    final showPageGaps = ref.watch(showPageGapsStateProvider);
    final webtoonSidePadding = ref.watch(webtoonSidePaddingStateProvider);
    final navigationLayout = ref.watch(readerNavigationLayoutStateProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.reader)),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ListTile(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text(context.l10n.default_reading_mode),
                      content: SizedBox(
                        width: context.width(0.8),
                        child: RadioGroup(
                          groupValue: defaultReadingMode,
                          onChanged: (value) {
                            ref
                                .read(defaultReadingModeStateProvider.notifier)
                                .set(value!);
                            Navigator.pop(context);
                          },
                          child: SuperListView.builder(
                            shrinkWrap: true,
                            itemCount: ReaderMode.values.length,
                            itemBuilder: (context, index) {
                              return RadioListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.all(0),
                                value: ReaderMode.values[index],
                                title: Row(
                                  children: [
                                    Text(
                                      getReaderModeName(
                                        ReaderMode.values[index],
                                        context,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      actions: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () async {
                                Navigator.pop(context);
                              },
                              child: Text(
                                context.l10n.cancel,
                                style: TextStyle(color: context.primaryColor),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
              title: Text(context.l10n.default_reading_mode),
              subtitle: Text(
                getReaderModeName(defaultReadingMode, context),
                style: TextStyle(fontSize: 11, color: context.secondaryColor),
              ),
            ),
            ListTile(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text(context.l10n.double_tap_animation_speed),
                      content: SizedBox(
                        width: context.width(0.8),
                        child: RadioGroup(
                          groupValue: doubleTapAnimationSpeed,
                          onChanged: (value) {
                            ref
                                .read(
                                  doubleTapAnimationSpeedStateProvider.notifier,
                                )
                                .set(value!);
                            Navigator.pop(context);
                          },
                          child: SuperListView.builder(
                            shrinkWrap: true,
                            itemCount: 3,
                            itemBuilder: (context, index) {
                              return RadioListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.all(0),
                                value: index,
                                title: Row(
                                  children: [
                                    Text(getAnimationSpeedName(index, context)),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      actions: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () async {
                                Navigator.pop(context);
                              },
                              child: Text(
                                context.l10n.cancel,
                                style: TextStyle(color: context.primaryColor),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
              title: Text(context.l10n.double_tap_animation_speed),
              subtitle: Text(
                getAnimationSpeedName(doubleTapAnimationSpeed, context),
                style: TextStyle(fontSize: 11, color: context.secondaryColor),
              ),
            ),
            ListTile(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text(context.l10n.background_color),
                      content: SizedBox(
                        width: context.width(0.8),
                        child: RadioGroup(
                          groupValue: backgroundColor,
                          onChanged: (value) {
                            ref
                                .read(backgroundColorStateProvider.notifier)
                                .set(value!);
                            Navigator.pop(context);
                          },
                          child: SuperListView.builder(
                            shrinkWrap: true,
                            itemCount: BackgroundColor.values.length,
                            itemBuilder: (context, index) {
                              return RadioListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.all(0),
                                value: BackgroundColor.values[index],
                                title: Row(
                                  children: [
                                    Text(
                                      getBackgroundColorName(
                                        BackgroundColor.values[index],
                                        context,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      actions: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () async {
                                Navigator.pop(context);
                              },
                              child: Text(
                                context.l10n.cancel,
                                style: TextStyle(color: context.primaryColor),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
              title: Text(context.l10n.background_color),
              subtitle: Text(
                getBackgroundColorName(backgroundColor, context),
                style: TextStyle(fontSize: 11, color: context.secondaryColor),
              ),
            ),
            ListTile(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    int tempAmount = pagePreloadAmount;
                    return AlertDialog(
                      title: Text(context.l10n.page_preload_amount),
                      content: SizedBox(
                        width: context.width(0.8),
                        child: StatefulBuilder(
                          builder: (context, setState) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  tempAmount.toString(),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Slider(
                                  value: tempAmount.toDouble(),
                                  min: 1,
                                  max: 20,
                                  // divisions: 19, // makes the slider a bit sluggish
                                  // label: tempAmount.toString(), // value indicator balloon. Redundant because of the Text widget above
                                  onChanged: (double newVal) {
                                    setState(() {
                                      tempAmount = newVal.round();
                                    });
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            context.l10n.cancel,
                            style: TextStyle(color: context.primaryColor),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            ref
                                .read(pagePreloadAmountStateProvider.notifier)
                                .set(tempAmount);
                            Navigator.pop(context);
                          },
                          child: Text(
                            context.l10n.ok,
                            style: TextStyle(color: context.primaryColor),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
              title: Text(context.l10n.page_preload_amount),
              subtitle: Text(
                context.l10n.page_preload_amount_subtitle,
                style: TextStyle(fontSize: 11, color: context.secondaryColor),
              ),
            ),
            ListTile(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text(context.l10n.scale_type),
                      content: SizedBox(
                        width: context.width(0.8),
                        child: RadioGroup(
                          groupValue: scaleType.index,
                          onChanged: (value) {
                            ref
                                .read(scaleTypeStateProvider.notifier)
                                .set(ScaleType.values[value!]);
                            Navigator.pop(context);
                          },
                          child: SuperListView.builder(
                            shrinkWrap: true,
                            itemCount: getScaleTypeNames(context).length,
                            itemBuilder: (context, index) {
                              return RadioListTile(
                                // dense: true,
                                contentPadding: const EdgeInsets.all(0),
                                value: index,
                                title: Row(
                                  children: [
                                    Text(
                                      getScaleTypeNames(
                                        context,
                                      )[index].toString(),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      actions: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () async {
                                Navigator.pop(context);
                              },
                              child: Text(
                                context.l10n.cancel,
                                style: TextStyle(color: context.primaryColor),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
              title: Text(context.l10n.scale_type),
              subtitle: Text(
                getScaleTypeNames(context)[scaleType.index],
                style: TextStyle(fontSize: 11, color: context.secondaryColor),
              ),
            ),
            if (!(Platform.isAndroid || Platform.isIOS))
              SwitchListTile(
                value: fullScreenReader,
                title: Text(context.l10n.fullscreen),
                onChanged: (value) {
                  ref.read(fullScreenReaderStateProvider.notifier).set(value);
                },
              ),
            SwitchListTile(
              value: animatePageTransitions,
              title: Text(context.l10n.animate_page_transitions),
              onChanged: (value) {
                ref
                    .read(animatePageTransitionsStateProvider.notifier)
                    .set(value);
              },
            ),
            SwitchListTile(
              value: cropBorders,
              title: Text(context.l10n.crop_borders),
              onChanged: (value) {
                ref.read(cropBordersStateProvider.notifier).set(value);
              },
            ),
            SwitchListTile(
              value: usePageTapZones,
              title: Text(context.l10n.use_page_tap_zones),
              onChanged: (value) {
                ref.read(usePageTapZonesStateProvider.notifier).set(value);
              },
            ),
            SwitchListTile(
              value: keepScreenOn,
              title: Text(context.l10n.keep_screen_on),
              onChanged: (value) {
                ref.read(keepScreenOnReaderStateProvider.notifier).set(value);
              },
            ),
            SwitchListTile(
              value: showPageGaps,
              title: Text(context.l10n.show_page_gaps),
              onChanged: (value) {
                ref.read(showPageGapsStateProvider.notifier).set(value);
              },
            ),
            ListTile(
              title: Text(context.l10n.webtoon_side_padding),
              subtitle: Slider(
                min: 0,
                max: 50,
                divisions: 50,
                label: '$webtoonSidePadding%',
                value: webtoonSidePadding.toDouble(),
                onChanged: (value) {
                  ref
                      .read(webtoonSidePaddingStateProvider.notifier)
                      .set(value.toInt());
                },
              ),
            ),
            ListTile(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) {
                    return SimpleDialog(
                      title: Text(context.l10n.navigation_layout),
                      children: [
                        RadioGroup<int>(
                          groupValue: navigationLayout,
                          onChanged: (val) {
                            ref
                                .read(
                                  readerNavigationLayoutStateProvider.notifier,
                                )
                                .set(val!);
                            Navigator.pop(ctx);
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(6, (i) {
                              return RadioListTile<int>(
                                value: i,
                                title: Text(getNavigationLayoutName(i, context)),
                              );
                            }),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
              title: Text(context.l10n.navigation_layout),
              subtitle: Text(
                getNavigationLayoutName(navigationLayout, context),
                style: TextStyle(fontSize: 11, color: context.secondaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

