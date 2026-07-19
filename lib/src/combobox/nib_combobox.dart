import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:nib_motion/nib_motion.dart'
    show NibAnim, NibMotion, NibTransition;

import '../theme/nib_theme.dart';
import 'nib_combobox_controller.dart';
import 'nib_combobox_filter.dart';
import 'nib_combobox_option.dart';

/// A native combobox: a text field fused with a filtered, keyboard-navigable
/// dropdown of [NibComboboxOption]s. Supports type-to-filter, single- and
/// multi-select (chips shown inside the field), free-text vs. selection-only
/// modes, and both synchronous ([options]) and async/debounced
/// ([asyncOptionsLoader]) data sources with an in-dropdown loading state.
///
/// Simplest usage needs only [options]:
///
/// ```dart
/// NibCombobox<String>(
///   options: const [
///     NibComboboxOption(value: 'apple', label: 'Apple'),
///     NibComboboxOption(value: 'banana', label: 'Banana'),
///   ],
///   onChanged: (value) => print(value),
/// )
/// ```
class NibCombobox<T> extends StatefulWidget {
  const NibCombobox({
    super.key,
    this.options = const [],
    this.asyncOptionsLoader,
    this.multiSelect = false,
    this.allowFreeText = false,
    this.debounceDuration = const Duration(milliseconds: 300),
    this.onChanged,
    this.onSelectionChanged,
    this.onFreeTextSubmitted,
    this.loading = false,
    this.filter,
    this.noResultsBuilder,
    this.placeholder = 'Select…',
    this.clearable = true,
    this.disabled = false,
    this.animated = false,
    this.transition,
    this.maxDropdownHeight = 280,
    this.controller,
  });

  /// The synchronous option list. Ignored while [asyncOptionsLoader] is set
  /// (that loader becomes the data source instead).
  final List<NibComboboxOption<T>> options;

  /// Async data source. When set, options are (re)loaded — debounced by
  /// [debounceDuration] — on each query change, with an in-dropdown spinner
  /// while pending and a stale-response guard so only the latest request's
  /// result is applied.
  final NibComboboxOptionsLoader<T>? asyncOptionsLoader;

  /// Multi-select mode: picks toggle, the dropdown stays open, and selected
  /// values render as removable chips inside the field.
  final bool multiSelect;

  /// When `true`, text that doesn't match an option can still be committed
  /// (Enter) — reported via [onFreeTextSubmitted]. When `false` (default), the
  /// value only ever changes by picking an option; typing that doesn't match
  /// reverts on close.
  final bool allowFreeText;

  final Duration debounceDuration;

  /// Single-select convenience: fires the newly-selected value (or `null` when
  /// cleared). For multi-select use [onSelectionChanged].
  final ValueChanged<T?>? onChanged;

  /// Fires the full selection list on every selection change, in both modes.
  final ValueChanged<List<T>>? onSelectionChanged;

  /// Fires the raw text when [allowFreeText] is on and the user commits text
  /// that isn't an option.
  final ValueChanged<String>? onFreeTextSubmitted;

  /// Consumer-forced loading state — shows the in-dropdown loading indicator
  /// without using [asyncOptionsLoader] (for callers driving their own async).
  final bool loading;

  /// Overridable local match predicate. Defaults to [defaultComboboxFilter]
  /// (case-insensitive substring on label/subtitle). Not used on the
  /// [asyncOptionsLoader] path (the loader owns matching there).
  final NibComboboxFilter<T>? filter;

  /// Builds the dropdown body when there are no results and nothing is
  /// loading. Defaults to a muted "No results" row.
  final WidgetBuilder? noResultsBuilder;

  final String placeholder;

  /// Whether to show the trailing clear (✕) button when there's a query or
  /// selection to clear.
  final bool clearable;

  final bool disabled;

  /// Opt-in dropdown entrance animation via `nib_motion`. `false` allocates
  /// zero `NibMotion`/`MotionValue` overhead.
  final bool animated;

  /// Transition used when [animated] is `true`. `null` falls back to a short
  /// fade+scale+slide.
  final NibTransition? transition;

  final double maxDropdownHeight;

  /// Optional external controller for selection/query/open state. Never
  /// required — `NibCombobox` creates and owns one internally when this is
  /// `null`, and disposes it on unmount/controller-swap.
  final NibComboboxController<T>? controller;

  @override
  State<NibCombobox<T>> createState() => _NibComboboxState<T>();
}

class _NibComboboxState<T> extends State<NibCombobox<T>> {
  late NibComboboxController<T> _controller;
  late bool _ownsController;

