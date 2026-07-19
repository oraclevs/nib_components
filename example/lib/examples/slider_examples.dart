import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';

/// 1. Minimal — a single-thumb slider over the default 0..1 domain.
class SliderMinimalExample extends StatefulWidget {
  const SliderMinimalExample({super.key});

  @override
  State<SliderMinimalExample> createState() => _SliderMinimalExampleState();
}

class _SliderMinimalExampleState extends State<SliderMinimalExample> {
  double _value = 0.4;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Minimal — value ${_value.toStringAsFixed(2)}'),
        const SizedBox(height: 16),
        SizedBox(
          width: 320,
          child: NibSlider(
            value: _value,
            onChanged: (v) => setState(() => _value = v),
          ),
        ),
      ],
    );
  }
}

/// 2. Divisions + value label — snaps to 10 ticks, shows a bubble while
/// dragging, and animates (thumb pop + label fade).
class SliderDivisionsLabelExample extends StatefulWidget {
  const SliderDivisionsLabelExample({super.key});

  @override
  State<SliderDivisionsLabelExample> createState() =>
      _SliderDivisionsLabelExampleState();
}

class _SliderDivisionsLabelExampleState
    extends State<SliderDivisionsLabelExample> {
  double _value = 40;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Divisions + label — ${_value.round()}%'),
        const SizedBox(height: 16),
        SizedBox(
          width: 320,
          child: NibSlider(
            value: _value,
            min: 0,
            max: 100,
            divisions: 10,
            showValueLabel: true,
            valueLabelFormatter: (v) => '${v.round()}%',
            animated: true,
            onChanged: (v) => setState(() => _value = v),
          ),
        ),
      ],
    );
  }
}

/// 3. Range — two thumbs that clamp against each other (price band).
class SliderRangeExample extends StatefulWidget {
  const SliderRangeExample({super.key});

  @override
  State<SliderRangeExample> createState() => _SliderRangeExampleState();
}

class _SliderRangeExampleState extends State<SliderRangeExample> {
  NibRangeValues _range = const NibRangeValues(200, 700);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Range — \$${_range.start.round()} … \$${_range.end.round()}'),
        const SizedBox(height: 16),
        SizedBox(
          width: 320,
          child: NibSlider.range(
            values: _range,
            min: 0,
            max: 1000,
            divisions: 20,
            showValueLabel: true,
            valueLabelFormatter: (v) => '\$${v.round()}',
            animated: true,
            onChanged: (r) => setState(() => _range = r),
          ),
        ),
      ],
    );
  }
}

/// 4. Advanced — vertical axis, custom colours + thumb size, animated.
class SliderVerticalCustomExample extends StatefulWidget {
  const SliderVerticalCustomExample({super.key});

  @override
  State<SliderVerticalCustomExample> createState() =>
      _SliderVerticalCustomExampleState();
}

class _SliderVerticalCustomExampleState
    extends State<SliderVerticalCustomExample> {
  double _volume = 65;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Vertical + custom — volume ${_volume.round()}'),
        const SizedBox(height: 16),
        SizedBox(
          height: 240,
          child: NibSlider(
            value: _volume,
            min: 0,
            max: 100,
            axis: Axis.vertical,
            showValueLabel: true,
            valueLabelFormatter: (v) => '${v.round()}',
            trackHeight: 8,
            thumbSize: 26,
            activeColor: const Color(0xFF7C3AED),
            inactiveColor: const Color(0xFFE9D5FF),
            thumbColor: const Color(0xFF7C3AED),
            trackRadius: BorderRadius.circular(4),
            animated: true,
            label: 'Volume',
            onChanged: (v) => setState(() => _volume = v),
          ),
        ),
      ],
    );
  }
}
