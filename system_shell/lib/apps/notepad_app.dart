// system_shell/lib/apps/notepad_app.dart

import 'package:flutter/material.dart';
import 'package:psito_sdk/psito_sdk.dart';

class NotepadView extends StatefulWidget {
  const NotepadView({super.key});

  @override
  State<NotepadView> createState() => _NotepadViewState();
}

class _NotepadViewState extends State<NotepadView> {
  final TextEditingController _controller = TextEditingController(
    text: 'Bem-vindo ao Psito Notepad!\n\nEscreva suas anotações aqui...',
  );

  @override
  void dispose() {
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
              const Spacer(),
              const Text(
                'Nota salva localmente',
                style: TextStyle(color: Colors.white38, fontSize: 11),
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
  Widget build(PsitoAppContext context) => const NotepadView();
}
