import 'package:flutter/material.dart';
import 'package:nib_components/nib_components.dart';

const _faq = [
  NibAccordionItem(
    title: Text('What is Nib?'),
    content: Text('A native Flutter component library — installable widgets, '
        'not copy-pasted snippets, built on nib_motion.'),
  ),
  NibAccordionItem(
    title: Text('Does it support dark mode?'),
    content: Text('Yes. Every component reads its colours from NibTheme and '
        'works in light and dark out of the box.'),
  ),
  NibAccordionItem(
    title: Text('Is it responsive?'),
    content: Text('Components adapt to mobile, tablet, and desktop widths and '
        'never clip or overflow silently.'),
  ),
];

/// 1. Minimal — single-open FAQ (default coordination).
class AccordionMinimalExample extends StatelessWidget {
  const AccordionMinimalExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: const [
        Text('Minimal — single-open FAQ (opening one closes the rest)'),
        SizedBox(height: 12),
        SizedBox(width: 420, child: NibAccordion(items: _faq)),
      ],
    );
  }
}

/// 2. Common — multi-open, animated, with leading icons and one open by default.
class AccordionMultiExample extends StatelessWidget {
  const AccordionMultiExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: const [
        Text('Multi-open, animated, leading icons, first open by default'),
        SizedBox(height: 12),
        SizedBox(
          width: 420,
          child: NibAccordion(
            allowMultipleOpen: true,
            animated: true,
            defaultOpenIndex: 0,
            items: [
              NibAccordionItem(
                leading: Icon(Icons.local_shipping_outlined),
                title: Text('Shipping'),
                content: Text('Free standard shipping on orders over \$50. '
                    'Arrives in 2–4 business days.'),
              ),
              NibAccordionItem(
                leading: Icon(Icons.assignment_return_outlined),
                title: Text('Returns'),
                content: Text('30-day free returns. Items must be unworn with '
                    'tags attached.'),
              ),
              NibAccordionItem(
                leading: Icon(Icons.verified_user_outlined),
                title: Text('Warranty'),
                content: Text('Two-year limited warranty covering manufacturing '
                    'defects.'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 3. Advanced — external controller with expand-all / collapse-all buttons.
class AccordionControllerExample extends StatefulWidget {
  const AccordionControllerExample({super.key});

  @override
  State<AccordionControllerExample> createState() => _AccordionControllerExampleState();
}

class _AccordionControllerExampleState extends State<AccordionControllerExample> {
  final _controller = NibAccordionController(allowMultiple: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Advanced — controller, expand/collapse all, animated'),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton(
              onPressed: () => _controller.openAll(_faq.length),
              child: const Text('Expand all'),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: _controller.closeAll,
              child: const Text('Collapse all'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 420,
          child: NibAccordion(
            controller: _controller,
            allowMultipleOpen: true,
            animated: true,
            items: _faq,
          ),
        ),
      ],
    );
  }
}
