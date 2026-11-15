import 'dart:math' as math;

import 'package:brentv/native_bridge.dart';
import 'package:flutter/material.dart';

/// Whole-app zoom in percent: Settings → UI scale, Ctrl+= / Ctrl+- / Ctrl+0.
final uiScale = ValueNotifier<int>(100);
const uiScaleSteps = [75, 90, 100, 110, 125, 150, 175, 200];

Future<void> setUiScale(int percent) async {
  uiScale.value = percent;
  await NativeBridge.instance.setUiScale(percent);
}

/// The next larger (1) or smaller (-1) step from the current scale.
Future<void> stepUiScale(int step) async {
  final next = step > 0
      ? uiScaleSteps.where((s) => s > uiScale.value).firstOrNull
      : uiScaleSteps.where((s) => s < uiScale.value).lastOrNull;
  if (next != null) await setUiScale(next);
}

/// Lays the app out on a smaller (or larger) canvas and scales it to the
/// window, so text, icons and spacing all grow together.
class UiScaled extends StatelessWidget {
  final Widget child;
  const UiScaled({super.key, required this.child});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: uiScale,
    builder: (context, percent, child) {
      final mq = MediaQuery.of(context);
      // Never lays out narrower than 280 px (Material's minimum dialog
      // width), so a large scale can't make a phone screen unusable.
      final scale = math.min(
        percent / 100,
        math.max(1.0, mq.size.shortestSide / 280),
      );
      return FittedBox(
        alignment: Alignment.topLeft,
        child: SizedBox.fromSize(
          size: mq.size / scale,
          child: MediaQuery(
            data: mq.copyWith(
              size: mq.size / scale,
              devicePixelRatio: mq.devicePixelRatio * scale,
              padding: mq.padding / scale,
              viewPadding: mq.viewPadding / scale,
              viewInsets: mq.viewInsets / scale,
            ),
            child: child!,
          ),
        ),
      );
    },
    child: child,
  );
}
