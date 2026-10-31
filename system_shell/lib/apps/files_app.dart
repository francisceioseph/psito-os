// system_shell/lib/apps/files_app.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:psito_sdk/psito_sdk.dart';

class FilesView extends StatefulWidget {
  const FilesView({super.key});

  @override
  State<FilesView> createState() => _FilesViewState();
}

class _FilesViewState extends State<FilesView> {
  String _currentPath = '/opt/psito'; // Começa na pasta do Psito na VM
  List<FileSystemEntity> _contents = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDirectory(_currentPath);
  }

  Future<void> _loadDirectory(String path) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dir = Directory(path);
      if (await dir.exists()) {
        final list = dir.listSync();
        setState(() {
          _currentPath = path;
          _contents = list;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Diretório não encontrado: $path';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro de permissão ou acesso: $e';
        _isLoading = false;
      });
    }
  }

  void _navigateToParent() {
    final parentPath = Directory(_currentPath).parent.path;
    _loadDirectory(parentPath);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barra de Caminho / Navegação
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.black.withValues(alpha: 0.3),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                onPressed: _navigateToParent,
                color: Colors.white70,
                tooltip: 'Pasta Superior',
                splashRadius: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    _currentPath,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFFFC107),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                onPressed: () => _loadDirectory(_currentPath),
                color: Colors.white70,
                tooltip: 'Atualizar',
                splashRadius: 16,
              ),
            ],
          ),
        ),

        // Conteúdo da Pasta (Lista de arquivos reais do Debian)
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFFC107)),
                )
              : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _contents.isEmpty
              ? const Center(
                  child: Text(
                    'Esta pasta está vazia.',
                    style: TextStyle(color: Colors.white38),
                  ),
                )
              : ListView.builder(
                  itemCount: _contents.length,
                  itemBuilder: (context, index) {
                    final entity = _contents[index];
                    final isDirectory = entity is Directory;
                    final name = entity.path.split(Platform.pathSeparator).last;

                    return ListTile(
                      leading: Icon(
                        isDirectory
                            ? Icons.folder_rounded
                            : Icons.insert_drive_file_rounded,
                        color: isDirectory
                            ? const Color(0xFFFFC107)
                            : Colors.white60,
                        size: 20,
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                      dense: true,
                      onTap: () {
                        if (isDirectory) {
                          _loadDirectory(entity.path);
                        } else {
                          debugPrint('🦜 Arquivo selecionado: ${entity.path}');
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class FilesApp extends PsitoApp {
  const FilesApp();

  @override
  String get id => 'files';

  @override
  String get name => 'Files';

  @override
  IconData get icon => Icons.folder_open_rounded;

  @override
  Color get color => const Color(0xFFFFC107);

  @override
  Widget build(PsitoAppContext context) => const FilesView();
}
