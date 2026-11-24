import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../core/services/api_service.dart';
import '../../models/menu_item_model.dart';
import '../../models/restaurant_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/cloudinary_service.dart';

class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  RestaurantModel? _restaurant;
  List<MenuItemModel> _menuItems = [];
  bool _loading = true;
  String _selectedCategory = 'Todas';
  final ApiService _apiService = ApiService();

  static const List<String> _categories = [
    'Todas',
    'Entradas',
    'Platos Fuertes',
    'Postres',
    'Bebidas',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    try {
      final list = await _apiService.getRestaurants();
      if (list.isNotEmpty) {
        // FALLO-21 Fix: Filtrar el restaurante por el propietario autenticado
        final myRest = list.firstWhere(
          (r) => r.ownerId == user.id,
          orElse: () => list.first,
        );
        final menu = await _apiService.getMenu(myRest.id);
        if (mounted) {
          setState(() {
            _restaurant = myRest;
            _menuItems = menu;
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_restaurant == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.storefront_outlined, size: 64, color: AppColors.textSecondary),
                const SizedBox(height: 16),
                Text('Primero debes registrar tu restaurante', style: AppTextStyles.title),
                const SizedBox(height: 8),
                Text(
                  'Dirígete a la pestaña "Mi Restaurante" para registrar los datos iniciales de tu establecimiento.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subtle,
                ),
              ],
            ),
          ),
        ),
      );
    }

    List<MenuItemModel> items = _menuItems;
    if (_selectedCategory != 'Todas') {
      items = items.where((i) => i.category == _selectedCategory).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Menú — ${_restaurant!.name}'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar Plato'),
        onPressed: () => _showAddEditDialog(context),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: _categories.map((cat) {
                final selected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: selected,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppColors.textPrimary,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.restaurant_menu_rounded, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text('No hay platos en esta categoría', style: AppTextStyles.subtle),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final item = items[i];
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 60,
                              height: 60,
                              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                                  ? Image.network(item.imageUrl!, fit: BoxFit.cover)
                                  : Container(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      child: const Icon(Icons.fastfood_rounded, color: AppColors.primary),
                                    ),
                            ),
                          ),
                          title: Text(item.name, style: AppTextStyles.title.copyWith(fontSize: 15)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (item.description.isNotEmpty)
                                Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption),
                              const SizedBox(height: 4),
                              Text(
                                '\$${item.price.toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 14),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: item.isAvailable,
                                activeColor: AppColors.primary,
                                onChanged: (val) {
                                  setState(() {
                                    final idx = _menuItems.indexWhere((m) => m.id == item.id);
                                    if (idx != -1) {
                                      _menuItems[idx] = item.copyWith(isAvailable: val);
                                    }
                                  });
                                },
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded),
                                onSelected: (val) {
                                  if (val == 'edit') {
                                    _showAddEditDialog(context, item: item);
                                  } else if (val == 'delete') {
                                    _deleteItem(item);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                                  const PopupMenuItem(value: 'delete', child: Text('Eliminar', style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _deleteItem(MenuItemModel item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar plato'),
        content: Text('¿Deseas eliminar "${item.name}" del menú?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() => _menuItems.removeWhere((m) => m.id == item.id));
              Navigator.pop(ctx);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddEditDialog(BuildContext context, {MenuItemModel? item}) {
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final descCtrl = TextEditingController(text: item?.description ?? '');
    final priceCtrl = TextEditingController(text: item != null ? item.price.toStringAsFixed(0) : '');
    String cat = item?.category ?? 'Platos Fuertes';
    XFile? pickedFile;
    String? existingUrl = item?.imageUrl;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setStateModal) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx2).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item == null ? 'Nuevo Plato' : 'Editar Plato', style: AppTextStyles.headline),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    final p = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
                    if (p != null) setStateModal(() => pickedFile = p);
                  },
                  child: Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: pickedFile != null
                        ? Image.network(pickedFile!.path, fit: BoxFit.cover)
                        : (existingUrl != null && existingUrl.isNotEmpty
                            ? Image.network(existingUrl, fit: BoxFit.cover)
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_outlined, color: AppColors.primary),
                                  SizedBox(height: 4),
                                  Text('Seleccionar imagen'),
                                ],
                              )),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre del plato')),
                const SizedBox(height: 12),
                TextField(controller: descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Descripción')),
                const SizedBox(height: 12),
                TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Precio (\$)')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: cat,
                  items: _categories.where((c) => c != 'Todas').map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) {
                    if (val != null) setStateModal(() => cat = val);
                  },
                  decoration: const InputDecoration(labelText: 'Categoría'),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
                      String? finalUrl = existingUrl;

                      if (pickedFile != null) {
                        final uploaded = await CloudinaryService.uploadImageXFile(pickedFile!);
                        if (uploaded != null) finalUrl = uploaded;
                      }

                      final newItem = MenuItemModel(
                        id: item?.id ?? 'm_${DateTime.now().millisecondsSinceEpoch}',
                        restaurantId: _restaurant!.id,
                        name: nameCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        price: price,
                        category: cat,
                        imageUrl: finalUrl,
                        isAvailable: item?.isAvailable ?? true,
                      );

                      if (item == null) {
                        setState(() => _menuItems.add(newItem));
                      } else {
                        setState(() {
                          final idx = _menuItems.indexWhere((m) => m.id == item.id);
                          if (idx != -1) _menuItems[idx] = newItem;
                        });
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Text(item == null ? 'Guardar Plato' : 'Actualizar', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
