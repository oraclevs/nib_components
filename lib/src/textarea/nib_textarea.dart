import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nib_motion/nib_motion.dart'
    show NibAnim, NibMotion, NibTransition;

import '../theme/nib_theme.dart';
import '../validation/nib_validators.dart';

/// A native, token-driven multi-line text field.
///
/// Simple by default — `NibTextarea(onChanged: ...)` already looks finished,
/// growing from [minLines] up to [maxLines] as the user types (then
/// scrolling), with optional [label]/[helperText]/[errorText]/character
/// counter chrome.
///
/// Extends [FormField], so it works inside a Flutter [Form] exactly like
/// [TextFormField] does: `Form(key: formKey, child: Column(children: [
/// NibTextarea(validator: ...), ...]))`, then `formKey.currentState!.validate()`
/// / `.save()` / `.reset()`.
///
/// ```dart
/// NibTextarea(label: 'Bio', onChanged: (v) {})
/// NibTextarea(maxLength: 280, showCounter: true, onChanged: (v) {})
/// NibTextarea(label: 'Bio', validator: NibValidators.required())
/// ```
class NibTextarea extends FormField<String> {
  // Forwards a NibValidator?-typed validator to super verbatim; a super
  // parameter would erase that nicer public type from the API.
  // ignore: use_super_parameters
  NibTextarea({
    super.key,
    this.controller,
    String? initialValue,
    this.onChanged,
    this.focusNode,
    this.autofocus = false,
    this.label,
    this.placeholder,
    this.helperText,

    /// Error message shown below the field (in [NibTheme.destructive]),
    /// overriding [helperText] and tinting the border/counter. Takes
    /// precedence over any error `validator` computes (passed straight
    /// through as [FormField.forceErrorText]) — use this for errors that
    /// can't be expressed as a pure function of the current text (e.g. a
    /// server-side/async validation result).
    String? errorText,

    /// Computes an error from the current text — `null` for valid, a
    /// message to show for invalid. See [NibValidators] for predefined
    /// checks (`email`, `password`, `name`, `required`, ...) and
    /// [NibValidators.compose] to chain several. Also runs (bypassing
    /// [autovalidateMode]) whenever an ancestor [Form]'s `validate()`/
    /// `save()` is called.
    NibValidator? validator,

    /// When the [validator]'s error is shown. Defaults to
    /// [AutovalidateMode.onUserInteraction] (validates from the first edit).
    /// [AutovalidateMode.onUnfocus] validates once the field loses focus;
    /// [AutovalidateMode.always] validates immediately, including on initial
    /// mount; [AutovalidateMode.disabled] only validates when explicitly
    /// triggered (e.g. `Form.validate()`, or a `GlobalKey<FormFieldState>`).
    AutovalidateMode autovalidateMode = AutovalidateMode.onUserInteraction,

    /// Called with the current text when an ancestor [Form] is saved via
    /// `Form.save()`/`FormState.save()`.
    super.onSaved,

    /// Called when this field is reset — directly via a
    /// `GlobalKey<FormFieldState>`, or when an ancestor [Form] is reset via
    /// `Form.reset()`.
    super.onReset,
    this.minLines = 3,
    this.maxLines,
    this.maxLength,
    this.showCounter = false,
    bool disabled = false,
    this.padding,
    this.minHeight,
    this.borderRadius,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth,
    this.style,
    this.labelStyle,
    this.hintStyle,
    this.helperStyle,
    this.errorStyle,
    this.counterStyle,
    this.labelSpacing,
    this.footerSpacing,
    this.animated = false,
    this.transition,
  }) : assert(
         controller == null || initialValue == null,
         'NibTextarea: provide either a controller or an initialValue, not both.',
       ),
       assert(
         maxLines == null || maxLines >= minLines,
         'NibTextarea: maxLines must be >= minLines when set.',
       ),
       disabled = disabled,
       super(
         initialValue: controller?.text ?? initialValue,
         validator: validator,
         forceErrorText: errorText,
         autovalidateMode: autovalidateMode,
         enabled: !disabled,
         builder: (field) => (field as _NibTextareaState)._build(),
       );

  /// Optional external controller. When `null`, the widget creates and owns
  /// its own, seeded with the constructor's `initialValue`.
  final TextEditingController? controller;

  /// Fires on every text change, from either an internal or external
  /// controller.
  final ValueChanged<String>? onChanged;

  /// Optional external focus node. When `null`, the widget creates and owns
  /// its own.
  final FocusNode? focusNode;

