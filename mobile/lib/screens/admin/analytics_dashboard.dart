import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../models/restaurant_model.dart';
import '../../providers/auth_provider.dart';

class AnalyticsDashboard extends StatelessWidget {
  final RestaurantModel? restaurant;
  const AnalyticsDashboard({super.key, this.restaurant});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Debes iniciar sesión para ver analíticas.')),
      );
    }

    // Si ya se pasó el objeto restaurante por parámetro o si debemos consultarlo en tiempo real
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('restaurants')
          .where('ownerId', isEqualTo: user.id)
          .limit(1)
          .snapshots(),
      builder: (context, restSnapshot) {
        if (restSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }

        final docs = restSnapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Tablero de Analítica BI')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bar_chart_rounded, size: 64, color: AppColors.textSecondary),
                    const SizedBox(height: 16),
                    Text('Aún no has registrado tu restaurante', style: AppTextStyles.title),
                    const SizedBox(height: 8),
                    Text(
                      'Registra tu establecimiento en la pestaña "Mi Local" para comenzar a recibir visitas, reservas e interacciones en tiempo real.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.subtle,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final restDoc = docs.first;
        final currentRest = RestaurantModel.fromJson({'id': restDoc.id, ...restDoc.data()});

        return _RealTimeAnalyticsView(restaurant: currentRest);
      },
    );
  }
}

