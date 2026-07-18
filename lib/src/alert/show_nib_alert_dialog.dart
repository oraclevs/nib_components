import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart' show NibTransition;

import '../button/nib_button.dart';
import '../button/nib_button_types.dart';
import '../dialog/nib_dialog_types.dart';
import '../dialog/show_nib_dialog.dart';
import '../theme/nib_theme.dart';
import 'nib_alert_types.dart';

/// Imperative confirm/alert popup — Flutter's `AlertDialog` equivalent, built
/// on [showNibDialog]: a modal with a title/message and Cancel/OK actions
/// that returns a result.
///
/// ```dart
/// final confirmed = await showNibAlertDialog(
///   context,
///   title: 'Delete file?',
///   description: 'This cannot be undone.',
///   severity: NibAlertSeverity.error,
/// );
/// if (confirmed == true) { ... }
/// ```
///
/// Resolves `true` when [confirmText] is tapped, `false` when [cancelText]
/// is tapped, `null` when dismissed via the barrier/Escape without deciding.
/// Pass `cancelText: null` for a single-button informational alert. There is
/// no corner close button — matching Flutter's own `AlertDialog`, dismissal
/// is always via an explicit action or the barrier, never a redundant second
/// affordance next to Cancel.
///
/// [icon]/[iconColor]/[titleTextStyle]/[descriptionTextStyle] customize the
/// body beyond [severity]'s defaults; [actionsAlignment]/[actionsSpacing]/
/// [actionsOverflowAlignment]/[actionsOverflowDirection] tune the action row
/// (backed by [OverflowBar], so it wraps to a vertical stack instead of
/// overflowing when actions don't fit — matters most with a custom
/// multi-button [actions] override).
///
/// The default Cancel/OK pair is itself fully customizable: [cancelVariant]/
/// [confirmVariant] pick each button's [NibButtonVariant] (e.g. set both to
/// the same variant if two visually different button styles — outline next
/// to filled — don't read as a matched pair at your chosen [buttonPadding]/
/// text lengths), [buttonPadding] overrides both buttons' internal padding,
/// [buttonWidth] forces both to an identical width (the most direct fix when
/// two different-length labels, like "Cancel"/"Delete", produce visibly
/// different content-sized button widths), and [cancelFirst] controls left-
/// to-right order (`true`, the default, is Cancel-then-Confirm). All of
/// these — including [actionsAlignment] etc. above — are Material-only;
/// [adaptive]'s iOS presentation uses fixed native-style full-width actions
/// instead ([buttonPadding] and [cancelFirst] still apply there; variant/
/// width/alignment do not, since Cupertino actions have no discrete width or
/// [NibButtonVariant] concept).
///
/// Set [adaptive] to switch to an iOS-style presentation (centered text,
/// full-width divided text actions, no ripple) when running on iOS/macOS;
/// `false` (the default) always uses the Material-style layout regardless of
/// platform.
Future<bool?> showNibAlertDialog(
  BuildContext context, {
  String? title,
  String? description,
  Widget? content,
  NibAlertSeverity? severity,
  Widget? icon,
  Color? iconColor,
  TextStyle? titleTextStyle,
  TextStyle? descriptionTextStyle,
  String confirmText = 'OK',
  String? cancelText = 'Cancel',
  VoidCallback? onConfirm,
  VoidCallback? onCancel,
  NibButtonVariant cancelVariant = NibButtonVariant.outline,
  NibButtonVariant? confirmVariant,
  EdgeInsetsGeometry? buttonPadding,
  double? buttonWidth,
  bool cancelFirst = true,
  List<Widget>? actions,
  MainAxisAlignment actionsAlignment = MainAxisAlignment.end,
  double actionsSpacing = 12,
  OverflowBarAlignment actionsOverflowAlignment = OverflowBarAlignment.end,
  VerticalDirection actionsOverflowDirection = VerticalDirection.down,
  bool barrierDismissible = true,
  bool adaptive = false,
  bool animated = false,
  NibTransition? transition,
}) {
  assert(
    title != null || description != null || content != null,
    'showNibAlertDialog requires at least one of title/description/content.',
  );

  final cupertino = adaptive &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);
  final destructive = severity == NibAlertSeverity.error;
  final resolvedConfirmVariant = confirmVariant ??
      (destructive ? NibButtonVariant.destructive : NibButtonVariant.primary);

  Widget buildBody() => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Absorbs `showNibDialog`'s FocusScope(autofocus: true) — without
          // this, it auto-focuses the first actionable descendant (Cancel),
          // which then permanently shows NibButton's focus ring/highlight
          // the instant the dialog opens, regardless of variant. See
          // _noAutofocusSink's doc comment.
          _noAutofocusSink,
          content ??
              _AlertBody(
                title: title,
                description: description,
                severity: severity,
                icon: icon,
                iconColor: iconColor,
                titleTextStyle: titleTextStyle,
                descriptionTextStyle: descriptionTextStyle,
                centered: cupertino,
              ),
        ],
      );

  Widget buildFooter(BuildContext dialogContext) {
    if (actions != null) {
      return OverflowBar(
        alignment: cupertino ? MainAxisAlignment.center : actionsAlignment,
        spacing: actionsSpacing,
        overflowSpacing: actionsSpacing,
        overflowAlignment: actionsOverflowAlignment,
        overflowDirection: actionsOverflowDirection,
        children: actions,
      );
    }
    void confirm() {
      NibDialogScope.of(dialogContext).close(true);
      onConfirm?.call();
    }

    void cancel() {
      NibDialogScope.of(dialogContext).close(false);
      onCancel?.call();
    }

    return cupertino
        ? _CupertinoAlertActions(
            confirmText: confirmText,
            cancelText: cancelText,
            destructive: destructive,
            cancelFirst: cancelFirst,
            buttonPadding: buttonPadding,
            onConfirm: confirm,
            onCancel: cancel,
          )
        : _MaterialAlertActions(
            confirmText: confirmText,
            cancelText: cancelText,
            cancelVariant: cancelVariant,
            confirmVariant: resolvedConfirmVariant,
            buttonPadding: buttonPadding,
            buttonWidth: buttonWidth,
            cancelFirst: cancelFirst,
            onConfirm: confirm,
            onCancel: cancel,
            alignment: actionsAlignment,
            spacing: actionsSpacing,
            overflowAlignment: actionsOverflowAlignment,
            overflowDirection: actionsOverflowDirection,
          );
  }

  return showNibDialog<bool>(
    context,
    content: buildBody(),
    footer: Builder(builder: buildFooter),
    size: NibDialogSize.md,
    width: cupertino ? 270 : null,
    showCloseButton: false,
    barrierDismissible: barrierDismissible,
    animated: animated,
    transition: transition,
  );
}

