import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:image_picker/image_picker.dart';

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
  
  File? _image;
  final _picker = ImagePicker();
  double _rating = 3.0;
  bool _loading = false;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() => _image = File(pickedFile.path));
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona una foto')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      // 1. Subir la imagen primero
      String fileName = _image!.path.split('/').last;
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(_image!.path, filename: fileName),
      });

      final uploadResponse = await ApiService().dio.post('/api/files/upload', data: formData);
      final String relativeUrl = uploadResponse.data['url'];
      // Convertimos a URL absoluta para que la app pueda verla (IP del backend)
      final String absoluteImageUrl = ApiService.baseUrl + relativeUrl;

      // 2. Crear el post con la URL de la imagen que nos devolvió el servidor
      await ApiService().dio.post('/api/posts', data: {
        'restaurantName': _restaurantController.text,
        'restaurantAddress': _addressController.text,
        'content': _contentController.text,
        'rating': _rating,
        'imageUrl': absoluteImageUrl,
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
              GestureDetector(
                onTap: () => _showPickerOptions(),
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[300]!),
                    image: _image != null
                        ? DecorationImage(image: FileImage(_image!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _image == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_a_photo_rounded, size: 40, color: AppColors.secondary),
                            const SizedBox(height: 8),
                            Text('Toca para añadir una foto', style: AppTextStyles.subtle),
                          ],
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 24),
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
            ],
          ),
        ),
      ),
    );
  }

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Galería'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Cámara'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }
}
