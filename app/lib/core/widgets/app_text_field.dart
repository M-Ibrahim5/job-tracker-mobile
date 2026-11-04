import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_constants.dart';

/// Text field with its label above (13/700), a red required marker and an
/// error line that pairs the message with an icon.
class AppTextField extends StatefulWidget {
  /// Creates a field.
  const AppTextField({
    required this.label,
    this.controller,
    this.focusNode,
    this.hint,
    this.helperText,
    this.errorText,
    this.isRequired = false,
    this.isPassword = false,
    this.readOnly = false,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.inputFormatters,
    this.validator,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
    this.onChanged,
    this.onFieldSubmitted,
    this.onTap,
    this.prefixIcon,
    this.suffix,
    this.minLines,
    this.maxLines = 1,
    this.maxLength,
    this.showCounter = false,
    this.initialValue,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hint;
  final String? helperText;

  /// Externally supplied error (e.g. a server field error); shown in addition
  /// to [validator].
  final String? errorText;

  /// Adds the red `*` marker to the label.
  final bool isRequired;

  /// Obscures the text and adds a show/hide toggle.
  final bool isPassword;
  final bool readOnly;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;
  final AutovalidateMode autovalidateMode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;

  /// Called when the field is tapped (e.g. to open a date picker on a
  /// [readOnly] field).
  final VoidCallback? onTap;
  final IconData? prefixIcon;
  final Widget? suffix;
  final int? minLines;
  final int? maxLines;
  final int? maxLength;

  /// Shows a "n / max" counter (needs [maxLength]).
  final bool showCounter;
  final String? initialValue;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final obscure = widget.isPassword && _obscured;

    final suffix = widget.isPassword
        ? IconButton(
            tooltip: _obscured
                ? AppStrings.showPassword
                : AppStrings.hidePassword,
            icon: Icon(
              _obscured
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
            onPressed: () => setState(() => _obscured = !_obscured),
          )
        : widget.suffix;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: widget.label,
            children: [
              if (widget.isRequired)
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: scheme.error),
                ),
            ],
          ),
          style: theme.textTheme.labelMedium?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Semantics(
          label: widget.label,
          excludeSemantics: false,
          child: TextFormField(
            controller: widget.controller,
            initialValue: widget.controller == null
                ? widget.initialValue
                : null,
            focusNode: widget.focusNode,
            obscureText: obscure,
            readOnly: widget.readOnly,
            enabled: widget.enabled,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            autofillHints: widget.autofillHints,
            inputFormatters: widget.inputFormatters,
            autovalidateMode: widget.autovalidateMode,
            minLines: widget.minLines,
            maxLines: obscure ? 1 : widget.maxLines,
            maxLength: widget.maxLength,
            maxLengthEnforcement: MaxLengthEnforcement.none,
            onChanged: widget.onChanged,
            onFieldSubmitted: widget.onFieldSubmitted,
            onTap: widget.onTap,
            validator: (v) => widget.errorText ?? widget.validator?.call(v),
            style: theme.textTheme.bodyLarge,
            buildCounter: widget.showCounter && widget.maxLength != null
                ? (
                    context, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => Text(
                    '$currentLength / $maxLength',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                : (
                    context, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
            errorBuilder: (context, message) => _FieldError(message: message),
            decoration: InputDecoration(
              hintText: widget.hint,
              helperText: widget.helperText,
              helperMaxLines: 3,
              prefixIcon: widget.prefixIcon == null
                  ? null
                  : Icon(widget.prefixIcon),
              suffixIcon: suffix,
              alignLabelWithHint: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldError extends StatelessWidget {
  const _FieldError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 16, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
