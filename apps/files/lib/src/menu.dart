// apps/files/lib/src/menu.dart
//
// O menu de contexto: o dos itens (Abrir, Abrir com, Mover para a lixeira,
// Obter informações, Renomear, Duplicar, Copiar e Recortar…), o do fundo da
// pasta (Nova pasta, Colar, Ver como) e os da lixeira (Pôr de volta, Apagar
// imediatamente, Esvaziar).
import 'package:flutter/material.dart';
import 'package:psito_files_ui/psito_files_ui.dart';
import 'package:psito_fs/psito_fs.dart';
import 'package:psito_sdk/psito_sdk.dart';

import 'controller.dart';
import 'dialogs.dart';
import 'env.dart';
import 'tab.dart';

import 'package:psito_files/l10n/l10n.dart';

/// Os itens do menu de [entry] (null: o fundo da pasta). [apps] são os do
/// "Abrir com" do tipo do primeiro selecionado.
List<Widget> contextMenu(
  BuildContext context,
  FilesController controller,
  FsEntry? entry,
  List<PsitoAppChoice> apps,
) {
  final tab = controller.tab;
  final location = tab.location;
  final selected = entry == null ? const <FsEntry>[] : tab.selectedEntries;
  final paths = [for (final e in selected) e.path];
  MenuItemButton item(String label, VoidCallback? onPressed, {String? hint}) =>
      MenuItemButton(
        onPressed: onPressed,
        trailingIcon: hint == null
            ? null
            : Text(
                hint,
                style: const TextStyle(fontSize: 11, color: Colors.white38),
              ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      );
  const divider = Divider(height: 8);

  if (location is TrashLocation) {
    if (entry == null) {
      return [
        item(
          context.l10n.emptyTrashEllipsis,
          tab.items.isEmpty ? null : controller.emptyTrashAsked,
        ),
      ];
    }
    return [
      item(context.l10n.restore, () => controller.restore(paths)),
      item(context.l10n.deleteNow, () => controller.deleteForeverAsked(paths)),
      divider,
      item(
        context.l10n.preview,
        () => showQuickLook(context, controller),
        hint: context.l10n.keySpace,
      ),
      if (selected.length == 1)
        item(
          context.l10n.getInfo,
          () => showInfo(context, controller, entry),
          hint: 'Ctrl+I',
        ),
    ];
  }

  if (entry == null) {
    final folder = tab.folder;
    final inFolder = location is FolderLocation;
    final clip = controller.clipboard.length;
    return [
      item(
        context.l10n.newFolder,
        inFolder ? controller.newFolder : null,
        hint: 'Ctrl+Shift+N',
      ),
      item(
        clip == 0 ? context.l10n.paste : context.l10n.pasteItems(clip),
        inFolder && clip > 0 ? controller.paste : null,
        hint: 'Ctrl+V',
      ),
      divider,
      SubmenuButton(
        menuChildren: [
          for (final (mode, label) in [
            (ViewMode.icons, context.l10n.viewIcons),
            (ViewMode.list, context.l10n.viewList),
            (ViewMode.columns, context.l10n.viewColumns),
          ])
            item(
              tab.mode == mode ? '$label  *' : label,
              mode == ViewMode.columns && !inFolder
                  ? null
                  : () => tab.setMode(mode),
            ),
        ],
        child: Text(context.l10n.viewAs, style: TextStyle(fontSize: 12)),
      ),
      item(
        controller.config.showHidden
            ? context.l10n.hideHidden
            : context.l10n.showHidden,
        () => controller.config.setShowHidden(!controller.config.showHidden),
        hint: 'Ctrl+H',
      ),
      if (folder != null && inFolder) ...[
        divider,
        item(context.l10n.getInfo, () {
          final info = FsEntry.stat(folder, controller.env.mime);
          if (info != null) showInfo(context, controller, info);
        }),
      ],
    ];
  }

  final single = selected.length == 1;
  final folders = selected.where((e) => e.isDirectory).toList();
  return [
    item(context.l10n.open, () => controller.open(selected), hint: 'Ctrl+O'),
    if (selected.every((e) => !e.isDirectory))
      SubmenuButton(
        menuChildren: [
          for (final app in apps)
            MenuItemButton(
              leadingIcon: ThemedIcon(
                [?app.icon],
                fallback: Icons.apps_rounded,
                size: 16,
              ),
              onPressed: () => controller.openWith(selected, app.id),
              child: Text(
                app.isDefault ? context.l10n.appDefault(app.name) : app.name,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          if (apps.isNotEmpty) divider,
          item(
            context.l10n.other,
            () => showOpenWithOther(context, controller, selected),
          ),
        ],
        child: Text(context.l10n.openWith, style: TextStyle(fontSize: 12)),
      ),
    if (folders.isNotEmpty)
      item(context.l10n.openInNewTab, () {
        for (final f in folders) {
          controller.newTab(FolderLocation(f.path));
        }
      }),
    divider,
    item(
      context.l10n.moveToTrash,
      () => controller.moveToTrash(paths),
      hint: 'Del',
    ),
    divider,
    if (single)
      item(
        context.l10n.getInfo,
        () => showInfo(context, controller, entry),
        hint: 'Ctrl+I',
      ),
    if (single && location is FolderLocation)
      item(
        context.l10n.rename,
        () => tab.startRename(entry.path),
        hint: 'Enter',
      ),
    item(
      context.l10n.duplicate,
      () => controller.duplicate(paths),
      hint: 'Ctrl+D',
    ),
    item(
      context.l10n.preview,
      () => showQuickLook(context, controller),
      hint: context.l10n.keySpace,
    ),
    divider,
    item(context.l10n.copy, () => controller.copy(paths), hint: 'Ctrl+C'),
    item(
      context.l10n.cut,
      () => controller.copy(paths, cut: true),
      hint: 'Ctrl+X',
    ),
    if (folders.isNotEmpty) ...[
      divider,
      item(context.l10n.addToSidebar, () {
        for (final f in folders) {
          controller.config.addFavorite(f.path);
        }
      }),
    ],
    if (location is SearchLocation && single) ...[
      divider,
      item(context.l10n.showInFolder, () => controller.reveal(entry.path)),
    ],
  ];
}
