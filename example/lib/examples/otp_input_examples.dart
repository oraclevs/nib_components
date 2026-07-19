import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';

/// 1. Minimal — a 6-digit code; shows the completed value below.
class OtpMinimalExample extends StatefulWidget {
  const OtpMinimalExample({super.key});

  @override
  State<OtpMinimalExample> createState() => _OtpMinimalExampleState();
}

class _OtpMinimalExampleState extends State<OtpMinimalExample> {
  String? _code;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Minimal — type or paste a 6-digit code (autofocus)'),
        const SizedBox(height: 12),
        NibOtpInput(
          length: 6,
          autoFocus: true,
          onCompleted: (v) => setState(() => _code = v),
        ),
        const SizedBox(height: 12),
        Text(_code == null ? 'Waiting…' : 'Completed: $_code'),
      ],
    );
  }
}

/// 2. Common — obscured 4-digit PIN with a pop animation.
class OtpPinExample extends StatelessWidget {
  const OtpPinExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('PIN — 4 digits, masked, animated'),
        const SizedBox(height: 12),
        const NibOtpInput(length: 4, obscureText: true, animated: true),
      ],
    );
  }
}

/// 3. On-screen keypad — masked ATM-style PIN with automatic verification: on
/// the last digit it grays out and shows the custom loader in the confirm slot,
/// then reveals the result. Device keyboard never opens.
class OtpOnScreenExample extends StatefulWidget {
  const OtpOnScreenExample({super.key});

  @override
  State<OtpOnScreenExample> createState() => _OtpOnScreenExampleState();
}

class _OtpOnScreenExampleState extends State<OtpOnScreenExample> {
  final _controller = NibOtpController();
  bool _loading = false;
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verify(String code) async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    setState(() {
      _loading = false;
      _done = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'On-screen keypad — masked 5-digit PIN, auto-verify + loader',
        ),
        const SizedBox(height: 12),
        NibOtpInput(
          length: 5,
          controller: _controller,
          keyboard: NibOtpKeyboard.onScreen,
          obscureText: true,
          animated: true,
          loading: _loading,
          onCompleted: _verify, // automatic verification on the last digit
          onConfirm: _verify, // or tap the confirm key
          onChanged: (_) {
            if (_done) setState(() => _done = false);
          },
        ),
        const SizedBox(height: 8),
        if (_done)
          Row(
            children: [
              const Icon(Icons.lock_open, color: Colors.green, size: 20),
              const SizedBox(width: 6),
              const Text('PIN verified'),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () {
                  _controller.clear();
                  setState(() => _done = false);
                },
                child: const Text('Reset'),
              ),
            ],
          ),
      ],
    );
  }
}

/// 3b. Styled keypad — custom colours, font, spacing, and a custom confirm
/// widget in place of the default check key.
class OtpStyledKeypadExample extends StatelessWidget {
  const OtpStyledKeypadExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Styled keypad — custom colours, font, spacing, confirm widget',
        ),
        const SizedBox(height: 12),
        NibOtpInput(
          length: 4,
          keyboard: NibOtpKeyboard.onScreen,
          keypadStyle: const NibOtpKeypadStyle(
            keyColor: Color(0xFF1E293B),
            keyTextColor: Colors.white,
            keyTextStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            iconColor: Color(0xFF94A3B8),
            keyWidth: 74,
            keyHeight: 58,
            keyRadius: 18,
            horizontalSpacing: 14,
            verticalSpacing: 14,
          ),
          confirmButton: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF02569B), Color(0xFF54C5F8)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(
              child: Text(
                'OK',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 4. Advanced — controller-driven with validation: wrong code shows an error
/// and clears; a "Fill demo code" button prefills programmatically.
class OtpAdvancedExample extends StatefulWidget {
  const OtpAdvancedExample({super.key});

  @override
  State<OtpAdvancedExample> createState() => _OtpAdvancedExampleState();
}

class _OtpAdvancedExampleState extends State<OtpAdvancedExample> {
  final _controller = NibOtpController();
  static const _correct = '2468';
  String? _error;
  bool _verified = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _verify(String code) {
    if (code == _correct) {
      setState(() {
        _verified = true;
        _error = null;
      });
    } else {
      setState(() => _error = 'Incorrect code — try 2468');
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Advanced — controller, validation, error state (code: 2468)',
        ),
        const SizedBox(height: 12),
        NibOtpInput(
          length: 4,
          controller: _controller,
          animated: true,
          errorText: _error,
          onCompleted: _verify,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton(
              onPressed: () => _controller.setValue(_correct),
              child: const Text('Fill demo code'),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: _controller.clear,
              child: const Text('Clear'),
            ),
            const SizedBox(width: 12),
            if (_verified)
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 6),
                  Text('Verified'),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
