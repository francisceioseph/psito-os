// apps/notepad/lib/notepad_app.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:psito_runtime/psito_runtime.dart';
import 'package:psito_sdk/psito_sdk.dart';

import 'l10n/notepad_localizations.dart';

/// O arquivo da nota: `~/nota.txt`, que no sandbox é o `$HOME` privado do
/// app (`~/.local/share/psito/apps/org.psito.notepad/` de verdade). Fora do
/// sandbox (o laboratório e os testes) a nota fica só na memória.
File? noteFile(Map<String, String> env) {
  final home = env['HOME'];
  if (env['PSITO_APP_ID'] == null || home == null) return null;
  return File('$home/nota.txt');
}

class NotepadView extends StatefulWidget {
  /// Onde a nota é gravada. Null: só na memória.
  final File? file;

  /// Como o arquivo aparece no "Salvo em".
  final String label;

  const NotepadView({super.key, this.file, this.label = '~/nota.txt'});

  @override
  State<NotepadView> createState() => _NotepadViewState();
}

class _NotepadViewState extends State<NotepadView> {
  final _controller = TextEditingController();

  /// Grava um tempo depois da última edição.
  static const _saveDelay = Duration(seconds: 1);
  Timer? _saveTimer;
  String _saved = '';
  bool _welcomed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final file = widget.file;
    if (file == null) return;
    unawaited(_load(file));
    _controller.addListener(_edited);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_welcomed) return;
    _welcomed = true;
    _saved = NotepadLocalizations.of(context).welcome;
    _controller.text = _saved;
  }

  Future<void> _load(File file) async {
    try {
      if (!await file.exists()) return;
      final text = await file.readAsString();
      if (!mounted) return;
      _saved = text;
      _controller.text = text;
    } on FileSystemException catch (e) {
      debugPrint('🦜 notepad: não li ${file.path} ($e)');
    }
  }

  void _edited() {
    if (_controller.text == _saved) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, () => unawaited(_save()));
    if (!_saving) setState(() => _saving = true);
  }

  Future<void> _save() async {
    final text = _controller.text;
    try {
      await widget.file!.writeAsString(text, flush: true);
      _saved = text;
    } on FileSystemException catch (e) {
      debugPrint('🦜 notepad: não gravei ($e)');
    }
    if (mounted) setState(() => _saving = _controller.text != _saved);
  }

  String get _status {
    final l = NotepadLocalizations.of(context);
    if (widget.file == null) return l.statusSessionOnly;
    return _saving ? l.statusSaving : l.statusSaved(widget.label);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    // O que faltou gravar vai antes de fechar
    if (widget.file != null && _controller.text != _saved) {
      try {
        widget.file!.writeAsStringSync(_controller.text, flush: true);
      } on FileSystemException catch (e) {
        debugPrint('🦜 notepad: não gravei ao fechar ($e)');
      }
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barra de ferramentas
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: context.palette.shadow.withValues(alpha: 0.2),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  _controller.clear();
                },
                icon: Icon(
                  Icons.cleaning_services_rounded,
                  size: 16,
                  color: context.palette.success,
                ),
                label: Text(
                  NotepadLocalizations.of(context).clear,
                  style: TextStyle(
                    color: context.palette.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Some com reticências em janelas estreitas
              Expanded(
                child: Text(
                  _status,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.palette.textDisabled,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Campo de texto blindado contra repetições fantasmas de keycodes
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              // Desativa correções automáticas agressivas do Flutter que confundem o QEMU
              enableSuggestions: false,
              autocorrect: false,
              style: TextStyle(color: context.palette.text, fontSize: 14),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: NotepadLocalizations.of(context).hint,
                hintStyle: TextStyle(color: context.palette.line),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Soltar um arquivo na janela abre ele numa janela nova, e a nota daqui fica
/// como está. Quem abre é o shell, porque o sandbox não vê o arquivo.
class NotepadDropZone extends StatefulWidget {
  final Future<bool> Function(List<String> paths) accepts;
  final Future<bool> Function(List<String> paths) open;
  final Widget child;

  const NotepadDropZone({
    super.key,
    required this.accepts,
    required this.open,
    required this.child,
  });

  @override
  State<NotepadDropZone> createState() => _NotepadDropZoneState();
}

class _NotepadDropZoneState extends State<NotepadDropZone> {
  String? _asked;
  bool _accepted = false;
  bool _asking = false;

  /// O soltar pergunta sem esperar, e a resposta vale para o próximo movimento
  /// do ponteiro: até lá, recusa.
  DropAction? _willAccept(List<String> paths) {
    final key = paths.join('\n');
    if (key != _asked) _accepted = false;
    if (key != _asked || !_asking) {
      _asked = key;
      _asking = true;
      unawaited(
        widget.accepts(paths).then((accepted) {
          if (key != _asked) return;
          _accepted = accepted;
          _asking = false;
        }),
      );
    }
    return _accepted ? DropAction.copy : null;
  }

  @override
  Widget build(BuildContext context) {
    return PsitoDropTarget(
      onWillAccept: _willAccept,
      onAccept: (paths, _, _) => widget.open(paths),
      builder: (context, hovering) => Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (hovering)
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: context.palette.success, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class NotepadApp extends PsitoApp {
  const NotepadApp();

  @override
  String get id => 'notepad';

  @override
  String get name => 'Notepad';

  @override
  String localizedName(Locale locale) =>
      lookupNotepadLocalizations(locale).appName;

  @override
  List<LocalizationsDelegate<dynamic>> get localizationsDelegates => const [
    NotepadLocalizations.delegate,
  ];

  @override
  IconData get icon => Icons.edit_note_rounded;

  @override
  Color get color => const Color(0xFF4CAF50);

  /// Aberto com um arquivo (o "Abrir" do Files), edita ele; senão, a nota.
  @override
  Widget build(PsitoAppContext context) {
    final opened = context.openedPaths;
    final name = opened.isEmpty
        ? null
        : opened.first.substring(opened.first.lastIndexOf('/') + 1);
    return NotepadDropZone(
      accepts: context.acceptsDrop,
      open: context.openDropped,
      child: name == null
          ? NotepadView(file: noteFile(Platform.environment))
          : NotepadView(file: File(opened.first), label: name),
    );
  }

  @override
  void onOpen(PsitoAppContext context) {
    final opened = context.openedPaths;
    if (opened.isEmpty) return;
    context.setTitle(opened.first.substring(opened.first.lastIndexOf('/') + 1));
  }
}
