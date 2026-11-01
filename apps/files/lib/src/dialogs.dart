// apps/files/lib/src/dialogs.dart
//
// As janelas por cima: a pré-visualização do Espaço (Quick Look), o "Obter
// informações", o conflito de nomes, o "Abrir com > Outro…" e as
// confirmações.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:psito_files_ui/psito_files_ui.dart';
import 'package:psito_fs/psito_fs.dart';
import 'package:psito_sdk/psito_sdk.dart';

import 'controller.dart';
import 'env.dart';
import 'format.dart';
import 'items.dart';

import 'package:psito_files/l10n/l10n.dart';

/// O Espaço mostra o item selecionado: a imagem, o começo do texto ou, no
/// resto, o ícone grande com as informações. As setas trocam de item, e o
/// Espaço ou o Esc fecham.
Future<void> showQuickLook(BuildContext context, FilesController controller) =>
    showDialog<void>(
      context: context,
      barrierColor: context.palette.scrim,
      builder: (_) => FilesScope(
        controller: controller,
        showMenu: (_, _) {},
        child: _QuickLook(controller: controller),
      ),
    );

class _QuickLook extends StatelessWidget {
  final FilesController controller;

  const _QuickLook({required this.controller});

  @override
  Widget build(BuildContext context) {
    final tab = controller.tab;
    void step(int delta) => tab.moveCursor(delta);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): () =>
            Navigator.of(context).pop(),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => step(1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => step(1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => step(-1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => step(-1),
      },
      child: Focus(
        autofocus: true,
        child: Dialog(
          backgroundColor: context.palette.panelAlt,
          insetPadding: const EdgeInsets.all(16),
          child: ListenableBuilder(
            listenable: tab,
            builder: (context, _) {
              final entry = tab.cursor == null
                  ? null
                  : tab.entryAt(tab.cursor!);
              if (entry == null) return const SizedBox(width: 200, height: 120);
              return ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 720,
                  maxHeight: 560,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (!entry.isDirectory &&
                              controller.tab.trashItems.isEmpty)
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                controller.open([entry]);
                              },
                              child: Text(context.l10n.open),
                            ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: _Preview(entry: entry, controller: controller),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  final FsEntry entry;
  final FilesController controller;

  const _Preview({required this.entry, required this.controller});

  /// O texto mostrado: o começo do arquivo.
  static const _textBytes = 64 * 1024;

  Future<String?> _text() async {
    try {
      final file = await File(entry.path).open();
      try {
        final bytes = await file.read(_textBytes);
        return utf8.decode(bytes, allowMalformed: true);
      } finally {
        await file.close();
      }
    } on FileSystemException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final env = controller.env;
    if (entry.mimeType.startsWith('image/') &&
        entry.mimeType != 'image/svg+xml') {
      return Image.file(
        File(entry.path),
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _summary(context, env),
      );
    }
    if (env.mime.isA(entry.mimeType, textType) && !entry.isDirectory) {
      return FutureBuilder(
        future: _text(),
        builder: (context, snapshot) {
          final text = snapshot.data;
          if (text == null) {
            return snapshot.connectionState == ConnectionState.done
                ? _summary(context, env)
                : const SizedBox(height: 120);
          }
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            color: context.palette.shadowSoft,
            child: SingleChildScrollView(
              child: SelectableText(
                text,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          );
        },
      );
    }
    return _summary(context, env);
  }

  Widget _summary(BuildContext context, FilesEnv env) {
    final now = controller.ctx.now();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FileIcon(entry: entry, env: env, size: 128),
        const SizedBox(height: 12),
        Text(
          env.describe(entry.mimeType),
          style: TextStyle(fontSize: 12, color: context.palette.textTertiary),
        ),
        if (!entry.isDirectory)
          Text(
            formatSize(context.l10n, entry.size),
            style: TextStyle(fontSize: 12, color: context.palette.textTertiary),
          ),
        Text(
          context.l10n.modifiedAt(
            formatDate(context.l10n, entry.modified, now),
          ),
          style: TextStyle(fontSize: 12, color: context.palette.textTertiary),
        ),
      ],
    );
  }
}

/// O "Obter informações" de um item.
Future<void> showInfo(
  BuildContext context,
  FilesController controller,
  FsEntry entry,
) => showDialog<void>(
  context: context,
  builder: (_) => FilesScope(
    controller: controller,
    showMenu: (_, _) {},
    child: _InfoDialog(controller: controller, entry: entry),
  ),
);

class _InfoDialog extends StatefulWidget {
  final FilesController controller;
  final FsEntry entry;

  const _InfoDialog({required this.controller, required this.entry});

  @override
  State<_InfoDialog> createState() => _InfoDialogState();
}

class _InfoDialogState extends State<_InfoDialog> {
  late final Future<(int, int)>? _size = widget.entry.isDirectory
      ? directorySize(widget.entry.path)
      : null;
  late Future<List<PsitoAppChoice>> _apps = widget.entry.isDirectory
      ? Future.value(const [])
      : widget.controller.appsFor(widget.entry.mimeType);

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final entry = widget.entry;
    final env = controller.env;
    final now = controller.ctx.now();
    final trash = controller.tab.trashItems[entry.path];
    Widget line(String label, Widget value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                color: context.palette.textDisabled,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: value),
        ],
      ),
    );
    Text text(String value) => Text(
      value,
      style: TextStyle(fontSize: 12, color: context.palette.text),
    );
    return AlertDialog(
      backgroundColor: context.palette.panelAlt,
      title: Row(
        children: [
          FileIcon(entry: entry, env: env, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              trash?.name ?? entry.name,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              line(context.l10n.kind, text(env.describe(entry.mimeType))),
              line(
                context.l10n.size,
                _size == null
                    ? text(
                        context.l10n.sizeWithBytes(
                          formatSize(context.l10n, entry.size),
                          entry.size,
                        ),
                      )
                    : FutureBuilder(
                        future: _size,
                        builder: (_, s) => text(
                          s.data == null
                              ? context.l10n.calculating
                              : context.l10n.sizeAndItems(
                                  s.data!.$2,
                                  formatSize(context.l10n, s.data!.$1),
                                ),
                        ),
                      ),
              ),
              line(
                trash != null ? context.l10n.wherefrom : context.l10n.where,
                SelectableText(
                  trash != null ? trash.originalPath : dirName(entry.path),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              if (entry.linkTarget != null)
                line(context.l10n.pointsTo, text(entry.linkTarget!)),
              if (trash?.deletedAt != null)
                line(
                  context.l10n.deletedAt,
                  text(formatLocalDate(context.l10n, trash!.deletedAt!, now)),
                ),
              line(
                context.l10n.modified,
                text(formatDate(context.l10n, entry.modified, now)),
              ),
              line(
                context.l10n.accessed,
                text(formatDate(context.l10n, entry.accessed, now)),
              ),
              line(context.l10n.permissions, text(formatMode(entry.mode))),
              if (!entry.isDirectory && trash == null)
                line(
                  context.l10n.openWith,
                  FutureBuilder(
                    future: _apps,
                    builder: (context, snapshot) {
                      final apps = snapshot.data ?? const [];
                      if (apps.isEmpty) {
                        return text(
                          snapshot.connectionState == ConnectionState.done
                              ? context.l10n.noApp
                              : '...',
                        );
                      }
                      return DropdownButton<String>(
                        value: apps.first.id,
                        isDense: true,
                        isExpanded: true,
                        style: const TextStyle(fontSize: 12),
                        items: [
                          for (final app in apps)
                            DropdownMenuItem(
                              value: app.id,
                              child: Text(
                                app.isDefault
                                    ? context.l10n.appDefault(app.name)
                                    : app.name,
                              ),
                            ),
                        ],
                        onChanged: (id) async {
                          if (id == null || id == apps.first.id) return;
                          // Como o "Alterar todos" do Finder: vale para o tipo
                          await controller.setDefaultApp(entry.mimeType, id);
                          setState(
                            () => _apps = controller.appsFor(entry.mimeType),
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.close),
        ),
      ],
    );
  }
}

/// O que fazer com um nome que já existe. A UI liga no
/// [FilesController.onConflict].
Future<ConflictAnswer> showConflict(BuildContext context, FsConflict c) async {
  var all = false;
  final choice = await showDialog<ConflictChoice>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        backgroundColor: context.palette.panelAlt,
        title: Text(
          context.l10n.conflictExists(
            baseName(dirName(c.target)),
            baseName(c.target),
          ),
          style: const TextStyle(fontSize: 14),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              c.targetIsDirectory && c.sourceIsDirectory
                  ? context.l10n.conflictFolderHint
                  : context.l10n.conflictFileHint,
              style: TextStyle(
                fontSize: 12,
                color: context.palette.textTertiary,
              ),
            ),
            CheckboxListTile(
              value: all,
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                context.l10n.applyToNext,
                style: TextStyle(fontSize: 12),
              ),
              onChanged: (v) => setState(() => all = v ?? false),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(ConflictChoice.skip),
            child: Text(context.l10n.skip),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(ConflictChoice.keepBoth),
            child: Text(context.l10n.keepBoth),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(ConflictChoice.replace),
            child: Text(context.l10n.replace),
          ),
        ],
      ),
    ),
  );
  return ConflictAnswer(choice ?? ConflictChoice.skip, applyToAll: all);
}

/// O "Abrir com > Outro…": todos os apps que recebem arquivos, e se o
/// escolhido vira o padrão do tipo.
Future<void> showOpenWithOther(
  BuildContext context,
  FilesController controller,
  List<FsEntry> entries,
) async {
  final mimeType = entries.first.mimeType;
  var always = false;
  final apps = await controller.appsFor('');
  if (!context.mounted) return;
  final chosen = await showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        backgroundColor: context.palette.panelAlt,
        title: Text(context.l10n.openWith, style: TextStyle(fontSize: 14)),
        content: SizedBox(
          width: 320,
          height: 320,
          child: Column(
            children: [
              Expanded(
                child: apps.isEmpty
                    ? Center(child: Text(context.l10n.noAppTakesFiles))
                    : ListView(
                        children: [
                          for (final app in apps)
                            ListTile(
                              dense: true,
                              leading: ThemedIcon(
                                [?app.icon],
                                fallback: Icons.apps_rounded,
                                size: 24,
                              ),
                              title: Text(app.name),
                              onTap: () => Navigator.of(context).pop(app.id),
                            ),
                        ],
                      ),
              ),
              CheckboxListTile(
                value: always,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  context.l10n.alwaysOpenWith(
                    controller.env.describe(mimeType),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
                onChanged: (v) => setState(() => always = v ?? false),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.cancel),
          ),
        ],
      ),
    ),
  );
  if (chosen == null) return;
  if (always) await controller.setDefaultApp(mimeType, chosen);
  await controller.openWith(entries, chosen);
}

/// Uma confirmação; true se o usuário confirmou.
Future<bool> showConfirm(
  BuildContext context,
  String question,
  String detail,
  String action,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.palette.panelAlt,
        title: Text(question, style: const TextStyle(fontSize: 14)),
        content: Text(detail, style: const TextStyle(fontSize: 12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.palette.danger,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;
