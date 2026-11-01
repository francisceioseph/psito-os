import 'dart:async';

import 'package:flutter/material.dart';
import 'package:psito_sdk/psito_sdk.dart';

import 'l10n/l10n.dart';

/// A seção Armazenamento: o uso de cada disco, as maiores pastas, a lixeira e
/// formatar um disco externo. Quem mede e formata é o shell.
class StorageSection extends StatefulWidget {
  final PsitoStorage storage;

  const StorageSection({super.key, required this.storage});

  @override
  State<StorageSection> createState() => _StorageSectionState();
}

class _StorageSectionState extends State<StorageSection> {
  late final Timer _timer;
  int _trash = 0;

  /// Aqui, e não em cada disco: ao formatar, o disco sai e volta da lista.
  bool _formatting = false;
  String? _message;

  Future<void> _format(
    PsitoDiskUsage disk,
    PsitoDiskFormat type,
    String label,
  ) async {
    final l = context.l10n;
    setState(() {
      _formatting = true;
      _message = null;
    });
    final result = await widget.storage.format(disk.id, type, label);
    if (!mounted) return;
    setState(() {
      _formatting = false;
      _message = switch (result) {
        PsitoDiskResult.ok => l.storageFormatDone,
        PsitoDiskResult.busy => l.storageFormatBusy,
        _ => l.storageFormatFailed,
      };
    });
    unawaited(_refresh());
  }

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    // Uma cópia ou esvaziar a lixeira mudam o espaço com a seção aberta
    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(_refresh()),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    await widget.storage.refresh();
    final trash = await widget.storage.trashSize();
    if (mounted) setState(() => _trash = trash);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ValueListenableBuilder(
      valueListenable: widget.storage.disks,
      builder: (context, disks, _) {
        if (disks.isEmpty) return Text(l.storageUnavailable);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final disk in disks)
              _DiskTile(
                key: ValueKey('disk-${disk.id}'),
                storage: widget.storage,
                disk: disk,
                onFormat: (type, label) => _format(disk, type, label),
              ),
            if (_formatting) const LinearProgressIndicator(),
            if (_message case final message?) Text(message),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_outline),
              title: Text(l.storageTrash),
              subtitle: Text(
                l.storageTrashSize(formatPsitoSize(_trash, l.localeName)),
              ),
              trailing: TextButton(
                key: const ValueKey('storage-empty-trash'),
                onPressed: _trash == 0
                    ? null
                    : () => unawaited(widget.storage.emptyTrash()),
                child: Text(l.storageEmptyTrash),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DiskTile extends StatefulWidget {
  final PsitoStorage storage;
  final PsitoDiskUsage disk;
  final Future<void> Function(PsitoDiskFormat type, String label) onFormat;

  const _DiskTile({
    super.key,
    required this.storage,
    required this.disk,
    required this.onFormat,
  });

  @override
  State<_DiskTile> createState() => _DiskTileState();
}

class _DiskTileState extends State<_DiskTile> {
  Future<List<PsitoFolderSize>>? _folders;
  bool _formatting = false;

  String _name(BuildContext context) {
    final disk = widget.disk;
    if (disk.isSystem) return context.l10n.storageThisComputer;
    return disk.name.isEmpty ? context.l10n.storageUnnamed : disk.name;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;
    final disk = widget.disk;
    final free = disk.free;
    final path = disk.path;
    String size(int bytes) => formatPsitoSize(bytes, l.localeName);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                disk.isSystem ? Icons.computer_outlined : Icons.usb,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _name(context),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (free != null && disk.total > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: 1 - free / disk.total,
                minHeight: 8,
                color: disk.almostFull ? palette.danger : null,
                backgroundColor: palette.textSecondary.withValues(alpha: 0.2),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            free == null
                ? l.storageNotMounted(size(disk.total))
                : l.storageFree(size(free), size(disk.total)),
            style: TextStyle(color: palette.textSecondary),
          ),
          if (disk.almostFull)
            Text(l.storageAlmostFull, style: TextStyle(color: palette.danger)),
          Wrap(
            spacing: 8,
            children: [
              if (path != null)
                TextButton(
                  key: ValueKey('storage-largest-${disk.id}'),
                  onPressed: () => setState(() {
                    _folders = _folders == null
                        ? widget.storage.largestFolders(path)
                        : null;
                  }),
                  child: Text(
                    _folders == null ? l.storageLargest : l.storageHideLargest,
                  ),
                ),
              if (!disk.isSystem)
                TextButton(
                  key: ValueKey('storage-format-${disk.id}'),
                  onPressed: () => setState(() => _formatting = !_formatting),
                  child: Text(l.storageFormat),
                ),
            ],
          ),
          if (_folders case final folders?)
            FutureBuilder(
              future: folders,
              builder: (context, snapshot) {
                final list = snapshot.data;
                if (list == null) return const LinearProgressIndicator();
                if (list.isEmpty) return Text(l.storageNoFolders);
                return Column(
                  children: [
                    for (final folder in list)
                      _FolderRow(
                        folder: folder,
                        largest: list.first.size,
                        onOpen: () =>
                            unawaited(widget.storage.openFolder(folder.path)),
                      ),
                  ],
                );
              },
            ),
          if (_formatting)
            _FormatForm(
              disk: disk,
              name: _name(context),
              onCancel: () => setState(() => _formatting = false),
              onFormat: (type, label) async {
                await widget.onFormat(type, label);
                if (mounted) setState(() => _formatting = false);
              },
            ),
        ],
      ),
    );
  }
}

