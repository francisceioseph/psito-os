// packages/psito_files_ui/lib/src/rename_field.dart
//
// O campo de renomear no próprio item: começa com o nome sem a extensão
// selecionado, o Enter ou perder o foco confirmam, e o Esc cancela.
import 'package:psito_sdk/psito_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:psito_fs/psito_fs.dart';

class RenameField extends StatefulWidget {
  final String name;
  final bool isDirectory;
  final TextAlign textAlign;

  /// O nome novo, já sem os espaços das pontas e diferente do atual.
  final ValueChanged<String> onSubmit;

  /// O Esc, ou o nome que ficou vazio ou igual.
  final VoidCallback onCancel;

  const RenameField({
    super.key,
    required this.name,
    this.isDirectory = false,
    this.textAlign = TextAlign.start,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  State<RenameField> createState() => _RenameFieldState();
}

class _RenameFieldState extends State<RenameField> {
  late final _controller = TextEditingController(text: widget.name);
  final _focus = FocusNode();
  bool _done = false;

  @override
  void initState() {
    super.initState();
    final (stem, _) = splitExtension(
      widget.name,
      isDirectory: widget.isDirectory,
    );
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: stem.length,
    );
    _focus.addListener(() {
      if (!_focus.hasFocus) _submit();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _submit() {
    if (_done) return;
    _done = true;
    final name = _controller.text.trim();
    if (name.isEmpty || name == widget.name) {
      widget.onCancel();
    } else {
      widget.onSubmit(name);
    }
  }

  void _cancel() {
    _done = true;
    widget.onCancel();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {const SingleActivator(LogicalKeyboardKey.escape): _cancel},
    child: TextField(
      controller: _controller,
      focusNode: _focus,
      textAlign: widget.textAlign,
      selectAllOnFocus: false,
      autocorrect: false,
      enableSuggestions: false,
      style: TextStyle(fontSize: 12, color: context.palette.text),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        filled: true,
        fillColor: context.palette.shadow.withValues(alpha: 0.6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
        ),
      ),
      onSubmitted: (_) => _submit(),
    ),
  );
}
