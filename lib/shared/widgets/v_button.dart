import 'package:flutter/material.dart';

class VButton extends StatelessWidget {
  final Widget? child;
  final String? label;
  final VoidCallback? onPressed;
  final bool outlined;
  final bool loading;

  const VButton._({
    super.key,
    this.label,
    this.onPressed,
    this.outlined = true,
    this.loading = false,
    this.child,
  });

  factory VButton({
    Key? key,
    String? label,
    VoidCallback? onPressed,
    bool loading = false,
    Widget? child,
  }) {
    return VButton._(
      key: key,
      label: label,
      onPressed: onPressed,
      loading: loading,
      child: child,
    );
  }

  factory VButton.outlined({
    Key? key,
    String? label,
    VoidCallback? onPressed,
    bool loading = false,
    Widget? child,
  }) {
    return VButton._(
      key: key,
      label: label,
      onPressed: onPressed,
      loading: loading,
      child: child,
    );
  }

  factory VButton.emphasized({
    Key? key,
    String? label,
    VoidCallback? onPressed,
    bool loading = false,
    Widget? child,
  }) {
    return VButton._(
      key: key,
      label: label,
      onPressed: onPressed,
      outlined: false,
      loading: loading,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: loading ? null : onPressed,
        style: TextButton.styleFrom(
          side: outlined ? const BorderSide(color: Colors.white) : null,
          backgroundColor: outlined ? Colors.transparent : Colors.white,
          foregroundColor: outlined ? Colors.white : Colors.black,
          shape: const RoundedRectangleBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : child ?? Text(
                label ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
      ),
    );
  }
}
