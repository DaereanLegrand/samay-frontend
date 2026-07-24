import 'package:flutter/material.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Samay')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bienvenido a Samay',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'Tu feed aparecerá aquí.\nPronto podrás ver eventos cercanos y actividades de tus grupos.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
