import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/services/supabase_service.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_input.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _picker = ImagePicker();
  XFile? _coverImage;
  bool _loading = false;

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => _coverImage = file);
  }

  Future<void> _create() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final groupCount = await SupabaseService.instance.getUserGroupCount();
      if (groupCount >= 5) {
        setState(() => _loading = false);
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Límite alcanzado'),
              content: const Text('Has alcanzado el límite de 5 grupos como promotor. Actualiza tu suscripción para crear más.'),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
            ),
          );
        }
        return;
      }
      String? coverUrl;
      if (_coverImage != null) {
        final bytes = await _coverImage!.readAsBytes();
        final ext = _coverImage!.name.split('.').last;
        final path = 'group_covers/${DateTime.now().millisecondsSinceEpoch}.$ext';
        await SupabaseService.instance.client.storage.from('groups').uploadBinary(path, bytes);
        coverUrl = SupabaseService.instance.client.storage.from('groups').getPublicUrl(path);
      }
      await SupabaseService.instance.createGroup({
        'name': _nameController.text.trim(),
        'description': _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        'cover_url': coverUrl,
      });
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grupo creado')),
        );
        context.pop();
      }
    } catch (e, st) {
      setState(() => _loading = false);
      debugPrint('createGroup error: $e\n$st');
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Error'),
            content: Text(e.toAppError().message),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
      }
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
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                border: Border.all(color: Colors.grey[700]!),
              ),
              child: _coverImage != null
                  ? ClipRect(
                      child: Image.file(
                        File(_coverImage!.path),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 160,
                      ),
                    )
                  : const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Agregar foto de portada', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),
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
