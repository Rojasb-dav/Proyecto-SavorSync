import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../models/restaurant_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/cloudinary_service.dart';
import 'analytics_dashboard.dart';

class RestaurantAdminDashboard extends StatefulWidget {
  const RestaurantAdminDashboard({super.key});

  @override
  State<RestaurantAdminDashboard> createState() => _RestaurantAdminDashboardState();
}

class _RestaurantAdminDashboardState extends State<RestaurantAdminDashboard> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController(text: 'Lunes a Sábado 12:00 PM - 10:00 PM');

  RestaurantModel? _restaurant;
  XFile? _pickedImage;
  String? _imageUrl;
  double? _latitude;
  double? _longitude;
  bool _loading = true;
  bool _saving = false;
  bool _gettingLocation = false;

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _loadRestaurant();
  }

  Future<void> _loadRestaurant() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    try {
      if (user.restaurantId != null && user.restaurantId!.isNotEmpty) {
        final doc = await FirebaseFirestore.instance.collection('restaurants').doc(user.restaurantId).get();
        if (doc.exists) {
          final res = RestaurantModel.fromJson({'id': doc.id, ...doc.data()!});
          _setRestaurantData(res);
          return;
        }
      }

      var query = await FirebaseFirestore.instance
          .collection('restaurants')
          .where('ownerId', isEqualTo: user.id)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        query = await FirebaseFirestore.instance
            .collection('restaurants')
            .where('adminIds', arrayContains: user.id)
            .limit(1)
            .get();
      }

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final res = RestaurantModel.fromJson({'id': doc.id, ...doc.data()});
        _setRestaurantData(res);
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setRestaurantData(RestaurantModel res) {
    setState(() {
      _restaurant = res;
      _nameCtrl.text = res.name;
      _addressCtrl.text = res.address;
      _categoryCtrl.text = res.category;
      _descCtrl.text = res.description;
      _phoneCtrl.text = res.phone;
      _imageUrl = res.imageUrl;
      _latitude = res.latitude;
      _longitude = res.longitude;
      _loading = false;
    });
  }

  Future<void> _fetchCurrentGpsAddress() async {
    setState(() => _gettingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Por favor activa los servicios de ubicación GPS en tu dispositivo')),
          );
        }
        setState(() => _gettingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _gettingLocation = false);
          return;
        }
      }

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _latitude = pos.latitude;
      _longitude = pos.longitude;

      _mapController.move(LatLng(pos.latitude, pos.longitude), 15.0);

      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${pos.latitude}&lon=${pos.longitude}&zoom=18&addressdetails=1',
      );
      final response = await http.get(url, headers: {'User-Agent': 'SavorSync-App/1.0 (co.edu.umb.savorsync)'});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final addressObj = data['address'] as Map<String, dynamic>?;
        final road = addressObj?['road'] ?? addressObj?['pedestrian'] ?? addressObj?['suburb'] ?? '';
        final houseNumber = addressObj?['house_number'] ?? '';
        final neighbourhood = addressObj?['neighbourhood'] ?? addressObj?['suburb'] ?? addressObj?['city_district'] ?? 'Bogotá';

        String formattedAddress = data['display_name'] ?? '';
        if (road.isNotEmpty) {
          formattedAddress = '$road $houseNumber, $neighbourhood, Bogotá'.replaceAll(' ,', ',');
        }

        if (mounted) {
          setState(() {
            _addressCtrl.text = formattedAddress;
            _gettingLocation = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dirección y coordenadas GPS capturadas con éxito 📍'), backgroundColor: Colors.green),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _gettingLocation = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _gettingLocation = false);
      }
    }
  }

  Future<void> _geocodeAddressIfNeeded(String address) async {
    try {
      final queryUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent('$address, Bogotá, Colombia')}&format=json&limit=1',
      );
      final response = await http.get(queryUrl, headers: {'User-Agent': 'SavorSync-App/1.0 (co.edu.umb.savorsync)'});
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        if (list.isNotEmpty) {
          final first = list.first as Map<String, dynamic>;
          final lat = double.tryParse(first['lat'] as String? ?? '');
          final lon = double.tryParse(first['lon'] as String? ?? '');
          if (lat != null && lon != null) {
            setState(() {
              _latitude = lat;
              _longitude = lon;
            });
            _mapController.move(LatLng(lat, lon), 15.0);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _pickCoverImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() => _pickedImage = picked);
    }
  }

  Future<void> _showInviteCoAdminDialog() async {
    if (_restaurant == null) return;
    final emailCtrl = TextEditingController();
    bool loading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.group_add_rounded, color: AppColors.primary, size: 26),
              const SizedBox(width: 10),
              Text('Vincular Co-Administrador', style: AppTextStyles.title),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ingresa el correo del usuario para vincularlo como co-administrador de este establecimiento:',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico del usuario',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    '🛡️ Regla de Seguridad 1:N: Un restaurante puede tener múltiples administradores, pero un usuario sólo puede pertenecer a 1 restaurante.',
                    style: TextStyle(color: Colors.orange.shade900, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: loading
                  ? null
                  : () async {
                      final email = emailCtrl.text.trim();
                      if (email.isEmpty) return;
                      setDlgState(() => loading = true);

                      try {
                        final userSnap = await FirebaseFirestore.instance
                            .collection('users')
                            .where('email', isEqualTo: email)
                            .limit(1)
                            .get();

                        if (userSnap.docs.isEmpty) {
                          setDlgState(() => loading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No existe un usuario con ese correo registrado')),
                          );
                          return;
                        }

                        final targetUserDoc = userSnap.docs.first;
                        final targetUserData = targetUserDoc.data();
                        final targetUserId = targetUserDoc.id;
                        final existingResId = targetUserData['restaurantId'] as String?;

                        if (existingResId != null && existingResId.isNotEmpty && existingResId != _restaurant!.id) {
                          setDlgState(() => loading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('⚠️ Seguridad: Este usuario ya administra otro restaurante.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        await FirebaseFirestore.instance.collection('restaurants').doc(_restaurant!.id).update({
                          'adminIds': FieldValue.arrayUnion([targetUserId]),
                        });

                        await FirebaseFirestore.instance.collection('users').doc(targetUserId).update({
                          'role': 'restaurant_admin',
                          'restaurantId': _restaurant!.id,
                        });

                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        _loadRestaurant();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Co-administrador $email vinculado exitosamente'), backgroundColor: Colors.green),
                        );
                      } catch (e) {
                        setDlgState(() => loading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error al vincular: $e')),
                        );
                      }
                    },
              child: loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Vincular Admin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveRestaurant() async {
    if (!_formKey.currentState!.validate()) return;
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    // Verificar si el usuario ya administra OTRO restaurante
    if (user.restaurantId != null && user.restaurantId!.isNotEmpty && _restaurant != null && user.restaurantId != _restaurant!.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Regla de Seguridad 1:N: Ya administras otro establecimiento. No puedes crear un segundo restaurante.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      String? finalImageUrl = _imageUrl;
      if (_pickedImage != null) {
        final uploaded = await CloudinaryService.uploadImageXFile(_pickedImage!);
        if (uploaded != null) {
          finalImageUrl = uploaded;
        }
      }

      if (_latitude == null || _longitude == null) {
        await _geocodeAddressIfNeeded(_addressCtrl.text.trim());
      }

      final statusToSave = _restaurant?.status ?? 'pendiente';
      final List<String> currentAdminIds = _restaurant?.adminIds ?? [];
      if (!currentAdminIds.contains(user.id)) {
        currentAdminIds.add(user.id);
      }

      final data = {
        'ownerId': _restaurant?.ownerId.isNotEmpty == true ? _restaurant!.ownerId : user.id,
        'adminIds': currentAdminIds,
        'name': _nameCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'category': _categoryCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'openingHours': _hoursCtrl.text.trim(),
        'imageUrl': finalImageUrl ?? 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=800&q=80',
        'latitude': _latitude ?? 4.6669,
        'longitude': _longitude ?? -74.0545,
        'status': statusToSave,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_restaurant != null) {
        await FirebaseFirestore.instance
            .collection('restaurants')
            .doc(_restaurant!.id)
            .update(data);
        _restaurant = RestaurantModel.fromJson({'id': _restaurant!.id, ...data});
      } else {
        final docRef = await FirebaseFirestore.instance.collection('restaurants').add(data);
        _restaurant = RestaurantModel.fromJson({'id': docRef.id, ...data});

        await FirebaseFirestore.instance.collection('users').doc(user.id).update({
          'restaurantId': docRef.id,
        });
      }

      if (!mounted) return;
      setState(() {
        _imageUrl = finalImageUrl;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Información del local actualizada con éxito en la plataforma'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }

    final isApproved = _restaurant?.status == 'activo' || _restaurant?.status == 'active';
    final currentLatLng = LatLng(_latitude ?? 4.6669, _longitude ?? -74.0545);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración del Establecimiento'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add_rounded, color: AppColors.primary),
            tooltip: 'Vincular Co-Administrador (1:N)',
            onPressed: _showInviteCoAdminDialog,
          ),
          IconButton(
            icon: const Icon(Icons.analytics_rounded, color: AppColors.primary),
            tooltip: 'Analítica BI',
            onPressed: () {
              if (_restaurant == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Guarda tu restaurante primero')),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AnalyticsDashboard(restaurant: _restaurant!),
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner de estado de aprobación
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isApproved ? Colors.green.shade50 : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isApproved ? Colors.green.shade300 : Colors.amber.shade300,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isApproved ? Icons.verified_rounded : Icons.pending_actions_rounded,
                              size: 32,
                              color: isApproved ? Colors.green.shade700 : Colors.amber.shade800,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _restaurant != null ? _restaurant!.name : 'Nuevo Restaurante',
                                style: AppTextStyles.title.copyWith(fontSize: 18),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Chip(
                              label: Text(
                                isApproved ? 'Aprobado y Activo' : 'Pendiente de Aprobación',
                                style: TextStyle(
                                  color: isApproved ? Colors.green.shade900 : Colors.amber.shade900,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              backgroundColor: isApproved ? Colors.green.shade100 : Colors.amber.shade100,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isApproved
                              ? 'Tu restaurante es visible públicamente en el mapa e interactivo para reservas.'
                              : 'Tu registro está siendo revisado por el equipo de moderadores de SavorSync Bogotá.',
                          style: AppTextStyles.body.copyWith(fontSize: 13, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Foto de Portada con Cloudinary
                  Text('Foto de Portada HD (Cloudinary)', style: AppTextStyles.title),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickCoverImage,
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider),
                        image: _pickedImage != null
                            ? DecorationImage(image: NetworkImage(_pickedImage!.path), fit: BoxFit.cover)
                            : (_imageUrl != null && _imageUrl!.isNotEmpty
                                ? DecorationImage(image: NetworkImage(_imageUrl!), fit: BoxFit.cover)
                                : null),
                      ),
                      child: (_pickedImage == null && (_imageUrl == null || _imageUrl!.isEmpty))
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.cloud_upload_outlined, size: 48, color: AppColors.primary),
                                const SizedBox(height: 8),
                                Text('Haz clic para cambiar o subir imagen de portada', style: AppTextStyles.caption),
                              ],
                            )
                          : Stack(
                              children: [
                                Positioned(
                                  right: 12,
                                  bottom: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                                        SizedBox(width: 6),
                                        Text('Cambiar Imagen', style: TextStyle(color: Colors.white, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Formulario en Grilla/Filas
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 700;
                      return Column(
                        children: [
                          if (isWide)
                            Row(
                              children: [
                                Expanded(
                                  child: _buildFormField('Nombre del Establecimiento *', _nameCtrl, 'Ej. Andrés Carne de Res'),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildFormField('Categoría Gastronómica *', _categoryCtrl, 'Ej. Parrilla, Postres, Italiana'),
                                ),
                              ],
                            )
                          else ...[
                            _buildFormField('Nombre del Establecimiento *', _nameCtrl, 'Ej. Andrés Carne de Res'),
                            const SizedBox(height: 16),
                            _buildFormField('Categoría Gastronómica *', _categoryCtrl, 'Ej. Parrilla, Postres, Italiana'),
                          ],
                          const SizedBox(height: 16),

                          if (isWide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFormField('Dirección en Bogotá *', _addressCtrl, 'Ej. Calle 82 # 12-21, Zona T'),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          TextButton.icon(
                                            onPressed: _gettingLocation ? null : _fetchCurrentGpsAddress,
                                            icon: _gettingLocation
                                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                                                : const Icon(Icons.my_location_rounded, size: 16, color: AppColors.primary),
                                            label: Text(
                                              _gettingLocation ? 'Buscando GPS...' : '📍 Autocompletar por mi GPS',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          TextButton.icon(
                                            onPressed: () => _geocodeAddressIfNeeded(_addressCtrl.text.trim()),
                                            icon: const Icon(Icons.search_rounded, size: 16, color: Colors.blue),
                                            label: const Text('🔍 Ubicar en el mapa', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildFormField('Teléfono de Contacto', _phoneCtrl, 'Ej. +57 601 3000000', keyboardType: TextInputType.phone),
                                ),
                              ],
                            )
                          else ...[
                            _buildFormField('Dirección en Bogotá *', _addressCtrl, 'Ej. Calle 82 # 12-21, Zona T'),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: _gettingLocation ? null : _fetchCurrentGpsAddress,
                                  icon: _gettingLocation
                                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                                      : const Icon(Icons.my_location_rounded, size: 16, color: AppColors.primary),
                                  label: Text(
                                    _gettingLocation ? 'Buscando GPS...' : '📍 Autocompletar por mi GPS',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  onPressed: () => _geocodeAddressIfNeeded(_addressCtrl.text.trim()),
                                  icon: const Icon(Icons.search_rounded, size: 16, color: Colors.blue),
                                  label: const Text('🔍 Ubicar en el mapa', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildFormField('Teléfono de Contacto', _phoneCtrl, 'Ej. +57 601 3000000', keyboardType: TextInputType.phone),
                          ],
                          const SizedBox(height: 16),

                          // Mapa Interactivo para ajustar la posición exacta arrastrando el pin
                          Text('Ubicación Exacta en el Mapa (Toca el mapa para mover el pin 📍)', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              height: 220,
                              width: double.infinity,
                              decoration: BoxDecoration(border: Border.all(color: AppColors.divider)),
                              child: FlutterMap(
                                mapController: _mapController,
                                options: MapOptions(
                                  initialCenter: currentLatLng,
                                  initialZoom: 15.0,
                                  onTap: (tapPosition, point) {
                                    setState(() {
                                      _latitude = point.latitude;
                                      _longitude = point.longitude;
                                    });
                                  },
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'co.edu.umb.savorsync',
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: currentLatLng,
                                        width: 50,
                                        height: 50,
                                        child: const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 40),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          _buildFormField('Horarios de Atención', _hoursCtrl, 'Ej. Lunes a Sábado 12:00 PM - 10:00 PM'),
                          const SizedBox(height: 16),

                          _buildFormField('Descripción y Concepto Culinario', _descCtrl, 'Describe la experiencia para los comensales...', maxLines: 3),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _saveRestaurant,
                          icon: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.save_rounded),
                          label: const Text('Guardar Información del Local'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormField(
    String label,
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            alignLabelWithHint: maxLines > 1,
          ),
          validator: (v) {
            if (label.contains('*') && (v == null || v.trim().isEmpty)) {
              return 'Campo requerido';
            }
            return null;
          },
        ),
      ],
    );
  }
}
