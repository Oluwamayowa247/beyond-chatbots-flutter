import 'dart:async';

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';

import '../../core/theme.dart';
import '../../widgets/pattern_stage.dart';
import '../../widgets/phone_frame.dart';
import 'loan_agent.dart';

class GenUiPatternPage extends StatelessWidget {
  const GenUiPatternPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PatternStage(
      label: 'PATTERN 01 · GENERATIVE UI',
      title: 'Answer with widgets,\nnot paragraphs',
      user: '“I need ₦200k for 3 months to restock my shop”',
      app: 'Renders my own LoanOfferCard plus genui’s built-in Slider, picked '
          'from my widget catalog. Drag the slider, the repayment updates, and '
          'the change flows back to the agent.',
      tryThis: const [
        'I need ₦200k for 3 months to restock my shop',
        'Can I get 1.5m for equipment over 9 months?',
      ],
      phone: PhoneFrame(
        theme: buildPhoneTheme(Brightness.light),
        child: const KoboLendScreen(),
      ),
    );
  }
}

sealed class _Entry {}

class _UserEntry extends _Entry {
  _UserEntry(this.text);
  final String text;
}

class _AiTextEntry extends _Entry {
  _AiTextEntry(this.text);
  String text;
}

class _SurfaceEntry extends _Entry {
  _SurfaceEntry(this.surfaceId);
  final String surfaceId;
}

class _ErrorEntry extends _Entry {
  _ErrorEntry(this.text);
  final String text;
}

class KoboLendScreen extends StatefulWidget {
  const KoboLendScreen({super.key});

  @override
  State<KoboLendScreen> createState() => _KoboLendScreenState();
}

class _KoboLendScreenState extends State<KoboLendScreen> {
  final _agent = LoanAgent();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _entries = <_Entry>[];
  late final StreamSubscription<ConversationEvent> _sub;

  /// The AI bubble currently being streamed into, if any.
  _AiTextEntry? _streaming;

  @override
  void initState() {
    super.initState();
    _sub = _agent.conversation.events.listen(_onEvent);
  }

  void _onEvent(ConversationEvent event) {
    setState(() {
      switch (event) {
        case ConversationContentReceived(:final text):
          final current = _streaming;
          if (current == null) {
            if (text.trim().isEmpty) return;
            _streaming = _AiTextEntry(text.trimLeft());
            _entries.add(_streaming!);
          } else {
            current.text += text;
          }
        case ConversationSurfaceAdded(:final surfaceId):
          _streaming = null;
          _entries.add(_SurfaceEntry(surfaceId));
        case ConversationSurfaceRemoved(:final surfaceId):
          _entries.removeWhere(
            (e) => e is _SurfaceEntry && e.surfaceId == surfaceId,
          );
        case ConversationError(:final error):
          _streaming = null;
          _entries.add(_ErrorEntry('$error'));
        case ConversationWaiting():
          _streaming = null;
        case ConversationComponentsUpdated():
          break;
      }
    });
    _scrollToEnd();
  }

  void _send([String? preset]) {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty) return;
    _input.clear();
    setState(() {
      _streaming = null;
      _entries.add(_UserEntry(text));
    });
    _scrollToEnd();
    _agent.send(text);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 400,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    _agent.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(
        children: [
          const _AppHeader(),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: _agent.conversation.state,
              builder: (context, state, _) {
                if (_entries.isEmpty) {
                  return _EmptyState(onPick: _send);
                }
                return ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    for (final e in _entries) _buildEntry(e, scheme),
                    if (state.isWaiting && _streaming == null)
                      const _TypingBubble(),
                  ],
                );
              },
            ),
          ),
          _Composer(controller: _input, onSend: _send),
        ],
      ),
    );
  }

  Widget _buildEntry(_Entry e, ColorScheme scheme) {
    return switch (e) {
      _UserEntry(:final text) => Align(
        alignment: Alignment.centerRight,
        child: _Bubble(text: text, color: scheme.primary, fg: Colors.white),
      ),
      _AiTextEntry(:final text) => Align(
        alignment: Alignment.centerLeft,
        child: _Bubble(
          text: text.trim(),
          color: scheme.surfaceContainerHighest,
          fg: scheme.onSurface,
        ),
      ),
      _SurfaceEntry(:final surfaceId) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant),
          ),
          // Render what the agent created.
          child: Surface(
            surfaceContext: _agent.controller.contextFor(surfaceId),
          ),
        ),
      ),
      _ErrorEntry(:final text) => _Bubble(
        text: 'Error: $text',
        color: scheme.errorContainer,
        fg: scheme.onErrorContainer,
      ),
    };
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Brand.blue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'K',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Kobo Lend', style: TextStyle(fontWeight: FontWeight.w700)),
              Text(
                'AI assistant',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onPick});

  final void Function(String) onPick;

  @override
  Widget build(BuildContext context) {
    const prompt = 'I need ₦200k for 3 months to restock my shop';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              color: Theme.of(context).colorScheme.primary,
              size: 32,
            ),
            const SizedBox(height: 12),
            const Text(
              'Ask for working capital and Kobo answers with a live offer.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
              onPressed: () => onPick(prompt),
              child: const Text(prompt, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 18),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Ask Kobo anything…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: onSend,
            icon: const Icon(Icons.send_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.color, required this.fg});

  final String text;
  final Color color;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: const BoxConstraints(maxWidth: 290),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(text, style: TextStyle(color: fg, height: 1.35)),
    );
  }
}

/// Latency: never leave a frozen screen.
class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: SizedBox(
          width: 36,
          child: LinearProgressIndicator(
            minHeight: 4,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}
