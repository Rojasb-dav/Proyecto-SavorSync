import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../models/restaurant_model.dart';
import '../../providers/auth_provider.dart';
import 'analytics_dashboard.dart';
import 'restaurant_reservations_screen.dart';

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

  RestaurantModel? _restaurant;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadRestaurant();
  }

  Future<void> _loadRestaurant() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    try {
      final query = await FirebaseFirestore.instance
          .collection('restaurants')
          .where('ownerId', isEqualTo: user.id)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final res = RestaurantModel.fromJson({'id': doc.id, ...doc.data()});
        setState(() {
          _restaurant = res;
          _nameCtrl.text = res.name;
          _addressCtrl.text = res.address;
          _categoryCtrl.text = res.category;
          _descCtrl.text = res.description;
          _phoneCtrl.text = res.phone;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveRestaurant() async {
    if (!_formKey.currentState!.validate()) return;
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      final data = {
        'name': _nameCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'category': _categoryCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'ownerId': user.id,
        'status': 'active',
        'latitude': 4.6533,
        'longitude': -74.0621,
        'ratingAverage': _restaurant?.ratingAverage ?? 5.0,
        'reviewsCount': _restaurant?.reviewsCount ?? 0,
        'imageUrl': _restaurant?.imageUrl ??
            'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=800&q=80',
      };

      if (_restaurant != null) {
        await FirebaseFirestore.instance
            .collection('restaurants')
            .doc(_restaurant!.id)
            .update(data);
      } else {
        final docRef = await FirebaseFirestore.instance.collection('restaurants').add(data);
        _restaurant = RestaurantModel.fromJson({'id': docRef.id, ...data});
      }

      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restaurante guardado exitosamente'), backgroundColor: Colors.green),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Restaurante'),
        actions: [
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.storefront_rounded, size: 32, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _restaurant != null ? _restaurant!.name : 'Nuevo Restaurante',
                            style: AppTextStyles.title,
                          ),
                          Text(
                            'Panel de Administración y Métricas de Negocio',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Nombre del Establecimiento', style: AppTextStyles.title),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(hintText: 'Ej. Andrés Carne de Res'),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              Text('Categoría Gastronómica', style: AppTextStyles.title),
              const SizedBox(height: 8),
              TextFormField(
                controller: _categoryCtrl,
                decoration: const InputDecoration(hintText: 'Ej. Parrilla, Postres, Italiana'),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              Text('Dirección en Bogotá', style: AppTextStyles.title),
              const SizedBox(height: 8),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(hintText: 'Ej. Calle 82 # 12-21, Zona T'),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              Text('Teléfono de Contacto', style: AppTextStyles.title),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(hintText: 'Ej. +57 601 3000000'),
              ),
              const SizedBox(height: 16),
              Text('Descripción del Lugar', style: AppTextStyles.title),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Describe la experiencia y concepto culinario...'),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _saving ? null : _saveRestaurant,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded),
                label: const Text('Guardar Cambios'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  side: const BorderSide(color: AppColors.primary),
                ),
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
                      builder: (_) => RestaurantReservationsScreen(restaurantId: _restaurant!.id),
                    ),
                  );
                },
                icon: const Icon(Icons.event_seat_rounded, color: AppColors.primary),
                label: const Text('Gestionar Reservas Recibidas', style: TextStyle(color: AppColors.primary)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  side: const BorderSide(color: AppColors.primary),
                ),
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
                icon: const Icon(Icons.bar_chart_rounded, color: AppColors.primary),
                label: const Text('Ver Tablero de Analítica BI', style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