class _AlertBody extends StatelessWidget {
  const _AlertBody({
    required this.title,
    required this.description,
    required this.severity,
    required this.icon,
    required this.iconColor,
    required this.titleTextStyle,
    required this.descriptionTextStyle,
    required this.centered,
  });

  final String? title;
  final String? description;
  final NibAlertSeverity? severity;
  final Widget? icon;
  final Color? iconColor;
  final TextStyle? titleTextStyle;
  final TextStyle? descriptionTextStyle;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    final align = centered ? TextAlign.center : TextAlign.start;

    final resolvedIcon = icon ??
        (severity != null
            ? Icon(
                severity!.defaultIcon(),
                color: iconColor ?? severity!.accent(theme),
                size: 28,
              )
            : null);

    return Column(
      crossAxisAlignment:
          centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (resolvedIcon != null) ...[
          // `iconColor` only needs to cascade here for a custom `icon` —
          // the severity-default branch above already resolved it directly.
          iconColor != null
              ? IconTheme.merge(
                  data: IconThemeData(color: iconColor),
                  child: resolvedIcon,
                )
              : resolvedIcon,
          const SizedBox(height: 14),
        ],
        if (title != null)
          Text(
            title!,
            textAlign: align,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: theme.cardForeground,
            ).merge(titleTextStyle),
          ),
        if (title != null && description != null) const SizedBox(height: 8),
        if (description != null)
          Text(
            description!,
            textAlign: align,
            style: TextStyle(color: theme.mutedForeground, fontSize: 14)
                .merge(descriptionTextStyle),
          ),
      ],
    );
  }
}

class _MaterialAlertActions extends StatelessWidget {
  const _MaterialAlertActions({
    required this.confirmText,
    required this.cancelText,
    required this.cancelVariant,
    required this.confirmVariant,
    required this.buttonPadding,
    required this.buttonWidth,
    required this.cancelFirst,
    required this.onConfirm,
    required this.onCancel,
    required this.alignment,
    required this.spacing,
    required this.overflowAlignment,
    required this.overflowDirection,
  });

  final String confirmText;
  final String? cancelText;
  final NibButtonVariant cancelVariant;
  final NibButtonVariant confirmVariant;
  final EdgeInsetsGeometry? buttonPadding;
  final double? buttonWidth;
  final bool cancelFirst;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final MainAxisAlignment alignment;
  final double spacing;
  final OverflowBarAlignment overflowAlignment;
  final VerticalDirection overflowDirection;

