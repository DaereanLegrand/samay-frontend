import 'package:flutter/material.dart';

class RankBadge extends StatelessWidget {
  final String bracket;

  const RankBadge({super.key, required this.bracket});

  static const Map<String, String> _labels = {
    'b90_100': 'Full Vibe',
    'b80_90': 'Leyendas de la Vibra',
    'b60_80': 'Creadores de la Vibra',
    'b40_60': 'Seguidores de la Vibra',
    'b20_40': 'Buscadores de la Vibra',
    'b0_20': 'En la Búsqueda',
  };

  String get label => _labels[bracket] ?? bracket;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
