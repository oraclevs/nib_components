import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_components/nib_components.dart';
import 'package:nib_motion/nib_motion.dart';

const _drops = [NibWaterDrop(id: 1, center: Offset(80, 80), radius: 32)];
NibWaterController _controller() => NibWaterController(drops: _drops);
Widget _host({
  NibWaterController? controller,
  bool animated = false,
  bool reducedMotion = false,
  bool systemReduced = false,
  bool paused = false,
  NibWaterConfig config = const NibWaterConfig(),
  List<NibWaterDrop> drops = _drops,
  NibTheme theme = NibTheme.dark,
  BorderRadius? radius,
  Widget? child,
  Listenable? backgroundChanges,
}) => MaterialApp(
  theme: ThemeData.dark().copyWith(extensions: [theme]),
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(800, 600),
      disableAnimations: systemReduced,
    ),
    child: Center(
      child: SizedBox(
        width: 320,
        height: 220,
        child: NibWaterGlass(
          controller: controller,
          animated: animated,
          config: config,
          drops: drops,
          paused: paused,
          reducedMotion: reducedMotion,
          borderRadius: radius,
          interaction: NibWaterInteraction.drag,
          background: const ColoredBox(color: Colors.blue),
          backgroundChanges: backgroundChanges,
          child: child,
        ),
      ),
    ),
  ),
);

Future<void> _frames(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 16));
}

NibWaterController _mounted(WidgetTester tester) =>
    tester.widget<NibWaterSurface>(find.byType(NibWaterSurface)).controller;
Offset _point(WidgetTester tester, Offset local) => tester
    .renderObject<RenderBox>(find.byType(NibWaterSurface))
    .localToGlobal(local);
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  await tester.pump();
  expect(tester.takeException(), isNull);
  expect(tester.binding.transientCallbackCount, 0);
}

