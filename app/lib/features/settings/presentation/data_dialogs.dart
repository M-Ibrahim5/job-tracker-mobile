import 'package:flutter/material.dart';

import '../../../core/constants/account_strings.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/enums/enums.dart';

/// Lets the user pick JSON or CSV; resolves to null when dismissed.
Future<ExportFormat?> showExportSheet(BuildContext context) {
  return showModalBottomSheet<ExportFormat>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.data_object_rounded),
            title: const Text(AccountStrings.exportJson),
            onTap: () => Navigator.of(context).pop(ExportFormat.json),
          ),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text(AccountStrings.exportCsv),
            onTap: () => Navigator.of(context).pop(ExportFormat.csv),
          ),
          const SizedBox(height: Spacing.sm),
        ],
      ),
    ),
  );
}

/// Two-step confirmation for wiping all data: a dialog, then typing DELETE.
/// Resolves to true only when both steps are confirmed.
Future<bool> confirmDeleteAllData(BuildContext context) async {
  final first = await showConfirmDialog(
    context,
    title: AccountStrings.deleteAllTitle,
    message: AccountStrings.deleteAllBody,
    confirmLabel: AppStrings.delete,
    destructive: true,
  );
  if (!first || !context.mounted) return false;
  final second = await showDialog<bool>(
    context: context,
    builder: (_) => const TypeToConfirmDialog(
      title: AccountStrings.deleteAllTypeTitle,
      word: AccountStrings.deleteConfirmWord,
      confirmLabel: AccountStrings.deleteAllData,
    ),
  );
  return second ?? false;
}

/// Dialog whose confirm button stays disabled until [word] is typed exactly.
class TypeToConfirmDialog extends StatefulWidget {
  /// Creates the dialog.
  const TypeToConfirmDialog({
    required this.title,
    required this.word,
    required this.confirmLabel,
    super.key,
  });

  final String title;
  final String word;
  final String confirmLabel;

  @override
  State<TypeToConfirmDialog> createState() => _TypeToConfirmDialogState();
}

class _TypeToConfirmDialogState extends State<TypeToConfirmDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return AlertDialog(
      title: Text(widget.title),
      content: AppTextField(
        label: widget.word,
        controller: _controller,
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(AppStrings.cancel),
        ),
        TextButton(
          onPressed: _controller.text == widget.word
              ? () => Navigator.of(context).pop(true)
              : null,
          style: TextButton.styleFrom(foregroundColor: error),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
