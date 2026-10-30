// system_shell/lib/apps/buddy_app.dart
import 'package:flutter/material.dart';
import 'package:psito_sdk/psito_sdk.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class BuddyView extends StatefulWidget {
  const BuddyView({super.key});

  @override
  State<BuddyView> createState() => _BuddyViewState();
}

class _BuddyViewState extends State<BuddyView> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<ChatMessage> _messages = [
    ChatMessage(
      text: 'Olá, Francisco! Sou o Psito Buddy, seu assistente pessoal neste sistema operacional penoso. Como posso ajudar nas tarefas ou códigos hoje?',
      isUser: false,
      timestamp: DateTime.now(),
    ),
  ];

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) return;

    _textController.clear();
    setState(() {
      _messages.add(
        ChatMessage(text: text, isUser: true, timestamp: DateTime.now()),
      );
    });

    _scrollToBottom();

    // Resposta simulada inteligente do Psito Buddy
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;

      String botResponse = _generateBuddyResponse(text);

      setState(() {
        _messages.add(
          ChatMessage(
            text: botResponse,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
      _scrollToBottom();
    });
  }

  String _generateBuddyResponse(String query) {
    final lower = query.toLowerCase();
    if (lower.contains('olá') ||
        lower.contains('oi') ||
        lower.contains('e aí')) {
      return 'Fiiu! Tudo ótimo por aqui na VM Debian. E com você? Pronto para programar mais em Flutter?';
    } else if (lower.contains('código') ||
        lower.contains('flutter') ||
        lower.contains('dart')) {
      return 'Código limpo e multitarefa rodando liso! Se precisar ajustar alguma janela ou app no Psito OS, é só mandar.';
    } else if (lower.contains('piada') || lower.contains('engraçado')) {
      return 'Sabe qual é o pássaro que voa de noite? O calops-noite! (Ok, essa foi fraca, mas dou o meu melhor piado.)';
    } else if (lower.contains('sistema') || lower.contains('status')) {
      return 'Sistema estável! `flutter-pi` rodando no DRM/KMS, sem perdas de pacotes e com as pálpebras abertas!';
    }
    return 'Fiiu-fiil! Entendi perfeitamente. Como um bom assistente penoso, estou anotando isso no meu bico!';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Lista de mensagens do chat
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(12),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              return Align(
                alignment: message.isUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  constraints: const BoxConstraints(maxWidth: 320),
                  decoration: BoxDecoration(
                    color: message.isUser
                        ? const Color(0xFFFFC107).withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: message.isUser
                          ? const Color(0xFFFFC107)
                          : Colors.white12,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!message.isUser) ...[
                        const Icon(
                          Icons.flutter_dash,
                          size: 16,
                          color: Color(0xFFFFC107),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          message.text,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Barra de input de texto
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.black.withValues(alpha: 0.3),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  onSubmitted: _handleSubmitted,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Converse com o Psito Buddy...',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.send_rounded,
                  size: 18,
                  color: Color(0xFFFFC107),
                ),
                onPressed: () => _handleSubmitted(_textController.text),
                splashRadius: 16,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class BuddyApp extends PsitoApp {
  const BuddyApp();

  @override
  String get id => 'buddy';

  @override
  String get name => 'Psito Buddy';

  @override
  IconData get icon => Icons.smart_toy_rounded;

  @override
  Color get color => const Color(0xFFFF5722);

  @override
  Widget build(PsitoAppContext context) => const BuddyView();
}
