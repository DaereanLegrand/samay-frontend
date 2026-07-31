import 'package:flutter/material.dart';
import 'package:samay/shared/widgets/v_button.dart';

class VComingSoonScreen extends StatelessWidget {
  final String title;
  final String description;
  final bool showBackButton;
  final IconData icon;

  const VComingSoonScreen({
    super.key,
    required this.title,
    required this.description,
    this.showBackButton = true,
    this.icon = Icons.construction,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 56, color: Colors.grey[800]),
                const SizedBox(height: 16),
                const Text(
                  'Pr\u00f3ximamente',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[500]),
                ),
                if (showBackButton) ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 200,
                    child: VButton.outlined(
                      label: 'Volver',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