class _RealTimeAnalyticsView extends StatelessWidget {
  final RestaurantModel restaurant;
  const _RealTimeAnalyticsView({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Analítica BI - ${restaurant.name}', style: AppTextStyles.headline),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('reservations')
                .where('restaurantId', isEqualTo: restaurant.id)
                .snapshots(),
            builder: (context, resSnapshot) {
              final reservationsDocs = resSnapshot.data?.docs ?? [];

              // Métricas en tiempo real de reservas
              int pendingReservations = 0;
              int confirmedReservations = 0;
              int canceledReservations = 0;

              // Conteo de reservas por día de la semana (0=Lun, 1=Mar, ..., 6=Dom)
              final List<int> reservationsPerDay = List.filled(7, 0);

              for (final d in reservationsDocs) {
                final data = d.data();
                final estado = (data['estado'] as String?) ?? 'pendiente';
                if (estado == 'pendiente') pendingReservations++;
                if (estado == 'confirmada') confirmedReservations++;
                if (estado == 'cancelada') canceledReservations++;

                // Mapear fecha de la reserva al día de la semana
                final timestamp = data['createdAt'] as Timestamp?;
                if (timestamp != null) {
                  final date = timestamp.toDate();
                  final weekdayIndex = date.weekday - 1; // DateTime.weekday es 1 (Lun) a 7 (Dom)
                  if (weekdayIndex >= 0 && weekdayIndex < 7) {
                    reservationsPerDay[weekdayIndex]++;
                  }
                }
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('restaurants')
                    .doc(restaurant.id)
                    .collection('menu')
                    .snapshots(),
                builder: (context, menuSnapshot) {
                  final menuCount = menuSnapshot.data?.docs.length ?? 0;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Inteligencia de Negocios (BI en Tiempo Real)', style: AppTextStyles.headline),
                                Text(
                                  'Métricas y desempeño dinámico de ${restaurant.name} registradas en Firestore.',
                                  style: AppTextStyles.subtle,
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              onPressed: () => _showExportExecutiveReportDialog(
                                context,
                                reservationsDocs.length,
                                confirmedReservations,
                                pendingReservations,
                                canceledReservations,
                                menuCount,
                              ),
                              icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
                              label: const Text('Exportar Reporte BI (PDF)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Tarjetas Métricas Reales
                        LayoutBuilder(
                          builder: (context, constraints) {
                            int crossAxisCount = 2;
                            if (constraints.maxWidth > 900) {
                              crossAxisCount = 4;
                            } else if (constraints.maxWidth > 600) {
                              crossAxisCount = 2;
                            }

                            return GridView.count(
                              crossAxisCount: crossAxisCount,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1.4,
                              children: [
                                _MetricCard(
                                  title: 'Visitas al Perfil',
                                  value: '${restaurant.viewsCount}',
                                  subtitle: 'Visualizaciones reales',
                                  icon: Icons.visibility_rounded,
                                  color: Colors.blue,
                                ),
                                _MetricCard(
                                  title: 'Total de Reservas',
                                  value: '${reservationsDocs.length}',
                                  subtitle: '$confirmedReservations confirmadas',
                                  icon: Icons.event_seat_rounded,
                                  color: Colors.green,
                                ),
                                _MetricCard(
                                  title: 'Guardados en Favoritos',
                                  value: '${restaurant.favoritesCount}',
                                  subtitle: 'Comensales interesados',
                                  icon: Icons.favorite_rounded,
                                  color: Colors.pink,
                                ),
                                _MetricCard(
                                  title: 'Platos en Carta / Menú',
                                  value: '$menuCount',
                                  subtitle: 'Ítems registrados',
                                  icon: Icons.restaurant_menu_rounded,
                                  color: AppColors.accent,
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 28),

                        // Gráfica de Reservas por Día & Desglose de Estado
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 800;
                            return isWide
                                ? Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(flex: 3, child: _buildReservationsChart(reservationsPerDay)),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        flex: 2,
                                        child: _buildReservationsStatusBreakdown(
                                          total: reservationsDocs.length,
                                          pending: pendingReservations,
                                          confirmed: confirmedReservations,
                                          canceled: canceledReservations,
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildReservationsChart(reservationsPerDay),
                                      const SizedBox(height: 24),
                                      _buildReservationsStatusBreakdown(
                                        total: reservationsDocs.length,
                                        pending: pendingReservations,
                                        confirmed: confirmedReservations,
                                        canceled: canceledReservations,
                                      ),
                                    ],
                                  );
                          },
                        ),
                        const SizedBox(height: 28),

                        // Recomendación Comercial BI Dinámica
                        Text('Recomendación de Toma de Decisiones', style: AppTextStyles.title),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lightbulb_rounded, color: AppColors.primary, size: 32),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  _generateDynamicBIRecommendation(
                                    views: restaurant.viewsCount,
                                    reservations: reservationsDocs.length,
                                    pending: pendingReservations,
                                    category: restaurant.category,
                                  ),
                                  style: AppTextStyles.body.copyWith(fontSize: 15),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  String _generateDynamicBIRecommendation({
    required int views,
    required int reservations,
    required int pending,
    required String category,
  }) {
    if (views == 0 && reservations == 0) {
      return 'Tu restaurante aún no registra visitas en Bogotá. Te sugerimos subir una foto de portada atractiva en la pestaña "Mi Local" y publicar tus mejores platillos en la sección "Menú / Carta".';
    }
    if (pending > 0) {
      return 'Tienes $pending solicitudes de reserva pendientes por responder en tiempo real. Ingresa a la pestaña "Reservas" para confirmarlas y garantizar la asistencia de tus comensales.';
    }
    if (views > 10 && reservations == 0) {
      return 'Tu restaurante $category registra $views visitas al perfil, pero aún no se han concretado reservas. Agrega precios claros y fotos apetitosas en tu menú para incentivar la conversión.';
    }
    return 'Tu establecimiento en la categoría $category registra $views visitas y $reservations reservas. Mantén actualizada la disponibilidad de tu carta para continuar aumentando tu fidelización en Bogotá.';
  }

  void _showExportExecutiveReportDialog(BuildContext context, int totalRes, int confirmed, int pending, int canceled, int menuCount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary, size: 28),
            const SizedBox(width: 10),
            Text('Reporte BI Ejecutivo', style: AppTextStyles.title),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Informe de Desempeño: ${restaurant.name}', style: AppTextStyles.title.copyWith(fontSize: 16)),
              Text('Categoría: ${restaurant.category} • Bogotá, D.C.', style: AppTextStyles.caption),
              const Divider(height: 24),
              _buildReportItem('Visitas totales al perfil:', '${restaurant.viewsCount} visualizaciones'),
              _buildReportItem('Calificación promedio:', '${restaurant.ratingAverage} ★ (${restaurant.reviewsCount} opiniones)'),
              _buildReportItem('Favoritos de la comunidad:', '${restaurant.favoritesCount} guardados'),
              _buildReportItem('Solicitudes de reserva:', '$totalRes ($confirmed confirmadas, $pending pendientes, $canceled canceladas)'),
              _buildReportItem('Platillos activos en la carta:', '$menuCount ítems'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Este documento resume el rendimiento comercial en tiempo real registrado en la plataforma SavorSync.',
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reporte BI exportado y listo para presentación'), backgroundColor: Colors.green),
              );
            },
            icon: const Icon(Icons.download_rounded, color: Colors.white, size: 18),
            label: const Text('Exportar Reporte (PDF/Excel)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildReportItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
          Text(value, style: AppTextStyles.body.copyWith(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildReservationsChart(List<int> perDay) {
    int maxVal = perDay.reduce((a, b) => a > b ? a : b);
    if (maxVal < 5) maxVal = 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gráfica de Reservas Creadas por Día (Semanal)', style: AppTextStyles.title),
        const SizedBox(height: 12),
        Container(
          height: 220,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxVal.toDouble() + 2,
              barTouchData: BarTouchData(enabled: true),
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
              barGroups: List.generate(7, (i) {
                final count = perDay[i].toDouble();
                final isWeekend = i >= 4;
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: count,
                      color: isWeekend ? AppColors.accent : AppColors.primary,
                      width: 18,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReservationsStatusBreakdown({
    required int total,
    required int pending,
    required int confirmed,
    required int canceled,
  }) {
    double pendingPct = total > 0 ? pending / total : 0.0;
    double confirmedPct = total > 0 ? confirmed / total : 0.0;
    double canceledPct = total > 0 ? canceled / total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Estado de Solicitudes de Reserva', style: AppTextStyles.title),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              _StatusProgressRow(
                label: 'Confirmadas ✅',
                count: confirmed,
                percentage: confirmedPct,
                color: Colors.green,
              ),
              const SizedBox(height: 12),
              _StatusProgressRow(
                label: 'Pendientes ⏳',
                count: pending,
                percentage: pendingPct,
                color: Colors.amber.shade700,
              ),
              const SizedBox(height: 12),
              _StatusProgressRow(
                label: 'Canceladas ❌',
                count: canceled,
                percentage: canceledPct,
                color: Colors.red,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 26),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: AppTextStyles.displayMedium.copyWith(fontSize: 24, fontWeight: FontWeight.bold)),
              Text(title, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
              Text(subtitle, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.92, 0.92));
  }
}

class _StatusProgressRow extends StatelessWidget {
  final String label;
  final int count;
  final double percentage;
  final Color color;

  const _StatusProgressRow({
    required this.label,
    required this.count,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
            Text('$count (${(percentage * 100).toStringAsFixed(0)}%)', style: AppTextStyles.caption),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            minHeight: 10,
            backgroundColor: Colors.grey[200],
            color: color,
          ),
        ),
      ],
    );
  }
}
