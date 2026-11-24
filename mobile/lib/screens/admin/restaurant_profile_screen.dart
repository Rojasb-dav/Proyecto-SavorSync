import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../core/services/api_service.dart';
import '../../models/post_model.dart';
import '../../providers/auth_provider.dart';

class RestaurantProfileScreen extends StatefulWidget {
  const RestaurantProfileScreen({super.key});

  @override
  State<RestaurantProfileScreen> createState() => _RestaurantProfileScreenState();
}

class _RestaurantProfileScreenState extends State<RestaurantProfileScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  List<PostModel> _promotions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPromotions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPromotions() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      final posts = await _apiService.getUserPosts(user.id);
      setState(() {
        _promotions = posts;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _showCreatePromotionDialog() async {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final imageCtrl = TextEditingController();
    double rating = 5.0;
    bool isSaving = false;

    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.local_offer_rounded, color: AppColors.primary, size: 26),
              const SizedBox(width: 10),
              Text('Crear Promoción u Oferta', style: AppTextStyles.title),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Título de la Promoción (Ej. 2x1 en Hamburguesas Gourmet)',
                      hintText: 'Ej. Noche de Cócteles 2x1',
                    ),
                    validator: (v) => v!.trim().isEmpty ? 'Ingresa el título' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: contentCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Descripción y Condiciones de la Oferta',
                      hintText: 'Válido de Lunes a Jueves. Aplica para consumo en el local.',
                    ),
                    validator: (v) => v!.trim().isEmpty ? 'Ingresa la descripción' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: imageCtrl,
                    decoration: const InputDecoration(
                      labelText: 'URL de Imagen de Portada (Opcional)',
                      hintText: 'https://images.unsplash.com/...',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDlgState(() => isSaving = true);
                      try {
                        final img = imageCtrl.text.trim().isNotEmpty
                            ? imageCtrl.text.trim()
                            : 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=800&q=80';

                        await _apiService.createPost({
                          'restaurantName': titleCtrl.text.trim(),
                          'restaurantAddress': 'Establecimiento Oficial',
                          'content': contentCtrl.text.trim(),
                          'rating': rating,
                          'imageUrl': img,
                          'userId': user.id,
                        });

                        if (!mounted) return;
                        Navigator.pop(dialogCtx);
                        _loadPromotions();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('¡Promoción publicada en vivo!'), backgroundColor: Colors.green),
                        );
                      } catch (e) {
                        setDlgState(() => isSaving = false);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error al crear promoción: $e')),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Publicar Oferta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil Institucional del Restaurante'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: _showCreatePromotionDialog,
              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
              label: const Text('+ Crear Promoción / Novedad', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera Institucional del Restaurante
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.divider),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 2),
                    ),
                    child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 38),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(user?.fullName ?? 'Mi Restaurante', style: AppTextStyles.headline.copyWith(fontSize: 22)),
                            const SizedBox(width: 10),
                            const Chip(
                              label: Text('APROBADO & ACTIVO 🟢', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                              backgroundColor: Colors.green,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('@${user?.username ?? 'restaurante'} • ${user?.email ?? ''}', style: AppTextStyles.caption),
                        const SizedBox(height: 8),
                        Text(
                          user?.bio ?? 'Establecimiento gastronómico verificado en Bogotá SavorSync.',
                          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Pestañas
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              tabs: const [
                Tab(icon: Icon(Icons.campaign_rounded), text: 'Novedades y Promociones Activas'),
                Tab(icon: Icon(Icons.info_outline_rounded), text: 'Información del Local'),
              ],
            ),
            const SizedBox(height: 20),

            SizedBox(
              height: 500,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Promociones Activas
                  _loading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                      : _promotions.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.local_offer_outlined, size: 60, color: AppColors.textSecondary),
                                  const SizedBox(height: 12),
                                  Text('Aún no has publicado promociones u ofertas', style: AppTextStyles.title),
                                  const SizedBox(height: 6),
                                  Text('Crea tu primera oferta especial usando el botón superior "+ Crear Promoción"', style: AppTextStyles.subtle),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: _promotions.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 16),
                              itemBuilder: (ctx, index) {
                                final promo = _promotions[index];
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppColors.divider),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          promo.imageUrl,
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            width: 100,
                                            height: 100,
                                            color: AppColors.background,
                                            child: const Icon(Icons.broken_image),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(promo.restaurantName, style: AppTextStyles.title.copyWith(fontSize: 16)),
                                            const SizedBox(height: 4),
                                            Text(promo.content, style: AppTextStyles.body),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primary),
                                                const SizedBox(width: 4),
                                                Text('Publicado el ${promo.createdAt.day}/${promo.createdAt.month}/${promo.createdAt.year}',
                                                    style: AppTextStyles.caption),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                                        tooltip: 'Eliminar Promoción',
                                        onPressed: () async {
                                          await _apiService.deletePost(promo.id);
                                          _loadPromotions();
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),

                  // Tab 2: Información del Local
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Detalles del Establecimiento', style: AppTextStyles.title),
                        const SizedBox(height: 16),
                        _infoTile(Icons.storefront_rounded, 'Nombre Oficial', user?.fullName ?? 'Restaurante SavorSync'),
                        _infoTile(Icons.alternate_email_rounded, 'Identificador', '@${user?.username ?? 'restaurante'}'),
                        _infoTile(Icons.email_outlined, 'Correo Oficial', user?.email ?? 'contacto@restaurante.com'),
                        _infoTile(Icons.verified_user_outlined, 'Rol en Plataforma', 'Administrador de Restaurante 🏪'),
                        _infoTile(Icons.security_rounded, 'Nivel de Cuenta', 'Propietario Verificado (1:N Admin IDs)'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Text('$title: ', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, fontSize: 13)),
          Expanded(child: Text(value, style: AppTextStyles.body.copyWith(fontSize: 13), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
