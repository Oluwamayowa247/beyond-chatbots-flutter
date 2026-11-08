import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/pattern_stage.dart';
import '../../widgets/phone_frame.dart';
import 'voice_actions.dart';
import 'wallet_state.dart';

class FunctionCallingPatternPage extends StatefulWidget {
  const FunctionCallingPatternPage({super.key});

  @override
  State<FunctionCallingPatternPage> createState() =>
      _FunctionCallingPatternPageState();
}

class _FunctionCallingPatternPageState
    extends State<FunctionCallingPatternPage> {
  final _wallet = WalletState();

  @override
  void dispose() {
    _wallet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PatternStage(
      label: 'PATTERN 03 · FUNCTION CALLING',
      title: 'Let the AI drive your app,\nnot just talk about it',
      user: '“Show me my failed transactions from last week… '
          'and switch to dark mode”',
      app: 'The model calls my functions, filterTransactions() and setTheme(), '
          'and the app navigates, filters and re-themes itself, through code '
          'I control.',
      tryThis: const [
        'Show me my failed transactions from last week and switch to dark mode',
        'Open my cards',
        'Send 5k to Tunde',
      ],
      phone: ListenableBuilder(
        listenable: _wallet,
        builder: (context, _) => PhoneFrame(
          theme: buildPhoneTheme(_wallet.brightness),
          child: WalletScreen(wallet: _wallet),
        ),
      ),
    );
  }
}

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key, required this.wallet});

  final WalletState wallet;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late final _agent = VoiceAgent(
    wallet: widget.wallet,
    confirmTransfer: _confirmTransfer,
  );

  Future<bool> _confirmTransfer(String to, num amount) async {
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: false, // keep it inside the phone frame
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.shield_outlined),
        title: const Text('Confirm transfer'),
        content: Text(
          'The assistant wants to send ${formatNaira(amount)} to $to.\n'
          'Money only moves when you confirm.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _openVoice() async {
    final transcript = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _VoiceSheet(),
    );
    if (transcript == null || transcript.trim().isEmpty) return;
    await _runAgent(transcript);
  }

  Future<void> _runAgent(String transcript) async {
    final wallet = widget.wallet;
    final before = wallet.snapshot();
    wallet.setThinking(true);
    try {
      final result = await _agent.handle(transcript);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (result.reply.isNotEmpty) Text(result.reply),
              for (final a in result.actions)
                Text(
                  '→ $a',
                  style: TextStyle(
                    fontFamily: 'RobotoMono',
                    fontFamilyFallback: const ['Inter'],
                    fontSize: 11,
                    color: Theme.of(
                      context,
                    ).colorScheme.onInverseSurface.withValues(alpha: 0.75),
                  ),
                ),
            ],
          ),
          // Undo restores view state only, so never offer it once money moved.
          action:
              result.actions.isEmpty ||
                  result.actions.any((a) => a.startsWith('sendMoney'))
              ? null
              : SnackBarAction(
                  label: 'Undo',
                  onPressed: () => wallet.restore(before),
                ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Assistant error: $e')));
    } finally {
      wallet.setThinking(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = widget.wallet;
    return ListenableBuilder(
      listenable: wallet,
      builder: (context, _) {
        return Scaffold(
          body: Column(
            children: [
              SizedBox(
                height: 3,
                child: wallet.thinking
                    ? const LinearProgressIndicator()
                    : const SizedBox.shrink(),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: switch (wallet.tab) {
                    WalletTab.home => _HomeTab(wallet: wallet),
                    WalletTab.transactions => _TransactionsTab(wallet: wallet),
                    WalletTab.cards => const _CardsTab(),
                    WalletTab.profile => const _ProfileTab(),
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: wallet.thinking ? null : _openVoice,
            shape: const CircleBorder(),
            child: const Icon(Icons.mic),
          ),
          bottomNavigationBar: NavigationBar(
            height: 64,
            selectedIndex: wallet.tab.index,
            onDestinationSelected: (i) => wallet.goTo(WalletTab.values[i]),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Transactions'),
              NavigationDestination(icon: Icon(Icons.credit_card), label: 'Cards'),
              NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
            ],
          ),
        );
      },
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.wallet});

  final WalletState wallet;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('home'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      children: [
        Row(
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
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hi, Ada', style: TextStyle(fontWeight: FontWeight.w700)),
                Text('Kobo Wallet', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFF0D4C92), Color(0xFF2E7FD1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Available balance', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 6),
              Text(
                formatNaira(wallet.balance, decimals: true),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              const Row(
                children: [
                  _Pill('+ Add money'),
                  SizedBox(width: 8),
                  _Pill('Send'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text('Recent', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (final tx in wallet.transactions.take(4)) _TxTile(tx: tx),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }
}

class _TransactionsTab extends StatelessWidget {
  const _TransactionsTab({required this.wallet});

  final WalletState wallet;

  @override
  Widget build(BuildContext context) {
    final items = wallet.visibleTransactions;
    final hasFilter = wallet.statusFilter != null || wallet.daysFilter != null;
    return ListView(
      key: const ValueKey('transactions'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      children: [
        const Text(
          'Transactions',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (wallet.statusFilter != null)
              InputChip(
                label: Text(
                  wallet.statusFilter == TxStatus.failed ? 'Failed' : 'Successful',
                ),
                onDeleted: () => wallet.filter(days: wallet.daysFilter),
              ),
            if (wallet.daysFilter != null)
              InputChip(
                label: Text('Last ${wallet.daysFilter} days'),
                onDeleted: () => wallet.filter(status: wallet.statusFilter),
              ),
            if (hasFilter)
              ActionChip(
                label: const Text('Clear'),
                onPressed: wallet.clearFilter,
              )
            else
              const Chip(label: Text('All transactions')),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('No transactions match')),
          ),
        for (final tx in items) _TxTile(tx: tx, showDate: true),
      ],
    );
  }
}

class _TxTile extends StatelessWidget {
  const _TxTile({required this.tx, this.showDate = false});

  final Tx tx;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final failed = tx.status == TxStatus.failed;
    final accent = failed ? Brand.danger : Brand.blue;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              tx.title[0],
              style: TextStyle(color: accent, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  showDate ? '${tx.subtitle} · ${formatShortDate(tx.date)}' : tx.subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: failed ? Brand.danger : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatNaira(tx.amount, signed: tx.amount > 0),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _CardsTab extends StatelessWidget {
  const _CardsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('cards'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      children: [
        const Text('Cards', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: 1.6,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFF06234A), Color(0xFF1976D2)],
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kobo Virtual', style: TextStyle(color: Colors.white70)),
                Spacer(),
                Text(
                  '5399  ••••  ••••  4821',
                  style: TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 1.5),
                ),
                SizedBox(height: 8),
                Text('ADA OKAFOR    09/29', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('profile'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      children: const [
        Text('Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        SizedBox(height: 16),
        ListTile(leading: CircleAvatar(child: Text('A')), title: Text('Ada Okafor'), subtitle: Text('Tier 3 · Verified')),
        ListTile(leading: Icon(Icons.lock_outline), title: Text('Security')),
        ListTile(leading: Icon(Icons.notifications_none), title: Text('Notifications')),
      ],
    );
  }
}

/// Voice (browser speech recognition) with a typed fallback.
class _VoiceSheet extends StatefulWidget {
  const _VoiceSheet();

  @override
  State<_VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<_VoiceSheet> {
  final _stt = SpeechToText();
  final _text = TextEditingController();
  bool _listening = false;
  bool _sttReady = false;

  static const _suggestions = [
    'Show me my failed transactions from last week and switch to dark mode',
    'Open my cards',
    'Send 5k to Tunde',
    'Switch to light mode',
  ];

  @override
  void initState() {
    super.initState();
    _initStt();
  }

  Future<void> _initStt() async {
    try {
      final ok = await _stt.initialize(
        onStatus: (s) {
          if (s == 'done' || s == 'notListening') {
            if (mounted) setState(() => _listening = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
      );
      if (mounted) setState(() => _sttReady = ok);
    } catch (_) {
      // No speech support in this browser: typing still works.
    }
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      await _stt.stop();
      setState(() => _listening = false);
      return;
    }
    setState(() => _listening = true);
    await _stt.listen(
      onResult: (r) {
        setState(() => _text.text = r.recognizedWords);
        if (r.finalResult && r.recognizedWords.isNotEmpty) {
          Navigator.pop(context, r.recognizedWords);
        }
      },
      listenOptions: SpeechListenOptions(partialResults: true),
    );
  }

  @override
  void dispose() {
    _stt.cancel();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: GestureDetector(
              onTap: _sttReady ? _toggleMic : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: _listening ? 84 : 72,
                height: _listening ? 84 : 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _sttReady ? scheme.primary : scheme.outlineVariant,
                  boxShadow: _listening
                      ? [BoxShadow(color: scheme.primary.withValues(alpha: 0.5), blurRadius: 24)]
                      : const [],
                ),
                child: Icon(
                  _listening ? Icons.graphic_eq : Icons.mic,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _sttReady
                ? (_listening ? 'Listening…' : 'Tap to speak, or type below')
                : 'Type a command',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            autofocus: !_sttReady,
            onSubmitted: (v) => Navigator.pop(context, v),
            decoration: InputDecoration(
              hintText: 'Show me my failed transactions…',
              suffixIcon: IconButton(
                icon: const Icon(Icons.send_rounded),
                onPressed: () => Navigator.pop(context, _text.text),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in _suggestions)
                ActionChip(
                  label: Text(s, style: const TextStyle(fontSize: 11.5)),
                  onPressed: () => Navigator.pop(context, s),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
