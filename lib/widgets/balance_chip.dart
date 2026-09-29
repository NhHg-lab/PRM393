import 'package:flutter/material.dart';

import '../config/app_theme.dart';

class BalanceChip extends StatelessWidget {
  const BalanceChip({super.key, required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on_rounded, color: AppTheme.accent),
          const SizedBox(width: 7),
          Text(
            '\$${_format(balance)}',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ],
      ),
    );
  }

  static String _format(int value) {
    final text = value.toString();
    return text.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  }
}