  /// Whether to focus this field on mount.
  final bool autofocus;

  /// Label shown above the field.
  final String? label;

  /// Hint text shown inside the field while empty.
  final String? placeholder;

  /// Helper text shown below the field. Replaced by the error text when set.
  final String? helperText;

  /// The field's height floor, in text lines.
  final int minLines;

  /// The field's height ceiling, in text lines, past which it scrolls
  /// internally instead of growing further. `null` ⇒ unbounded growth.
  final int? maxLines;

  /// Caps the number of characters the field accepts. `null` ⇒ unlimited.
  final int? maxLength;

  /// Shows a `current/max` (or just `current` when [maxLength] is `null`)
  /// counter below the field.
  final bool showCounter;

  /// Disables interaction and dims the field.
  final bool disabled;

  /// Inner content padding. `null` ⇒ a sensible default.
  final EdgeInsetsGeometry? padding;

  /// Minimum height of the decorated field, excluding label and footer.
  /// Text scaling and additional lines may make it taller.
  final double? minHeight;

  /// Corner radius of the box. `null` ⇒ [NibTheme.radiusDefault].
  final BorderRadius? borderRadius;

  /// Fill color of the box. `null` ⇒ [NibTheme.background] (or
  /// [NibTheme.muted] while [disabled]).
  final Color? backgroundColor;

  /// Border color of the box. `null` ⇒ [NibTheme.border] (or
  /// [NibTheme.destructive] while showing an error).
  final Color? borderColor;

  /// Border thickness of the box. `null` ⇒ `1`.
  final double? borderWidth;

  /// Style of the typed text. Merged onto the default (any property you
  /// don't set — e.g. leaving `color` unset — keeps the theme default).
  final TextStyle? style;

  /// Style of [label]. Merged onto the default.
  final TextStyle? labelStyle;

  /// Style of the [placeholder] hint. Merged onto the default.
  final TextStyle? hintStyle;

  /// Style of [helperText]. Merged onto the default. Has no effect while the
  /// error text is showing — see [errorStyle].
  final TextStyle? helperStyle;

  /// Style of the error text. Merged onto the default (which includes
  /// [NibTheme.destructive] as the color).
  final TextStyle? errorStyle;

  /// Style of the character counter. Merged onto the default.
  final TextStyle? counterStyle;

  /// Vertical gap between [label] and the field. `null` ⇒ `6`.
  final double? labelSpacing;

  /// Vertical gap between the field and the helper/error/counter row below
  /// it. `null` ⇒ `6`.
  final double? footerSpacing;

  /// Opt-in `nib_motion` fade+slide when the helper/error row appears or its
  /// text changes. `false` builds **zero** [NibMotion].
  final bool animated;

  /// Timing/curve for the [animated] helper/error transition. `null` → a
  /// short ~150ms ease.
  final NibTransition? transition;

  @override
  FormFieldState<String> createState() => _NibTextareaState();
}

class _NibTextareaState extends FormFieldState<String> {
  TextEditingController? _internalController;
  FocusNode? _internalFocusNode;
  bool _focused = false;
  int _length = 0;

  @override
  NibTextarea get widget => super.widget as NibTextarea;

  TextEditingController get _effectiveController =>
      widget.controller ??
      (_internalController ??= TextEditingController(
        text: widget.initialValue,
      ));

  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  NibTransition get _transition =>
      widget.transition ??
      const NibTransition(duration: Duration(milliseconds: 150));

