import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
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
  bool _loading = true;
  String _selectedCategory = 'Todas';

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
        setState(() {
          _restaurant = RestaurantModel.fromJson({'id': doc.id, ...doc.data()});
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
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

    return Scaffold(
      appBar: AppBar(
        title: Text('Gestión del Menú - ${_restaurant!.name}', style: AppTextStyles.headline),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => _showAddEditItemDialog(),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Agregar Plato', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Carta & Menú Gastronómico', style: AppTextStyles.headline),
                        const SizedBox(height: 4),
                        Text(
                          'Administra los platillos, precios e imágenes disponibles para tus clientes.',
                          style: AppTextStyles.subtle,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Filtro de Categorías
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
                      final isSel = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          selected: isSel,
                          label: Text(cat),
                          selectedColor: AppColors.primary.withValues(alpha: 0.15),
                          checkmarkColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSel ? AppColors.primary : AppColors.textPrimary,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (_) => setState(() => _selectedCategory = cat),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                // Lista de Menú
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('restaurants')
                        .doc(_restaurant!.id)
                        .collection('menu')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                      }

                      final docs = snapshot.data?.docs ?? [];
                      List<MenuItemModel> items = docs
                          .map((d) => MenuItemModel.fromJson({'id': d.id, ...d.data() as Map<String, dynamic>}))
                          .toList();

                      if (_selectedCategory != 'Todas') {
                        items = items.where((i) => i.category == _selectedCategory).toList();
                      }

                      if (items.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.restaurant_outlined, size: 54, color: AppColors.textSecondary),
                              const SizedBox(height: 12),
                              Text('No hay platillos en esta categoría', style: AppTextStyles.title),
                              const SizedBox(height: 4),
                              Text('Haz clic en "+ Agregar Plato" para crear tu primer ítem.', style: AppTextStyles.subtle),
                            ],
                          ),
                        );
                      }

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          int crossAxisCount = 1;
                          if (constraints.maxWidth > 900) {
                            crossAxisCount = 3;
                          } else if (constraints.maxWidth > 600) {
                            crossAxisCount = 2;
                          }

                          return GridView.builder(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1.15,
                            ),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return _MenuItemCard(
                                item: item,
                                onEdit: () => _showAddEditItemDialog(item: item),
                                onDelete: () => _deleteMenuItem(item),
                                onToggleAvailable: (val) => _toggleAvailability(item, val),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleAvailability(MenuItemModel item, bool isAvailable) async {
    try {
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(_restaurant!.id)
          .collection('menu')
          .doc(item.id)
          .update({'isAvailable': isAvailable});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar disponibilidad: $e')),
        );
      }
    }
  }

  Future<void> _deleteMenuItem(MenuItemModel item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Platillo'),
        content: Text('¿Seguro que deseas eliminar "${item.name}" del menú?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('restaurants')
            .doc(_restaurant!.id)
            .collection('menu')
            .doc(item.id)
            .delete();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e')),
          );
        }
      }
    }
  }

  Future<void> _showAddEditItemDialog({MenuItemModel? item}) async {
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final descCtrl = TextEditingController(text: item?.description ?? '');
    final priceCtrl = TextEditingController(text: item?.price.toString() ?? '');
    String category = item?.category ?? 'Platos Fuertes';
    XFile? pickedImage;
    String? imageUrl = item?.imageUrl;
    bool saving = false;

    final picker = ImagePicker();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(item == null ? 'Nuevo Platillo' : 'Editar Platillo'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 480,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Imagen del Plato
                      GestureDetector(
                        onTap: () async {
                          final file = await picker.pickImage(source: ImageSource.gallery);
                          if (file != null) {
                            setModalState(() => pickedImage = file);
                          }
                        },
                        child: Container(
                          height: 140,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.divider),
                            image: pickedImage != null
                                ? DecorationImage(image: NetworkImage(pickedImage!.path), fit: BoxFit.cover)
                                : (imageUrl != null && imageUrl!.isNotEmpty
                                    ? DecorationImage(image: NetworkImage(imageUrl!), fit: BoxFit.cover)
                                    : null),
                          ),
                          child: (pickedImage == null && (imageUrl == null || imageUrl!.isEmpty))
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.add_a_photo_outlined, size: 36, color: AppColors.textSecondary),
                                    const SizedBox(height: 6),
                                    Text('Seleccionar foto del plato (Cloudinary)', style: AppTextStyles.caption),
                                  ],
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Nombre del plato *'),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: descCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Descripción / Ingredientes'),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: priceCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Precio (COP) *', prefixText: '\$ '),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: category,
                              decoration: const InputDecoration(labelText: 'Categoría'),
                              items: ['Entradas', 'Platos Fuertes', 'Postres', 'Bebidas']
                                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) setModalState(() => category = v);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (nameCtrl.text.trim().isEmpty || priceCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Ingresa nombre y precio del plato')),
                            );
                            return;
                          }

                          setModalState(() => saving = true);

                          try {
                            if (pickedImage != null) {
                              final uploadedUrl = await CloudinaryService.uploadImageXFile(pickedImage!);
                              if (uploadedUrl != null) {
                                imageUrl = uploadedUrl;
                              }
                            }

                            final data = {
                              'name': nameCtrl.text.trim(),
                              'description': descCtrl.text.trim(),
                              'price': double.tryParse(priceCtrl.text.trim()) ?? 0.0,
                              'category': category,
                              'imageUrl': imageUrl ?? '',
                              'isAvailable': item?.isAvailable ?? true,
                            };

                            final menuRef = FirebaseFirestore.instance
                                .collection('restaurants')
                                .doc(_restaurant!.id)
                                .collection('menu');

                            if (item == null) {
                              await menuRef.add(data);
                            } else {
                              await menuRef.doc(item.id).update(data);
                            }

                            if (context.mounted) Navigator.pop(context);
                          } catch (e) {
                            setModalState(() => saving = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error al guardar: $e')),
                              );
                            }
                          }
                        },
                  child: saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(item == null ? 'Guardar' : 'Actualizar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final MenuItemModel item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleAvailable;

  const _MenuItemCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleAvailable,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Foto
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              height: 110,
              width: double.infinity,
              color: Colors.grey.shade100,
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? Image.network(item.imageUrl!, fit: BoxFit.cover)
                  : const Center(
                      child: Icon(Icons.fastfood_rounded, size: 40, color: AppColors.textSecondary),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: AppTextStyles.title.copyWith(fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '\$ ${item.price.toStringAsFixed(0)}',
                      style: AppTextStyles.title.copyWith(color: AppColors.primary, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.description.isNotEmpty ? item.description : 'Sin descripción',
                  style: AppTextStyles.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Chip(
                      label: Text(item.category, style: const TextStyle(fontSize: 11)),
                      backgroundColor: AppColors.background,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    Row(
                      children: [
                        Switch(
                          value: item.isAvailable,
                          activeColor: AppColors.primary,
                          onChanged: onToggleAvailable,
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.textSecondary),
                          onPressed: onEdit,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
                          onPressed: onDelete,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
