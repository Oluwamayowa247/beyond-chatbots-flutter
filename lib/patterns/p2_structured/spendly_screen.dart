import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/pattern_stage.dart';
import '../../widgets/phone_frame.dart';
import 'expense.dart';
import 'receipt_scanner.dart';

class StructuredPatternPage extends StatelessWidget {
  const StructuredPatternPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PatternStage(
      label: 'PATTERN 02 · STRUCTURED OUTPUT',
      title: 'Turn a photo into a form,\nnot a conversation',
      user: 'One tap: “Scan a receipt”',
      app: 'Gemini reads the image and returns JSON that matches my schema. '
          'The form fills itself, already typed and validated, and the user '
          'just hits save.',
      phone: PhoneFrame(
        theme: buildPhoneTheme(Brightness.light, seed: Brand.success),
        child: const SpendlyScreen(),
      ),
    );
  }
}

enum _ScanState { idle, scanning, filled }

class SpendlyScreen extends StatefulWidget {
  const SpendlyScreen({super.key});

  @override
  State<SpendlyScreen> createState() => _SpendlyScreenState();
}

class _SpendlyScreenState extends State<SpendlyScreen> {
  final _merchant = TextEditingController();
  final _amount = TextEditingController();
  final _date = TextEditingController();
  final _receiptKey = GlobalKey();
  String? _category;

  _ScanState _state = _ScanState.idle;
  Uint8List? _photo;
  bool _usingSample = false;
  String? _rawJson;

  Future<void> _chooseSource() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('Use sample receipt'),
              subtitle: const Text('Mama Put Kitchen, Yaba'),
              onTap: () => Navigator.pop(context, 'sample'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take or upload a photo'),
              subtitle: Text(
                AppState.isLive
                    ? 'Sent to Gemini'
                    : 'Offline: use a file from sample_receipts',
              ),
              onTap: () => Navigator.pop(context, 'photo'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == 'sample') await _scanSample();
    if (choice == 'photo') await _scanPhoto();
  }

  Future<void> _scanSample() async {
    setState(() {
      _usingSample = true;
      _photo = null;
      _state = _ScanState.scanning;
      _reset();
    });
    // Let the receipt paint, then snapshot it to a real PNG for Gemini.
    await WidgetsBinding.instance.endOfFrame;
    final bytes = await _snapshotReceipt();
    await _run(bytes, 'image/png');
  }

  Future<void> _scanPhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _usingSample = false;
      _photo = bytes;
      _state = _ScanState.scanning;
      _reset();
    });
    await _run(bytes, file.mimeType ?? 'image/jpeg', fileName: file.name);
  }

  Future<Uint8List> _snapshotReceipt() async {
    final boundary =
        _receiptKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.5);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<void> _run(Uint8List bytes, String mime, {String? fileName}) async {
    try {
      final expense = await ReceiptScanner.scan(
        bytes,
        mime,
        fileName: fileName,
      );
      if (!mounted) return;
      setState(() {
        _merchant.text = expense.merchant;
        _amount.text = expense.amount.toString();
        _date.text = expense.date;
        _category = expenseCategories.contains(expense.category)
            ? expense.category
            : 'other';
        _rawJson = const JsonEncoder.withIndent('  ').convert(expense.toJson());
        _state = _ScanState.filled;
      });
    } catch (e) {
      if (!mounted) return;
      // Back to the "Scan a receipt" card so the presenter can try again.
      setState(() {
        _state = _ScanState.idle;
        _photo = null;
        _usingSample = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text('Could not read receipt: $e'),
        ),
      );
    }
  }

  void _reset() {
    _merchant.clear();
    _amount.clear();
    _date.clear();
    _category = null;
    _rawJson = null;
  }

  void _save() {
    final amount = num.tryParse(_amount.text);
    if (_merchant.text.isEmpty || amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Merchant and amount are required')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Saved ${formatNaira(amount)} at ${_merchant.text}',
        ),
      ),
    );
    setState(() {
      _reset();
      _state = _ScanState.idle;
      _photo = null;
      _usingSample = false;
    });
  }

  @override
  void dispose() {
    _merchant.dispose();
    _amount.dispose();
    _date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filled = _state == _ScanState.filled;
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              children: [
                const _Header(),
                const SizedBox(height: 16),
                if (_usingSample || _photo != null)
                  _PhotoPreview(
                    scanning: _state == _ScanState.scanning,
                    child: _usingSample
                        ? RepaintBoundary(
                            key: _receiptKey,
                            child: const SampleReceiptView(),
                          )
                        : Image.memory(_photo!, fit: BoxFit.cover),
                  )
                else
                  _ScanCard(onTap: _chooseSource),
                if (filled) ...[
                  const SizedBox(height: 12),
                  _AiBanner(
                    rawJson: _rawJson,
                    onRescan: _chooseSource,
                  ),
                ],
                const SizedBox(height: 16),
                _Field(label: 'Merchant', controller: _merchant, ai: filled),
                _Field(
                  label: 'Amount',
                  controller: _amount,
                  ai: filled,
                  prefix: '₦ ',
                  keyboard: TextInputType.number,
                ),
                _Field(label: 'Date', controller: _date, ai: filled),
                const SizedBox(height: 4),
                Text(
                  'Category',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final c in expenseCategories)
                      ChoiceChip(
                        label: Text(c[0].toUpperCase() + c.substring(1)),
                        selected: _category == c,
                        onSelected: (_) => setState(() => _category = c),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _state == _ScanState.scanning ? null : _save,
                child: const Text('Save expense'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Brand.success,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'S',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 10),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New expense', style: TextStyle(fontWeight: FontWeight.w700)),
            Text('Spendly', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ],
    );
  }
}

