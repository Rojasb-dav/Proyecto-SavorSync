import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';

class ReservationTicketModal extends StatelessWidget {
  final String reservationId;
  final String restaurantName;
  final String clienteNombre;
  final String fechaReserva;
  final String horaReserva;
  final int numPersonas;
  final String estado;

  const ReservationTicketModal({
    super.key,
    required this.reservationId,
    required this.restaurantName,
    required this.clienteNombre,
    required this.fechaReserva,
    required this.horaReserva,
    required this.numPersonas,
    required this.estado,
  });

  @override
  Widget build(BuildContext context) {
    final qrData = 'SAVORSYNC-TICKET|$reservationId|$restaurantName|$clienteNombre|$fechaReserva|$horaReserva|$numPersonas';
    final isConfirmed = estado == 'confirmada';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Ticket Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.confirmation_number_rounded, color: AppColors.primary, size: 36),
              ),
              const SizedBox(height: 12),

              Text('Ticket de Reserva', style: AppTextStyles.headline),
              const SizedBox(height: 4),
              Text(
                restaurantName,
                style: AppTextStyles.title.copyWith(color: AppColors.primary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Código QR Escaneable
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider, width: 1.5),
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 180.0,
                  foregroundColor: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Código: SS-RES-${reservationId.substring(0, reservationId.length > 8 ? 8 : reservationId.length).toUpperCase()}',
                style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              const SizedBox(height: 16),

              const Divider(),
              const SizedBox(height: 8),

              // Detalles de la reserva
              _buildTicketRow(Icons.person_outline_rounded, 'Titular', clienteNombre),
              const SizedBox(height: 8),
              _buildTicketRow(Icons.calendar_today_rounded, 'Fecha y Hora', '$fechaReserva - $horaReserva'),
              const SizedBox(height: 8),
              _buildTicketRow(Icons.people_outline_rounded, 'Comensales', '$numPersonas Personas'),
              const SizedBox(height: 8),
              _buildTicketRow(
                Icons.info_outline_rounded,
                'Estado',
                isConfirmed ? 'Confirmada ✅' : 'Pendiente ⏳',
                color: isConfirmed ? Colors.green : Colors.orange,
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar Ticket', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTicketRow(IconData icon, String label, String value, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color ?? AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(label, style: AppTextStyles.caption),
        const Spacer(),
        Text(
          value,
          style: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.bold,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
