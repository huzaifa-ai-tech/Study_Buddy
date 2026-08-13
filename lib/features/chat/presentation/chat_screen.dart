import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/study_material.dart';
import '../../../data/services/ai_service.dart';
import '../../settings/state/settings_bloc.dart';

/// Ask the AI questions about a study material.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.material});

  final StudyMaterial material;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<({String role, String text})> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  bool _sending = false;

  Future<void> _send() async {
    final question = _inputController.text.trim();
    if (question.isEmpty || _sending) return;
    setState(() {
      _messages.add((role: 'user', text: question));
      _sending = true;
    });
    _inputController.clear();
    try {
      final settings = context.read<SettingsBloc>().state.settings;
      final service = OpenAiService(settings);
      final answer = await service.chatWithNotes(
        widget.material.title,
        widget.material.content,
        _messages.toList(),
        question,
      );
      if (!mounted) return;
      setState(() {
        _messages.add((role: 'assistant', text: answer));
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask AI', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          if (!context.read<SettingsBloc>().state.settings.isConfigured)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Add your AI API key in Settings to chat with your notes.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                  fontSize: 13,
                ),
              ),
            ),
          Expanded(
            child: _messages.isEmpty
                ? _EmptyChat(materialTitle: widget.material.title)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_sending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return const _TypingBubble();
                      }
                      final message = _messages[index];
                      return _MessageBubble(
                        isUser: message.role == 'user',
                        text: message.text,
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Ask about your notes...',
                        prefixIcon: Icon(Icons.help_outline_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_rounded),
                    tooltip: 'Send',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.isUser, required this.text});

  final bool isUser;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          gradient: isUser ? AppTheme.brandGradient : null,
          color: isUser ? null : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
        ),
        child: SelectableText(
          text,
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            color: isUser ? Colors.white : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Thinking...',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.materialTitle});

  final String materialTitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy_rounded,
                size: 52, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              'Chat with "$materialTitle"',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask anything about this material and the AI answers '
              'using your notes.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
