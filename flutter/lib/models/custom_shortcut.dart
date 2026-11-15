import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomShortcut extends ShortcutActivator {
  final ShortcutActivator activator;

  const CustomShortcut(this.activator);

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) {
    if (!activator.accepts(event, state)) {
      return false;
    }

    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext != null) {
      final isEditing =
          focusContext.findAncestorWidgetOfExactType<EditableText>() != null;
      if (isEditing) {
        return false;
      }
    }

    return true;
  }

  @override
  String debugDescribeKeys() {
    return activator.debugDescribeKeys();
  }
}

/// Shortcuts for a whole page. A key goes to the focused widget and then up
/// the tree, and while nothing on a page has focus the route's focus scope,
/// which sits above the page, holds it, so a plain [CallbackShortcuts] inside
/// the page never sees the key. The autofocused scope below the bindings takes
/// that focus instead. Widgets inside can still autofocus, because this scope
/// starts with no focused child.
class PageShortcuts extends StatelessWidget {
  final Map<ShortcutActivator, VoidCallback> bindings;
  final Widget child;

  const PageShortcuts({super.key, required this.bindings, required this.child});

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: bindings,
    child: FocusScope(autofocus: true, child: child),
  );
}
