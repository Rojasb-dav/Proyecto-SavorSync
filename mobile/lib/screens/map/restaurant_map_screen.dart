import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../core/services/api_service.dart';
import '../../models/restaurant_model.dart';
import '../restaurants/restaurant_detail_screen.dart';

class RestaurantMapScreen extends StatefulWidget {
  const RestaurantMapScreen({super.key});

  @override
  State<RestaurantMapScreen> createState() => _RestaurantMapScreenState();
}

class _RestaurantMapScreenState extends State<RestaurantMapScreen> {
  RestaurantModel? _selectedRestaurant;
  Position? _currentPosition;
  static const LatLng _bogotaCenter = LatLng(4.6533, -74.0621);
  final ApiService _apiService = ApiService();
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _initUserLocation();
  }

  Future<void> _initUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() => _currentPosition = pos);
        final userLatLng = LatLng(pos.latitude, pos.longitude);
        _mapController.move(userLatLng, 14.5);
      }
    } catch (e) {
      debugPrint('Error obteniendo ubicación GPS: $e');
    }
  }

  void _centerOnUser() {
    if (_currentPosition != null) {
      _mapController.move(LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 15.0);
    } else {
      _initUserLocation();
    }
  }

  String _calculateDistanceStr(RestaurantModel r) {
    final userLat = _currentPosition?.latitude ?? _bogotaCenter.latitude;
    final userLng = _currentPosition?.longitude ?? _bogotaCenter.longitude;

    final meters = Geolocator.distanceBetween(
      userLat,
      userLng,
      r.latitude,
      r.longitude,
    );

    if (meters < 1000) {
      return '${meters.toInt()} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  Future<void> _openExternalNavigation(RestaurantModel r) async {
    final googleMapsUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${r.latitude},${r.longitude}');
    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(googleMapsUrl, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir mapas: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final LatLng userLatLng = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : _bogotaCenter;

    return Scaffold(
      body: FutureBuilder<List<RestaurantModel>>(
        future: _apiService.getRestaurants(),
        builder: (context, snapshot) {
          final restaurants = snapshot.data ?? [];

          final restMarkers = restaurants.map((r) {
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

          Marker? userMarker;
          if (_currentPosition != null) {
            userMarker = Marker(
              point: userLatLng,
              width: 50,
              height: 50,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blue, width: 2),
                ),
                child: const Icon(Icons.my_location_rounded, color: Colors.blue, size: 26),
              ),
            );
          }

          final allMarkers = [...restMarkers, if (userMarker != null) userMarker];

          final List<LatLng> routePoints = _selectedRestaurant != null
              ? [userLatLng, LatLng(_selectedRestaurant!.latitude, _selectedRestaurant!.longitude)]
              : [];

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: userLatLng,
                  initialZoom: 14.0,
                  onTap: (_, __) {
                    setState(() => _selectedRestaurant = null);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'co.edu.umb.savorsync',
                  ),
                  if (routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: routePoints,
                          strokeWidth: 4.5,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  MarkerLayer(markers: allMarkers),
                ],
              ),

              // Barra superior
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
                        Expanded(child: Text('Mapa Interactivo SavorSync', style: AppTextStyles.title.copyWith(fontSize: 15))),
                        GestureDetector(
                          onTap: _centerOnUser,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.gps_fixed_rounded, size: 14, color: Colors.blue),
                                const SizedBox(width: 6),
                                Text(
                                  _currentPosition != null ? 'Mi Ubicación GPS 📍' : 'Obteniendo GPS...',
                                  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Botón Flotante para Centrar GPS
              Positioned(
                right: 20,
                bottom: _selectedRestaurant != null ? 180 : 30,
                child: FloatingActionButton(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue,
                  elevation: 6,
                  onPressed: _centerOnUser,
                  child: const Icon(Icons.my_location_rounded, size: 28),
                ),
              ),

              // Ficha inferior
              if (_selectedRestaurant != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 24,
                  child: _RestaurantCardPreview(
                    restaurant: _selectedRestaurant!,
                    distanceStr: _calculateDistanceStr(_selectedRestaurant!),
                    onClose: () => setState(() => _selectedRestaurant = null),
                    onNavigate: () => _openExternalNavigation(_selectedRestaurant!),
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
  final String distanceStr;
  final VoidCallback onClose;
  final VoidCallback onNavigate;
  final VoidCallback onTap;

  const _RestaurantCardPreview({
    required this.restaurant,
    required this.distanceStr,
    required this.onClose,
    required this.onNavigate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: restaurant.imageUrl,
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(restaurant.name, style: AppTextStyles.title)),
                          Chip(
                            avatar: const Icon(Icons.near_me_rounded, size: 12, color: AppColors.primary),
                            label: Text(distanceStr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(restaurant.address, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          RatingBarIndicator(
                            rating: restaurant.ratingAverage,
                            itemBuilder: (context, index) => const Icon(
                              Icons.star_rounded,
                              color: AppColors.accent,
                            ),
                            itemCount: 5,
                            itemSize: 14.0,
                          ),
                          const SizedBox(width: 6),
                          Text(restaurant.ratingAverage.toStringAsFixed(1), style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
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
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(38),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: onNavigate,
                  icon: const Icon(Icons.navigation_rounded, color: Colors.white, size: 18),
                  label: Text('¿Cómo llegar? ($distanceStr)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
