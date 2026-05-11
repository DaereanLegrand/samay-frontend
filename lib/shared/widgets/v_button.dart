import 'package:flutter/material.dart';

class VButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool outlined;

  const VButton._({super.key, required this.child, this.onPressed, this.outlined = true});

  factory VButton.outlined({Key? key, VoidCallback? onPressed, required Widget child}) {
    return VButton._(key: key, onPressed: onPressed, outlined: true, child: child);
  }

  factory VButton.emphasized({Key? key, VoidCallback? onPressed, required Widget child}) {
    return VButton._(key: key, onPressed: onPressed, outlined: false, child: child);
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        side: outlined ? const BorderSide(color: Colors.white) : null,
        backgroundColor: outlined ? Colors.transparent : Colors.white,
        foregroundColor: outlined ? Colors.white : Colors.black,
        shape: const RoundedRectangleBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
      child: child,
    );
  }
}
