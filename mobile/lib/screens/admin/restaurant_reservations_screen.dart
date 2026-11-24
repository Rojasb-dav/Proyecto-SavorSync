import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../core/services/api_service.dart';
import '../../models/reservation_model.dart';

class RestaurantReservationsScreen extends StatefulWidget {
  final String? restaurantId;
  const RestaurantReservationsScreen({super.key, this.restaurantId});

  @override
  State<RestaurantReservationsScreen> createState() => _RestaurantReservationsScreenState();
}

class _RestaurantReservationsScreenState extends State<RestaurantReservationsScreen> {
  final ApiService _apiService = ApiService();
  List<ReservationModel> _reservations = [];
  bool _loading = true;
  String _filterStatus = 'todas';

  @override
  void initState() {
    super.initState();
    _loadReservations();
  }

  Future<void> _loadReservations() async {
    try {
      final list = await _apiService.getReservations(restaurantId: widget.restaurantId);
      if (mounted) {
        setState(() {
          _reservations = list;
          _loading = false;
        });
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

    var docs = _reservations;
    if (_filterStatus != 'todas') {
      docs = docs.where((d) => d.estado == _filterStatus).toList();
    }

    return Scaffold(
      appBar: AppBar(title: Text('Gestión de Reservas Recibidas', style: AppTextStyles.headline)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Solicitudes de Reserva', style: AppTextStyles.headline),
                const SizedBox(height: 4),
                Text(
                  'Confirma o rechaza reservas enviadas por comensales en tiempo real.',
                  style: AppTextStyles.subtle,
                ),
                const SizedBox(height: 16),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('todas', 'Todas'),
                      const SizedBox(width: 8),
                      _buildFilterChip('pendiente', 'Pendientes ⏳'),
                      const SizedBox(width: 8),
                      _buildFilterChip('confirmada', 'Confirmadas ✅'),
                      const SizedBox(width: 8),
                      _buildFilterChip('cancelada', 'Canceladas ❌'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Expanded(
                  child: docs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 54, color: AppColors.textSecondary),
                              const SizedBox(height: 12),
                              Text('No hay reservas en esta sección', style: AppTextStyles.title),
                              const SizedBox(height: 4),
                              Text('Las nuevas reservas recibidas aparecerán automáticamente.', style: AppTextStyles.subtle),
                            ],
                          ),
                        )
                      : LayoutBuilder(
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
                                childAspectRatio: 1.35,
                              ),
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final res = docs[index];
                                final estado = res.estado;

                                Color estadoColor = Colors.orange;
                                if (estado == 'confirmada') estadoColor = Colors.green;
                                if (estado == 'cancelada') estadoColor = Colors.red;

                                return Container(
                                  padding: const EdgeInsets.all(16),
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
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              res.clienteNombre,
                                              style: AppTextStyles.title.copyWith(fontSize: 16),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: estadoColor.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              estado.toUpperCase(),
                                              style: TextStyle(
                                                color: estadoColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.people_rounded, size: 16, color: AppColors.primary),
                                          const SizedBox(width: 6),
                                          Text('${res.numPersonas} Personas', style: AppTextStyles.body),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.event_rounded, size: 16, color: AppColors.primary),
                                          const SizedBox(width: 6),
                                          Text('${res.fechaReserva} a las ${res.horaReserva}', style: AppTextStyles.body),
                                        ],
                                      ),
                                      if (res.notas.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          'Notas: ${res.notas}',
                                          style: AppTextStyles.caption,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      const Spacer(),
                                      if (estado == 'pendiente')
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            OutlinedButton(
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.red,
                                                side: const BorderSide(color: Colors.red),
                                                minimumSize: const Size(90, 36),
                                              ),
                                              onPressed: () async {
                                                await _apiService.updateReservationStatus(res.id, 'cancelada');
                                                _loadReservations();
                                              },
                                              child: const Text('Rechazar'),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                minimumSize: const Size(110, 36),
                                              ),
                                              onPressed: () async {
                                                await _apiService.updateReservationStatus(res.id, 'confirmada');
                                                _loadReservations();
                                              },
                                              child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
                                            ),
                                          ],
                                        )
                                      else
                                        Text(
                                          estado == 'confirmada'
                                              ? 'Reserva confirmada ✅'
                                              : 'Reserva rechazada/cancelada ❌',
                                          style: AppTextStyles.caption.copyWith(
                                            color: estadoColor,
                                            fontWeight: FontWeight.bold,
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSel = _filterStatus == key;
    return FilterChip(
      selected: isSel,
      label: Text(label),
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSel ? AppColors.primary : AppColors.textPrimary,
        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => setState(() => _filterStatus = key),
    );
  }
}
