import 'dart:async';
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart' as ai;
import 'package:genui/genui.dart';

import '../../core/app_state.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import 'loan_catalog.dart';

// ─── Slide 8: "Under the hood: wiring GenUI to Gemini" ──────────────────────

/// Owns the GenUI pipeline for the Kobo Lend demo:
/// Gemini (or the offline script) → A2UI JSON → SurfaceController → Surface.
class LoanAgent {
  LoanAgent() {
    // 02  The adapter turns streamed A2UI JSON into surfaces.
    transport = A2uiTransportAdapter(onSend: _onSend);
    // 03  Conversation loops user input (and UI events) back to the agent.
    conversation = Conversation(controller: controller, transport: transport);
  }

  final controller = SurfaceController(catalogs: [catalog]);
  late final A2uiTransportAdapter transport;
  late final Conversation conversation;

  /// 01  PromptBuilder turns your catalog into the system prompt.
  ///     (`custom` instead of `chat` so the agent may also seed the data
  ///     model, e.g. the initial tenure for the Slider.)
  static final prompt = PromptBuilder.custom(
    catalog: catalog,
    allowedOperations: SurfaceOperations.createOnly(dataModel: true),
    systemPromptFragments: [
      'You are Kobo, the friendly lending assistant inside the Kobo Lend app '
          'for small business owners in Nigeria. Amounts are in Naira (₦).',
      'Offer loans as LoanOfferCard + Slider. When the user asks for a loan, '
          'reply with ONE short sentence, then create a surface whose root is '
          'a Column containing, in order: a LoanOfferCard (monthlyRate 0.04, '
          'tenurePath "/loan/months", a short purpose), a Slider labelled '
          '"Tenure (months)" with min 1, max 12 and value bound to '
          '{"path": "/loan/months"}, and a Button (variant "primary") with '
          'a Text child "Accept offer", whose '
          'action is {"event": {"name": "accept_offer", "context": '
          '{"months": {"path": "/loan/months"}, "amount": <amount>}}}.',
      'Seed the tenure with updateDataModel on path "/loan/months" using the '
          'number of months the user asked for (default 3).',
      'When you receive an accept_offer action, confirm in one or two '
          'sentences using the months and amount from its context. Do not '
          'create another surface for the confirmation.',
    ],
  );

  ai.ChatSession? _chat;

  ai.ChatSession get _liveChat => _chat ??= ai.FirebaseAI.googleAI()
      .generativeModel(
        model: kGeminiModel,
        systemInstruction: ai.Content.system(prompt.systemPromptJoined()),
      )
      .startChat();

  Future<void> send(String userText) =>
      conversation.sendRequest(ChatMessage.user(userText));

  Future<void> _onSend(ChatMessage message) async {
    final text = _describe(message);
    if (AppState.isLive) {
      final reply = _liveChat.sendMessageStream(ai.Content.text(text));
      await for (final chunk in reply) {
        transport.addChunk(chunk.text ?? ''); // A2UI JSON → widgets
      }
    } else {
      await for (final chunk in _DemoScript.reply(message, catalog)) {
        transport.addChunk(chunk);
      }
    }
  }

  /// User text, plus any UI interactions (button taps carry the Slider value).
  static String _describe(ChatMessage message) {
    final interactions = message.parts.uiInteractionParts
        .map((p) => p.interaction)
        .toList();
    return [
      if (message.text.isNotEmpty) message.text,
      for (final i in interactions) 'User interaction: $i',
    ].join('\n');
  }

  void dispose() {
    conversation.dispose();
    transport.dispose();
    controller.dispose();
  }
}

/// Offline stand-in for Gemini. It streams the same kind of A2UI JSON a real
/// model would, so the GenUI pipeline you see on stage is the real one.
abstract final class _DemoScript {
  static int _surfaceCount = 0;

