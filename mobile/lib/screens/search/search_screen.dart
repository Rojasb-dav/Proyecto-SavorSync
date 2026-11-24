import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../core/services/api_service.dart';
import '../../models/restaurant_model.dart';
import '../../widgets/smart_recommendation_modal.dart';
import '../restaurants/restaurant_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ApiService _apiService = ApiService();
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
          _allRestaurants = list;
          _filteredRestaurants = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
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
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textPrimary;

    return Scaffold(
      appBar: AppBar(
        title: Text('Descubre Restaurantes', style: TextStyle(color: textColor)),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
            tooltip: 'Recomendador IA por Presupuesto y Ocasión',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const SmartRecommendationModal(),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
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
                      color: isSelected ? Colors.white : textColor,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: cardColor,
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
                      ? Center(child: Text('No se encontraron restaurantes', style: TextStyle(color: textColor)))
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
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.divider.withValues(alpha: 0.3)),
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
                                          Text(r.name, style: AppTextStyles.title.copyWith(color: textColor)),
                                          const SizedBox(height: 2),
                                          Text(r.category, style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          Text(r.address, style: AppTextStyles.caption.copyWith(color: textColor.withValues(alpha: 0.7)), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                                              Text('${r.ratingAverage.toStringAsFixed(1)} (${r.reviewsCount})', style: AppTextStyles.caption.copyWith(color: textColor)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.arrow_forward_ios_rounded, size: 16, color: textColor.withValues(alpha: 0.5)),
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
