import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';

import '../../core/app_state.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import 'on_device_model.dart';

/// Which engine actually produced the suggestions. Shown on screen, honestly.
enum FieldEngine { onDevice, cloud, scripted }

class FieldInsights {
  FieldInsights({
    required this.actionItems,
    required this.loanAmount,
    required this.loanPurpose,
    required this.tenureMonths,
    required this.sms,
  });

  final List<String> actionItems;
  final num loanAmount;
  final String loanPurpose;
  final int tenureMonths;
  final String sms;

  factory FieldInsights.fromJson(Map<String, dynamic> j) {
    final loan = (j['loanRequest'] as Map?) ?? const {};
    return FieldInsights(
      actionItems: [
        for (final i in (j['actionItems'] as List? ?? const [])) '$i',
      ].take(3).toList(),
      loanAmount: (loan['amount'] as num?) ?? 0,
      loanPurpose: '${loan['purpose'] ?? ''}',
      tenureMonths: (loan['tenureMonths'] as num?)?.round() ?? 3,
      sms: '${j['sms'] ?? ''}',
    );
  }
}

// ─── Slide 14: "Under the hood: Gemini Nano on the device" ──────────────────

abstract final class FieldAssistant {
  static const _system =
      'You help a loan officer in Nigeria who is on a field visit. Turn their '
      'notes into exactly 3 short action items, a pre-filled loan request '
      '(amount in Naira, purpose, tenureMonths) and a friendly SMS to the '
      'customer under 160 characters. Return JSON only.';

  static const Map<String, Object?> _jsonSchema = {
    'type': 'object',
    'properties': {
      'actionItems': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'loanRequest': {
        'type': 'object',
        'properties': {
          'amount': {'type': 'number'},
          'purpose': {'type': 'string'},
          'tenureMonths': {'type': 'integer'},
        },
        'required': ['amount', 'purpose', 'tenureMonths'],
      },
      'sms': {'type': 'string'},
    },
    'required': ['actionItems', 'loanRequest', 'sms'],
  };

  static Future<(FieldInsights, FieldEngine)> process(
    String customer,
    String notes,
  ) async {
    final input = 'Customer: $customer\nNotes: $notes';

    // 01  Ask whether Gemini Nano is on this device.
    final status = await OnDeviceModel.availability();

    // 02  Not ready? Fall back to a cloud model (hybrid).
    if (status != 'available') {
      if (AppState.isLive) return (await _askCloudModel(input), FieldEngine.cloud);
      return (_scripted(customer, notes), FieldEngine.scripted);
    }

    // 03  Run inference locally: private, offline, free per call.
    final raw = await OnDeviceModel.prompt(
      system: _system,
      input: input,
      schema: _jsonSchema,
    );
    return (FieldInsights.fromJson(_decode(raw)), FieldEngine.onDevice);
  }

  static Future<FieldInsights> _askCloudModel(String input) async {
    final model = FirebaseAI.googleAI().generativeModel(
      model: kGeminiModel,
      systemInstruction: Content.system(_system),
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: Schema.object(
          properties: {
            'actionItems': Schema.array(items: Schema.string()),
            'loanRequest': Schema.object(
              properties: {
                'amount': Schema.number(),
                'purpose': Schema.string(),
                'tenureMonths': Schema.integer(),
              },
            ),
            'sms': Schema.string(),
          },
        ),
      ),
    );
    final res = await model.generateContent([Content.text(input)]);
    return FieldInsights.fromJson(_decode(res.text ?? '{}'));
  }

  static Map<String, dynamic> _decode(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    final json = start >= 0 && end > start ? raw.substring(start, end + 1) : raw;
    return jsonDecode(json) as Map<String, dynamic>;
  }

  /// Offline stand-in when neither Gemini Nano nor the cloud is available.
  static FieldInsights _scripted(String customer, String notes) {
    final lower = notes.toLowerCase().replaceAll(',', '');
    final m = RegExp(r'(?:₦|n)?\s*(\d+(?:\.\d+)?)\s*(k|m)\b').firstMatch(lower);
    num amount = 500000;
    if (m != null) {
      amount = num.parse(m.group(1)!) * (m.group(2) == 'm' ? 1000000 : 1000);
    }
    final easter = lower.contains('easter');
    final name = customer.replaceAll(RegExp(r"'s store$", caseSensitive: false), '');
    return FieldInsights(
      actionItems: [
        'Prepare a ${formatNaira(amount)} stock loan application'
            '${easter ? ' before Easter' : ''}',
        'Collect sales records since December to support the request',
        'Flag strong history: two prior loans repaid early',
      ],
      loanAmount: amount,
      loanPurpose: easter ? 'Stock for Easter sales' : 'Inventory restock',
      tenureMonths: 3,
      sms: 'Hello $name, thanks for your time today. We have started your '
          '${formatNaira(amount)} stock loan request and will update you '
          'shortly. - Kobo Field Team',
    );
  }
}
