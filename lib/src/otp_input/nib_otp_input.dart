import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nib_motion/nib_motion.dart'
    show NibAnim, NibMotion, NibTransition;

import '../loader/nib_circular_loader.dart';
import '../theme/nib_theme.dart';
import 'nib_otp_controller.dart';

/// Visual styling for a [NibOtpKeypad] — button colours, key text font, key
/// size/radius, and the gaps between keys. Every field is optional; anything
/// left `null` falls back to the Nib theme.
class NibOtpKeypadStyle {
  const NibOtpKeypadStyle({
    this.keyColor,
    this.keyTextStyle,
    this.keyTextColor,
    this.iconColor,
    this.confirmColor,
    this.confirmIconColor,
    this.keyWidth = 68,
    this.keyHeight = 54,
    this.keyRadius,
    this.horizontalSpacing = 12,
    this.verticalSpacing = 12,
    this.maxWidth = 280,
  });

  /// Background of the digit/backspace keys.
  final Color? keyColor;

  /// Text style for the digit keys (size/weight/family). Its colour is
  /// overridden by [keyTextColor] when that is set.
  final TextStyle? keyTextStyle;

  /// Colour of the digit key text.
  final Color? keyTextColor;

  /// Colour of the backspace icon.
  final Color? iconColor;

  /// Background of the default confirm key.
  final Color? confirmColor;

  /// Icon colour of the default confirm key.
  final Color? confirmIconColor;

  /// Per-key width and height.
  final double keyWidth;
  final double keyHeight;

  /// Key corner radius. `null` → the theme's default radius.
  final double? keyRadius;

  /// Gap between keys within a row.
  final double horizontalSpacing;

  /// Gap between rows.
  final double verticalSpacing;

  /// Ceiling width for the whole keypad.
  final double maxWidth;
}

/// Where a [NibOtpInput]'s digits come from.
enum NibOtpKeyboard {
  /// The device's own keyboard (default). Supports pasting a whole code and
  /// SMS one-time-code autofill.
  system,

  /// A built-in on-screen numeric keypad; the OS keyboard never appears. Use
  /// this for high-security entry (ATM PINs, banking) where the device keyboard
  /// shouldn't be trusted, and where paste/autofill are intentionally off.
  onScreen,
}

/// A one-time-code / PIN entry field: a row of [length] single-character cells
/// that fill as the user types, auto-advancing per digit.
///
/// Built on a single native [TextField] behind the cells, so the hard parts
/// come for free: **pasting** a whole code splits it across the cells, and
/// **SMS autofill** works via [AutofillHints.oneTimeCode]. Digits only by
/// default. Usable with just a length:
///
/// ```dart
/// NibOtpInput(length: 6, onCompleted: (code) => verify(code))
/// ```
///
/// Drive/read it with a [NibOtpController]; set [obscureText] to mask entries,
/// [errorText] to show an error state, and [animated] to pop each cell in via
/// `nib_motion`.
class NibOtpInput extends StatefulWidget {
  const NibOtpInput({
    super.key,
    this.length = 6,
    this.controller,
    this.keyboard = NibOtpKeyboard.system,
    this.obscureText = false,
    this.enabled = true,
    this.loading = false,
    this.autoFocus = false,
    this.errorText,
    this.onChanged,
    this.onCompleted,
    this.onConfirm,
    this.keypadStyle,
    this.confirmButton,
    this.showConfirmButton = true,
    this.animated = false,
    this.transition,
    this.cellWidth = 44,
    this.cellHeight = 52,
    this.spacing = 10,
    this.semanticLabel,
  });

  /// Number of cells / expected code length.
  final int length;

  /// Optional external controller. Never required — `NibOtpInput` owns one
  /// internally when this is `null`, disposing it on unmount/controller-swap.
  final NibOtpController? controller;

  /// Whether digits come from the device keyboard ([NibOtpKeyboard.system],
  /// default) or a built-in on-screen keypad ([NibOtpKeyboard.onScreen]).
  final NibOtpKeyboard keyboard;

  /// Whether to mask each entered digit behind a dot.
  final bool obscureText;

  /// Whether input is accepted. When `false`, cells render greyed and the field
  /// ignores input.
  final bool enabled;

  /// Verification-in-progress state. When `true`, the cells and keypad grey out
  /// and stop accepting input, and the keypad's confirm slot shows a
  /// [NibCircularLoader]. Typically flipped on inside [onCompleted]/[onConfirm]
  /// while a code is checked.
  final bool loading;

  /// Whether to focus (and raise the keyboard) on mount.
  final bool autoFocus;

