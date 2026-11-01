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
          'Esvaziar a lixeira...',
          tab.items.isEmpty ? null : controller.emptyTrashAsked,
        ),
      ];
    }
    return [
      item('Pôr de volta', () => controller.restore(paths)),
      item(
        'Apagar imediatamente...',
        () => controller.deleteForeverAsked(paths),
      ),
      divider,
      item(
        'Pré-visualizar',
        () => showQuickLook(context, controller),
        hint: 'Espaço',
      ),
      if (selected.length == 1)
        item(
          'Obter informações',
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
        'Nova pasta',
        inFolder ? controller.newFolder : null,
        hint: 'Ctrl+Shift+N',
      ),
      item(
        clip == 0 ? 'Colar' : 'Colar ${clip == 1 ? '1 item' : '$clip itens'}',
        inFolder && clip > 0 ? controller.paste : null,
        hint: 'Ctrl+V',
      ),
      divider,
      SubmenuButton(
        menuChildren: [
          for (final (mode, label) in [
            (ViewMode.icons, 'Ícones'),
            (ViewMode.list, 'Lista'),
            (ViewMode.columns, 'Colunas'),
          ])
            item(
              tab.mode == mode ? '$label  *' : label,
              mode == ViewMode.columns && !inFolder
                  ? null
                  : () => tab.setMode(mode),
            ),
        ],
        child: const Text('Ver como', style: TextStyle(fontSize: 12)),
      ),
      item(
        controller.config.showHidden ? 'Esconder ocultos' : 'Mostrar ocultos',
        () => controller.config.setShowHidden(!controller.config.showHidden),
        hint: 'Ctrl+H',
      ),
      if (folder != null && inFolder) ...[
        divider,
        item('Obter informações', () {
          final info = FsEntry.stat(folder, controller.env.mime);
          if (info != null) showInfo(context, controller, info);
        }),
      ],
    ];
  }

  final single = selected.length == 1;
  final folders = selected.where((e) => e.isDirectory).toList();
  return [
    item('Abrir', () => controller.open(selected), hint: 'Ctrl+O'),
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
                app.isDefault ? '${app.name} (padrão)' : app.name,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          if (apps.isNotEmpty) divider,
          item(
            'Outro...',
            () => showOpenWithOther(context, controller, selected),
          ),
        ],
        child: const Text('Abrir com', style: TextStyle(fontSize: 12)),
      ),
    if (folders.isNotEmpty)
      item('Abrir em nova aba', () {
        for (final f in folders) {
          controller.newTab(FolderLocation(f.path));
        }
      }),
    divider,
    item(
      'Mover para a lixeira',
      () => controller.moveToTrash(paths),
      hint: 'Del',
    ),
    divider,
    if (single)
      item(
        'Obter informações',
        () => showInfo(context, controller, entry),
        hint: 'Ctrl+I',
      ),
    if (single && location is FolderLocation)
      item('Renomear', () => tab.startRename(entry.path), hint: 'Enter'),
    item('Duplicar', () => controller.duplicate(paths), hint: 'Ctrl+D'),
    item(
      'Pré-visualizar',
      () => showQuickLook(context, controller),
      hint: 'Espaço',
    ),
    divider,
    item('Copiar', () => controller.copy(paths), hint: 'Ctrl+C'),
    item('Recortar', () => controller.copy(paths, cut: true), hint: 'Ctrl+X'),
    if (folders.isNotEmpty) ...[
      divider,
      item('Adicionar à barra lateral', () {
        for (final f in folders) {
          controller.config.addFavorite(f.path);
        }
      }),
    ],
    if (location is SearchLocation && single) ...[
      divider,
      item('Mostrar na pasta', () => controller.reveal(entry.path)),
    ],
  ];
}
