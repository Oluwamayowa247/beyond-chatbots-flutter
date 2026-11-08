import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import 'wallet_state.dart';

// ─── Slide 12: "Under the hood: tools, not text" ────────────────────────────

/// 01  Declare what your app can do as FunctionDeclarations.
final filterTx = FunctionDeclaration(
  'filterTransactions',
  'Filter the transactions screen',
  parameters: {
    'status': Schema.enumString(enumValues: ['failed', 'success']),
    'days': Schema.integer(description: 'Only show the last N days.'),
  },
  optionalParameters: ['status', 'days'],
);

final navigate = FunctionDeclaration(
  'navigate',
  'Open a tab in the wallet app',
  parameters: {
    'screen': Schema.enumString(
      enumValues: ['home', 'transactions', 'cards', 'profile'],
    ),
  },
);

final setTheme = FunctionDeclaration(
  'setTheme',
  'Switch the app between light and dark mode',
  parameters: {
    'mode': Schema.enumString(enumValues: ['light', 'dark']),
  },
);

final sendMoney = FunctionDeclaration(
  'sendMoney',
  'Start a transfer. The app always asks the user to confirm first.',
  parameters: {
    'recipient': Schema.string(description: 'First name of the recipient.'),
    'amount': Schema.number(description: 'Amount in Naira.'),
  },
);

/// A request the model made. Same shape whether it came from Gemini or the
/// offline script, so both go through the same router.
typedef ActionRequest = ({String name, Map<String, Object?> args, String? id});

/// What the agent did, for the "show what the AI did" + undo UI.
class AgentResult {
  AgentResult({required this.actions, required this.reply});
  final List<String> actions;
  final String reply;
}

class VoiceAgent {
  VoiceAgent({required this.wallet, required this.confirmTransfer});

  final WalletState wallet;

  /// Trust: money never moves without an explicit tap from the user.
  final Future<bool> Function(String recipient, num amount) confirmTransfer;

  ChatSession? _chat;

  ChatSession get _liveChat => _chat ??= FirebaseAI.googleAI()
      .generativeModel(
        model: kGeminiModel,
        systemInstruction: Content.system(
          'You control the Kobo Wallet app by calling functions. '
          'Today is ${isoDate(DateTime.now())}. "Last week" means days: 7. '
          'Prefer calling functions over describing what to do. After the '
          'functions run, reply with one short, friendly sentence.',
        ),
        tools: [
          Tool.functionDeclarations([filterTx, navigate, setTheme, sendMoney]),
        ],
      )
      .startChat();

  Future<AgentResult> handle(String transcript) async {
    if (!AppState.isLive) return _demo(transcript);

    // 02  The model returns functionCalls: requests, not actions.
    final res = await _liveChat.sendMessage(Content.text(transcript));
    final calls = res.functionCalls.toList();
    if (calls.isEmpty) {
      return AgentResult(actions: const [], reply: res.text ?? '');
    }

    // 03  Run them through your own router and state.
    final log = <String>[];
    final responses = <FunctionResponse>[];
    for (final call in calls) {
      final result = await run((
        name: call.name,
        args: call.args,
        id: call.id,
      ), log);
      responses.add(FunctionResponse(call.name, result, id: call.id));
    }
    final follow = await _liveChat.sendMessage(
      Content.functionResponses(responses),
    );
    return AgentResult(actions: log, reply: follow.text ?? '');
  }

