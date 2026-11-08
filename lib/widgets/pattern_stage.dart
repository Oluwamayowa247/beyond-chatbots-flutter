import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Lays a pattern out like the deck: phone on the left, story on the right.
class PatternStage extends StatelessWidget {
  const PatternStage({
    super.key,
    required this.label,
    required this.title,
    required this.user,
    required this.app,
    required this.phone,
    this.tryThis = const [],
    this.footer,
  });

  final String label;
  final String title;
  final String user;
  final String app;
  final Widget phone;
  final List<String> tryThis;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 980;
        final phoneBox = Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
          child: Center(child: phone),
        );
        if (!wide) return phoneBox;
        return Row(
          children: [
            Expanded(flex: 5, child: phoneBox),
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 40, 64, 40),
                child: _Story(
                  label: label,
                  title: title,
                  user: user,
                  app: app,
                  tryThis: tryThis,
                  footer: footer,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Story extends StatelessWidget {
  const _Story({
    required this.label,
    required this.title,
    required this.user,
    required this.app,
    required this.tryThis,
    this.footer,
  });

  final String label;
  final String title;
  final String user;
  final String app;
  final List<String> tryThis;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const small = TextStyle(
      color: Brand.muted,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
      fontSize: 13,
    );
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Brand.sky,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: t.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 36),
          const Text('THE USER', style: small),
          const SizedBox(height: 8),
          Text(
            user,
            style: t.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 28),
          const Text('THE APP', style: small),
          const SizedBox(height: 8),
          Text(
            app,
            style: t.titleMedium?.copyWith(color: Colors.white, height: 1.45),
          ),
          if (tryThis.isNotEmpty) ...[
            const SizedBox(height: 28),
            const Text('TRY SAYING', style: small),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in tryThis)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Brand.navyCard,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      s,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ],
          if (footer != null) ...[const SizedBox(height: 28), footer!],
        ],
      ),
    );
  }
}
