import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vive_app/core/services/supabase_service.dart';
import 'package:vive_app/shared/widgets/v_button.dart';
import 'package:vive_app/shared/widgets/v_input.dart';

class DonateShardsScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const DonateShardsScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<DonateShardsScreen> createState() => _DonateShardsScreenState();
}

class _DonateShardsScreenState extends State<DonateShardsScreen> {
  final _amountController = TextEditingController();
  bool _loading = false;

  Future<void> _donate() async {
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto válido')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await SupabaseService.instance.donateToGroup(widget.groupId, amount);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Donación exitosa')),
        );
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Donar shards')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Donar a ${widget.groupName}',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Estos shards impulsarán el ranking del grupo durante 14 días',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          VInput(
            controller: _amountController,
            label: 'Cantidad de shards',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 32),
          VButton.emphasized(
            label: 'Donar',
            loading: _loading,
            onPressed: _donate,
          ),
        ],
      ),
    );
  }
}
