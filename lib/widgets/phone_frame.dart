import 'package:flutter/material.dart';

/// A phone-shaped viewport so each demo looks like the mockups in the deck,
/// while running as a fast web app instead of a laggy emulator.
///
/// Snackbars, dialogs and bottom sheets stay inside the phone because the
/// frame hosts its own [Navigator] and [ScaffoldMessenger].
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.theme, required this.child});

  static const Size screenSize = Size(390, 820);
  static const double _bezel = 12;
  static const double _statusBar = 44;

  final ThemeData theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = theme.brightness == Brightness.dark;
    return FittedBox(
      fit: BoxFit.contain,
      child: Container(
        width: screenSize.width + _bezel * 2,
        height: screenSize.height + _bezel * 2,
        padding: const EdgeInsets.all(_bezel),
        decoration: BoxDecoration(
          color: const Color(0xFF0B0F17),
          borderRadius: BorderRadius.circular(56),
          border: Border.all(color: const Color(0xFF2B3442), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 40,
              offset: Offset(0, 20),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(44),
          child: AnimatedTheme(
            data: theme,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                size: screenSize,
                padding: EdgeInsets.zero,
                viewPadding: EdgeInsets.zero,
                viewInsets: EdgeInsets.zero,
              ),
              child: ColoredBox(
                color: theme.scaffoldBackgroundColor,
                child: Column(
                  children: [
                    _StatusBar(dark: dark, height: _statusBar),
                    Expanded(
                      child: ScaffoldMessenger(
                        child: Navigator(
                          onGenerateRoute: (_) => MaterialPageRoute<void>(
                            builder: (_) => child,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.dark, required this.height});

  final bool dark;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : const Color(0xFF0B0F17);
    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 110,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Row(
              children: [
                Text(
                  '9:41',
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Icon(Icons.signal_cellular_alt, size: 16, color: fg),
                const SizedBox(width: 4),
                Icon(Icons.wifi, size: 16, color: fg),
                const SizedBox(width: 4),
                Icon(Icons.battery_full, size: 18, color: fg),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
