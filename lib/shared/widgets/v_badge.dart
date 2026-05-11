import 'package:flutter/material.dart';

class VBadge extends StatelessWidget {
  final String label;
  final Color? color;

  const VBadge({super.key, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        border: Border.all(color: Colors.white),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color != null ? Colors.black : Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
