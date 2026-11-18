import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
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

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  bool _isFavorite = false;
  List<PostModel> _reviews = [];
  bool _loadingReviews = true;

  @override
  void initState() {
    super.initState();
    _checkFavorite();
    _loadReviews();
  }

  Future<void> _checkFavorite() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    try {
      final favDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .collection('favorites')
          .doc(widget.restaurant.id)
          .get();
      if (!mounted) return;
      setState(() => _isFavorite = favDoc.exists);
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user.id)
        .collection('favorites')
        .doc(widget.restaurant.id);

    setState(() => _isFavorite = !_isFavorite);

    if (_isFavorite) {
      await ref.set({
        'restaurantId': widget.restaurant.id,
        'name': widget.restaurant.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.delete();
    }
  }

  Future<void> _loadReviews() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('restaurantName', isEqualTo: widget.restaurant.name)
          .get();

      final posts = snapshot.docs.map((doc) {
        final data = doc.data();
        final createdAtField = data['createdAt'];
        DateTime dt = DateTime.now();
        if (createdAtField is Timestamp) {
          dt = createdAtField.toDate();
        }
        return PostModel.fromJson({
          'id': doc.id,
          ...data,
          'createdAt': dt.toIso8601String(),
        });
      }).toList();

      if (!mounted) return;
      setState(() {
        _reviews = posts;
        _loadingReviews = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingReviews = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(r.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                      Text('${r.ratingAverage.toStringAsFixed(1)} (${r.reviewsCount})', style: AppTextStyles.caption),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (r.description.isNotEmpty) ...[
                    Text(r.description, style: AppTextStyles.body),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(r.address, style: AppTextStyles.subtle)),
                    ],
                  ),
                  const Divider(height: 32),
                  Text('Reseñas de la comunidad (${_reviews.length})', style: AppTextStyles.headline),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          if (_loadingReviews)
            const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else if (_reviews.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: Text('Sé el primero en calificar este restaurante')),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: PostCard(post: _reviews[i], onDeleted: _loadReviews),
                ),
                childCount: _reviews.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 30)),
        ],
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
