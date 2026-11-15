import 'dart:io' show Platform;

import 'package:flutter/material.dart';

/// A phone has no keyboard or pointer resting on anything, so nothing is
/// shown as focused there; a tap still flashes what was touched.
bool get showsFocus => !Platform.isIOS;

// dwl's palette, as in brendwl, the bar, foot and mako.
const _background = Color(0xff222222);
const _border = Color(0xff444444);
const _focus = Color(0xff005577);
const _text = Color(0xffeeeeee);
const _dimText = Color(0xffbbbbbb);
const _urgent = Color(0xffff0000);

/// dwl's border width; tiles, fields, dialogs and focus outlines use it.
const borderWidth = 3.0;

final squareCorners = ValueNotifier(false);

/// Keeps each surface's existing radius in Rounded mode.
BorderRadius cornerRadius(BuildContext context, [double rounded = 12]) {
  final shape = Theme.of(context).cardTheme.shape;
  return shape is RoundedRectangleBorder &&
          shape.borderRadius == BorderRadius.zero
      ? BorderRadius.zero
      : BorderRadius.circular(rounded);
}

/// Flat #222222 surfaces with #444444 borders; focused or selected things
/// are #005577, like dwl's focused window and the bar's selected tag.
ThemeData dwlTheme({
  required bool showFocusOutline,
  bool squareCorners = false,
}) {
  final radius = squareCorners ? BorderRadius.zero : BorderRadius.circular(12);
  const square = RoundedRectangleBorder();
  final buttonShape = squareCorners
      ? const WidgetStatePropertyAll(square)
      : null;
  // A #005577 ring, or a white one on things that are already #005577.
  BorderSide? ring(Set<WidgetState> states, {bool filled = false}) =>
      states.contains(WidgetState.focused) && showFocusOutline && showsFocus
      ? BorderSide(
          color: filled || states.contains(WidgetState.selected)
              ? _text
              : _focus,
          width: borderWidth,
        )
      : null;
  final frame = RoundedRectangleBorder(
    borderRadius: radius,
    side: const BorderSide(color: _border, width: borderWidth),
  );
  Color label(Set<WidgetState> states) => states.contains(WidgetState.error)
      ? _urgent
      : states.contains(WidgetState.focused)
      ? _text
      : _dimText;
  final field = OutlineInputBorder(
    borderRadius: radius,
    borderSide: const BorderSide(color: _border, width: borderWidth),
  );
  return ThemeData(
    useMaterial3: true,
    // A focused tile or list row turns #005577, like the bar's selected title.
    focusColor: showsFocus ? _focus : Colors.transparent,
    colorScheme: const ColorScheme.dark(
      primary: _focus,
      onPrimary: _text,
      primaryContainer: _focus,
      onPrimaryContainer: _text,
      secondary: _focus,
      onSecondary: _text,
      secondaryContainer: _focus,
      onSecondaryContainer: _text,
      tertiary: _focus,
      onTertiary: _text,
      error: _urgent,
      onError: _text,
      surface: _background,
      onSurface: _text,
      onSurfaceVariant: _dimText,
      surfaceDim: _background,
      surfaceBright: _background,
      surfaceContainerLowest: _background,
      surfaceContainerLow: _background,
      surfaceContainer: _background,
      surfaceContainerHigh: _background,
      surfaceContainerHighest: _background,
      outline: _border,
      outlineVariant: _border,
      inverseSurface: _text,
      onInverseSurface: _background,
      inversePrimary: _focus,
      surfaceTint: Colors.transparent,
    ),
    cardTheme: CardThemeData(elevation: 0, shape: frame),
    dialogTheme: DialogThemeData(shape: frame),
    popupMenuTheme: PopupMenuThemeData(shape: frame),
    // #005577 only fills and outlines; as text on #222222 it is unreadable.
    inputDecorationTheme: InputDecorationTheme(
      floatingLabelStyle: WidgetStateTextStyle.resolveWith(
        (states) => TextStyle(color: label(states)),
      ),
      border: field,
      enabledBorder: field,
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: _focus, width: borderWidth),
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: _text,
      unselectedLabelColor: _dimText,
      indicatorColor: _focus,
      dividerColor: _border,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: _text,
      linearTrackColor: _border,
      circularTrackColor: Colors.transparent,
      borderRadius: squareCorners ? BorderRadius.zero : null,
    ),
    snackBarTheme: const SnackBarThemeData(
      // mako's notification colors.
      backgroundColor: _focus,
      contentTextStyle: TextStyle(color: _text),
      actionTextColor: _text,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: _background,
      indicatorColor: _focus,
      indicatorShape: squareCorners ? square : null,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? _text : _dimText,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          color: states.contains(WidgetState.selected) ? _text : _dimText,
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: buttonShape,
        side: WidgetStateProperty.resolveWith(
          (states) =>
              ring(states) ??
              const BorderSide(color: _border, width: borderWidth),
        ),
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: _text,
      selectionColor: _focus,
      selectionHandleColor: _text,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        shape: buttonShape,
        side: WidgetStateProperty.resolveWith(
          (states) => ring(states, filled: true) ?? BorderSide.none,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        shape: buttonShape,
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? _text.withValues(alpha: 0.38)
              : _text,
        ),
        side: WidgetStateProperty.resolveWith(ring),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        shape: buttonShape,
        side: WidgetStateProperty.resolveWith(ring),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(shape: buttonShape),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(shape: buttonShape),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      shape: squareCorners ? square : null,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      shape: squareCorners ? square : null,
    ),
    menuTheme: MenuThemeData(style: MenuStyle(shape: buttonShape)),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? _text : _dimText,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => ring(states)?.color,
      ),
      trackOutlineWidth: WidgetStateProperty.resolveWith(
        (states) => ring(states)?.width,
      ),
    ),
  );
}