  final _textController = TextEditingController();
  final _focusNode = FocusNode(debugLabel: 'nib-combobox');
  final _link = LayerLink();
  OverlayEntry? _overlayEntry;

  List<NibComboboxOption<T>> _visibleOptions = [];
  int _highlightedIndex = -1;
  bool _asyncLoading = false;
  Timer? _debounce;
  int _requestSeq = 0;

  bool get _isAsync => widget.asyncOptionsLoader != null;
  NibComboboxFilter<T> get _filter => widget.filter ?? defaultComboboxFilter<T>;

  @override
  void initState() {
    super.initState();
    _bindController(widget.controller);
    _syncFieldTextToSelection();
  }

  @override
  void didUpdateWidget(covariant NibCombobox<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _unbindController();
      _bindController(widget.controller);
    }
    if (!identical(widget.options, oldWidget.options) &&
        _controller.isOpen &&
        !_isAsync) {
      _recomputeSyncVisible();
      _overlayEntry?.markNeedsBuild();
    }
    if (widget.loading != oldWidget.loading) {
      _overlayEntry?.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    _unbindController();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _bindController(NibComboboxController<T>? external) {
    _controller = external ?? NibComboboxController<T>();
    _ownsController = external == null;
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
      _removeOverlay();
    }
    if (mounted) setState(() {});
  }

  // --- Field text <-> selection helpers -------------------------------------

  String _labelForValue(T value) {
    for (final o in widget.options) {
      if (o.value == value) return o.label;
    }
    return value.toString();
  }

  /// In single-select, mirrors the field text to the current selection's
  /// label. No-op in multi-select (chips carry the selection; the field holds
  /// only the query).
  void _syncFieldTextToSelection() {
    if (widget.multiSelect) return;
    final value = _controller.selectedValue;
    _textController.text = value == null ? '' : _labelForValue(value);
  }

  // --- Open / close ---------------------------------------------------------

