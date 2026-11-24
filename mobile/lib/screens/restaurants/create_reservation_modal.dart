import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../core/services/api_service.dart';
import '../../core/services/notification_service.dart';
import '../../models/restaurant_model.dart';
import '../../providers/auth_provider.dart';
import 'reservation_ticket_modal.dart';

class CreateReservationModal extends StatefulWidget {
  final RestaurantModel restaurant;
  const CreateReservationModal({super.key, required this.restaurant});

  @override
  State<CreateReservationModal> createState() => _CreateReservationModalState();
}

class _CreateReservationModalState extends State<CreateReservationModal> {
  final _formKey = GlobalKey<FormState>();
  final _notasCtrl = TextEditingController();
  final ApiService _apiService = ApiService();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 13, minute: 0);
  int _numPersonas = 2;
  bool _loading = false;

  @override
  void dispose() {
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitReservation() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final fechaStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final horaStr = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';
      final clienteNombre = user.fullName ?? user.username;

      final res = await _apiService.createReservation({
        'restaurantId': widget.restaurant.id,
        'restaurantName': widget.restaurant.name,
        'userId': user.id,
        'userName': clienteNombre,
        'userPhone': user.phone ?? '+57 300 000 0000',
        'guests': _numPersonas,
        'date': fechaStr,
        'time': horaStr,
        'specialNotes': _notasCtrl.text.trim(),
      });

      if (widget.restaurant.ownerId.isNotEmpty) {
        NotificationService.sendNotification(
          targetUserId: widget.restaurant.ownerId,
          title: 'Nueva Solicitud de Reserva 🏪',
          body: 'Nueva reserva de $clienteNombre para $_numPersonas personas el $fechaStr.',
          type: 'reservation',
          targetId: res.id,
        );
      }

      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.pop(context);

      showDialog(
        context: context,
        builder: (_) => ReservationTicketModal(
          reservationId: res.id,
          restaurantName: widget.restaurant.name,
          clienteNombre: clienteNombre,
          fechaReserva: fechaStr,
          horaReserva: horaStr,
          numPersonas: _numPersonas,
          estado: 'pendiente',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al procesar reserva: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Solicitar Reserva', style: AppTextStyles.headline),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Text(widget.restaurant.name, style: AppTextStyles.subtle.copyWith(color: AppColors.primary)),
              const SizedBox(height: 20),
              Text('Número de personas', style: AppTextStyles.title),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                    onPressed: _numPersonas > 1 ? () => setState(() => _numPersonas--) : null,
                  ),
                  Text('$_numPersonas personas', style: AppTextStyles.title),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    onPressed: _numPersonas < 20 ? () => setState(() => _numPersonas++) : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Fecha y Hora', style: AppTextStyles.title),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today_rounded, size: 18),
                      label: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 60)),
                        );
                        if (picked != null) setState(() => _selectedDate = picked);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time_rounded, size: 18),
                      label: Text(_selectedTime.format(context)),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _selectedTime,
                        );
                        if (picked != null) setState(() => _selectedTime = picked);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Notas adicionales (opcional)', style: AppTextStyles.title),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notasCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Ej. Mesa exterior, celebración de cumpleaños...',
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: _loading ? null : _submitReservation,
                child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Confirmar Reserva & Generar Ticket QR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
