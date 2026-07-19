import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:nib_motion/nib_motion.dart'
    show NibAnim, NibMotion, NibMotionList, NibPresence, NibTransition;

import '../theme/nib_theme.dart';
import 'nib_select_animation.dart';
import 'nib_select_controller.dart';
import 'nib_select_option.dart';

/// Builds the dropdown body shown when a `searchable` [NibSelect] has filtered
/// its options down to nothing.
typedef NibSelectNoResultsBuilder = Widget Function(BuildContext context);

/// A native single/multi select: a button-style trigger that opens an
/// anchored, keyboard-navigable dropdown of [NibSelectOption]s. The overlay
/// flips above the trigger and clamps its height to the available space when
/// there isn't room below, matches the trigger's width, supports optional
/// in-list search, grouped section headers ([groups]), and disabled options.
///
/// Simplest usage needs only [options] and [onChanged]:
///
/// ```dart
/// NibSelect<String>(
///   options: const [
///     NibSelectOption(value: 'apple', label: 'Apple'),
///     NibSelectOption(value: 'banana', label: 'Banana'),
///   ],
///   onChanged: (value) => print(value),
/// )
/// ```
///
/// Pass [groups] instead of [options] for grouped section headers; the two are
/// mutually exclusive.
class NibSelect<T> extends StatefulWidget {
  const NibSelect({
    super.key,
    this.options,
    this.groups,
    this.value,
    this.values,
    this.multiSelect = false,
    this.searchable = false,
    this.clearable = false,
    this.onChanged,
    this.onSelectionChanged,
    this.placeholder = 'Select…',
    this.searchPlaceholder = 'Search…',
    this.noResultsBuilder,
    this.disabled = false,
    this.loading = false,
    this.animated = false,
    this.animation = NibSelectAnimation.fadeScale,
    this.enterFrom,
    this.staggerOptions = false,
    this.transition,
    this.maxDropdownHeight = 280,
    this.semanticLabel,
    this.controller,
  }) : assert(
         (options == null) != (groups == null),
         'Provide exactly one of `options` (flat) or `groups` (grouped).',
       );

  /// The flat, ungrouped option list — the common case. Mutually exclusive
  /// with [groups].
  final List<NibSelectOption<T>>? options;

  /// Grouped options rendered with a section header per group. Mutually
  /// exclusive with [options].
  final List<NibSelectGroup<T>>? groups;

  /// Initial single-select value, applied to the internally-owned controller
  /// on first build. Ignored when an external [controller] is supplied (that
  /// controller is the source of truth).
  final T? value;

  /// Initial multi-select values, applied to the internally-owned controller
  /// on first build. Ignored when an external [controller] is supplied.
  final List<T>? values;

  /// Multi-select mode: picks toggle, the dropdown stays open, and the closed
  /// trigger shows the selected labels joined with commas (ellipsised).
  final bool multiSelect;

  /// Whether to show an in-list search field at the top of the dropdown that
  /// filters options by label/subtitle.
  final bool searchable;

  /// Whether to show a trailing clear (✕) button on the trigger when there's a
  /// selection to clear.
  final bool clearable;

  /// Single-select convenience: fires the newly-selected value (or `null` when
  /// cleared). For multi-select use [onSelectionChanged].
  final ValueChanged<T?>? onChanged;

  /// Fires the full selection list on every selection change, in both modes.
  final ValueChanged<List<T>>? onSelectionChanged;

  final String placeholder;

  final String searchPlaceholder;

  /// Builds the dropdown body when [searchable] has filtered options to none.
  /// Defaults to a muted "No results" row.
  final NibSelectNoResultsBuilder? noResultsBuilder;

  final bool disabled;

  /// Consumer-forced loading state — shows a spinner in the dropdown body in
  /// place of the option list.
  final bool loading;

  /// Opt-in dropdown entrance/exit animation via `nib_motion`. `false`
  /// allocates zero `NibMotion`/`NibPresence`/`MotionValue` overhead (the
  /// dropdown appears and closes instantly).
  final bool animated;

  /// Which predefined motion the dropdown opens/closes with when [animated] is
  /// `true`. Ignored when [enterFrom] is set (that raw state wins) or when
  /// [animated] is `false`. Defaults to [NibSelectAnimation.fadeScale].
  final NibSelectAnimation animation;

