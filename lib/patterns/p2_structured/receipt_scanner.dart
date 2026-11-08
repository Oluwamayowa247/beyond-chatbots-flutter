import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';

import '../../core/app_state.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import 'expense.dart';

// ─── Slide 10: "Under the hood: schema in, typed data out" ──────────────────

class ReceiptScanner {
  /// 01  Describe the exact shape you want with Schema.object.
  static final _model = FirebaseAI.googleAI().generativeModel(
    model: kGeminiModel,
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json',
      responseSchema: Schema.object(
        properties: {
          'merchant': Schema.string(),
          'amount': Schema.number(description: 'Total paid, in Naira.'),
          'date': Schema.string(description: 'ISO date, YYYY-MM-DD.'),
          'category': Schema.enumString(enumValues: expenseCategories),
        },
      ),
    ),
  );

  static Future<Expense> scan(
    Uint8List photoBytes,
    String mimeType, {
    String? fileName,
  }) async {
    if (!AppState.isLive) return _demoScan(fileName);

    // 02  Send the photo plus one instruction as multimodal input.
    final res = await _model.generateContent([
      Content.multi([
        TextPart('Extract this receipt'),
        InlineDataPart(mimeType, photoBytes),
      ]),
    ]);

    // 03  Parse straight into your model class. No regex, no chat.
    return Expense.fromJson(jsonDecode(res.text!) as Map<String, dynamic>);
  }

  /// What Gemini returns for the images in the `sample_receipts` folder.
  /// Offline mode can only "read" these, since it has no model.
  static const _sampleFiles = {
    '1-food': Expense(
      merchant: 'Iya Basira Buka',
      amount: 8800,
      date: '2026-11-03',
      category: 'food',
    ),
    '2-transport': Expense(
      merchant: 'Emeka Fuel Station',
      amount: 26250,
      date: '2026-11-05',
      category: 'transport',
    ),
    '3-bills': Expense(
      merchant: 'BrightPower Electricity',
      amount: 15000,
      date: '2026-10-30',
      category: 'bills',
    ),
  };

  /// Offline stand-in that returns what Gemini returns for the sample receipt.
  static Future<Expense> _demoScan(String? fileName) async {
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (fileName != null) {
      for (final entry in _sampleFiles.entries) {
        // contains, not startsWith: resized photos are named "scaled_<name>".
        if (fileName.contains(entry.key)) return entry.value;
      }
      throw StateError(
        'Offline mode can only read the images in the sample_receipts '
        'folder. Switch to Live to scan any photo.',
      );
    }
    return Expense(
      merchant: SampleReceipt.merchant,
      amount: SampleReceipt.total,
      date: isoDate(SampleReceipt.date),
      category: 'food',
    );
  }
}

/// Data for the receipt drawn by `SampleReceiptView`.
abstract final class SampleReceipt {
  static const merchant = 'Mama Put Kitchen';
  static const address = '12 Herbert Macaulay Way, Yaba';
  static const items = [
    ('Jollof rice', 2, 2500),
    ('Grilled chicken', 1, 3000),
    ('Zobo (50cl)', 2, 500),
  ];
  static int get total => items.fold(0, (sum, i) => sum + i.$2 * i.$3);
  static DateTime get date =>
      DateTime.now().subtract(const Duration(days: 2));
}