  /// When non-null, all cells switch to their error visual (destructive border)
  /// and the message is shown below.
  final String? errorText;

  /// Called with the full string on user edits and later controller changes.
  /// Adopting a prefilled or replacement controller does not emit an edit.
  final ValueChanged<String>? onChanged;

  /// Called once with the code when the last cell is filled after binding.
  /// A prefilled or replacement controller is adopted without completion. Use this for
  /// automatic verification (kick off the check, then set [loading] `true`).
  final ValueChanged<String>? onCompleted;

  /// Called with the current code when the keypad's confirm key is tapped
  /// ([NibOtpKeyboard.onScreen] only, when [showConfirmButton] is `true` and no
  /// custom [confirmButton] handles its own tap).
  final ValueChanged<String>? onConfirm;

  /// Styling for the on-screen keypad (colours, key font, spacing, sizes).
  final NibOtpKeypadStyle? keypadStyle;

  /// A custom widget for the keypad's confirm slot (bottom-left), replacing the
  /// default check-mark key. Wire its own tap — you have full control over its
  /// look. Ignored while [loading] (the slot shows the loader instead).
  final Widget? confirmButton;

  /// Whether the on-screen keypad shows a confirm key in its bottom-left slot.
  final bool showConfirmButton;

  /// Opt-in `nib_motion` pop of each cell as it fills. `false` builds zero
  /// `NibMotion`.
  final bool animated;

  /// Timing/curve for the [animated] cell pop. `null` → a short ~180ms ease.
  final NibTransition? transition;

  /// Per-cell width, height, and the gap between cells.
  final double cellWidth;
  final double cellHeight;
  final double spacing;

  /// Accessibility label for the field.
  final String? semanticLabel;

  @override
  State<NibOtpInput> createState() => _NibOtpInputState();
}

class _NibOtpInputState extends State<NibOtpInput> {
  late TextEditingController _text;
  final _focus = FocusNode();

