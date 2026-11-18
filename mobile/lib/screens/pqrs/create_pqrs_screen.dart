import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../providers/auth_provider.dart';

class CreatePqrsScreen extends StatefulWidget {
  const CreatePqrsScreen({super.key});

  @override
  State<CreatePqrsScreen> createState() => _CreatePqrsScreenState();
}

class _CreatePqrsScreenState extends State<CreatePqrsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _asuntoCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _tipo = 'peticion'; // 'peticion' | 'queja' | 'reclamo' | 'sugerencia'
  bool _loading = false;

  @override
  void dispose() {
    _asuntoCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitPqrs() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final docRef = FirebaseFirestore.instance.collection('pqrs').doc();
      await docRef.set({
        'clienteId': user.id,
        'clienteEmail': user.email,
        'empleadoId': null,
        'tipo': _tipo,
        'asunto': _asuntoCtrl.text.trim(),
        'descripcion': _descCtrl.text.trim(),
        'estado': 'recibida', // 'recibida' | 'en_gestion' | 'resuelta' | 'cerrada'
        'respuesta': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Radicado enviado con éxito. Te responderemos pronto.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar radicado: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Soporte PQRS')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Radicar Petición, Queja o Reclamo', style: AppTextStyles.headline),
              const SizedBox(height: 6),
              Text('Nuestro equipo atenderá tu mensaje en la menor brevedad.', style: AppTextStyles.subtle),
              const SizedBox(height: 24),
              Text('Tipo de Solicitud', style: AppTextStyles.title),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _tipo,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.category_rounded),
                ),
                items: const [
                  DropdownMenuItem(value: 'peticion', child: Text('Petición')),
                  DropdownMenuItem(value: 'queja', child: Text('Queja')),
                  DropdownMenuItem(value: 'reclamo', child: Text('Reclamo')),
                  DropdownMenuItem(value: 'sugerencia', child: Text('Sugerencia')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _tipo = val);
                },
              ),
              const SizedBox(height: 16),
              Text('Asunto', style: AppTextStyles.title),
              const SizedBox(height: 8),
              TextFormField(
                controller: _asuntoCtrl,
                decoration: const InputDecoration(hintText: 'Resumen del motivo'),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              Text('Descripción Detallada', style: AppTextStyles.title),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(hintText: 'Explica los detalles de tu requerimiento...'),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _loading ? null : _submitPqrs,
                icon: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: const Text('Enviar Radicado'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