class _ScanCard extends StatelessWidget {
  const _ScanCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFEAF5FD),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: CustomPaint(
          painter: _DashedBorder(color: const Color(0xFF8CC3EA)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Brand.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_camera, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scan a receipt',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0B1B2E),
                      ),
                    ),
                    Text(
                      'AI fills the form for you',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  _DashedBorder({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)),
      );
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}

class _PhotoPreview extends StatefulWidget {
  const _PhotoPreview({required this.scanning, required this.child});

  final bool scanning;
  final Widget child;

  @override
  State<_PhotoPreview> createState() => _PhotoPreviewState();
}

class _PhotoPreviewState extends State<_PhotoPreview>
    with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 260,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: const Color(0xFFE3E7EC),
              child: Center(child: widget.child),
            ),
            if (widget.scanning)
              AnimatedBuilder(
                animation: _anim,
                builder: (context, _) => Align(
                  alignment: Alignment(0, _anim.value * 2 - 1),
                  child: Container(
                    height: 3,
                    decoration: const BoxDecoration(
                      color: Brand.sky,
                      boxShadow: [
                        BoxShadow(color: Brand.sky, blurRadius: 16),
                      ],
                    ),
                  ),
                ),
              ),
            if (widget.scanning)
              const Positioned(
                left: 12,
                bottom: 12,
                child: Chip(
                  avatar: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  label: Text('Reading receipt…'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Trust: show what the AI did, and let the user check it.
class _AiBanner extends StatelessWidget {
  const _AiBanner({required this.rawJson, required this.onRescan});

  final String? rawJson;
  final VoidCallback onRescan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F6EC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 18, color: Brand.success),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Filled by AI. Check the details, then save.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF14532D)),
            ),
          ),
          if (rawJson != null)
            IconButton(
              tooltip: 'Show JSON',
              icon: const Icon(Icons.data_object, size: 18),
              onPressed: () => showDialog<void>(
                context: context,
                useRootNavigator: false,
                builder: (context) => AlertDialog(
                  title: const Text('What Gemini returned'),
                  content: SelectableText(
                    rawJson!,
                    style: const TextStyle(
                      fontFamily: 'RobotoMono',
                      fontFamilyFallback: ['Inter'],
                    ),
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Scan again',
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: onRescan,
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.ai,
    this.prefix,
    this.keyboard,
  });

  final String label;
  final TextEditingController controller;
  final bool ai;
  final String? prefix;
  final TextInputType? keyboard;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: ai
                  ? [
                      BoxShadow(
                        color: Brand.success.withValues(alpha: 0.25),
                        blurRadius: 8,
                      ),
                    ]
                  : const [],
            ),
            child: TextField(
              controller: controller,
              keyboardType: keyboard,
              decoration: InputDecoration(
                prefixText: prefix,
                suffixIcon: ai
                    ? const Icon(
                        Icons.auto_awesome,
                        size: 16,
                        color: Brand.success,
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A receipt drawn in Flutter. In Live mode it is snapshotted to PNG and sent
/// to Gemini exactly like a camera photo would be.
class SampleReceiptView extends StatelessWidget {
  const SampleReceiptView({super.key});

  @override
  Widget build(BuildContext context) {
    const mono = TextStyle(
      fontFamily: 'RobotoMono',
                    fontFamilyFallback: ['Inter'],
      fontSize: 11,
      color: Color(0xFF222222),
      height: 1.4,
    );
    final d = SampleReceipt.date;
    final date =
        '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
    return Transform.rotate(
      angle: -0.03,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(14),
        color: Colors.white,
        child: DefaultTextStyle(
          style: mono,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                SampleReceipt.merchant.toUpperCase(),
                style: mono.copyWith(fontWeight: FontWeight.w900, fontSize: 13),
              ),
              const Text(SampleReceipt.address, textAlign: TextAlign.center),
              Text('$date   14:32'),
              const Text('--------------------------------'),
              for (final (name, qty, price) in SampleReceipt.items)
                Row(
                  children: [
                    Expanded(child: Text('$qty x $name')),
                    Text(formatNaira(qty * price)),
                  ],
                ),
              const Text('--------------------------------'),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'TOTAL',
                      style: mono.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  Text(
                    formatNaira(SampleReceipt.total),
                    style: mono.copyWith(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text('PAID: TRANSFER'),
              const Text('Thank you! Come again'),
            ],
          ),
        ),
      ),
    );
  }
}