void main() {
  testWidgets('sampling policy and optics reach the shared surface', (
    tester,
  ) async {
    const quality = NibWaterQuality(scale: .75, maxPixels: 200000);
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 200,
          height: 160,
          child: NibWaterGlass(
            background: ColoredBox(color: Colors.blue),
            sampling: NibWaterSampling.throttled,
            quality: quality,
            sampleInterval: Duration(milliseconds: 80),
            material: NibWaterMaterial.deep,
          ),
        ),
      ),
    );
    final surface = tester.widget<NibWaterSurface>(
      find.byType(NibWaterSurface),
    );
    expect(surface.sampling, NibWaterSampling.throttled);
    expect(surface.quality, same(quality));
    expect(surface.sampleInterval, const Duration(milliseconds: 80));
    expect(surface.material, same(NibWaterMaterial.deep));
    await _unmount(tester);
  });

  testWidgets(
    'default owned controller resolves motion statically and disposes on unmount',
    (tester) async {
      await tester.pumpWidget(_host());
      await _frames(tester);
      final owned = _mounted(tester);
      expect(owned.isReducedMotion, isTrue);
      final drag = await tester.startGesture(
        _point(tester, const Offset(80, 80)),
      );
      await drag.moveTo(_point(tester, const Offset(120, 100)));
      expect(owned.drops.single.center, const Offset(120, 100));
      expect(owned.activeInputs, 1);
      await drag.up();
      await _unmount(tester);
      expect(owned.isDisposed, isTrue);
    },
  );

  testWidgets('external controller config wins and unmount leaves it usable', (
    tester,
  ) async {
    final external = _controller();
    addTearDown(external.dispose);
    external.configure(const NibWaterConfig(waveSpeed: 250));
    await tester.pumpWidget(
      _host(
        controller: external,
        config: const NibWaterConfig(waveSpeed: 100),
        animated: true,
      ),
    );
    await _frames(tester);
    expect(_mounted(tester), same(external));
    expect(external.config.waveSpeed, 250);
    final drag = await tester.startGesture(
      _point(tester, const Offset(80, 80)),
    );
    expect(external.activeInputs, 1);
    await _unmount(tester);
    expect(external.activeInputs, 0);
    expect(external.isDisposed, isFalse);
    external.disturb(Offset.zero);
    expect(external.impulses, hasLength(1));
    await drag.cancel();
  });

  testWidgets(
    'owned config update retains identity; changed drops reset owned state',
    (tester) async {
      await tester.pumpWidget(_host(animated: true));
      await _frames(tester);
      final first = _mounted(tester);
      first.disturb(Offset.zero);
      await tester.pumpWidget(
        _host(animated: true, config: const NibWaterConfig(waveSpeed: 250)),
      );
      expect(_mounted(tester), same(first));
      expect(first.config.waveSpeed, 250);
      expect(first.impulses, isNotEmpty);
      await tester.pumpWidget(
        _host(
          animated: true,
          drops: const [
            NibWaterDrop(id: 7, center: Offset(120, 100), radius: 40),
          ],
        ),
      );
      await _frames(tester);
      final second = _mounted(tester);
      expect(second, isNot(same(first)));
      expect(first.isDisposed, isTrue);
      expect(second.drops.single.id, 7);
      expect(second.impulses, isEmpty);
      await _unmount(tester);
      expect(second.isDisposed, isTrue);
    },
  );

  testWidgets(
    'owned to external and external to owned swaps keep ownership correct',
    (tester) async {
      final external = _controller();
      addTearDown(external.dispose);
      await tester.pumpWidget(_host());
      await _frames(tester);
      final owned = _mounted(tester);
      await tester.pumpWidget(_host(controller: external));
      await _frames(tester);
      expect(owned.isDisposed, isTrue);
      expect(_mounted(tester), same(external));
      await tester.pumpWidget(_host());
      await _frames(tester);
      final replacement = _mounted(tester);
      expect(replacement, isNot(same(external)));
      expect(external.isDisposed, isFalse);
      await _unmount(tester);
      expect(replacement.isDisposed, isTrue);
      expect(external.isDisposed, isFalse);
    },
  );

  testWidgets(
    'system reduction takes precedence over animated and local preferences',
    (tester) async {
      final external = _controller();
      addTearDown(external.dispose);
      await tester.pumpWidget(
        _host(controller: external, animated: true, systemReduced: true),
      );
      await _frames(tester);
      expect(external.isReducedMotion, isTrue);
      external.disturb(Offset.zero);
      expect(external.impulses, isEmpty);
      await tester.pumpWidget(_host(controller: external, animated: true));
      expect(external.isReducedMotion, isFalse);
      await tester.pumpWidget(
        _host(controller: external, animated: true, reducedMotion: true),
      );
      expect(external.isReducedMotion, isTrue);
      await _unmount(tester);
    },
  );

  testWidgets('pause cancels held pointer and rejects further input', (
    tester,
  ) async {
    final external = _controller();
    addTearDown(external.dispose);
    await tester.pumpWidget(_host(controller: external));
    await _frames(tester);
    final drag = await tester.startGesture(
      _point(tester, const Offset(80, 80)),
    );
    expect(external.activeInputs, 1);
    await tester.pumpWidget(_host(controller: external, paused: true));
    expect(external.activeInputs, 0);
    await drag.moveBy(const Offset(40, 0));
    expect(external.drops.single.center, const Offset(80, 80));
    await drag.cancel();
    await _unmount(tester);
  });

  testWidgets('reads theme radius and allows explicit clipping override', (
    tester,
  ) async {
    final external = _controller();
    addTearDown(external.dispose);
    final clip = find
        .descendant(
          of: find.byType(NibWaterGlass),
          matching: find.byType(ClipRRect),
        )
        .first;
    await tester.pumpWidget(
      _host(
        controller: external,
        theme: NibTheme.light.copyWith(radiusDefault: 18),
      ),
    );
    expect(
      tester.widget<ClipRRect>(clip).borderRadius,
      BorderRadius.circular(18),
    );
    await tester.pumpWidget(
      _host(controller: external, radius: BorderRadius.circular(31)),
    );
    expect(
      tester.widget<ClipRRect>(clip).borderRadius,
      BorderRadius.circular(31),
    );
    await _unmount(tester);
  });

  testWidgets(
    'sharp foreground action remains focusable and independently actionable',
    (tester) async {
      final external = _controller();
      addTearDown(external.dispose);
      final focus = FocusNode();
      addTearDown(focus.dispose);
      final semantics = tester.ensureSemantics();
      var presses = 0;
      await tester.pumpWidget(
        _host(
          controller: external,
          child: Center(
            child: TextButton(
              focusNode: focus,
              onPressed: () => presses++,
              child: const Text('Continue'),
            ),
          ),
        ),
      );
      await _frames(tester);
      focus.requestFocus();
      await tester.pump();
      external.merge();
      external.split();
      expect(focus.hasFocus, isTrue);
      expect(find.bySemanticsLabel('Continue'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      expect(presses, 1);
      await _unmount(tester);
      semantics.dispose();
    },
  );

  testWidgets('forwards background invalidation without owning the signal', (
    tester,
  ) async {
    final controller = _controller();
    final signal = ValueNotifier(0);
    addTearDown(controller.dispose);
    addTearDown(signal.dispose);
    await tester.pumpWidget(
      _host(controller: controller, backgroundChanges: signal),
    );
    await _frames(tester);
    expect(
      tester
          .widget<NibWaterSurface>(find.byType(NibWaterSurface))
          .backgroundChanges,
      same(signal),
    );
    signal.value++;
    await _unmount(tester);
    signal.value++;
    expect(signal.value, 2);
  });
}
