import 'package:flutter/material.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/providers/l10n_providers.dart';

String getReaderModeName(ReaderMode readerMode, BuildContext context) {
  return switch (readerMode) {
    ReaderMode.vertical => context.l10n.reading_mode_vertical,
    ReaderMode.verticalContinuous =>
      context.l10n.reading_mode_vertical_continuous,
    ReaderMode.ltr => context.l10n.reading_mode_left_to_right,
    ReaderMode.rtl => context.l10n.reading_mode_right_to_left,
    ReaderMode.horizontalContinuous => context.l10n.horizontal_continious,
    ReaderMode.horizontalContinuousRTL =>
      '${context.l10n.horizontal_continious} (RTL)',
    _ => context.l10n.reading_mode_webtoon,
  };
}

String getBackgroundColorName(
  BackgroundColor backgroundColor,
  BuildContext context,
) {
  return switch (backgroundColor) {
    BackgroundColor.white => context.l10n.white,
    BackgroundColor.grey => context.l10n.grey,
    BackgroundColor.black => context.l10n.black,
    _ => context.l10n.automaic,
  };
}

Color? getBackgroundColor(BackgroundColor backgroundColor) {
  return switch (backgroundColor) {
    BackgroundColor.white => Colors.white,
    BackgroundColor.grey => Colors.grey,
    BackgroundColor.black => Colors.black,
    _ => null,
  };
}

String getColorFilterBlendModeName(
  ColorFilterBlendMode backgroundColor,
  BuildContext context,
) {
  return switch (backgroundColor) {
    ColorFilterBlendMode.none => context.l10n.blend_mode_default,
    ColorFilterBlendMode.multiply => context.l10n.blend_mode_multiply,
    ColorFilterBlendMode.screen => context.l10n.blend_mode_screen,
    ColorFilterBlendMode.overlay => context.l10n.blend_mode_overlay,
    ColorFilterBlendMode.colorDodge => context.l10n.blend_mode_colorDodge,
    ColorFilterBlendMode.lighten => context.l10n.blend_mode_lighten,
    ColorFilterBlendMode.colorBurn => context.l10n.blend_mode_colorBurn,
    ColorFilterBlendMode.difference => context.l10n.blend_mode_difference,
    ColorFilterBlendMode.saturation => context.l10n.blend_mode_saturation,
    ColorFilterBlendMode.softLight => context.l10n.blend_mode_softLight,
    ColorFilterBlendMode.plus => context.l10n.blend_mode_plus,
    ColorFilterBlendMode.exclusion => context.l10n.blend_mode_exclusion,
    _ => context.l10n.blend_mode_darken,
  };
}

BlendMode? getColorFilterBlendMode(
  ColorFilterBlendMode backgroundColor,
  BuildContext context,
) {
  return switch (backgroundColor) {
    ColorFilterBlendMode.none => null,
    ColorFilterBlendMode.multiply => BlendMode.multiply,
    ColorFilterBlendMode.screen => BlendMode.screen,
    ColorFilterBlendMode.overlay => BlendMode.overlay,
    ColorFilterBlendMode.colorDodge => BlendMode.colorDodge,
    ColorFilterBlendMode.lighten => BlendMode.lighten,
    ColorFilterBlendMode.colorBurn => BlendMode.colorBurn,
    ColorFilterBlendMode.difference => BlendMode.difference,
    ColorFilterBlendMode.saturation => BlendMode.saturation,
    ColorFilterBlendMode.softLight => BlendMode.softLight,
    ColorFilterBlendMode.plus => BlendMode.plus,
    ColorFilterBlendMode.exclusion => BlendMode.exclusion,
    _ => BlendMode.darken,
  };
}

String getAnimationSpeedName(int type, BuildContext context) {
  return switch (type) {
    0 => context.l10n.no_animation,
    1 => context.l10n.normal,
    _ => context.l10n.fast,
  };
}

List<String> getScaleTypeNames(BuildContext context) {
  return [
    context.l10n.scale_type_fit_screen,
    context.l10n.scale_type_stretch,
    context.l10n.scale_type_fit_width,
    context.l10n.scale_type_fit_height,
  ];
}

String getNavigationLayoutName(int index, BuildContext context) {
  return switch (index) {
    0 => context.l10n.nav_layout_default,
    1 => context.l10n.nav_layout_l_shaped,
    2 => context.l10n.nav_layout_kindle,
    3 => context.l10n.nav_layout_edge,
    4 => context.l10n.nav_layout_right_and_left,
    5 => context.l10n.nav_layout_disabled,
    _ => context.l10n.nav_layout_default,
  };
}
