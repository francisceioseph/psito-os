// examples/player/lib/src/ui/pages/soon_page.dart
//
// O lugar das telas das próximas fases.
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../templates/page_template.dart';

class SoonPage extends StatelessWidget {
  final String title;

  const SoonPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) => PageTemplate(
    title: title,
    slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(context.l10n.comingSoon),
        ),
      ),
    ],
  );
}
