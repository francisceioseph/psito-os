// apps/notepad/lib/notepad_app.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:psito_sdk/psito_sdk.dart';

/// O arquivo da nota: `~/nota.txt`, que no sandbox é o `$HOME` privado do
/// app (`~/.local/share/psito/apps/org.psito.notepad/` de verdade). Fora do
/// sandbox (o laboratório e os testes) a nota fica só na memória.
File? noteFile(Map<String, String> env) {
  final home = env['HOME'];
  if (env['PSITO_APP_ID'] == null || home == null) return null;
  return File('$home/nota.txt');
}

const _welcome =
    'Bem-vindo ao Psito Notepad!\n\nEscreva suas anotações aqui...';

class NotepadView extends StatefulWidget {
  /// Onde a nota é gravada. Null: só na memória.
  final File? file;

  const NotepadView({super.key, this.file});

  @override
  State<NotepadView> createState() => _NotepadViewState();
}

class _NotepadViewState extends State<NotepadView> {
  final TextEditingController _controller = TextEditingController(
    text: _welcome,
  );

  /// Grava um tempo depois da última edição.
  static const _saveDelay = Duration(seconds: 1);
  Timer? _saveTimer;
  String _saved = _welcome;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final file = widget.file;
    if (file == null) return;
    unawaited(_load(file));
    _controller.addListener(_edited);
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
    if (widget.file == null) return 'Nota só nesta sessão';
    return _saving ? 'Salvando...' : 'Salvo em ~/nota.txt';
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
          color: Colors.black.withValues(alpha: 0.2),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  _controller.clear();
                },
                icon: const Icon(
                  Icons.cleaning_services_rounded,
                  size: 16,
                  color: Color(0xFF4CAF50),
                ),
                label: const Text(
                  'Limpar',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
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
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
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
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Digite algo...',
                hintStyle: TextStyle(color: Colors.white24),
              ),
            ),
          ),
        ),
      ],
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
  IconData get icon => Icons.edit_note_rounded;

  @override
  Color get color => const Color(0xFF4CAF50);

  @override
  Widget build(PsitoAppContext context) =>
      NotepadView(file: noteFile(Platform.environment));
}