  NibOtpController? _controller;
  bool _syncing = false;
  String? _lastCompleted;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController();
    _text.addListener(_onTextChanged);
    _bindController(widget.controller);
    _focus.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant NibOtpInput old) {
    super.didUpdateWidget(old);
    if (widget.controller != old.controller) {
      _unbindController();
      _bindController(widget.controller);
    }
  }

  @override
  void dispose() {
    _text.removeListener(_onTextChanged);
    _text.dispose();
    _focus.dispose();
    _unbindController();
    super.dispose();
  }

  void _bindController(NibOtpController? external) {
    _controller = external;
    if (external == null) return;
    external.addListener(_onExternalChanged);
    // Binding adopts existing state during initState/didUpdateWidget. It is
    // not a new edit and must not call an ancestor while its layout is building.
    final next = _sanitize(external.value);
    _setTextSilently(next);
    _lastCompleted = next.length == widget.length ? next : null;
  }

  void _unbindController() {
    _controller?.removeListener(_onExternalChanged);
  }

  String _sanitize(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length > widget.length
        ? digits.substring(0, widget.length)
        : digits;
  }

  void _setTextSilently(String value) {
    _syncing = true;
    _text.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _syncing = false;
  }

  void _onExternalChanged() {
    final next = _sanitize(_controller!.value);
    if (next == _text.text) return;
    _setTextSilently(next);
    // _text's listener is suppressed while syncing, so drive the visuals/
    // callbacks directly for the programmatic change.
    _handleValue(next);
  }

  void _onTextChanged() {
    if (_syncing) return;
    _handleValue(_text.text);
    if (_controller != null) _controller!.setValue(_text.text);
  }

  void _onFocusChanged() => setState(() {});

  void _handleValue(String value) {
    if (mounted) setState(() {});
    widget.onChanged?.call(value);
    if (value.length == widget.length) {
      if (value != _lastCompleted) {
        _lastCompleted = value;
        widget.onCompleted?.call(value);
      }
    } else {
      _lastCompleted = null;
    }
  }

  int get _activeIndex {
    final len = _text.text.length;
    return len >= widget.length ? widget.length - 1 : len;
  }

  /// Input is accepted only when enabled and not mid-verification.
  bool get _interactive => widget.enabled && !widget.loading;

  bool _cellActive(int i) {
    if (!_interactive) return false;
    // On-screen mode has no OS focus, so the next cell is always the active one.
    final focused =
        widget.keyboard == NibOtpKeyboard.onScreen || _focus.hasFocus;
    return focused && i == _activeIndex;
  }

  // On-screen keypad input. Routes through _text so the controller/onChanged/
  // onCompleted/error handling is identical to typed input.
  void _appendDigit(String d) {
    if (!_interactive || _text.text.length >= widget.length) return;
    _text.text = _text.text + d;
  }

  void _backspace() {
    if (!_interactive || _text.text.isEmpty) return;
    _text.text = _text.text.substring(0, _text.text.length - 1);
  }

  void _confirm() => widget.onConfirm?.call(_text.text);

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    final text = _text.text;
    final hasError = widget.errorText != null;

    final cells = <Widget>[];
    for (var i = 0; i < widget.length; i++) {
      if (i > 0) cells.add(SizedBox(width: widget.spacing));
      final hasChar = i < text.length;
      cells.add(
        NibOtpCell(
          char: hasChar ? text[i] : '',
          obscured: hasChar && widget.obscureText,
          active: _cellActive(i),
          error: hasError,
          enabled: _interactive,
          animated: widget.animated,
          transition: widget.transition,
          width: widget.cellWidth,
          height: widget.cellHeight,
          theme: theme,
        ),
      );
    }

    final cellsRow = Row(mainAxisSize: MainAxisSize.min, children: cells);

    final Widget input;
    if (widget.keyboard == NibOtpKeyboard.system) {
      input = Semantics(
        label: widget.semanticLabel ?? 'One-time code',
        textField: true,
        child: Stack(
          children: [
            cellsRow,
            // Transparent capture field on top: one field means paste splits
            // across the cells and SMS autofill lands in one place.
            Positioned.fill(
              child: TextField(
                controller: _text,
                focusNode: _focus,
                enabled: _interactive,
                autofocus: widget.autoFocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                maxLength: widget.length,
                autofillHints: const [AutofillHints.oneTimeCode],
                enableInteractiveSelection: false,
                showCursor: false,
                cursorColor: Colors.transparent,
                style: const TextStyle(color: Colors.transparent, height: 0.01),
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(widget.length),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // On-screen keypad — no OS keyboard, no capture TextField.
      input = Semantics(
        label: widget.semanticLabel ?? 'One-time code',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            cellsRow,
            const SizedBox(height: 20),
            NibOtpKeypad(
              enabled: _interactive,
              loading: widget.loading,
              theme: theme,
              style: widget.keypadStyle,
              onDigit: _appendDigit,
              onBackspace: _backspace,
              onConfirm: _confirm,
              confirmButton: widget.confirmButton,
              showConfirmButton: widget.showConfirmButton,
            ),
          ],
        ),
      );
    }

    if (widget.errorText == null) return input;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        input,
        const SizedBox(height: 8),
        Text(
          widget.errorText!,
          style: TextStyle(color: theme.destructive, fontSize: 13),
        ),
      ],
    );
  }
}

/// A single OTP cell. Public so a consumer's tests can count them; you rarely
/// construct one directly.
class NibOtpCell extends StatelessWidget {
  const NibOtpCell({
    super.key,
    required this.char,
    required this.active,
    required this.theme,
    this.obscured = false,
    this.error = false,
    this.enabled = true,
    this.animated = false,
    this.transition,
    this.width = 44,
    this.height = 52,
  });

  final String char;
  final bool active;
  final NibTheme theme;
  final bool obscured;
  final bool error;
  final bool enabled;
  final bool animated;
  final NibTransition? transition;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final filled = char.isNotEmpty;
    final borderColor = !enabled
        ? theme.border
        : error
        ? theme.destructive
        : active
        ? theme.ring
        : filled
        ? theme.foreground.withValues(alpha: 0.35)
        : theme.border;

    Widget? glyph;
    if (filled) {
      glyph = Text(
        obscured ? '●' : char,
        style: TextStyle(
          fontSize: obscured ? 14 : 20,
          fontWeight: FontWeight.w700,
          color: enabled ? theme.foreground : theme.mutedForeground,
        ),
      );
      if (animated) {
        glyph = NibMotion(
          key: ValueKey(char),
          initial: const NibAnim(scale: 0.4, opacity: 0),
          animate: NibAnim.identity,
          transition:
              transition ??
              const NibTransition(duration: Duration(milliseconds: 180)),
          child: glyph,
        );
      }
    }

    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: enabled ? theme.background : theme.muted,
          borderRadius: BorderRadius.circular(theme.radiusDefault),
          border: Border.all(color: borderColor, width: active ? 2 : 1.4),
        ),
        child: Center(child: glyph),
      ),
    );
  }
}