  void _open() {
    if (widget.disabled || _controller.isOpen) return;
    if (_isAsync) {
      _visibleOptions = const [];
      _runAsyncLoad('');
    } else {
      _recomputeAllVisible();
    }
    _focusNode.requestFocus();
    // Select-all so the first keystroke replaces any reverted label and the
    // freshly-opened list shows everything rather than filtering by it.
    if (_textController.text.isNotEmpty) {
      _textController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _textController.text.length,
      );
    }
    _controller.open();
  }

  void _closeAndRevert() {
    if (!_controller.isOpen) return;
    _controller.close();
    if (!widget.allowFreeText) {
      if (widget.multiSelect) {
        _textController.clear();
      } else {
        _syncFieldTextToSelection();
      }
      _controller.setQuery(_textController.text);
    }
  }

  void _toggleOpen() => _controller.isOpen ? _closeAndRevert() : _open();

  // --- Visible-option computation -------------------------------------------

  void _recomputeAllVisible() {
    _visibleOptions = List<NibComboboxOption<T>>.from(widget.options);
    _resetHighlight();
  }

  void _recomputeSyncVisible() {
    _visibleOptions = filterOptions(
      widget.options,
      _textController.text,
      _filter,
    );
    _resetHighlight();
  }

  void _resetHighlight() {
    _highlightedIndex = _visibleOptions.indexWhere((o) => !o.disabled);
  }

  // --- Async loading --------------------------------------------------------

  void _scheduleAsyncLoad(String query) {
    _debounce?.cancel();
    _debounce = Timer(widget.debounceDuration, () => _runAsyncLoad(query));
  }

  Future<void> _runAsyncLoad(String query) async {
    final seq = ++_requestSeq;
    setState(() => _asyncLoading = true);
    _overlayEntry?.markNeedsBuild();
    try {
      final result = await widget.asyncOptionsLoader!(query);
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _visibleOptions = result;
        _asyncLoading = false;
        _resetHighlight();
      });
    } catch (_) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _visibleOptions = const [];
        _asyncLoading = false;
      });
    }
    _overlayEntry?.markNeedsBuild();
  }

  // --- Text / selection changes ---------------------------------------------

  void _handleTextChanged(String text) {
    _controller.setQuery(text);
    if (!_controller.isOpen) {
      _open();
      return;
    }
    if (_isAsync) {
      setState(() {}); // reflect the typed text immediately
      _scheduleAsyncLoad(text);
    } else {
      setState(_recomputeSyncVisible);
    }
    _overlayEntry?.markNeedsBuild();
  }

  void _selectOption(NibComboboxOption<T> option) {
    if (option.disabled) return;
    if (widget.multiSelect) {
      _controller.toggle(option.value);
      _textController.clear();
      _controller.setQuery('');
      if (_isAsync) {
        _runAsyncLoad('');
      } else {
        _recomputeAllVisible();
      }
      widget.onSelectionChanged?.call(_controller.selectedValues);
      _overlayEntry?.markNeedsBuild();
    } else {
      _controller.selectOnly(option.value);
      _textController.text = option.label;
      _controller.setQuery(option.label);
      _controller.close();
      widget.onChanged?.call(option.value);
      widget.onSelectionChanged?.call(_controller.selectedValues);
    }
  }

  void _commitFreeText() {
    final text = _textController.text;
    if (text.isEmpty) return;
    widget.onFreeTextSubmitted?.call(text);
    _controller.close();
  }

  void _clearAll() {
    _textController.clear();
    _controller.setQuery('');
    final had = _controller.selectedValues.isNotEmpty;
    _controller.clear();
    if (_controller.isOpen) {
      if (_isAsync) {
        _runAsyncLoad('');
      } else {
        _recomputeAllVisible();
      }
      _overlayEntry?.markNeedsBuild();
    }
    if (had) {
      widget.onChanged?.call(null);
      widget.onSelectionChanged?.call(const []);
    }
    setState(() {});
  }

  void _removeChip(T value) {
    _controller.toggle(value); // present -> removes
    widget.onSelectionChanged?.call(_controller.selectedValues);
    if (_controller.isOpen) _overlayEntry?.markNeedsBuild();
    setState(() {});
  }

  // --- Keyboard navigation --------------------------------------------------

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
    } else if (widget.allowFreeText) {
      _commitFreeText();
    }
  }

  // --- Overlay build --------------------------------------------------------

  void _showOverlay() {
    if (_overlayEntry != null || !mounted) return;
    _overlayEntry = OverlayEntry(builder: _buildDropdownOverlay);
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
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

    var fieldWidth = 240.0;
    var available = widget.maxDropdownHeight;
    var openUp = false;
    if (box != null && box.hasSize) {
      fieldWidth = box.size.width;
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
        child: _buildDropdownBody(theme, overlayContext),
      ),
    );

    return Stack(
      children: [
        // Opaque full-screen barrier: an outside tap (or a tap back on the
        // field) closes the dropdown, and — being opaque — never double-fires
        // into whatever sits beneath it (same rationale as NibAnchoredOverlay).
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _closeAndRevert,
          ),
        ),
        CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: openUp ? Alignment.topLeft : Alignment.bottomLeft,
          followerAnchor: openUp ? Alignment.bottomLeft : Alignment.topLeft,
          offset: Offset(0, openUp ? -4 : 4),
          child: SizedBox(
            width: fieldWidth,
            child: widget.animated
                ? NibMotion(
                    initial: NibAnim(
                      opacity: 0,
                      scale: 0.98,
                      y: openUp ? 8 : -8,
                    ),
                    animate: const NibAnim(opacity: 1, scale: 1, y: 0),
                    transition:
                        widget.transition ??
                        const NibTransition(
                          duration: Duration(milliseconds: 140),
                        ),
                    child: card,
                  )
                : card,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownBody(NibTheme theme, BuildContext overlayContext) {
    final loadingActive = _asyncLoading || widget.loading;

    if (loadingActive && _visibleOptions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    if (_visibleOptions.isEmpty) {
      return widget.noResultsBuilder?.call(overlayContext) ??
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'No results',
              style: TextStyle(color: theme.mutedForeground),
            ),
          );
    }

    final list = ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      shrinkWrap: true,
      itemCount: _visibleOptions.length,
      itemBuilder: (context, i) =>
          _buildOptionRow(theme, _visibleOptions[i], i),
    );

    if (!loadingActive) return list;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LinearProgressIndicator(
          minHeight: 2,
          backgroundColor: theme.muted,
          color: theme.primary,
        ),
        Flexible(child: list),
      ],
    );
  }

  Widget _buildOptionRow(
    NibTheme theme,
    NibComboboxOption<T> option,
    int index,
  ) {
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

  // --- Field build ----------------------------------------------------------

  Map<ShortcutActivator, Intent> _shortcuts() {
    final canRemoveChip =
        widget.multiSelect &&
        _textController.text.isEmpty &&
        _controller.selectedValues.isNotEmpty;
    return {
      const SingleActivator(LogicalKeyboardKey.arrowDown):
          const _MoveOrOpenIntent(1),
      const SingleActivator(LogicalKeyboardKey.arrowUp):
          const _MoveHighlightIntent(-1),
      const SingleActivator(LogicalKeyboardKey.enter): const _ActivateIntent(),
      const SingleActivator(LogicalKeyboardKey.numpadEnter):
          const _ActivateIntent(),
      const SingleActivator(LogicalKeyboardKey.escape): const _CloseIntent(),
      if (canRemoveChip)
        const SingleActivator(LogicalKeyboardKey.backspace):
            const _RemoveLastChipIntent(),
    };
  }

  Widget _buildChip(NibTheme theme, T value) {
    return Container(
      margin: const EdgeInsets.only(right: 6, top: 3, bottom: 3),
      padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: theme.secondary,
        borderRadius: BorderRadius.circular(theme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _labelForValue(value),
            style: TextStyle(color: theme.secondaryForeground, fontSize: 13),
          ),
          const SizedBox(width: 2),
          InkWell(
            onTap: widget.disabled ? null : () => _removeChip(value),
            borderRadius: BorderRadius.circular(theme.radiusPill),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                Icons.close,
                size: 14,
                color: theme.secondaryForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = NibTheme.of(context);
    final hasClearable =
        widget.clearable &&
        !widget.disabled &&
        (_textController.text.isNotEmpty ||
            _controller.selectedValues.isNotEmpty);

    final field = TextField(
      controller: _textController,
      focusNode: _focusNode,
      enabled: !widget.disabled,
      onChanged: _handleTextChanged,
      onTap: _open,
      // Without this, TextField only fires onTap when the tap *changes* focus;
      // a combobox that stays focused after a pick would then never reopen on
      // a subsequent tap.
      onTapAlwaysCalled: true,
      style: TextStyle(color: theme.foreground),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: (widget.multiSelect && _controller.selectedValues.isNotEmpty)
            ? null
            : widget.placeholder,
        hintStyle: TextStyle(color: theme.mutedForeground),
        contentPadding: EdgeInsets.zero,
      ),
    );

    final Widget input;
    if (widget.multiSelect && _controller.selectedValues.isNotEmpty) {
      input = Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final v in _controller.selectedValues) _buildChip(theme, v),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 120),
            child: field,
          ),
        ],
      );
    } else {
      input = field;
    }

    return Shortcuts(
      shortcuts: _shortcuts(),
      child: Actions(
        actions: {
          _MoveOrOpenIntent: CallbackAction<_MoveOrOpenIntent>(
            onInvoke: (i) {
              if (!_controller.isOpen) {
                _open();
              } else {
                _moveHighlight(i.delta);
              }
              return null;
            },
          ),
          _MoveHighlightIntent: CallbackAction<_MoveHighlightIntent>(
            onInvoke: (i) {
              if (_controller.isOpen) _moveHighlight(i.delta);
              return null;
            },
          ),
          _ActivateIntent: CallbackAction<_ActivateIntent>(
            onInvoke: (_) {
              if (_controller.isOpen) {
                _activateHighlighted();
              } else if (widget.allowFreeText) {
                _commitFreeText();
              }
              return null;
            },
          ),
          _CloseIntent: CallbackAction<_CloseIntent>(
            onInvoke: (_) {
              _closeAndRevert();
              return null;
            },
          ),
          _RemoveLastChipIntent: CallbackAction<_RemoveLastChipIntent>(
            onInvoke: (_) {
              final sel = _controller.selectedValues;
              if (sel.isNotEmpty) _removeChip(sel.last);
              return null;
            },
          ),
        },
        child: CompositedTransformTarget(
          link: _link,
          child: Semantics(
            textField: true,
            label: widget.placeholder,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: widget.disabled ? theme.muted : theme.background,
                border: Border.all(
                  color: _controller.isOpen ? theme.ring : theme.border,
                ),
                borderRadius: BorderRadius.circular(theme.radiusDefault),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 18, color: theme.mutedForeground),
                    const SizedBox(width: 8),
                    Expanded(child: input),
                    if (hasClearable)
                      InkWell(
                        onTap: _clearAll,
                        borderRadius: BorderRadius.circular(theme.radiusPill),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: theme.mutedForeground,
                          ),
                        ),
                      ),
                    InkWell(
                      onTap: widget.disabled ? null : _toggleOpen,
                      borderRadius: BorderRadius.circular(theme.radiusPill),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          _controller.isOpen
                              ? Icons.arrow_drop_up
                              : Icons.arrow_drop_down,
                          color: theme.mutedForeground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoveOrOpenIntent extends Intent {
  const _MoveOrOpenIntent(this.delta);
  final int delta;
}

class _MoveHighlightIntent extends Intent {
  const _MoveHighlightIntent(this.delta);
  final int delta;
}

class _ActivateIntent extends Intent {
  const _ActivateIntent();
}

class _CloseIntent extends Intent {
  const _CloseIntent();
}

class _RemoveLastChipIntent extends Intent {
  const _RemoveLastChipIntent();
}
