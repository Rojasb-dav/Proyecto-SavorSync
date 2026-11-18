import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../models/restaurant_model.dart';
import '../restaurants/restaurant_detail_screen.dart';

class RestaurantMapScreen extends StatefulWidget {
  const RestaurantMapScreen({super.key});

  @override
  State<RestaurantMapScreen> createState() => _RestaurantMapScreenState();
}

class _RestaurantMapScreenState extends State<RestaurantMapScreen> {
  RestaurantModel? _selectedRestaurant;

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
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('restaurants').snapshots(),
        builder: (context, snapshot) {
          List<RestaurantModel> restaurants = [];
          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            restaurants = snapshot.data!.docs
                .map((doc) => RestaurantModel.fromJson({'id': doc.id, ...doc.data()}))
                .toList();
          } else {
            restaurants = _seedRestaurants;
          }

          final markers = restaurants.map((r) {
            return Marker(
              point: LatLng(r.latitude, r.longitude),
              width: 120,
              height: 70,
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedRestaurant = r);
                },
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
                      ),
                      child: Text(
                        r.name,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 36),
                  ],
                ),
              ),
            );
          }).toList();

          return Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: const LatLng(4.6533, -74.0621), // Bogotá, Colombia
                  initialZoom: 13.0,
                  onTap: (_, __) {
                    setState(() => _selectedRestaurant = null);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'co.edu.umb.savorsync',
                  ),
                  MarkerLayer(markers: markers),
                ],
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.map_rounded, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Mapa de Bogotá (OpenStreetMap)',
                            style: AppTextStyles.title,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('100% Gratis', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_selectedRestaurant != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 24,
                  child: _RestaurantCardPreview(
                    restaurant: _selectedRestaurant!,
                    onClose: () => setState(() => _selectedRestaurant = null),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RestaurantDetailScreen(restaurant: _selectedRestaurant!),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RestaurantCardPreview extends StatelessWidget {
  final RestaurantModel restaurant;
  final VoidCallback onClose;
  final VoidCallback onTap;

  const _RestaurantCardPreview({
    required this.restaurant,
    required this.onClose,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: restaurant.imageUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(restaurant.name, style: AppTextStyles.title),
                  const SizedBox(height: 4),
                  Text(restaurant.address, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      RatingBarIndicator(
                        rating: restaurant.ratingAverage,
                        itemBuilder: (context, index) => const Icon(
                          Icons.star_rounded,
                          color: AppColors.accent,
                        ),
                        itemCount: 5,
                        itemSize: 16.0,
                      ),
                      const SizedBox(width: 6),
                      Text(restaurant.ratingAverage.toStringAsFixed(1), style: AppTextStyles.caption),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.grey),
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}
