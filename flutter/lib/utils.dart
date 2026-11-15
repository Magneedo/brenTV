import 'package:flutter/material.dart';
import 'package:brentv/native_bridge.dart';
import 'package:brentv/whats_new_modal.dart';
import 'package:package_info_plus/package_info_plus.dart';

class Utils {
  static Future<bool> hasTouchScreen() async {
    return true;
  }

  static Future<void> maybeShowWhatsNew(BuildContext context) async {
    final version = (await PackageInfo.fromPlatform()).version;
    if (!context.mounted) return;
    if (!await NativeBridge.instance.shouldShowWhatsNew(version)) return;
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (context) => WhatsNewModal(version: version),
    );
  }
}
