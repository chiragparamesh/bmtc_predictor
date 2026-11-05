import 'package:flutter/material.dart';

import '../../features/schedule/domain/network.dart';
import '../utils/ist_time.dart';

/// Route number pill, blue for ordinary buses, green for AC Vajra / Vayu Vajra.
class RouteBadge extends StatelessWidget {
  const RouteBadge({super.key, required this.route});

  final BusRoute route;

  static const ordinary = Color(0xFF1565C0);
  static const vajra = Color(0xFF00897B);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 64),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: route.vajra ? vajra : ordinary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(route.short,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
          if (route.vajra)
            const Text('AC', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Coloured delay label: green when roughly on time, amber, then red.
class DelayChip extends StatelessWidget {
  const DelayChip({super.key, required this.minutes});

  final double minutes;

  static Color colorFor(double m) => m < 3
      ? const Color(0xFF2E7D32)
      : m < 10
          ? const Color(0xFFEF6C00)
          : const Color(0xFFC62828);

  @override
  Widget build(BuildContext context) {
    final c = colorFor(minutes);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(formatDelay(minutes), style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }
}
