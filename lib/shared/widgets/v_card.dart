import 'package:flutter/material.dart';

class VCard extends StatelessWidget {
  final Widget child;

  const VCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border.symmetric(
          horizontal: BorderSide(color: Color(0xFF333333)),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}