class _FolderRow extends StatelessWidget {
  final PsitoFolderSize folder;
  final int largest;
  final VoidCallback onOpen;

  const _FolderRow({
    required this.folder,
    required this.largest,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final name = folder.path.split('/').last;
    return Tooltip(
      message: l.storageOpenFolder(name),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Text(
                    formatPsitoSize(folder.size, l.localeName),
                    style: TextStyle(color: context.palette.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              LinearProgressIndicator(
                value: largest == 0 ? 0 : folder.size / largest,
                minHeight: 3,
                backgroundColor: context.palette.textSecondary.withValues(
                  alpha: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Formatar é a ação mais perigosa do sistema: o botão só acende com o nome do
/// disco digitado.
class _FormatForm extends StatefulWidget {
  final PsitoDiskUsage disk;
  final String name;
  final VoidCallback onCancel;
  final Future<void> Function(PsitoDiskFormat type, String label) onFormat;

  const _FormatForm({
    required this.disk,
    required this.name,
    required this.onCancel,
    required this.onFormat,
  });

  @override
  State<_FormatForm> createState() => _FormatFormState();
}

class _FormatFormState extends State<_FormatForm> {
  final _label = TextEditingController();
  final _confirm = TextEditingController();
  PsitoDiskFormat _type = PsitoDiskFormat.exfat;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _label.text = widget.disk.name;
    _confirm.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _label.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _format() async {
    setState(() => _running = true);
    final label = _label.text.trim();
    await widget.onFormat(
      _type,
      label.length > _type.maxLabel
          ? label.substring(0, _type.maxLabel)
          : label,
    );
    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.storageFormatWarning(widget.name),
            style: TextStyle(color: context.palette.danger),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<PsitoDiskFormat>(
            key: const ValueKey('storage-format-type'),
            initialValue: _type,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.storageFormatType),
            items: [
              for (final type in PsitoDiskFormat.values)
                DropdownMenuItem(
                  value: type,
                  child: Text(switch (type) {
                    PsitoDiskFormat.vfat => l.storageFormatFat,
                    PsitoDiskFormat.exfat => l.storageFormatExfat,
                    PsitoDiskFormat.ext4 => l.storageFormatExt4,
                  }, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _running
                ? null
                : (type) => setState(() => _type = type ?? _type),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('storage-format-label'),
            controller: _label,
            enabled: !_running,
            maxLength: _type.maxLabel,
            decoration: InputDecoration(labelText: l.storageFormatLabel),
          ),
          TextField(
            key: const ValueKey('storage-format-confirm'),
            controller: _confirm,
            enabled: !_running,
            decoration: InputDecoration(
              labelText: l.storageFormatConfirm(widget.name),
            ),
          ),
          const SizedBox(height: 8),
          if (_running) const LinearProgressIndicator(),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: _running ? null : widget.onCancel,
                child: Text(l.storageFormatCancel),
              ),
              FilledButton(
                key: const ValueKey('storage-format-go'),
                style: FilledButton.styleFrom(
                  backgroundColor: context.palette.danger,
                ),
                onPressed: _running || _confirm.text != widget.name
                    ? null
                    : () => unawaited(_format()),
                child: Text(l.storageFormatAction),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
