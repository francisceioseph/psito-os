// apps/settings/lib/settings_ui.dart
//
// As peças de que as seções são feitas: os grupos em cartão, as linhas e as
// notas. É o que dá o mesmo jeito a todas elas.
import 'package:flutter/material.dart';
import 'package:psito_sdk/psito_sdk.dart';

/// Um cartão de linhas relacionadas, com o título em cima e a nota embaixo.
class SettingsGroup extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  final String? footer;

  const SettingsGroup({
    super.key,
    this.title,
    required this.children,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title case final title?)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: palette.textSecondary,
                ),
              ),
            ),
          // Material: os ListTile pintam o realce nele
          Material(
            color: palette.panelRaised,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, child) in children.indexed) ...[
                  if (i > 0) Divider(height: 1, color: palette.lineSoft),
                  child,
                ],
              ],
            ),
          ),
          if (footer case final footer?) SettingsNote(footer),
        ],
      ),
    );
  }
}

/// Um texto de apoio, sem competir com os controles.
class SettingsNote extends StatelessWidget {
  final String text;

  const SettingsNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
    child: Text(
      text,
      style: TextStyle(fontSize: 12, color: context.palette.textTertiary),
    ),
  );
}

/// Uma linha com o nome à esquerda e o controle à direita. Sem largura para os
/// dois, o controle desce.
class SettingsRow extends StatelessWidget {
  final String title;
  final Widget control;

  const SettingsRow({super.key, required this.title, required this.control});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 420
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(title), const SizedBox(height: 8), control],
            )
          : Row(
              children: [
                Expanded(child: Text(title)),
                const SizedBox(width: 16),
                control,
              ],
            ),
    ),
  );
}

/// O respiro de um conteúdo solto dentro do cartão.
class SettingsPad extends StatelessWidget {
  final Widget child;

  const SettingsPad({super.key, required this.child});

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.all(16), child: child);
}
