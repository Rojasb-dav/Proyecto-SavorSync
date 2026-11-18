import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../models/restaurant_model.dart';
import '../../providers/auth_provider.dart';

class CreateReservationModal extends StatefulWidget {
  final RestaurantModel restaurant;
  const CreateReservationModal({super.key, required this.restaurant});

  @override
  State<CreateReservationModal> createState() => _CreateReservationModalState();
}

class _CreateReservationModalState extends State<CreateReservationModal> {
  final _formKey = GlobalKey<FormState>();
  final _notasCtrl = TextEditingController();

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

      final resRef = FirebaseFirestore.instance.collection('reservations').doc();
      final data = {
        'restaurantId': widget.restaurant.id,
        'restaurantName': widget.restaurant.name,
        'clienteId': user.id,
        'clienteNombre': user.fullName ?? user.username,
        'numPersonas': _numPersonas,
        'fechaReserva': fechaStr,
        'horaReserva': horaStr,
        'notas': _notasCtrl.text.trim(),
        'estado': 'pendiente',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await resRef.set(data);

      // Incrementar métrica de analíticas del restaurante
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurant.id)
          .update({'analytics.totalReservas': FieldValue.increment(1)});

      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Reserva solicitada con éxito!'),
          backgroundColor: Colors.green,
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
              Text(widget.restaurant.name, style: AppTextStyles.subtle),
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
                      icon: const Icon(Icons.calendar_today_rounded),
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
                      icon: const Icon(Icons.access_time_rounded),
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
                onPressed: _loading ? null : _submitReservation,
                child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Confirmar Reserva'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