  /// Raw escape hatch: the [NibAnim] "from" state the dropdown animates out of
  /// on open and back into on close, overriding [animation]. Only used when
  /// [animated] is `true`.
  final NibAnim? enterFrom;

  /// When `true` (and [animated] is `true`), each option row animates in
  /// staggered (a cascade) instead of the whole panel moving as one block.
  /// This builds all visible rows eagerly (no `ListView` virtualization), so
  /// it's intended for modest option counts — leave it `false` for very long
  /// lists.
  final bool staggerOptions;

  /// Timing/curve/spring for the [animated] transition (both directions).
  /// `null` falls back to a short ~140ms ease. The motion *shape* comes from
  /// [animation]/[enterFrom]; this only controls how it's timed.
  final NibTransition? transition;

  final double maxDropdownHeight;

  /// Overrides the trigger's accessibility label. Defaults to [placeholder].
  final String? semanticLabel;

  /// Optional external controller for selection/open state. Never required —
  /// `NibSelect` creates and owns one internally when this is `null`, and
  /// disposes it on unmount/controller-swap.
  final NibSelectController<T>? controller;

  @override
  State<NibSelect<T>> createState() => _NibSelectState<T>();
}

class _NibSelectState<T> extends State<NibSelect<T>> {
  late NibSelectController<T> _controller;
  late bool _ownsController;

  final _triggerFocus = FocusNode(debugLabel: 'nib-select-trigger');
  final _searchFocus = FocusNode(debugLabel: 'nib-select-search');
  final _searchController = TextEditingController();
  final _link = LayerLink();
  OverlayEntry? _overlayEntry;

  // Exit-animation bookkeeping: while an animated dropdown is playing its
  // close (exit) motion, the overlay stays mounted (`_closing == true`) until
  // `_exitTimer` fires and actually removes it.
  bool _closing = false;
  Timer? _exitTimer;
  final _cardKey = const ValueKey<String>('nib-select-card');

  String _query = '';
  List<_SelectEntry<T>> _entries = [];
  List<NibSelectOption<T>> _visibleOptions = [];
  int _highlightedIndex = -1;

  @override
  void initState() {
    super.initState();
    _bindController(widget.controller);
    _computeVisible();
  }

