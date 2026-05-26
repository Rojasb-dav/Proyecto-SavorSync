import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../core/services/api_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _restaurantController = TextEditingController();
  final _addressController = TextEditingController();
  final _contentController = TextEditingController();
  final _imageUrlController = TextEditingController();
  double _rating = 3.0;
  bool _loading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await ApiService().dio.post('/api/posts', data: {
        'restaurantName': _restaurantController.text,
        'restaurantAddress': _addressController.text,
        'content': _contentController.text,
        'rating': _rating,
        'imageUrl': _imageUrlController.text,
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al crear publicación')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Publicación'),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            TextButton(
              onPressed: _submit,
              child: const Text('Publicar',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Restaurante', style: AppTextStyles.title),
              const SizedBox(height: 8),
              TextFormField(
                controller: _restaurantController,
                decoration: const InputDecoration(hintText: 'Nombre del lugar'),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              Text('Ubicación', style: AppTextStyles.title),
              const SizedBox(height: 8),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(hintText: 'Ciudad o dirección'),
              ),
              const SizedBox(height: 16),
              Text('Calificación', style: AppTextStyles.title),
              const SizedBox(height: 8),
              RatingBar.builder(
                initialRating: _rating,
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: true,
                itemCount: 5,
                itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                itemBuilder: (context, _) => const Icon(
                  Icons.star_rounded,
                  color: AppColors.accent,
                ),
                onRatingUpdate: (rating) => setState(() => _rating = rating),
              ),
              const SizedBox(height: 16),
              Text('Experiencia', style: AppTextStyles.title),
              const SizedBox(height: 8),
              TextFormField(
                controller: _contentController,
                maxLines: 4,
                decoration: const InputDecoration(
                    hintText: '¿Qué tal estuvo la comida?'),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              Text('URL de la foto', style: AppTextStyles.title),
              const SizedBox(height: 8),
              TextFormField(
                controller: _imageUrlController,
                decoration: const InputDecoration(
                    hintText: 'https://ejemplo.com/foto.jpg'),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
