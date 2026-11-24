import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../core/services/api_service.dart';
import '../../models/menu_item_model.dart';
import '../../models/post_model.dart';
import '../../models/restaurant_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/post_card.dart';
import 'create_reservation_modal.dart';

class RestaurantDetailScreen extends StatefulWidget {
  final RestaurantModel restaurant;
  const RestaurantDetailScreen({super.key, required this.restaurant});

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> with SingleTickerProviderStateMixin {
  bool _isFavorite = false;
  List<PostModel> _communityReviews = [];
  List<PostModel> _officialPosts = [];
  List<MenuItemModel> _menuItems = [];
  bool _loadingPosts = true;
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  final _currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final posts = await _apiService.getPosts();
      final menu = await _apiService.getMenu(widget.restaurant.id);

      final matching = posts.where((p) => p.restaurantName.toLowerCase() == widget.restaurant.name.toLowerCase() || p.restaurantId == widget.restaurant.id).toList();

      if (!mounted) return;
      setState(() {
        _communityReviews = matching;
        _officialPosts = [];
        _menuItems = menu;
        _loadingPosts = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPosts = false);
    }
  }

  void _toggleFavorite() {
    setState(() => _isFavorite = !_isFavorite);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textPrimary;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(r.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: r.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: AppColors.divider),
                    errorWidget: (_, __, ___) => Container(color: AppColors.divider),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: _isFavorite ? AppColors.primary : Colors.white,
                ),
                onPressed: _toggleFavorite,
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          r.category,
                          style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Spacer(),
                      RatingBarIndicator(
                        rating: r.ratingAverage,
                        itemBuilder: (context, index) => const Icon(
                          Icons.star_rounded,
                          color: AppColors.accent,
                        ),
                        itemCount: 5,
                        itemSize: 20.0,
                      ),
                      const SizedBox(width: 6),
                      Text('${r.ratingAverage.toStringAsFixed(1)} (${r.reviewsCount})', style: AppTextStyles.caption.copyWith(color: textColor)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (r.description.isNotEmpty) ...[
                    Text(r.description, style: AppTextStyles.body.copyWith(color: textColor)),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(r.address, style: AppTextStyles.subtle.copyWith(color: textColor.withValues(alpha: 0.7)))),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TabBar(
                    controller: _tabController,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: textColor.withValues(alpha: 0.6),
                    indicatorColor: AppColors.primary,
                    tabs: [
                      const Tab(icon: Icon(Icons.restaurant_menu_rounded), text: 'Menú / Carta'),
                      Tab(icon: const Icon(Icons.rate_review_rounded), text: 'Reseñas (${_communityReviews.length})'),
                      Tab(icon: const Icon(Icons.campaign_rounded), text: 'Promociones (${_officialPosts.length})'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _menuItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.restaurant_menu_rounded, size: 54, color: AppColors.secondary),
                        const SizedBox(height: 12),
                        Text('Menú digital disponible', style: AppTextStyles.title.copyWith(color: textColor)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _menuItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final item = _menuItems[i];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider.withValues(alpha: 0.3)),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                                    ? item.imageUrl!
                                    : 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=400&q=80',
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: Text(item.name, style: AppTextStyles.title.copyWith(fontSize: 15, color: textColor))),
                                      if (!item.isAvailable)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
                                          child: const Text('Agotado', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(item.category, style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                  if (item.description.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(item.description, style: AppTextStyles.caption.copyWith(color: textColor.withValues(alpha: 0.7)), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  ],
                                  const SizedBox(height: 6),
                                  Text(
                                    _currencyFormat.format(item.price),
                                    style: AppTextStyles.title.copyWith(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

            _loadingPosts
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _communityReviews.isEmpty
                    ? Center(child: Text('Sé el primero en calificar este restaurante', style: TextStyle(color: textColor)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _communityReviews.length,
                        itemBuilder: (context, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: PostCard(post: _communityReviews[i], onDeleted: _loadData),
                        ),
                      ),

            _loadingPosts
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _officialPosts.isEmpty
                    ? Center(child: Text('El restaurante aún no ha publicado promociones u ofertas especiales', style: TextStyle(color: textColor), textAlign: TextAlign.center))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _officialPosts.length,
                        itemBuilder: (context, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: PostCard(post: _officialPosts[i], onDeleted: _loadData),
                        ),
                      ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.table_restaurant_rounded, color: Colors.white),
            label: const Text('Solicitar Reserva', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            onPressed: () {
              final user = context.read<AuthProvider>().user;
              if (user == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Inicia sesión para reservar')),
                );
                return;
              }
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => CreateReservationModal(restaurant: r),
              );
            },
          ),
        ),
      ),
    );
  }
}