  @override
  void didUpdateWidget(covariant NibSelect<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _unbindController();
      _bindController(widget.controller);
    }
    final dataChanged =
        !identical(widget.options, oldWidget.options) ||
        !identical(widget.groups, oldWidget.groups);
    if (dataChanged && _controller.isOpen) {
      _computeVisible();
      _overlayEntry?.markNeedsBuild();
    }
    if (widget.loading != oldWidget.loading) {
      _overlayEntry?.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    _exitTimer?.cancel();
    _removeOverlay();
    _unbindController();
    _triggerFocus.dispose();
    _searchFocus.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- Controller binding ---------------------------------------------------

  void _bindController(NibSelectController<T>? external) {
    _controller = external ?? NibSelectController<T>();
    _ownsController = external == null;
    if (_ownsController) {
      if (widget.multiSelect && widget.values != null) {
        _controller.setSelection(widget.values!);
      } else if (!widget.multiSelect && widget.value != null) {
        _controller.setSelection([widget.value as T]);
      }
    }
    _controller.addListener(_handleControllerChanged);
    if (_controller.isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handleControllerChanged();
      });
    }
  }

  void _unbindController() {
    _controller.removeListener(_handleControllerChanged);
    if (_ownsController) _controller.dispose();
  }

  void _handleControllerChanged() {
    if (_controller.isOpen) {
      _showOverlay();
    } else {
      _beginClose();
    }
    if (mounted) setState(() {});
  }

  // --- Label helpers --------------------------------------------------------

  Iterable<NibSelectOption<T>> get _allOptions => widget.groups != null
      ? widget.groups!.expand((g) => g.options)
      : widget.options!;

  String _labelForValue(T value) {
    for (final o in _allOptions) {
      if (o.value == value) return o.label;
    }
    return value.toString();
  }

  NibSelectOption<T>? _optionForValue(T value) {
    for (final o in _allOptions) {
      if (o.value == value) return o;
    }
    return null;
  }

  // --- Open / close ---------------------------------------------------------

  void _open() {
    if (widget.disabled || _controller.isOpen) return;
    // Reopening mid-exit: cancel the pending removal and reuse the still-mounted
    // overlay (NibPresence cancels the in-flight exit when the card key returns).
    _exitTimer?.cancel();
    _closing = false;
    _query = '';
    _searchController.clear();
    _computeVisible();
    _controller.open();
    if (widget.searchable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.isOpen) _searchFocus.requestFocus();
      });
    } else {
      _triggerFocus.requestFocus();
    }
  }

  void _close() {
    if (!_controller.isOpen) return;
    _controller.close();
    // Return focus to the trigger so keyboard users can immediately reopen.
    _triggerFocus.requestFocus();
  }

  void _toggleOpen() => _controller.isOpen ? _close() : _open();

  // --- Visible-option computation -------------------------------------------

  void _computeVisible() {
    final q = _query.trim().toLowerCase();
    bool matches(NibSelectOption<T> o) =>
        q.isEmpty ||
        o.label.toLowerCase().contains(q) ||
        (o.subtitle?.toLowerCase().contains(q) ?? false);

    final entries = <_SelectEntry<T>>[];
    final options = <NibSelectOption<T>>[];

    if (widget.groups != null) {
      for (final group in widget.groups!) {
        final matched = group.options.where(matches).toList();
        if (matched.isEmpty) continue;
        entries.add(_HeaderEntry<T>(group.label));
        for (final o in matched) {
          entries.add(_OptionEntry<T>(o, options.length));
          options.add(o);
        }
      }
    } else {
      for (final o in widget.options!) {
        if (!matches(o)) continue;
        entries.add(_OptionEntry<T>(o, options.length));
        options.add(o);
      }
    }

    _entries = entries;
    _visibleOptions = options;
    _resetHighlight();
  }

  void _resetHighlight() {
    _highlightedIndex = _visibleOptions.indexWhere((o) => !o.disabled);
  }

  void _handleSearchChanged(String text) {
    _query = text;
    setState(_computeVisible);
    _overlayEntry?.markNeedsBuild();
  }

  // --- Selection ------------------------------------------------------------

  void _selectOption(NibSelectOption<T> option) {
    if (option.disabled) return;
    if (widget.multiSelect) {
      _controller.toggle(option.value);
      widget.onSelectionChanged?.call(_controller.selectedValues);
      _overlayEntry?.markNeedsBuild();
    } else {
      _controller.selectOnly(option.value);
      widget.onChanged?.call(option.value);
      widget.onSelectionChanged?.call(_controller.selectedValues);
      _close();
    }
  }

  void _clear() {
    final had = _controller.selectedValues.isNotEmpty;
    if (!had) return;
    _controller.clear();
    if (!widget.multiSelect) widget.onChanged?.call(null);
    widget.onSelectionChanged?.call(const []);
    _overlayEntry?.markNeedsBuild();
    setState(() {});
  }

  // --- Keyboard -------------------------------------------------------------

  void _moveHighlight(int delta) {
    final enabled = <int>[
      for (var i = 0; i < _visibleOptions.length; i++)
        if (!_visibleOptions[i].disabled) i,
    ];
    if (enabled.isEmpty) return;
    final pos = enabled.indexOf(_highlightedIndex);
    final nextPos = pos == -1
        ? (delta > 0 ? 0 : enabled.length - 1)
        : (pos + delta) % enabled.length;
    final wrapped = nextPos < 0 ? enabled.length + nextPos : nextPos;
    setState(() => _highlightedIndex = enabled[wrapped]);
    _overlayEntry?.markNeedsBuild();
  }

  void _activateHighlighted() {
    if (_highlightedIndex >= 0 && _highlightedIndex < _visibleOptions.length) {
      _selectOption(_visibleOptions[_highlightedIndex]);
    }
  }

  void _onMove(int delta) =>
      _controller.isOpen ? _moveHighlight(delta) : _open();
  void _onActivate() => _controller.isOpen ? _activateHighlighted() : _open();

  // --- Overlay --------------------------------------------------------------

  void _showOverlay() {
    if (_overlayEntry != null || !mounted) return;
    _closing = false;
    _overlayEntry = OverlayEntry(builder: _buildDropdownOverlay);
    Overlay.of(context).insert(_overlayEntry!);
  }

  /// Closes the dropdown. Unanimated selects remove the overlay immediately;
  /// animated ones keep it mounted, flip [_closing] so its content plays the
  /// exit motion (via `NibPresence`), and remove it once [_exitTimer] fires.
  void _beginClose() {
    if (_overlayEntry == null) return;
    if (!_animatedDropdown) {
      _removeOverlay();
      return;
    }
    if (_closing) return;
    _closing = true;
    _overlayEntry?.markNeedsBuild();
    _exitTimer?.cancel();
    _exitTimer = Timer(_exitDuration(), _removeOverlay);
  }

  void _removeOverlay() {
    _exitTimer?.cancel();
    _exitTimer = null;
    _closing = false;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /// Whether the dropdown should build `nib_motion` widgets at all — `false`
  /// keeps the `animated: false` / `NibSelectAnimation.none` paths overhead-free.
  bool get _animatedDropdown =>
      widget.animated &&
      (widget.enterFrom != null || widget.animation != NibSelectAnimation.none);

  NibTransition _effectiveTransition() =>
      widget.transition ??
      const NibTransition(duration: Duration(milliseconds: 140));

  /// How long to keep the overlay mounted after a close so the exit motion can
  /// finish before removal. Springs have no fixed duration, so estimate.
  Duration _exitDuration() {
    final t = _effectiveTransition();
    final base = t.spring != null
        ? const Duration(milliseconds: 450)
        : t.duration;
    return base + t.delay + const Duration(milliseconds: 40);
  }

  Widget _buildDropdownOverlay(BuildContext overlayContext) {
    final theme = NibTheme.of(context);
    final box = context.findRenderObject() as RenderBox?;
    final mq = MediaQuery.of(overlayContext);
    final screen = mq.size;
    // Keep the dropdown clear of the status bar (top), and of the system nav bar
    // or on-screen keyboard (bottom) — otherwise on a phone it opens under them.
    final safeTop = mq.padding.top;
    final safeBottom = mq.padding.bottom > mq.viewInsets.bottom
        ? mq.padding.bottom
        : mq.viewInsets.bottom;

    var triggerWidth = 240.0;
    var available = widget.maxDropdownHeight;
    var openUp = false;
    if (box != null && box.hasSize) {
      triggerWidth = box.size.width;
      final topLeft = box.localToGlobal(Offset.zero);
      final spaceBelow =
          screen.height - safeBottom - (topLeft.dy + box.size.height) - 8;
      final spaceAbove = topLeft.dy - safeTop - 8;
      openUp = spaceBelow < 160 && spaceAbove > spaceBelow;
      available = (openUp ? spaceAbove : spaceBelow).clamp(
        80.0,
        widget.maxDropdownHeight,
      );
    }

    final maxHeight = available.clamp(80.0, widget.maxDropdownHeight);

    final card = Material(
      color: theme.card,
      elevation: 8,
      borderRadius: BorderRadius.circular(theme.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: _buildDropdownBody(theme, overlayContext, openUp),
      ),
    );

    return Shortcuts(
      shortcuts: _overlayShortcuts(),
      child: Actions(
        actions: _navActions(),
        child: Stack(
          children: [
            // Opaque full-screen barrier: an outside tap closes the dropdown
            // and — being opaque — never double-fires into the trigger beneath
            // it (same rationale as NibAnchoredOverlay / NibCombobox). Dropped
            // while the exit motion plays so it doesn't block the trigger.
            if (!_closing)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                ),
              ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              targetAnchor: openUp ? Alignment.topLeft : Alignment.bottomLeft,
              followerAnchor: openUp ? Alignment.bottomLeft : Alignment.topLeft,
              offset: Offset(0, openUp ? -4 : 4),
              child: SizedBox(
                width: triggerWidth,
                child: _buildAnimatedCard(card, openUp: openUp),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Wraps the dropdown [card] in the `nib_motion` enter/exit machinery when
  /// animated, or returns it untouched otherwise. Exit is orchestrated by
  /// [NibPresence]: while [_closing], the keyed [NibMotion] is removed from the
  /// presence's children so it plays its [NibMotion.exit] before unmounting.
  ///
  /// With [NibSelect.staggerOptions] the panel itself only fades (the per-row
  /// cascade in [_buildDropdownBody] carries the preset motion), so the two
  /// don't double up.
  Widget _buildAnimatedCard(Widget card, {required bool openUp}) {
    if (!_animatedDropdown) return card;
    final panelFrom = widget.staggerOptions
        ? const NibAnim(opacity: 0)
        : (widget.enterFrom ??
              resolveNibSelectEnter(widget.animation, openUp: openUp));
    final motion = NibMotion(
      key: _cardKey,
      initial: panelFrom,
      animate: NibAnim.identity,
      exit: panelFrom,
      transition: _effectiveTransition(),
      child: card,
    );
    return NibPresence(children: _closing ? const [] : [motion]);
  }

  Widget _buildDropdownBody(
    NibTheme theme,
    BuildContext overlayContext,
    bool openUp,
  ) {
    final Widget body;
    if (widget.loading) {
      body = const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    } else if (_visibleOptions.isEmpty) {
      body =
          widget.noResultsBuilder?.call(overlayContext) ??
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'No results',
              style: TextStyle(color: theme.mutedForeground),
            ),
          );
    } else if (_animatedDropdown && widget.staggerOptions) {
      // Cascade: build every row eagerly and stagger each one's entrance. The
      // per-row "from" state carries the chosen preset (the panel only fades).
      final rowFrom =
          widget.enterFrom ??
          resolveNibSelectEnter(widget.animation, openUp: openUp);
      body = SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: NibMotionList(
          initial: rowFrom,
          animate: NibAnim.identity,
          staggerDelay: const Duration(milliseconds: 28),
          transition: _effectiveTransition(),
          children: [for (final entry in _entries) _buildEntry(theme, entry)],
        ),
      );
    } else {
      body = ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        shrinkWrap: true,
        itemCount: _entries.length,
        itemBuilder: (context, i) => _buildEntry(theme, _entries[i]),
      );
    }

    if (!widget.searchable) return body;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSearchField(theme),
        Flexible(child: body),
      ],
    );
  }

  Widget _buildSearchField(NibTheme theme) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Icon(Icons.search, size: 18, color: theme.mutedForeground),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                onChanged: _handleSearchChanged,
                style: TextStyle(color: theme.foreground),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: widget.searchPlaceholder,
                  hintStyle: TextStyle(color: theme.mutedForeground),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntry(NibTheme theme, _SelectEntry<T> entry) {
    if (entry is _HeaderEntry<T>) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
        child: Text(
          entry.label,
          style: TextStyle(
            color: theme.mutedForeground,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      );
    }
    final option = (entry as _OptionEntry<T>).option;
    return _buildOptionRow(theme, option, entry.optionIndex);
  }

  Widget _buildOptionRow(NibTheme theme, NibSelectOption<T> option, int index) {
    final highlighted = index == _highlightedIndex;
    final selected = _controller.selectedValues.contains(option.value);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Semantics(
        button: true,
        enabled: !option.disabled,
        selected: selected,
        label: option.label,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: highlighted ? theme.secondary : null,
            borderRadius: BorderRadius.circular(theme.radiusSm),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: option.disabled ? null : () => _selectOption(option),
              borderRadius: BorderRadius.circular(theme.radiusSm),
              excludeFromSemantics: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      if (option.icon != null) ...[
                        option.icon!,
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option.label,
                              style: TextStyle(
                                color: option.disabled
                                    ? theme.mutedForeground
                                    : theme.foreground,
                                fontWeight: highlighted
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            if (option.subtitle != null)
                              Text(
                                option.subtitle!,
                                style: TextStyle(
                                  color: theme.mutedForeground,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (selected) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.check, size: 18, color: theme.primary),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Shortcuts / actions --------------------------------------------------

  Map<ShortcutActivator, Intent> _triggerShortcuts() => const {
    SingleActivator(LogicalKeyboardKey.arrowDown): _MoveIntent(1),
    SingleActivator(LogicalKeyboardKey.arrowUp): _MoveIntent(-1),
    SingleActivator(LogicalKeyboardKey.enter): _ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.numpadEnter): _ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.space): _ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.escape): _CloseIntent(),
  };

  // No `space` here — inside the search field it must type a space, not select.
  Map<ShortcutActivator, Intent> _overlayShortcuts() => const {
    SingleActivator(LogicalKeyboardKey.arrowDown): _MoveIntent(1),
    SingleActivator(LogicalKeyboardKey.arrowUp): _MoveIntent(-1),
    SingleActivator(LogicalKeyboardKey.enter): _ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.numpadEnter): _ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.escape): _CloseIntent(),
  };

  Map<Type, Action<Intent>> _navActions() => {
    _MoveIntent: CallbackAction<_MoveIntent>(
      onInvoke: (i) {
        _onMove(i.delta);
        return null;
      },
    ),
    _ActivateIntent: CallbackAction<_ActivateIntent>(
      onInvoke: (_) {
        _onActivate();
        return null;
      },
    ),
    _CloseIntent: CallbackAction<_CloseIntent>(
      onInvoke: (_) {
        _close();
        return null;
      },
    ),
  };

  // --- Trigger build --------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    final selected = _controller.selectedValues;
    final hasSelection = selected.isNotEmpty;
    final showClear = widget.clearable && !widget.disabled && hasSelection;

    final Widget label;
    Widget? leadingIcon;
    if (!hasSelection) {
      label = Text(
        widget.placeholder,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: theme.mutedForeground),
      );
    } else if (widget.multiSelect) {
      label = Text(
        selected.map(_labelForValue).join(', '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: theme.foreground),
      );
    } else {
      leadingIcon = _optionForValue(selected.first)?.icon;
      label = Text(
        _labelForValue(selected.first),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: theme.foreground),
      );
    }

    return Shortcuts(
      shortcuts: _triggerShortcuts(),
      child: Actions(
        actions: _navActions(),
        child: CompositedTransformTarget(
          link: _link,
          child: Semantics(
            button: true,
            enabled: !widget.disabled,
            expanded: _controller.isOpen,
            label: widget.semanticLabel ?? widget.placeholder,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                focusNode: _triggerFocus,
                canRequestFocus: !widget.disabled,
                onTap: widget.disabled ? null : _toggleOpen,
                borderRadius: BorderRadius.circular(theme.radiusDefault),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.disabled ? theme.muted : theme.background,
                    border: Border.all(
                      color: _controller.isOpen ? theme.ring : theme.border,
                    ),
                    borderRadius: BorderRadius.circular(theme.radiusDefault),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 46),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          if (leadingIcon != null) ...[
                            leadingIcon,
                            const SizedBox(width: 8),
                          ],
                          Expanded(child: label),
                          if (showClear)
                            InkWell(
                              onTap: _clear,
                              borderRadius: BorderRadius.circular(
                                theme.radiusPill,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: theme.mutedForeground,
                                ),
                              ),
                            ),
                          Icon(
                            _controller.isOpen
                                ? Icons.arrow_drop_up
                                : Icons.arrow_drop_down,
                            color: theme.mutedForeground,
                          ),
                        ],
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

/// A rendered row in the dropdown: either a group [_HeaderEntry] or a
/// selectable [_OptionEntry].
sealed class _SelectEntry<T> {
  const _SelectEntry();
}

class _HeaderEntry<T> extends _SelectEntry<T> {
  const _HeaderEntry(this.label);
  final String label;
}

class _OptionEntry<T> extends _SelectEntry<T> {
  const _OptionEntry(this.option, this.optionIndex);
  final NibSelectOption<T> option;

  /// This option's index into the flat `_visibleOptions` list — used to line
  /// up keyboard highlight with the rendered row.
  final int optionIndex;
}

class _MoveIntent extends Intent {
  const _MoveIntent(this.delta);
  final int delta;
}

class _ActivateIntent extends Intent {
  const _ActivateIntent();
}

class _CloseIntent extends Intent {
  const _CloseIntent();
}
