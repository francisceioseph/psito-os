// system_shell/lib/apps/browser_app.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class BrowserApp extends StatefulWidget {
  const BrowserApp({super.key});

  @override
  State<BrowserApp> createState() => _BrowserAppState();
}

class _BrowserAppState extends State<BrowserApp> {
  final TextEditingController _urlController = TextEditingController(
    text: 'https://example.com',
  );
  String _currentUrl = 'https://example.com';
  String _pageContent = 'Digite uma URL e clique em carregar para buscar o conteúdo.';
  bool _isLoading = false;
  int _statusCode = 0;

  Future<void> _fetchPage(String url) async {
    String formattedUrl = url.trim();
    if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
      formattedUrl = 'https://$formattedUrl';
    }

    setState(() {
      _isLoading = true;
      _currentUrl = formattedUrl;
      _urlController.text = formattedUrl;
      _pageContent = 'Conectando a $_currentUrl...';
    });

    try {
      final response = await http.get(Uri.parse(formattedUrl)).timeout(
        const Duration(seconds: 10),
      );

      if (mounted) {
        setState(() {
          _statusCode = response.statusCode;
          // Mostra o corpo da resposta (HTML bruto ou texto limpo)
          _pageContent = response.body.isNotEmpty 
              ? response.body 
              : '[Página vazia ou sem conteúdo textual]';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusCode = 500;
          _pageContent = 'Erro ao carregar a página:\n$e\n\n(Verifique se a VM possui acesso à internet ou se o site bloqueia requisições diretas via HTTP).';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchPage(_currentUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barra de Ferramentas / Endereço do Browser
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          color: Colors.black.withValues(alpha: 0.3),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 16),
                onPressed: () => _fetchPage(_currentUrl),
                color: Colors.white70,
                tooltip: 'Recarregar',
                splashRadius: 14,
              ),
              const SizedBox(width: 4),
              // Campo de URL
              Expanded(
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _statusCode == 200 ? Icons.lock_rounded : Icons.warning_rounded,
                        size: 12,
                        color: _statusCode == 200 ? const Color(0xFF4CAF50) : Colors.orangeAccent,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          onSubmitted: _fetchPage,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                onPressed: () => _fetchPage(_urlController.text),
                color: Color(0xFFFFC107),
                tooltip: 'Ir',
                splashRadius: 14,
              ),
            ],
          ),
        ),

        // Área de Exibição do Conteúdo Real da Web
        Expanded(
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: const Color(0xFF12181B),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _pageContent,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontFamily: 'monospace', // Ideal para ver código HTML/texto estruturado
                    ),
                  ),
                ),
              ),
              if (_isLoading)
                const LinearProgressIndicator(
                  color: Color(0xFFFFC107),
                  backgroundColor: Colors.transparent,
                  minHeight: 2,
                ),
            ],
          ),
        ),
      ],
    );
  }
}