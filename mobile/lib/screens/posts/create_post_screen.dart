import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../models/restaurant_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/cloudinary_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customRestaurantController = TextEditingController();
  final _addressController = TextEditingController();
  final _contentController = TextEditingController();

  List<RestaurantModel> _registeredRestaurants = [];
  RestaurantModel? _selectedRestaurant;
  bool _isManualRestaurant = false;
  bool _loadingRestaurants = true;

  String _selectedCity = 'Bogotá, D.C.';
  static const List<String> _cities = [
    'Bogotá, D.C.',
    'Chía',
    'Soacha',
    'Cajicá',
    'Zipaquirá',
    'Medellín',
    'Cali',
    'Barranquilla',
  ];

  XFile? _pickedXFile;
  final _picker = ImagePicker();
  double _rating = 4.0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  Future<void> _loadRestaurants() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('restaurants')
          .get();

      final list = snapshot.docs
          .map((doc) => RestaurantModel.fromJson({'id': doc.id, ...doc.data()}))
          .toList();

      if (mounted) {
        setState(() {
          _registeredRestaurants = list;
          if (list.isNotEmpty) {
            _selectedRestaurant = list.first;
            _addressController.text = list.first.address;
          } else {
            _isManualRestaurant = true;
          }
          _loadingRestaurants = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isManualRestaurant = true;
          _loadingRestaurants = false;
        });
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() => _pickedXFile = pickedFile);
      }
    } catch (e) {
      debugPrint('Error al seleccionar imagen: $e');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedXFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona una foto para tu reseña')),
      );
      return;
    }

    final restaurantName = _isManualRestaurant
        ? _customRestaurantController.text.trim()
        : _selectedRestaurant?.name ?? 'Restaurante';

    if (restaurantName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa o selecciona un restaurante')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final user = context.read<AuthProvider>().user;

      // 1. Subir la imagen a Cloudinary
      final imageUrl = await CloudinaryService.uploadImageXFile(_pickedXFile!) ??
          'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=800&q=80';

      final restaurantId = _isManualRestaurant ? null : _selectedRestaurant?.id;
      final fullAddress = '${_addressController.text.trim()} ($_selectedCity)';

      // 2. Crear documento de publicación en Cloud Firestore
      await FirebaseFirestore.instance.collection('posts').add({
        'userId': user?.id ?? '',
        'username': user?.username ?? 'foodie',
        'fullName': user?.fullName ?? 'Foodie Bogotá',
        'userAvatarUrl': user?.avatarUrl,
        'restaurantId': restaurantId,
        'restaurantName': restaurantName,
        'restaurantAddress': fullAddress,
        'content': _contentController.text.trim(),
        'rating': _rating,
        'imageUrl': imageUrl,
        'likesCount': 0,
        'commentsCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Si el restaurante está registrado, actualizar el promedio de calificaciones y conteo de reseñas
      if (restaurantId != null && restaurantId.isNotEmpty) {
        try {
          final restRef = FirebaseFirestore.instance.collection('restaurants').doc(restaurantId);
          final restDoc = await restRef.get();
          if (restDoc.exists) {
            final data = restDoc.data() ?? {};
            final currentCount = (data['reviewsCount'] as num?)?.toInt() ?? 0;
            final currentRating = (data['ratingAverage'] as num?)?.toDouble() ?? 5.0;
            final newCount = currentCount + 1;
            final newRating = ((currentRating * currentCount) + _rating) / newCount;

            await restRef.update({
              'reviewsCount': newCount,
              'ratingAverage': double.parse(newRating.toStringAsFixed(1)),
            });
          }
        } catch (_) {}
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Reseña publicada exitosamente!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al crear reseña: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Reseña Gastronómica'),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _submit,
              child: const Text(
                'Publicar',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
              ),
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
              // Selector de Imagen
              GestureDetector(
                onTap: _showPickerOptions,
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[300]!),
                    image: _pickedXFile != null
                        ? DecorationImage(
                            image: NetworkImage(_pickedXFile!.path),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _pickedXFile == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_a_photo_rounded, size: 44, color: AppColors.primary),
                            const SizedBox(height: 8),
                            Text('Toca para añadir una foto de tu experiencia', style: AppTextStyles.subtle),
                          ],
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 24),

              // Selector de Restaurante Registrado / Manual
              Text('Restaurante Gastronómico', style: AppTextStyles.title),
              const SizedBox(height: 8),
              if (_loadingRestaurants)
                const LinearProgressIndicator(color: AppColors.primary)
              else Column(
                children: [
                  if (!_isManualRestaurant && _registeredRestaurants.isNotEmpty) ...[
                    DropdownButtonFormField<RestaurantModel>(
                      value: _selectedRestaurant,
                      decoration: const InputDecoration(
                        labelText: 'Selecciona un restaurante registrado en Bogotá',
                        prefixIcon: Icon(Icons.storefront_rounded, color: AppColors.primary),
                      ),
                      items: [
                        ..._registeredRestaurants.map((r) => DropdownMenuItem(
                              value: r,
                              child: Text('${r.name} - ${r.category}'),
                            )),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedRestaurant = val;
                          if (val != null) {
                            _addressController.text = val.address;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _isManualRestaurant = true;
                            _customRestaurantController.clear();
                            _addressController.clear();
                          });
                        },
                        icon: const Icon(Icons.edit_note_rounded, size: 18),
                        label: const Text('¿No aparece en la lista? Escribir manualmente'),
                      ),
                    ),
                  ] else ...[
                    TextFormField(
                      controller: _customRestaurantController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del restaurante',
                        hintText: 'Ej. La Puerta Falsa',
                        prefixIcon: Icon(Icons.edit_outlined, color: AppColors.primary),
                      ),
                      validator: (v) => _isManualRestaurant && (v == null || v.trim().isEmpty)
                          ? 'Ingresa el nombre del lugar'
                          : null,
                    ),
                    if (_registeredRestaurants.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _isManualRestaurant = false;
                              if (_selectedRestaurant != null) {
                                _addressController.text = _selectedRestaurant!.address;
                              }
                            });
                          },
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: const Text('Volver a seleccionar de la lista'),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Selector de Ciudad / Zona
              Text('Ciudad / Zona', style: AppTextStyles.title),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCity,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.location_city_rounded, color: AppColors.primary),
                ),
                items: _cities
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCity = val);
                },
              ),
              const SizedBox(height: 16),

              // Dirección / Ubicación
              Text('Dirección o Punto de Referencia', style: AppTextStyles.title),
              const SizedBox(height: 8),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  hintText: 'Ej. Calle 11 # 6-50, La Candelaria',
                  prefixIcon: Icon(Icons.pin_drop_rounded, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 16),

              // Calificación
              Text('Calificación de la Experiencia', style: AppTextStyles.title),
              const SizedBox(height: 8),
              Row(
                children: [
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
                  const SizedBox(width: 12),
                  Text('$_rating ★', style: AppTextStyles.title.copyWith(color: AppColors.accent)),
                ],
              ),
              const SizedBox(height: 16),

              // Comentario / Experiencia
              Text('Comentario & Reseña', style: AppTextStyles.title),
              const SizedBox(height: 8),
              TextFormField(
                controller: _contentController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Cuéntale a la comunidad de Bogotá qué tal estuvo la atención, los sabores y el ambiente...',
                ),
                validator: (v) => v!.trim().isEmpty ? 'Ingresa tu comentario sobre la experiencia' : null,
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
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: const Text('Galería de fotos'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              title: const Text('Tomar foto con cámara'),
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
