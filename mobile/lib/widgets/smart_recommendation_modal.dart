import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/constants/colors.dart';
import '../core/constants/text_styles.dart';
import '../models/restaurant_model.dart';
import '../screens/restaurants/restaurant_detail_screen.dart';

class SmartRecommendationModal extends StatefulWidget {
  const SmartRecommendationModal({super.key});

  @override
  State<SmartRecommendationModal> createState() => _SmartRecommendationModalState();
}

class _SmartRecommendationModalState extends State<SmartRecommendationModal> {
  String _budget = '< \$30.000 COP';
  String _occasion = 'Cita Romántica 💕';
  String _zone = 'Zona T / Rosa';

  bool _calculating = false;
  List<Map<String, dynamic>> _recommendations = [];

  static const List<String> _budgets = [
    '< \$30.000 COP',
    '\$30.000 - \$60.000 COP',
    '> \$60.000 COP',
  ];

  static const List<String> _occasions = [
    'Cita Romántica 💕',
    'Reunión Ejecutiva 💼',
    'Salida Familiar 👨‍👩‍👧‍👦',
    'Amigos / Fiesta 🎉',
  ];

  static const List<String> _zones = [
    'Zona T / Rosa',
    'Chapinero',
    'La Candelaria',
    'Usaquén',
    'Chía / Afueras',
  ];

  Future<void> _calculateRecommendations() async {
    setState(() => _calculating = true);

    try {
      final snapshot = await FirebaseFirestore.instance.collection('restaurants').get();
      final docs = snapshot.docs;

      final results = <Map<String, dynamic>>[];

      for (var i = 0; i < docs.length; i++) {
        final d = docs[i];
        final rest = RestaurantModel.fromJson({'id': d.id, ...d.data()});

        int score = 80;
        if (rest.address.toLowerCase().contains(_zone.split(' ').first.toLowerCase())) {
          score += 15;
        }
        if (rest.ratingAverage >= 4.5) {
          score += 5;
        }

        score = score.clamp(75, 99);

        results.add({
          'restaurant': rest,
          'match': score,
        });
      }

      results.sort((a, b) => (b['match'] as int).compareTo(a['match'] as int));

      if (mounted) {
        setState(() {
          _recommendations = results;
          _calculating = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _calculating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Asistente Recomendador IA', style: AppTextStyles.headline.copyWith(fontSize: 16)),
                    Text('Encuentra el lugar perfecto en Bogotá', style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_recommendations.isEmpty) ...[
            Text('1. Presupuesto aproximado por persona:', style: AppTextStyles.title.copyWith(fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _budgets.map((b) {
                final isSel = _budget == b;
                return ChoiceChip(
                  label: Text(b),
                  selected: isSel,
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    color: isSel ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (_) => setState(() => _budget = b),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            Text('2. Ocasión de la visita:', style: AppTextStyles.title.copyWith(fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _occasions.map((o) {
                final isSel = _occasion == o;
                return ChoiceChip(
                  label: Text(o),
                  selected: isSel,
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    color: isSel ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (_) => setState(() => _occasion = o),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            Text('3. Zona preferida en Bogotá:', style: AppTextStyles.title.copyWith(fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _zones.map((z) {
                final isSel = _zone == z;
                return ChoiceChip(
                  label: Text(z),
                  selected: isSel,
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    color: isSel ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (_) => setState(() => _zone = z),
                );
              }).toList(),
            ),
            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _calculating ? null : _calculateRecommendations,
                icon: _calculating
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome_rounded, color: Colors.white),
                label: const Text('Generar Recomendación IA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Text('Lugares recomendados para ti', style: AppTextStyles.title),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() => _recommendations = []),
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('Ajustar Filtros'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: _recommendations.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = _recommendations[index];
                  final rest = item['restaurant'] as RestaurantModel;
                  final match = item['match'] as int;

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
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 64,
                          height: 64,
                          color: Colors.grey.shade200,
                          child: rest.imageUrl.isNotEmpty
                              ? Image.network(rest.imageUrl, fit: BoxFit.cover)
                              : const Icon(Icons.storefront_rounded, color: AppColors.primary),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(child: Text(rest.name, style: AppTextStyles.title.copyWith(fontSize: 16))),
                          Chip(
                            label: Text('$match% Match 🔥', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                            backgroundColor: AppColors.primary,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('${rest.category} • ${rest.address}', style: AppTextStyles.caption),
                          const SizedBox(height: 2),
                          Text('${rest.ratingAverage} ★ (${rest.reviewsCount} reseñas)', style: AppTextStyles.caption.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RestaurantDetailScreen(restaurant: rest),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