/// The built-in on-screen numeric keypad used by a [NibOtpInput] in
/// [NibOtpKeyboard.onScreen] mode: digits 1–9, then a confirm key (bottom-left),
/// 0, and a backspace (bottom-right). Fully stylable via [style], with an
/// overridable [confirmButton] slot. Public so it can be reused or found in
/// tests; you rarely construct one directly.
class NibOtpKeypad extends StatelessWidget {
  const NibOtpKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    required this.theme,
    this.onConfirm,
    this.confirmButton,
    this.showConfirmButton = true,
    this.loading = false,
    this.enabled = true,
    this.style,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final NibTheme theme;

  /// Tapped when the default confirm key is used.
  final VoidCallback? onConfirm;

  /// Custom widget for the bottom-left confirm slot (replaces the default key).
  final Widget? confirmButton;

  /// Whether the bottom-left confirm slot is shown at all.
  final bool showConfirmButton;

  /// Whether a [NibCircularLoader] replaces the confirm slot (verification in
  /// progress).
  final bool loading;

  final bool enabled;
  final NibOtpKeypadStyle? style;

  @override
  Widget build(BuildContext context) {
    final s = style ?? const NibOtpKeypadStyle();
    final radius = s.keyRadius ?? theme.radiusDefault;

    Widget digit(String d) => NibOtpKey(
      label: d,
      enabled: enabled,
      theme: theme,
      onTap: () => onDigit(d),
      color: s.keyColor,
      textStyle: s.keyTextStyle,
      textColor: s.keyTextColor,
      width: s.keyWidth,
      height: s.keyHeight,
      radius: radius,
    );

    Widget row(List<Widget> children) => Padding(
      padding: EdgeInsets.only(bottom: s.verticalSpacing),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(width: s.horizontalSpacing),
            children[i],
          ],
        ],
      ),
    );

    final confirmSlot = SizedBox(
      width: s.keyWidth,
      height: s.keyHeight,
      child: loading
          ? Center(
              child: NibCircularLoader(
                size: s.keyHeight * 0.72,
                strokeWidth: 3.5,
              ),
            )
          : !showConfirmButton
          ? const SizedBox.shrink()
          : confirmButton ??
                NibOtpKey(
                  icon: Icons.check_rounded,
                  enabled: enabled,
                  theme: theme,
                  onTap: onConfirm ?? () {},
                  color: s.confirmColor ?? theme.primary,
                  iconColor: s.confirmIconColor ?? theme.primaryForeground,
                  width: s.keyWidth,
                  height: s.keyHeight,
                  radius: radius,
                ),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: s.maxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row([digit('1'), digit('2'), digit('3')]),
          row([digit('4'), digit('5'), digit('6')]),
          row([digit('7'), digit('8'), digit('9')]),
          row([
            confirmSlot,
            digit('0'),
            NibOtpKey(
              icon: Icons.backspace_outlined,
              enabled: enabled,
              theme: theme,
              onTap: onBackspace,
              color: s.keyColor,
              iconColor: s.iconColor,
              width: s.keyWidth,
              height: s.keyHeight,
              radius: radius,
            ),
          ]),
        ],
      ),
    );
  }
}

/// A single key on a [NibOtpKeypad] — a digit [label] or an [icon] (backspace /
/// confirm). Colours, text, size, and radius are overridable.
class NibOtpKey extends StatelessWidget {
  const NibOtpKey({
    super.key,
    required this.onTap,
    required this.theme,
    this.label,
    this.icon,
    this.enabled = true,
    this.color,
    this.textStyle,
    this.textColor,
    this.iconColor,
    this.width = 68,
    this.height = 54,
    this.radius,
  }) : assert(label != null || icon != null, 'a key needs a label or an icon');

  final VoidCallback onTap;
  final NibTheme theme;
  final String? label;
  final IconData? icon;
  final bool enabled;
  final Color? color;
  final TextStyle? textStyle;
  final Color? textColor;
  final Color? iconColor;
  final double width;
  final double height;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? theme.muted;
    final fg = enabled
        ? (iconColor ?? textColor ?? theme.foreground)
        : theme.mutedForeground;
    final r = radius ?? theme.radiusDefault;

    return SizedBox(
      width: width,
      height: height,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(r),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: Center(
              child: icon != null
                  ? Icon(icon, size: 22, color: fg)
                  : Text(
                      label!,
                      style:
                          (textStyle ??
                                  const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                  ))
                              .copyWith(
                                color: enabled
                                    ? (textColor ?? theme.foreground)
                                    : theme.mutedForeground,
                              ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
