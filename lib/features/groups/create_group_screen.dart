import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vive_app/core/services/supabase_service.dart';
import 'package:vive_app/shared/widgets/v_button.dart';
import 'package:vive_app/shared/widgets/v_input.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  bool _loading = false;

  Future<void> _create() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await SupabaseService.instance.createGroup({
        'name': _nameController.text.trim(),
        'description': _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        'cover_url': null,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grupo creado')),
        );
        context.pop();
      }
    } catch (e) {
      final msg = e.toString().replaceAll(RegExp(r'(Exception: |PostgrestException\([^)]*\))'), '').trim();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg.isNotEmpty ? msg : 'Error al crear grupo')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear grupo')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          VInput(
            controller: _nameController,
            label: 'Nombre del grupo',
          ),
          const SizedBox(height: 16),
          VInput(
            controller: _descController,
            label: 'Descripción (opcional)',
            maxLines: 3,
          ),
          const SizedBox(height: 32),
          VButton.emphasized(
            label: 'Crear',
            loading: _loading,
            onPressed: _create,
          ),
        ],
      ),
    );
  }
}