  /// The router: your code, your rules. Validate everything.
  Future<Map<String, Object?>> run(
    ActionRequest call,
    List<String> log,
  ) async {
    final args = call.args;
    switch (call.name) {
      case 'filterTransactions':
        final status = switch (args['status']) {
          'failed' => TxStatus.failed,
          'success' => TxStatus.success,
          _ => null,
        };
        final days = (args['days'] as num?)?.toInt();
        if (days != null && (days < 1 || days > 365)) {
          return {'error': 'days must be between 1 and 365'};
        }
        wallet.filter(status: status, days: days);
        log.add(
          'filterTransactions(${[
            if (status != null) 'status: ${status.name}',
            if (days != null) 'days: $days',
          ].join(', ')})',
        );
        return {'shown': wallet.visibleTransactions.length};
      case 'navigate':
        final tab = WalletTab.values.where((t) => t.name == args['screen']);
        if (tab.isEmpty) return {'error': 'unknown screen'};
        wallet.goTo(tab.first);
        log.add('navigate(screen: ${tab.first.name})');
        return {'ok': true};
      case 'setTheme':
        final dark = args['mode'] == 'dark';
        wallet.setBrightness(dark ? Brightness.dark : Brightness.light);
        log.add('setTheme(mode: ${dark ? 'dark' : 'light'})');
        return {'ok': true};
      case 'sendMoney':
        final to = '${args['recipient'] ?? ''}'.trim();
        final amount = args['amount'] as num?;
        if (to.isEmpty || amount == null || amount <= 0) {
          return {'error': 'recipient and a positive amount are required'};
        }
        if (amount > wallet.balance) return {'error': 'insufficient balance'};
        log.add('sendMoney(recipient: $to, amount: $amount)');
        final ok = await confirmTransfer(to, amount);
        if (!ok) return {'status': 'cancelled by user'};
        wallet.addTransfer(to, amount);
        return {'status': 'sent', 'newBalance': wallet.balance};
      default:
        return {'error': 'unknown function ${call.name}'};
    }
  }

  // ── Offline stand-in: turns the transcript into the same function calls ──
  Future<AgentResult> _demo(String transcript) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final calls = demoCallsFor(transcript);
    final log = <String>[];
    final replies = <String>[];
    for (final call in calls) {
      final r = await run(call, log);
      replies.add(switch (call.name) {
        'filterTransactions' =>
          'Showing ${r['shown']} matching transaction${r['shown'] == 1 ? '' : 's'}.',
        'setTheme' => 'Switched to ${call.args['mode']} mode.',
        'navigate' => 'Opened ${call.args['screen']}.',
        'sendMoney' => r['status'] == 'sent'
            ? 'Sent ${formatNaira(call.args['amount']! as num)} to ${call.args['recipient']}.'
            : 'Transfer ${r['status'] ?? r['error']}.',
        _ => '',
      });
    }
    return AgentResult(
      actions: log,
      reply: replies.isEmpty
          ? 'Try “show me my failed transactions from last week”.'
          : replies.join(' '),
    );
  }

  static List<ActionRequest> demoCallsFor(String transcript) {
    final t = transcript.toLowerCase().replaceAll(',', '');
    final calls = <ActionRequest>[];

    final send = RegExp(
      r'send\s+(?:₦|n)?\s*(\d+(?:\.\d+)?)\s*(k)?\s+to\s+([a-z]+)',
    ).firstMatch(t);
    if (send != null) {
      var amount = num.parse(send.group(1)!);
      if (send.group(2) == 'k') amount *= 1000;
      final name = send.group(3)!;
      calls.add((
        name: 'sendMoney',
        args: {
          'recipient': name[0].toUpperCase() + name.substring(1),
          'amount': amount,
        },
        id: null,
      ));
    }

    final status = t.contains('fail')
        ? 'failed'
        : t.contains('success')
        ? 'success'
        : null;
    int? days;
    final n = RegExp(r'(\d+)\s*days?').firstMatch(t);
    if (n != null) {
      days = int.parse(n.group(1)!);
    } else if (RegExp(r'(last|past|this)\s+week').hasMatch(t)) {
      days = 7;
    } else if (RegExp(r'(last|past|this)\s+month').hasMatch(t)) {
      days = 30;
    } else if (t.contains('today')) {
      days = 1;
    }
    if (status != null || days != null) {
      calls.add((
        name: 'filterTransactions',
        args: {'status': ?status, 'days': ?days},
        id: null,
      ));
    } else {
      for (final screen in ['transactions', 'cards', 'profile', 'home']) {
        if (t.contains(screen.substring(0, screen.length - 1))) {
          calls.add((name: 'navigate', args: {'screen': screen}, id: null));
          break;
        }
      }
    }

    if (t.contains('dark')) {
      calls.add((name: 'setTheme', args: {'mode': 'dark'}, id: null));
    } else if (t.contains('light')) {
      calls.add((name: 'setTheme', args: {'mode': 'light'}, id: null));
    }
    return calls;
  }
}
