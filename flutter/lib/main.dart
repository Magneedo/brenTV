import 'library/media_library.dart';
import 'library/download_ui.dart';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show LicenseRegistry, LicenseEntryWithLineBreaks;
import 'package:flutter/services.dart';
import 'package:brentv/generated/generated_proto.pb.dart' as gen;
import 'package:brentv/home.dart';
import 'package:brentv/models/custom_shortcut.dart';
import 'package:brentv/models/filters.dart';
import 'package:brentv/models/view_type.dart';
import 'package:brentv/models/node_type.dart';
import 'package:brentv/models/node.dart';
import 'package:brentv/models/home_manager.dart';
import 'package:brentv/models/settings.dart';
import 'package:brentv/utils.dart';
import 'package:brentv/native_bridge.dart' as nb;
import 'package:brentv/setup.dart';
import 'package:brentv/theme.dart';
import 'package:brentv/tv_home.dart';
import 'package:brentv/ui_scale.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isIOS) {
    LicenseRegistry.addLicense(() async* {
      final notices = <String>[];
      for (final name in ['NOTICE', 'LGPL-3.0', 'GPL-3.0']) {
        notices.add(await rootBundle.loadString('assets/FFmpeg-$name.txt'));
      }
      yield LicenseEntryWithLineBreaks([
        'FFmpeg',
        'FFmpegKit',
      ], notices.join('\n\n'));
    });
  }
  await SystemChrome.setPreferredOrientations([]);
  final appDir = await getApplicationSupportDirectory();
  final tempDir = await getApplicationCacheDirectory();
  try {
    await nb.NativeBridge.instance.initialize(
      gen.InitMessage(dbPath: appDir.path, tempPath: tempDir.path),
    );
  } catch (e, stack) {
    if (!e.toString().contains(appDir.path)) {
      developer.log(
        "Failed to initialize NativeBridge",
        error: e,
        stackTrace: stack,
        name: "xyz.brendynmarroquin.brentv",
      );
    }
  }
  await MediaLibrary.instance.initialize(
    await nb.NativeBridge.instance.getMediaState(),
    documentsDirectory: Platform.isIOS
        ? (await getApplicationDocumentsDirectory()).path
        : null,
  );
  final hasSources = await nb.NativeBridge.instance.hasSources();
  final settings = await nb.NativeBridge.instance.getSettings();
  final hasTouchScreen = await Utils.hasTouchScreen();
  uiScale.value = settings.uiScalePercent;
  squareCorners.value = settings.squareCorners;
  runApp(
    MyApp(
      skipSetup: hasSources,
      settings: settings,
      hasTouchScreen: hasTouchScreen,
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool skipSetup;
  final Settings settings;
  final bool hasTouchScreen;
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  const MyApp({
    super.key,
    required this.skipSetup,
    required this.settings,
    required this.hasTouchScreen,
  });

  void _showDownloads() {
    final context = navigatorKey.currentState?.overlay?.context;
    if (context == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: const DownloadsPage(activeOnly: true),
      ),
    );
  }

  bool get _isEditingText {
    final focus = FocusManager.instance.primaryFocus;
    return focus?.context?.findAncestorWidgetOfExactType<EditableText>() !=
        null;
  }

  bool get _showFocusOutline => !hasTouchScreen || Platform.isLinux;

  bool get _isTvMode =>
      settings.forceTVMode || (!hasTouchScreen && Platform.isIOS);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: squareCorners,
      builder: (context, square, _) => _buildApp(square),
    );
  }

  Widget _buildApp(bool square) {
    return MaterialApp(
      title: 'brenTV',
      navigatorKey: navigatorKey,
      builder: (context, child) {
        return CallbackShortcuts(
          bindings: {
            const CustomShortcut(
              SingleActivator(LogicalKeyboardKey.escape),
            ): () {
              if (_isEditingText) return;
              navigatorKey.currentState?.maybePop();
            },
            const CustomShortcut(
              SingleActivator(LogicalKeyboardKey.backspace),
            ): () {
              if (_isEditingText) return;
              navigatorKey.currentState?.maybePop();
            },
            for (final shift in [false, true])
              SingleActivator(
                LogicalKeyboardKey.equal,
                control: true,
                shift: shift,
              ): () =>
                  stepUiScale(1),
            const SingleActivator(
              LogicalKeyboardKey.numpadAdd,
              control: true,
            ): () =>
                stepUiScale(1),
            const SingleActivator(
              LogicalKeyboardKey.minus,
              control: true,
            ): () =>
                stepUiScale(-1),
            const SingleActivator(
              LogicalKeyboardKey.numpadSubtract,
              control: true,
            ): () =>
                stepUiScale(-1),
            const SingleActivator(
              LogicalKeyboardKey.digit0,
              control: true,
            ): () =>
                setUiScale(100),
          },
          child: TooltipVisibility(
            visible: false,
            child: UiScaled(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  child ?? const SizedBox.shrink(),
                  if (MediaQuery.viewInsetsOf(context).bottom == 0)
                    Positioned(
                      right: 16,
                      bottom: 100,
                      child: SafeArea(
                        child: DownloadProgressIndicator(
                          onOpen: _showDownloads,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
      theme: dwlTheme(
        showFocusOutline: _showFocusOutline,
        squareCorners: square,
      ),
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      home: skipSetup
          ? (_isTvMode
                ? const TvHome()
                : Home(
                    firstLaunch: true,
                    refresh: settings.refreshOnStart,
                    home: HomeManager(
                      filters: Filters(viewType: settings.effectiveStartPage),
                    ),
                    openNode:
                        settings.effectiveStartPage == ViewType.categories &&
                            settings.startGroupId != null
                        ? Node(
                            id: settings.startGroupId!,
                            name: settings.startGroupName ?? "",
                            type: NodeType.category,
                          )
                        : null,
                  ))
          : Setup(tvMode: _isTvMode),
    );
  }
}
