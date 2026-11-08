import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/format.dart';

/// A plain widget that "already exists" in the lending app.
/// GenUI does not need it to change at all; we only describe it to the model.
class LoanOfferCard extends StatelessWidget {
  const LoanOfferCard({
    super.key,
    required this.amount,
    required this.monthlyRate,
    required this.months,
    this.purpose,
  });

  final num amount;
  final num monthlyRate;
  final int months;
  final String? purpose;

  /// Standard amortised repayment.
  double get monthlyRepayment {
    final r = monthlyRate.toDouble();
    final n = math.max(months, 1);
    if (r == 0) return amount / n;
    return amount * r / (1 - math.pow(1 + r, -n));
  }

  @override
  Widget build(BuildContext context) {
    final total = monthlyRepayment * months;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF0D4C92), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storefront, color: Colors.white70, size: 18),
                const SizedBox(width: 6),
                Text(
                  purpose ?? 'Business loan offer',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(monthlyRate * 100).toStringAsFixed(1)}% / mo',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              formatNaira(amount),
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _Stat(
                  label: 'Monthly',
                  value: formatNaira(monthlyRepayment.round()),
                ),
                _Stat(label: 'Tenure', value: '$months mo'),
                _Stat(label: 'Total', value: formatNaira(total.round())),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 2),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(
              value,
              key: ValueKey(value),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