  @override
  Widget build(BuildContext context) {
    final cancel = cancelText == null
        ? null
        : NibButton(
            label: cancelText!,
            variant: cancelVariant,
            padding: buttonPadding,
            width: buttonWidth,
            onPressed: onCancel,
          );
    final confirm = NibButton(
      label: confirmText,
      variant: confirmVariant,
      padding: buttonPadding,
      width: buttonWidth,
      onPressed: onConfirm,
    );

    return OverflowBar(
      alignment: alignment,
      spacing: spacing,
      overflowSpacing: spacing,
      overflowAlignment: overflowAlignment,
      overflowDirection: overflowDirection,
      children: [
        if (cancelFirst) ...[
          ?cancel,
          confirm,
        ] else ...[
          confirm,
          ?cancel,
        ],
      ],
    );
  }
}

/// iOS-style actions row: full-width, divided, text-only buttons. Hand-built
/// (not `CupertinoButton`) so colours come from [NibTheme] rather than
/// Cupertino's system palette — but it still carries the accessibility
/// surface a native button gives for free: `Semantics(button:)`, focus +
/// `ActivateIntent` (Enter/Space) via [FocusableActionDetector], a hover/
/// focus highlight, and a ≥48px-tall tap target.
class _CupertinoAlertActions extends StatelessWidget {
  const _CupertinoAlertActions({
    required this.confirmText,
    required this.cancelText,
    required this.destructive,
    required this.cancelFirst,
    required this.buttonPadding,
    required this.onConfirm,
    required this.onCancel,
  });

  final String confirmText;
  final String? cancelText;
  final bool destructive;
  final bool cancelFirst;
  final EdgeInsetsGeometry? buttonPadding;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    final confirmButton = _CupertinoAlertButton(
      label: confirmText,
      emphasized: true,
      color: destructive ? theme.destructive : theme.primary,
      padding: buttonPadding,
      onTap: onConfirm,
    );

    final row = cancelText == null
        ? SizedBox(width: double.infinity, child: confirmButton)
        : Builder(builder: (context) {
            final cancelButton = _CupertinoAlertButton(
              label: cancelText!,
              emphasized: false,
              color: theme.primary,
              padding: buttonPadding,
              onTap: onCancel,
            );
            final divider =
                VerticalDivider(width: 1, thickness: 1, color: theme.border);
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: cancelFirst
                    ? [
                        Expanded(child: cancelButton),
                        divider,
                        Expanded(child: confirmButton),
                      ]
                    : [
                        Expanded(child: confirmButton),
                        divider,
                        Expanded(child: cancelButton),
                      ],
              ),
            );
          });

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(height: 1, thickness: 1, color: theme.border),
        row,
      ],
    );
  }
}

class _CupertinoAlertButton extends StatefulWidget {
  const _CupertinoAlertButton({
    required this.label,
    required this.emphasized,
    required this.color,
    required this.padding,
    required this.onTap,
  });

  final String label;
  final bool emphasized;
  final Color color;
  final EdgeInsetsGeometry? padding;
  final VoidCallback onTap;

  @override
  State<_CupertinoAlertButton> createState() => _CupertinoAlertButtonState();
}

class _CupertinoAlertButtonState extends State<_CupertinoAlertButton> {
  bool _pressed = false;
  bool _hover = false;
  bool _focus = false;
  bool get _highlighted => _hover || _focus;

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    return Semantics(
      button: true,
      enabled: true,
      label: widget.label,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (h) => setState(() => _hover = h),
        onShowFocusHighlight: (f) => setState(() => _focus = f),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          // The outer Semantics already declares `label`/`button` — exclude
          // the visible Text's own auto-label so it doesn't merge into a
          // doubled-up "OK\nOK".
          child: ExcludeSemantics(
            child: ColoredBox(
              color: _highlighted ? theme.muted : Colors.transparent,
              child: AnimatedOpacity(
                opacity: _pressed ? 0.4 : 1,
                duration: const Duration(milliseconds: 100),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Center(
                    child: Padding(
                      padding: widget.padding ??
                          const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          color: widget.color,
                          fontSize: 16,
                          fontWeight:
                              widget.emphasized ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Invisible focusable placeholder, mounted first in the dialog's body so it
/// — not Cancel/Confirm — absorbs `showNibDialog`'s `FocusScope(autofocus:
/// true)` (which otherwise auto-focuses the *first* focusable descendant on
/// open, permanently showing that button's focus ring/highlight the instant
/// the alert appears, regardless of `variant`). It simply stays focused
/// afterwards — a bare `Focus` around a zero-size box paints nothing
/// regardless of focus state, so there is no ring/highlight for it to show.
/// It becomes one extra (invisible, harmless) stop at the start of Tab
/// traversal; every real action remains reachable by Tab/Shift+Tab exactly
/// as before.
const Focus _noAutofocusSink = Focus(autofocus: true, child: SizedBox.shrink());
