import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

/// Shows a floating snackbar, replacing any visible one.
void showAppSnackBar(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: actionLabel == null
            ? null
            : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
      ),
    );
}

/// Shows [message] with an Undo action. [onClosedWithoutUndo] runs when the
/// snackbar closes for any reason other than the Undo tap, so callers can
/// delay a destructive request until then.
void showUndoSnackBar(
  BuildContext context,
  String message, {
  required VoidCallback onUndo,
  required VoidCallback onClosedWithoutUndo,
}) {
  var undone = false;
  final controller = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  controller
      .showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 5),
          // Snackbars with an action persist by default; this one must close
          // by itself so the delayed request is sent.
          persist: false,
          action: SnackBarAction(
            label: AppStrings.undo,
            onPressed: () {
              undone = true;
              onUndo();
            },
          ),
        ),
      )
      .closed
      .then((_) {
        if (!undone) onClosedWithoutUndo();
      });
}
