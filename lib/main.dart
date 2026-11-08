import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_state.dart';
import 'core/config.dart';
import 'core/theme.dart';
import 'patterns/p1_genui/kobo_lend_screen.dart';
import 'patterns/p2_structured/spendly_screen.dart';
import 'patterns/p3_functions/wallet_screen.dart';
import 'patterns/p4_on_device/field_notes_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppState.init();
  runApp(const BeyondChatbotsApp());
}

class BeyondChatbotsApp extends StatelessWidget {
  const BeyondChatbotsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beyond Chatbots · FlutterBytes 2026',
      debugShowCheckedModeBanner: false,
      theme: buildStageTheme(),
      home: const StageShell(),
    );
  }
}

class _Tab {
  const _Tab(this.number, this.label, this.builder);
  final String number;
  final String label;
  final WidgetBuilder builder;
}

final _tabs = <_Tab>[
  _Tab('', 'Intro', (_) => const _IntroPage()),
  _Tab('01', 'Generative UI', (_) => const GenUiPatternPage()),
  _Tab('02', 'Structured output', (_) => const StructuredPatternPage()),
  _Tab('03', 'Function calling', (_) => const FunctionCallingPatternPage()),
  _Tab('04', 'On-device AI', (_) => const OnDevicePatternPage()),
];

class StageShell extends StatefulWidget {
  const StageShell({super.key});

  @override
  State<StageShell> createState() => _StageShellState();
}

class _StageShellState extends State<StageShell> {
  int _index = 0;

  void _go(int i) => setState(() => _index = i.clamp(0, _tabs.length - 1));

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      // Arrow keys, or a presentation clicker (PageUp / PageDown).
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _go(_index + 1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _go(_index - 1),
        const SingleActivator(LogicalKeyboardKey.pageDown): () => _go(_index + 1),
        const SingleActivator(LogicalKeyboardKey.pageUp): () => _go(_index - 1),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Column(
            children: [
              _TopBar(index: _index, onSelect: _go),
              Expanded(
                // IndexedStack keeps each demo's state while you switch.
                child: IndexedStack(
                  index: _index,
                  children: [for (final t in _tabs) Builder(builder: t.builder)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x22FFFFFF))),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Brand.sky, size: 20),
          const SizedBox(width: 8),
          const Text(
            'Beyond Chatbots',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: _TabButton(
                        tab: _tabs[i],
                        selected: i == index,
                        onTap: () => onSelect(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          const SizedBox(width: 240, child: _ModeToggle()),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Brand.navyCard : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              if (tab.number.isNotEmpty) ...[
                Text(
                  tab.number,
                  style: const TextStyle(
                    color: Brand.sky,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                tab.label,
                style: TextStyle(
                  color: selected ? Colors.white : Brand.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Live Gemini vs the scripted offline demo (for bad conference wifi).
class _ModeToggle extends StatelessWidget {
  const _ModeToggle();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AppState.mode,
      builder: (context, mode, _) => Tooltip(
        message: AppState.firebaseReady
            ? 'Live uses $kGeminiModel via Firebase AI Logic'
            : 'Run `flutterfire configure` to enable Live mode',
        child: SegmentedButton<AiMode>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            selectedBackgroundColor: Brand.blue,
            selectedForegroundColor: Colors.white,
          ),
          segments: [
            ButtonSegment(
              value: AiMode.live,
              enabled: AppState.firebaseReady,
              icon: const Icon(Icons.cloud_done_outlined, size: 16),
              label: const Text('Live'),
            ),
            const ButtonSegment(
              value: AiMode.demo,
              icon: Icon(Icons.offline_bolt_outlined, size: 16),
              label: Text('Offline'),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (s) => AppState.mode.value = s.first,
        ),
      ),
    );
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const cards = [
      ('01', 'Generative UI', 'genui + A2UI', 'Answer with widgets, not paragraphs'),
      ('02', 'Structured output', 'firebase_ai', 'Turn a photo into a form'),
      ('03', 'Function calling', 'firebase_ai', 'Let the AI drive your app'),
      ('04', 'On-device AI', 'Gemini Nano', 'Works offline, data stays local'),
    ];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Beyond Chatbots',
                style: t.displayLarge?.copyWith(
                  color: Brand.sky,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Building Interactive AI Experiences in Flutter',
                style: t.titleLarge?.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Mayowa Olutuyo · FlutterBytes Conference 2026',
                style: t.titleSmall?.copyWith(color: Brand.muted),
              ),
              const SizedBox(height: 48),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  for (final (i, c) in cards.indexed)
                    _IntroCard(
                      number: c.$1,
                      title: c.$2,
                      tech: c.$3,
                      line: c.$4,
                      onTap: () => context
                          .findAncestorStateOfType<_StageShellState>()
                          ?._go(i + 1),
                    ),
                ],
              ),
              const SizedBox(height: 40),
              ValueListenableBuilder(
                valueListenable: AppState.mode,
                builder: (context, mode, _) => Text(
                  mode == AiMode.live
                      ? 'Live mode: real calls to $kGeminiModel'
                      : AppState.firebaseReady
                      ? 'Offline demo mode: scripted responses, no network'
                      : 'Offline demo mode. Run `flutterfire configure` to go live.',
                  style: const TextStyle(color: Brand.muted),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '← → or PageUp / PageDown to switch patterns',
                style: TextStyle(color: Brand.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({
    required this.number,
    required this.title,
    required this.tech,
    required this.line,
    required this.onTap,
  });

  final String number;
  final String title;
  final String tech;
  final String line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Material(
        color: Brand.navyCard,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  number,
                  style: const TextStyle(
                    color: Brand.sky,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tech,
                  style: const TextStyle(
                    color: Brand.sky,
                    fontFamily: 'RobotoMono',
                    fontFamilyFallback: ['Inter'],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Text(line, style: const TextStyle(color: Brand.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
