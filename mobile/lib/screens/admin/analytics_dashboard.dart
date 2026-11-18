import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../models/restaurant_model.dart';

class AnalyticsDashboard extends StatelessWidget {
  final RestaurantModel? restaurant;
  const AnalyticsDashboard({super.key, this.restaurant});

  static const RestaurantModel _defaultRestaurant = RestaurantModel(
    id: 'res_default',
    name: 'Mi Restaurante',
    description: '',
    address: 'Bogotá',
    category: 'Gastronomía',
    latitude: 4.6097,
    longitude: -74.0817,
    ratingAverage: 4.8,
    reviewsCount: 45,
    imageUrl: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=800&q=80',
  );

  @override
  Widget build(BuildContext context) {
    final r = restaurant ?? _defaultRestaurant;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tablero de Analítica BI'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Inteligencia de Negocios', style: AppTextStyles.headline),
            Text(
              'Métricas y desempeño de ${r.name} en Bogotá.',
              style: AppTextStyles.subtle,
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                _MetricCard(
                  title: 'Visitas al Perfil',
                  value: '${(r.reviewsCount * 4.5).toInt() + 42}',
                  icon: Icons.visibility_rounded,
                  color: Colors.blue,
                ),
                _MetricCard(
                  title: 'Calificación',
                  value: '${r.ratingAverage.toStringAsFixed(1)} ★',
                  icon: Icons.star_rounded,
                  color: AppColors.accent,
                ),
                _MetricCard(
                  title: 'Reseñas',
                  value: '${r.reviewsCount}',
                  icon: Icons.rate_review_rounded,
                  color: Colors.green,
                ),
                _MetricCard(
                  title: 'Favoritos',
                  value: '${(r.reviewsCount * 1.8).toInt() + 12}',
                  icon: Icons.favorite_rounded,
                  color: Colors.pink,
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text('Gráfica de Visitas Semanales (BI)', style: AppTextStyles.title),
            const SizedBox(height: 12),
            Container(
              height: 200,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 100,
                  barTouchData: BarTouchDataEnabled(false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
                          if (value.toInt() >= 0 && value.toInt() < days.length) {
                            return Text(days[value.toInt()], style: AppTextStyles.caption);
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 35, color: AppColors.primary, width: 16, borderRadius: BorderRadius.circular(4))]),
                    BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 42, color: AppColors.primary, width: 16, borderRadius: BorderRadius.circular(4))]),
                    BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 58, color: AppColors.primary, width: 16, borderRadius: BorderRadius.circular(4))]),
                    BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 64, color: AppColors.primary, width: 16, borderRadius: BorderRadius.circular(4))]),
                    BarChartGroupData(x: 4, barRods: [BarChartRodData(toY: 88, color: AppColors.accent, width: 16, borderRadius: BorderRadius.circular(4))]),
                    BarChartGroupData(x: 5, barRods: [BarChartRodData(toY: 95, color: AppColors.accent, width: 16, borderRadius: BorderRadius.circular(4))]),
                    BarChartGroupData(x: 6, barRods: [BarChartRodData(toY: 72, color: AppColors.primary, width: 16, borderRadius: BorderRadius.circular(4))]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text('Desglose de Calificaciones', style: AppTextStyles.title),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: const [
                  _RatingBarRow(stars: 5, percentage: 0.78),
                  _RatingBarRow(stars: 4, percentage: 0.15),
                  _RatingBarRow(stars: 3, percentage: 0.05),
                  _RatingBarRow(stars: 2, percentage: 0.01),
                  _RatingBarRow(stars: 1, percentage: 0.01),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text('Recomendación de Toma de Decisiones', style: AppTextStyles.title),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_rounded, color: AppColors.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tu categoría (${r.category}) registra pico de demanda los viernes y sábados en Bogotá. Lanza promociones especiales entre 12:00 PM y 3:00 PM para maximizar conversiones.',
                      style: AppTextStyles.body,
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
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const Spacer(),
            ],
          ),
          const Spacer(),
          Text(value, style: AppTextStyles.displayMedium.copyWith(fontSize: 22)),
          Text(title, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _RatingBarRow extends StatelessWidget {
  final int stars;
  final double percentage;

  const _RatingBarRow({required this.stars, required this.percentage});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 30, child: Text('$stars ★', style: AppTextStyles.caption)),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text('${(percentage * 100).toInt()}%', style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
