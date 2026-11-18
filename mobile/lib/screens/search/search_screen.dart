import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../models/restaurant_model.dart';
import '../restaurants/restaurant_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<RestaurantModel> _allRestaurants = [];
  List<RestaurantModel> _filteredRestaurants = [];
  String _selectedCategory = 'Todos';
  bool _loading = true;

  final List<String> _categories = const [
    'Todos',
    'Parrilla',
    'Postres',
    'Asiática',
    'Hamburguesas',
    'Italiana',
  ];

  final List<RestaurantModel> _seedRestaurants = const [
    RestaurantModel(
      id: 'res_1',
      name: 'Andrés Carne de Res',
      description: 'Icónico restaurante colombiano con música, parrilla y excelente ambiente.',
      address: 'Calle 82 # 12-21, Zona T, Bogotá',
      category: 'Parrilla',
      latitude: 4.6669,
      longitude: -74.0545,
      ratingAverage: 4.8,
      reviewsCount: 128,
      imageUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=800&q=80',
    ),
    RestaurantModel(
      id: 'res_2',
      name: 'Crepes & Waffles',
      description: 'Famosos crepes salados, dulces y helados artesanales en Bogotá.',
      address: 'Carrera 11 # 85-09, Bogotá',
      category: 'Postres',
      latitude: 4.6702,
      longitude: -74.0583,
      ratingAverage: 4.7,
      reviewsCount: 215,
      imageUrl: 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?auto=format&fit=crop&w=800&q=80',
    ),
    RestaurantModel(
      id: 'res_3',
      name: 'Wok Zona G',
      description: 'Gastronomía asiática sustentable y variada en el corazón gourmet de la ciudad.',
      address: 'Carrera 5 # 69-10, Zona G, Bogotá',
      category: 'Asiática',
      latitude: 4.6521,
      longitude: -74.0551,
      ratingAverage: 4.6,
      reviewsCount: 94,
      imageUrl: 'https://images.unsplash.com/photo-1512058564366-18510be2db19?auto=format&fit=crop&w=800&q=80',
    ),
    RestaurantModel(
      id: 'res_4',
      name: 'El Corral Gourmet',
      description: 'Hamburguesas premium con ingredientes seleccionados y papas en cascos.',
      address: 'Calle 93 # 12-11, Parque de la 93, Bogotá',
      category: 'Hamburguesas',
      latitude: 4.6761,
      longitude: -74.0482,
      ratingAverage: 4.5,
      reviewsCount: 110,
      imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=800&q=80',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  Future<void> _loadRestaurants() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('restaurants').get();
      List<RestaurantModel> list = [];
      if (snapshot.docs.isNotEmpty) {
        list = snapshot.docs
            .map((doc) => RestaurantModel.fromJson({'id': doc.id, ...doc.data()}))
            .toList();
      } else {
        list = _seedRestaurants;
      }
      if (mounted) {
        setState(() {
          _allRestaurants = list;
          _filteredRestaurants = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _allRestaurants = _seedRestaurants;
          _filteredRestaurants = _seedRestaurants;
          _loading = false;
        });
      }
    }
  }

  void _applyFilters() {
    final query = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filteredRestaurants = _allRestaurants.where((r) {
        final matchesQuery = query.isEmpty ||
            r.name.toLowerCase().contains(query) ||
            r.address.toLowerCase().contains(query) ||
            r.category.toLowerCase().contains(query);
        final matchesCategory =
            _selectedCategory == 'Todos' || r.category == _selectedCategory;
        return matchesQuery && matchesCategory;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextFormField(
                controller: _searchCtrl,
                onChanged: (_) => _applyFilters(),
                decoration: InputDecoration(
                  hintText: 'Buscar restaurantes o comida...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchCtrl.clear();
                            _applyFilters();
                          },
                        )
                      : null,
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final cat = _categories[i];
                  final isSelected = cat == _selectedCategory;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedCategory = cat);
                        _applyFilters();
                      }
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _filteredRestaurants.isEmpty
                      ? const Center(child: Text('No se encontraron restaurantes'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredRestaurants.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final r = _filteredRestaurants[i];
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RestaurantDetailScreen(restaurant: r),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.divider),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: CachedNetworkImage(
                                        imageUrl: r.imageUrl,
                                        width: 84,
                                        height: 84,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(r.name, style: AppTextStyles.title),
                                          const SizedBox(height: 2),
                                          Text(r.category, style: AppTextStyles.caption.copyWith(color: AppColors.primary)),
                                          const SizedBox(height: 4),
                                          Text(r.address, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              RatingBarIndicator(
                                                rating: r.ratingAverage,
                                                itemBuilder: (context, index) => const Icon(
                                                  Icons.star_rounded,
                                                  color: AppColors.accent,
                                                ),
                                                itemCount: 5,
                                                itemSize: 16.0,
                                              ),
                                              const SizedBox(width: 6),
                                              Text('${r.ratingAverage.toStringAsFixed(1)} (${r.reviewsCount})', style: AppTextStyles.caption),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
