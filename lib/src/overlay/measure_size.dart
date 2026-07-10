import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Reports [child]'s laid-out size via [onChange] after every layout pass
/// that changes it, without affecting [child]'s constraints or paint.
///
/// Used to measure content whose final size isn't known until after it's
/// built (an overlay flyout before its flip/clamp position is decided, or
/// off-screen nav items before overflow packing decides what fits).
class MeasureSize extends SingleChildRenderObjectWidget {
  const MeasureSize({super.key, required this.onChange, required Widget super.child});

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMeasureSize(onChange);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderMeasureSize).onChange = onChange;
  }
}

class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize(this.onChange);

  ValueChanged<Size> onChange;
  Size? _oldSize;

  @override
  void performLayout() {
    super.performLayout();
    final newSize = child?.size ?? Size.zero;
    if (_oldSize == newSize) return;
    _oldSize = newSize;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(newSize));
  }
}