  @override
  void initState() {
    super.initState();
    _length = _effectiveController.text.length;
    _effectiveFocusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(NibTextarea old) {
    super.didUpdateWidget(old);
    if (widget.focusNode != old.focusNode) {
      final previousNode = old.focusNode ?? _internalFocusNode;
      previousNode?.removeListener(_handleFocusChange);
      if (widget.focusNode == null) {
        _internalFocusNode ??= FocusNode();
      } else {
        _internalFocusNode?.dispose();
        _internalFocusNode = null;
      }
      _effectiveFocusNode.addListener(_handleFocusChange);
    }
  }

  @override
  void dispose() {
    _internalFocusNode?.removeListener(_handleFocusChange);
    _internalFocusNode?.dispose();
    _internalController?.dispose();
    super.dispose();
  }

  @override
  void reset() {
    super.reset();
    setState(() {
      _effectiveController.text = widget.initialValue ?? '';
      _length = _effectiveController.text.length;
    });
  }

  void _handleFocusChange() {
    setState(() => _focused = _effectiveFocusNode.hasFocus);
  }

  void _handleChanged(String value) {
    setState(() => _length = value.length);
    didChange(value);
    widget.onChanged?.call(value);
  }

  Widget _build() {
    final theme = NibTheme.of(context);
    final String? errorMessage = errorText;
    final hasError = errorMessage != null;
    final atLimit = widget.maxLength != null && _length >= widget.maxLength!;

    // Border color/width stay constant across focus states — the focus
    // indicator is a layout-neutral ring overlay (below), so it never
    // shifts the field's inner content box.
    final Color borderColor =
        widget.borderColor ?? (hasError ? theme.destructive : theme.border);
    final radius =
        widget.borderRadius ?? BorderRadius.circular(theme.radiusDefault);
    final padding =
        widget.padding ??
        const EdgeInsets.symmetric(horizontal: 12, vertical: 10);

    final field = TextField(
      controller: _effectiveController,
      focusNode: _effectiveFocusNode,
      autofocus: widget.autofocus,
      enabled: !widget.disabled,
      onChanged: widget.disabled ? null : _handleChanged,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      inputFormatters: widget.maxLength == null
          ? null
          : [LengthLimitingTextInputFormatter(widget.maxLength)],
      style: const TextStyle(
        fontSize: 14,
        height: 1.4,
      ).copyWith(color: theme.foreground).merge(widget.style),
      cursorColor: theme.primary,
      decoration: InputDecoration(
        // Explicit `filled: false` so an ambient Material `InputDecorationTheme`
        // can't paint its own fill behind just the text — the DecoratedBox
        // below is the field's only background.
        filled: false,
        border: InputBorder.none,
        isDense: true,
        isCollapsed: true,
        hintText: widget.placeholder,
        hintStyle: const TextStyle(
          fontSize: 14,
        ).copyWith(color: theme.mutedForeground).merge(widget.hintStyle),
        counterText: '',
      ),
    );

    final Widget box = Stack(
      clipBehavior: Clip.none,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: widget.minHeight ?? 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color:
                  widget.backgroundColor ??
                  (widget.disabled ? theme.muted : theme.background),
              borderRadius: radius,
              border: Border.all(
                color: borderColor,
                width: widget.borderWidth ?? 1,
              ),
            ),
            child: Padding(padding: padding, child: field),
          ),
        ),
        if (_focused && !widget.disabled)
          Positioned(
            left: -2,
            top: -2,
            right: -2,
            bottom: -2,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: hasError ? theme.destructive : theme.ring,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ).copyWith(color: theme.foreground).merge(widget.labelStyle),
          ),
          SizedBox(height: widget.labelSpacing ?? 6),
        ],
        box,
        if (_showFootRow(hasError))
          _buildFootRow(
            theme,
            hasError: hasError,
            atLimit: atLimit,
            errorMessage: errorMessage,
          ),
      ],
    );
  }

  bool _showFootRow(bool hasError) =>
      hasError || widget.helperText != null || widget.showCounter;

  Widget _buildFootRow(
    NibTheme theme, {
    required bool hasError,
    required bool atLimit,
    required String? errorMessage,
  }) {
    final String? message = hasError ? errorMessage : widget.helperText;

    final TextStyle messageStyle = const TextStyle(fontSize: 12)
        .copyWith(color: hasError ? theme.destructive : theme.mutedForeground)
        .merge(hasError ? widget.errorStyle : widget.helperStyle);

    Widget? messageText = message == null
        ? null
        : Text(message, style: messageStyle);

    if (widget.animated && messageText != null) {
      messageText = NibMotion(
        key: ValueKey('$hasError:$message'),
        initial: const NibAnim(opacity: 0, y: 4),
        animate: NibAnim.identity,
        transition: _transition,
        child: messageText,
      );
    }

    final Widget? counter = widget.showCounter
        ? Text(
            widget.maxLength == null
                ? '$_length'
                : '$_length/${widget.maxLength}',
            style: const TextStyle(fontSize: 12)
                .copyWith(
                  color: atLimit ? theme.destructive : theme.mutedForeground,
                )
                .merge(widget.counterStyle),
          )
        : null;

    return Padding(
      padding: EdgeInsets.only(top: widget.footerSpacing ?? 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: messageText ?? const SizedBox.shrink()),
          if (counter != null) ...[const SizedBox(width: 8), counter],
        ],
      ),
    );
  }
}
