import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/pattern_stage.dart';
import '../../widgets/phone_frame.dart';
import 'field_assistant.dart';
import 'on_device_model.dart';

class OnDevicePatternPage extends StatelessWidget {
  const OnDevicePatternPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PatternStage(
      label: 'PATTERN 04 · ON-DEVICE AI',
      title: 'AI that works offline and\nkeeps data on the phone',
      user: 'Nothing. A field agent just finishes a note in a market with no '
          'signal',
      app: 'Gemini Nano turns the note into action items, a pre-filled loan '
          'request and a suggested SMS. Zero bytes leave the phone.',
      phone: PhoneFrame(
        theme: buildPhoneTheme(Brightness.light),
        child: const FieldNotesScreen(),
      ),
      footer: const _EngineExplainer(),
    );
  }
}

class _EngineExplainer extends StatelessWidget {
  const _EngineExplainer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Brand.navyCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'On the web this uses Chrome’s built-in Gemini Nano (Prompt API). '
        'On Android, the same flow uses ML Kit GenAI (google_mlkit_genai_prompt). '
        'If neither is available it falls back to the cloud, exactly like '
        'slide 14.',
        style: TextStyle(color: Brand.muted, fontSize: 13, height: 1.4),
      ),
    );
  }
}

class FieldNotesScreen extends StatefulWidget {
  const FieldNotesScreen({super.key});

  @override
  State<FieldNotesScreen> createState() => _FieldNotesScreenState();
}

class _FieldNotesScreenState extends State<FieldNotesScreen> {
  static const _customer = "Mrs. Adebayo's store";
  final _notes = TextEditingController(
    text: 'Sales up since December. Wants ₦500k for stock before Easter. '
        'Two prior loans, both repaid early.',
  );

  Timer? _debounce;
  String _nano = 'checking';
  double? _downloadProgress;
  bool _busy = false;
  FieldInsights? _insights;
  FieldEngine? _engine;
  String? _error;
  final _done = <int>{};

  @override
  void initState() {
    super.initState();
    _checkNano();
  }

  Future<void> _checkNano() async {
    final s = await OnDeviceModel.availability();
    if (mounted) setState(() => _nano = s);
  }

  /// The user does nothing: suggestions appear once they stop typing.
  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1400), _process);
  }

  Future<void> _process() async {
    if (_notes.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _done.clear();
    });
    try {
      final (insights, engine) = await FieldAssistant.process(
        _customer,
        _notes.text,
      );
      if (!mounted) return;
      setState(() {
        _insights = insights;
        _engine = engine;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadNano() async {
    setState(() => _downloadProgress = 0);
    try {
      await OnDeviceModel.download(
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'Download failed: $e');
    }
    if (!mounted) return;
    setState(() => _downloadProgress = null);
    await _checkNano();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onDevice = _engine != FieldEngine.cloud;
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Row(
            children: [
              _Pill(
                icon: onDevice ? Icons.airplanemode_active : Icons.cloud_outlined,
                text: onDevice ? 'Offline · on-device' : 'Online · cloud fallback',
                bg: Brand.navy,
                fg: Colors.white,
              ),
              const Spacer(),
              _Pill(
                text: onDevice ? '0 bytes sent' : 'sent to Gemini',
                bg: onDevice ? const Color(0xFFE6F6EC) : const Color(0xFFFFF4E0),
                fg: onDevice ? Brand.success : const Color(0xFF9A6200),
                mono: true,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'FIELD VISIT · TODAY',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            _customer,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          TextField(
            controller: _notes,
            onChanged: _onChanged,
            maxLines: null,
            style: const TextStyle(fontSize: 14, height: 1.45),
            decoration: const InputDecoration(
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
              hintText: 'Type your visit notes…',
            ),
          ),
          if (_nano == 'downloadable' || _nano == 'downloading')
            _DownloadBanner(progress: _downloadProgress, onTap: _downloadNano),
          if (_insights == null && !_busy)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _process,
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Suggest next steps'),
              ),
            ),
          const SizedBox(height: 8),
          if (_busy) const _Skeleton(),
          if (_error != null)
            Text(_error!, style: TextStyle(color: scheme.error, fontSize: 12)),
          if (!_busy && _insights != null) ..._results(_insights!, scheme),
          const SizedBox(height: 12),
          _EngineLine(nano: _nano, engine: _engine),
        ],
      ),
    );
  }

  List<Widget> _results(FieldInsights i, ColorScheme scheme) => [
    _Section(
      icon: Icons.checklist,
      title: 'Action items',
      child: Column(
        children: [
          for (var k = 0; k < i.actionItems.length; k++)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _done.contains(k),
              onChanged: (v) => setState(
                () => v == true ? _done.add(k) : _done.remove(k),
              ),
              title: Text(i.actionItems[k], style: const TextStyle(fontSize: 13)),
            ),
        ],
      ),
    ),
    _Section(
      icon: Icons.request_quote_outlined,
      title: 'Pre-filled loan request',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatNaira(i.loanAmount),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          Text(
            '${i.loanPurpose} · ${i.tenureMonths} months',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Saved as draft. It syncs when you are back online.'),
              ),
            ),
            child: const Text('Review request'),
          ),
        ],
      ),
    ),
    _Section(
      icon: Icons.sms_outlined,
      title: 'Suggested SMS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(i.sms, style: const TextStyle(fontSize: 13, height: 1.4)),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: i.sms));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('SMS copied')),
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy'),
              ),
            ],
          ),
        ],
      ),
    ),
  ];
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.bg,
    required this.fg,
    this.icon,
    this.mono = false,
  });

  final String text;
  final Color bg;
  final Color fg;
  final IconData? icon;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: mono ? 'RobotoMono' : null,
              fontFamilyFallback: const ['Inter'],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.child});

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

/// Latency: show skeletons, never a frozen screen.
class _Skeleton extends StatefulWidget {
  const _Skeleton();

  @override
  State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return FadeTransition(
      opacity: Tween(begin: 0.4, end: 1.0).animate(_c),
      child: Column(
        children: [
          for (final h in [96.0, 110.0, 80.0])
            Container(
              height: h,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
        ],
      ),
    );
  }
}

class _DownloadBanner extends StatelessWidget {
  const _DownloadBanner({required this.progress, required this.onTap});

  final double? progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Brand.mist,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gemini Nano can run in this browser. Download it once, then it '
            'works offline.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF0B1B2E)),
          ),
          const SizedBox(height: 8),
          if (progress != null)
            LinearProgressIndicator(value: progress == 0 ? null : progress)
          else
            FilledButton.tonal(
              onPressed: onTap,
              child: const Text('Download model'),
            ),
        ],
      ),
    );
  }
}

class _EngineLine extends StatelessWidget {
  const _EngineLine({required this.nano, required this.engine});

  final String nano;
  final FieldEngine? engine;

  @override
  Widget build(BuildContext context) {
    final text = switch (engine) {
      FieldEngine.onDevice => 'Generated by ${OnDeviceModel.engineName}.',
      FieldEngine.cloud =>
        'On-device model $nano here, so this used the cloud ($kGeminiModel).',
      FieldEngine.scripted =>
        'On-device model $nano in this browser, and Live mode is off, so '
            'this is the scripted demo.',
      null => 'On-device model: $nano',
    };
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
