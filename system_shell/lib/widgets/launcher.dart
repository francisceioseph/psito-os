// system_shell/lib/widgets/launcher.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shell/app_entry.dart';
import '../shell/app_search.dart';
import 'dock_menu.dart';

import 'package:system_shell/l10n/l10n.dart';

/// Menu Psito: busca com foco e grade de apps.
class Launcher extends StatefulWidget {
  final List<AppEntry> apps;
  final void Function(AppEntry app) onLaunch;
  final VoidCallback onClose;

  /// Arrastar um app para fora da grade (para a dock). Quem chama segue o
  /// ponteiro dali em diante: o launcher pode fechar.
  final void Function(AppEntry app)? onDragStart;

  /// As opções do clique direito num app. Null: sem menu.
  final List<DockMenuItem> Function(AppEntry app)? menuFor;

  const Launcher({
    super.key,
    required this.apps,
    required this.onLaunch,
    required this.onClose,
    this.onDragStart,
    this.menuFor,
  });

  static const columns = 5;

  @override
  State<Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<Launcher> {
  static const _tileSize = 96.0;
  static const _spacing = 8.0;

  late List<AppEntry> _results = widget.apps;
  int _selected = 0;
  int? _hovered;

  /// O app com o menu aberto, e onde.
  (AppEntry, Offset)? _menu;

  void _search(String query) {
    setState(() {
      _results = searchApps(widget.apps, query);
      _selected = 0;
    });
  }

  void _move(int delta) {
    if (_results.isEmpty) return;
    setState(() {
      _selected = (_selected + delta).clamp(0, _results.length - 1);
    });
  }

  void _launchSelected() {
    if (_results.isEmpty) return;
    widget.onLaunch(_results[_selected]);
  }

  @override
  Widget build(BuildContext context) {
    // Mais perto do campo que os atalhos de texto do app: as setas navegam
    // na grade em vez de mover o cursor.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _move(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _move(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            _move(-Launcher.columns),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            _move(Launcher.columns),
        // O foco fica na busca: o Esc do menu aberto chega aqui
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_menu != null) {
            setState(() => _menu = null);
          } else {
            widget.onClose();
          }
        },
      },
      child: Stack(
        children: [
          // Fundo escurecido: clicar fora fecha
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onClose,
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.45)),
            ),
          ),
          Center(child: _buildPanel()),
          if (_menu case (final app, final at)?)
            Positioned.fill(
              child: DockMenu(
                at: at,
                title: app.name,
                items: widget.menuFor!(app),
                onClose: () => setState(() => _menu = null),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPanel() {
    const gridWidth =
        Launcher.columns * _tileSize + (Launcher.columns - 1) * _spacing;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E252B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: SizedBox(
        width: gridWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              autofocus: true,
              onChanged: _search,
              onSubmitted: (_) => _launchSelected(),
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: context.l10n.searchApps,
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_results.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  context.l10n.noAppsFound,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
                ),
              )
            else
              Wrap(
                spacing: _spacing,
                runSpacing: _spacing,
                children: [
                  for (var i = 0; i < _results.length; i++) _buildTile(i),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(int index) {
    final app = _results[index];
    final selected = index == _selected;
    final highlighted = selected || index == _hovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = index),
      onExit: (_) => setState(() => _hovered = null),
      child: GestureDetector(
        onTap: () => widget.onLaunch(app),
        onSecondaryTapUp: widget.menuFor == null
            ? null
            : (details) =>
                  setState(() => _menu = (app, details.globalPosition)),
        onPanStart: widget.onDragStart == null
            ? null
            : (_) => widget.onDragStart!(app),
        child: AnimatedContainer(
          key: ValueKey('launcher-${app.id}'),
          duration: const Duration(milliseconds: 150),
          width: _tileSize,
          height: _tileSize,
          decoration: BoxDecoration(
            color: app.color.withValues(alpha: highlighted ? 0.25 : 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? app.color : Colors.white12,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              app.icon(36),
              const SizedBox(height: 8),
              Text(
                app.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