  static Stream<String> reply(ChatMessage message, Catalog catalog) async* {
    await Future<void>.delayed(const Duration(milliseconds: 600));

    final interaction = message.parts.uiInteractionParts.firstOrNull;
    if (interaction != null) {
      final action = (jsonDecode(interaction.interaction) as Map)['action'];
      final ctx = (action is Map ? action['context'] : null) as Map? ?? {};
      final months = (ctx['months'] as num?)?.round() ?? 3;
      final amount = (ctx['amount'] as num?) ?? 200000;
      yield* _typed(
        'Done! Your ${formatNaira(amount)} loan over $months months has been '
        'submitted. You will get a decision in under 5 minutes.',
      );
      return;
    }

    final request = _parse(message.text);
    if (request == null) {
      yield* _typed(
        'I can help you get working capital. Tell me how much you need and '
        'for how long, e.g. "I need ₦200k for 3 months to restock my shop".',
      );
      return;
    }

    final id = 'offer-${++_surfaceCount}';
    yield* _typed(
      'Here is an offer for ${formatNaira(request.amount)}. '
      'Drag the slider to change the tenure.',
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    for (final msg in [
      {
        'version': 'v0.9',
        'createSurface': {
          'surfaceId': id,
          'catalogId': catalog.catalogId,
          'sendDataModel': true,
        },
      },
      {
        'version': 'v0.9',
        'updateDataModel': {
          'surfaceId': id,
          'path': '/loan/months',
          'value': request.months,
        },
      },
      {
        'version': 'v0.9',
        'updateComponents': {
          'surfaceId': id,
          'components': [
            {
              'id': 'root',
              'component': 'Column',
              'children': ['offer', 'tenure', 'accept'],
            },
            {
              'id': 'offer',
              'component': 'LoanOfferCard',
              'amount': request.amount,
              'monthlyRate': 0.04,
              'tenurePath': '/loan/months',
              'purpose': request.purpose,
            },
            {
              'id': 'tenure',
              'component': 'Slider',
              'label': 'Tenure (months)',
              'min': 1,
              'max': 12,
              'value': {'path': '/loan/months'},
            },
            {
              'id': 'accept',
              'component': 'Button',
              'variant': 'primary',
              'child': 'acceptText',
              'action': {
                'event': {
                  'name': 'accept_offer',
                  'context': {
                    'months': {'path': '/loan/months'},
                    'amount': request.amount,
                  },
                },
              },
            },
            {'id': 'acceptText', 'component': 'Text', 'text': 'Accept offer'},
          ],
        },
      },
    ]) {
      yield '\n```json\n${jsonEncode(msg)}\n```\n';
    }
  }

  /// Streams text word by word, like a model would.
  static Stream<String> _typed(String text) async* {
    final words = text.split(' ');
    for (var i = 0; i < words.length; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 35));
      yield i == 0 ? words[i] : ' ${words[i]}';
    }
  }

  static ({num amount, int months, String purpose})? _parse(String text) {
    final lower = text.toLowerCase().replaceAll(',', '');
    final amountMatch = RegExp(
      r'(?:₦|n|ngn)?\s*(\d+(?:\.\d+)?)\s*(k|m|million|thousand)?\b',
    ).allMatches(lower).where((m) {
      // Ignore the "3" in "3 months".
      final after = lower.substring(m.end).trimLeft();
      return !after.startsWith('month') && !after.startsWith('mo ');
    }).firstOrNull;
    if (amountMatch == null) return null;
    var amount = num.parse(amountMatch.group(1)!);
    switch (amountMatch.group(2)) {
      case 'k' || 'thousand':
        amount *= 1000;
      case 'm' || 'million':
        amount *= 1000000;
    }
    if (amount < 1000) return null;
    final months =
        int.tryParse(
          RegExp(r'(\d+)\s*(?:months?|mo)\b').firstMatch(lower)?.group(1) ??
              '',
        ) ??
        3;
    final purpose = lower.contains('restock') || lower.contains('stock')
        ? 'Shop restock'
        : lower.contains('equipment')
        ? 'Equipment'
        : 'Business loan offer';
    return (amount: amount, months: months.clamp(1, 12), purpose: purpose);
  }
}
