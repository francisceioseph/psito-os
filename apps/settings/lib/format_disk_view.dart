import 'dart:async';

import 'package:flutter/material.dart';
import 'package:psito_sdk/psito_sdk.dart';

import 'l10n/l10n.dart';
import 'settings_ui.dart';

/// O disco pedido nos argumentos, ou null: as Configurações normais.
String? formatDiskArgument(List<String> arguments) {
  for (final argument in arguments) {
    if (argument.startsWith(psitoFormatDiskPrefix)) {
      return argument.substring(psitoFormatDiskPrefix.length);
    }
  }
  return null;
}

/// A janela de formatar um disco. Formatar é a ação mais perigosa do sistema:
/// fica à parte do resto, e o botão ainda pergunta antes de apagar.
class FormatDiskView extends StatefulWidget {
  final PsitoAppContext appContext;
  final String id;

  const FormatDiskView({super.key, required this.appContext, required this.id});

  @override
  State<FormatDiskView> createState() => _FormatDiskViewState();
}

class _FormatDiskViewState extends State<FormatDiskView> {
  final _label = TextEditingController();
  PsitoDiskFormat _type = PsitoDiskFormat.exfat;
  bool _running = false;
  bool _labelSet = false;
  PsitoDiskResult? _result;

  /// Muda quando o formulário recomeça, depois de formatar: os campos nascem
  /// de novo, com o que o disco tem agora.
  int _form = 0;

  /// O nome de antes: ao formatar, o disco sai da lista e volta com outro.
  String? _name;

  PsitoStorage get _storage => widget.appContext.storage;

  /// Formatado, à espera do OK. O disco pode estar fora da lista nesse tempo.
  bool get _done => _result == PsitoDiskResult.ok;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _ask(String name) async {
    final l = context.l10n;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.storageFormatTitle(name)),
        content: Text(l.storageFormatWarning(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.storageFormatCancel),
          ),
          FilledButton(
            key: const ValueKey('storage-format-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: context.palette.danger,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.storageFormatAction),
          ),
        ],
      ),
    );
    if (yes ?? false) await _format();
  }

  Future<void> _format() async {
    setState(() {
      _running = true;
      _result = null;
    });
    final label = _label.text.trim();
    final result = await _storage.format(
      widget.id,
      _type,
      label.length > _type.maxLabel
          ? label.substring(0, _type.maxLabel)
          : label,
    );
    if (!mounted) return;
    setState(() {
      _running = false;
      _result = result;
    });
    if (result != PsitoDiskResult.ok) return;
    final l = context.l10n;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Text(l.storageFormatDone),
        actions: [
          FilledButton(
            key: const ValueKey('storage-format-ok'),
            onPressed: () => Navigator.pop(context),
            child: Text(l.storageFormatOk),
          ),
        ],
      ),
    );
    if (!mounted) return;
    unawaited(_storage.refresh());
    setState(() {
      _result = null;
      _labelSet = false;
      _type = PsitoDiskFormat.exfat;
      _form++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ValueListenableBuilder(
      valueListenable: _storage.disks,
      builder: (context, disks, _) {
        final disk = disks.where((d) => d.id == widget.id).firstOrNull;
        if (disk != null) {
          final next = disk.name.isEmpty ? l.storageUnnamed : disk.name;
          if (next != _name) {
            widget.appContext.setTitle(l.storageFormatTitle(next));
          }
          _name = next;
          if (!_labelSet) {
            _labelSet = true;
            _label.text = disk.name;
          }
        }
        final name = _name;
        final gone = name == null || (disk == null && !_running && !_done);
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: KeyedSubtree(
                  key: ValueKey(_form),
                  child: ListView(
                    children: gone
                        ? [Text(l.storageFormatGone)]
                        : _fields(context, disk),
                  ),
                ),
              ),
              if (_running)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              if (_result case final result? when !_done)
                SettingsNote(
                  result == PsitoDiskResult.busy
                      ? l.storageFormatBusy
                      : l.storageFormatFailed,
                ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    key: const ValueKey('storage-format-close'),
                    onPressed: _running ? null : widget.appContext.close,
                    child: Text(l.storageFormatCancel),
                  ),
                  if (!gone)
                    FilledButton(
                      key: const ValueKey('storage-format-go'),
                      onPressed: _running || disk == null
                          ? null
                          : () => unawaited(_ask(name)),
                      child: Text(l.storageFormatGo),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _fields(BuildContext context, PsitoDiskUsage? disk) {
    final l = context.l10n;
    const border = OutlineInputBorder();
    return [
      _Field(
        title: l.storageFormatLabel,
        child: TextField(
          key: const ValueKey('storage-format-label'),
          controller: _label,
          enabled: !_running,
          maxLength: _type.maxLabel,
          decoration: const InputDecoration(
            border: border,
            isDense: true,
            counterText: '',
          ),
        ),
      ),
      _Field(
        title: l.storageFormatCapacity,
        child: InputDecorator(
          decoration: const InputDecoration(
            border: border,
            isDense: true,
            enabled: false,
          ),
          child: Text(
            disk == null ? '' : formatPsitoSize(disk.total, l.localeName),
            key: const ValueKey('storage-format-capacity'),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
      _Field(
        title: l.storageFormatType,
        child: DropdownButtonFormField<PsitoDiskFormat>(
          key: const ValueKey('storage-format-type'),
          initialValue: _type,
          isExpanded: true,
          decoration: InputDecoration(
            border: border,
            isDense: true,
            helperText: switch (_type) {
              PsitoDiskFormat.vfat => l.storageFormatFat,
              PsitoDiskFormat.exfat => l.storageFormatExfat,
              PsitoDiskFormat.ext4 => l.storageFormatExt4,
            },
            helperMaxLines: 2,
          ),
          items: [
            for (final type in PsitoDiskFormat.values)
              DropdownMenuItem(
                value: type,
                child: Text(switch (type) {
                  PsitoDiskFormat.vfat => l.storageFormatFatName,
                  PsitoDiskFormat.exfat => l.storageFormatExfatName,
                  PsitoDiskFormat.ext4 => l.storageFormatExt4Name,
                }),
              ),
          ],
          onChanged: _running
              ? null
              : (type) => setState(() => _type = type ?? _type),
        ),
      ),
    ];
  }
}

/// Um campo com o nome em cima, que também é o nome dele para o leitor de tela.
class _Field extends StatelessWidget {
  final String title;
  final Widget child;

  const _Field({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Semantics(
      label: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Text(title, style: const TextStyle(fontSize: 13)),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    ),
  );
}
