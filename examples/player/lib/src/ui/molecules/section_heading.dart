// examples/player/lib/src/ui/molecules/section_heading.dart
import 'package:flutter/material.dart';

class SectionHeading extends StatelessWidget {
  final String title;
  final Widget? action;

  const SectionHeading(this.title, {super.key, this.action});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ?action,
      ],
    ),
  );
}
