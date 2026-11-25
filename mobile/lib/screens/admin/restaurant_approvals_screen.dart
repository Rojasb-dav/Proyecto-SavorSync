import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../core/services/api_service.dart';
import '../../models/restaurant_model.dart';

class RestaurantApprovalsScreen extends StatefulWidget {
  const RestaurantApprovalsScreen({super.key});

  @override
  State<RestaurantApprovalsScreen> createState() => _RestaurantApprovalsScreenState();
}

class _RestaurantApprovalsScreenState extends State<RestaurantApprovalsScreen> {
  final ApiService _apiService = ApiService();
  List<RestaurantModel> _restaurants = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  Future<void> _loadRestaurants() async {
    try {
      final list = await _apiService.getRestaurants();
      if (mounted) {
        setState(() {
          _restaurants = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteRestaurant(RestaurantModel r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Restaurante Definitivamente'),
        content: Text('¿Seguro que deseas eliminar el restaurante "${r.name}"? Esta acción eliminará el local de la plataforma.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar Local 🗑️', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _apiService.dio.delete('/restaurants/${r.id}');
      _loadRestaurants();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restaurante "${r.name}" eliminado definitivamente')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar restaurante: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _showInspectModal(BuildContext context, RestaurantModel r) {
    final canDelete = context.read<AuthProvider>().user?.role == 'admin_sistema';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: CachedNetworkImage(
                      imageUrl: r.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: AppColors.background),
                      errorWidget: (_, __, ___) => Container(color: AppColors.background, child: const Icon(Icons.broken_image)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(r.name, style: AppTextStyles.headline.copyWith(fontSize: 20))),
                          Chip(
                            label: Text(r.status.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                            backgroundColor: r.status == 'activo' ? Colors.green : Colors.orange.shade800,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _detailRow(Icons.category_rounded, 'Categoría', r.category),
                      _detailRow(Icons.location_on_rounded, 'Dirección', r.address),
                      _detailRow(Icons.phone_rounded, 'Teléfono', r.phone),
                      const SizedBox(height: 12),
                      Text('Descripción y Concepto Culinario:', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(r.description, style: AppTextStyles.body),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          if (canDelete) IconButton(
            icon: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
            tooltip: 'Eliminar Local Definitivamente',
            onPressed: () {
              Navigator.pop(ctx);
              _deleteRestaurant(r);
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            label: const Text('Aprobar y Activar Local', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () async {
              await _apiService.updateRestaurantStatus(r.id, 'activo');
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _loadRestaurants();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Restaurante aprobado y publicado en vivo para Foodies'), backgroundColor: Colors.green),
              );
            },
          ),
        ],
      ),
    );
  }

  static Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text('$label: ', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, style: AppTextStyles.body.copyWith(fontSize: 13), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canDelete = context.watch<AuthProvider>().user?.role == 'admin_sistema';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aprobación y Gobierno de Restaurantes'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.storefront_rounded, color: Colors.green, size: 24),
                      const SizedBox(width: 8),
                      Text('Restaurantes Registrados (${_restaurants.length})', style: AppTextStyles.title),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _restaurants.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final r = _restaurants[i];

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.storefront_rounded, color: Colors.green, size: 32),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.name, style: AppTextStyles.title),
                                  Text('${r.category} • ${r.address}', style: AppTextStyles.caption),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _showInspectModal(context, r),
                              icon: const Icon(Icons.search_rounded, size: 16),
                              label: const Text('Ver Ficha 🔍', style: TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 8),
                            if (canDelete) IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                              tooltip: 'Eliminar Restaurante Definitivamente',
                              onPressed: () => _deleteRestaurant(r),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
