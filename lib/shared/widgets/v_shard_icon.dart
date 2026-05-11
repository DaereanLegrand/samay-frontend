import 'package:flutter/material.dart';

class VShardIcon extends StatelessWidget {
  final double size;

  const VShardIcon({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.diamond,
      color: Colors.white,
      size: size,
    );
  }
}
