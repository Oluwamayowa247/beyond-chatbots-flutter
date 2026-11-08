import 'package:flutter/material.dart';

enum TxStatus { success, failed }

class Tx {
  const Tx({
    required this.title,
    required this.amount,
    required this.status,
    required this.daysAgo,
  });

  final String title;
  final num amount;
  final TxStatus status;
  final int daysAgo;

  DateTime get date => DateTime.now().subtract(Duration(days: daysAgo));
  String get subtitle => status == TxStatus.failed
      ? 'Failed · reversed'
      : (daysAgo == 0 ? 'Successful · today' : 'Successful');
}

enum WalletTab { home, transactions, cards, profile }

/// Everything the AI is allowed to change lives here, behind methods we own.
class WalletState extends ChangeNotifier {
  num balance = 184250;
  final List<Tx> transactions = [
    const Tx(title: 'Shoprite Lekki', amount: -12400, status: TxStatus.success, daysAgo: 1),
    const Tx(title: 'Transfer · Tunde', amount: -25000, status: TxStatus.failed, daysAgo: 2),
    const Tx(title: 'Salary · Acme Ltd', amount: 350000, status: TxStatus.success, daysAgo: 4),
    const Tx(title: 'DSTV Premium', amount: -29500, status: TxStatus.failed, daysAgo: 5),
    const Tx(title: 'Bolt ride', amount: -3200, status: TxStatus.success, daysAgo: 6),
    const Tx(title: 'MTN Airtime', amount: -2000, status: TxStatus.failed, daysAgo: 9),
    const Tx(title: 'Ikeja Electric', amount: -15000, status: TxStatus.success, daysAgo: 12),
    const Tx(title: 'Transfer · Chioma', amount: -50000, status: TxStatus.success, daysAgo: 20),
  ];

  WalletTab tab = WalletTab.home;
  TxStatus? statusFilter;
  int? daysFilter;
  Brightness brightness = Brightness.light;

  /// True while the agent is working, so the UI can show progress.
  bool thinking = false;

  List<Tx> get visibleTransactions => transactions.where((t) {
    if (statusFilter != null && t.status != statusFilter) return false;
    if (daysFilter != null && t.daysAgo > daysFilter!) return false;
    return true;
  }).toList();

  void setThinking(bool value) {
    thinking = value;
    notifyListeners();
  }

  void goTo(WalletTab value) {
    tab = value;
    notifyListeners();
  }

  void filter({TxStatus? status, int? days}) {
    statusFilter = status;
    daysFilter = days;
    tab = WalletTab.transactions;
    notifyListeners();
  }

  void clearFilter() => filter();

  void setBrightness(Brightness value) {
    brightness = value;
    notifyListeners();
  }

  void addTransfer(String to, num amount) {
    balance -= amount;
    transactions.insert(
      0,
      Tx(title: 'Transfer · $to', amount: -amount, status: TxStatus.success, daysAgo: 0),
    );
    notifyListeners();
  }

  // ── Undo support (Trust: show what the AI did and offer undo) ───────────
  WalletSnapshot snapshot() => WalletSnapshot(
    tab: tab,
    statusFilter: statusFilter,
    daysFilter: daysFilter,
    brightness: brightness,
  );

  void restore(WalletSnapshot s) {
    tab = s.tab;
    statusFilter = s.statusFilter;
    daysFilter = s.daysFilter;
    brightness = s.brightness;
    notifyListeners();
  }
}

class WalletSnapshot {
  const WalletSnapshot({
    required this.tab,
    required this.statusFilter,
    required this.daysFilter,
    required this.brightness,
  });

  final WalletTab tab;
  final TxStatus? statusFilter;
  final int? daysFilter;
  final Brightness brightness;
}
