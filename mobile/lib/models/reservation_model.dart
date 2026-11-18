import 'package:cloud_firestore/cloud_firestore.dart';

class ReservationModel {
  final String id;
  final String restaurantId;
  final String restaurantName;
  final String clienteId;
  final String clienteNombre;
  final int numPersonas;
  final String fechaReserva;
  final String horaReserva;
  final String notas;
  final String estado; // 'pendiente' | 'confirmada' | 'cancelada' | 'completada'
  final DateTime createdAt;

  const ReservationModel({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.clienteId,
    required this.clienteNombre,
    required this.numPersonas,
    required this.fechaReserva,
    required this.horaReserva,
    required this.notas,
    required this.estado,
    required this.createdAt,
  });

  factory ReservationModel.fromJson(Map<String, dynamic> json) {
    final createdAtField = json['createdAt'];
    DateTime dt = DateTime.now();
    if (createdAtField is Timestamp) {
      dt = createdAtField.toDate();
    } else if (createdAtField is String) {
      dt = DateTime.tryParse(createdAtField) ?? DateTime.now();
    }

    return ReservationModel(
      id: json['id'] as String? ?? '',
      restaurantId: json['restaurantId'] as String? ?? '',
      restaurantName: json['restaurantName'] as String? ?? 'Restaurante',
      clienteId: json['clienteId'] as String? ?? '',
      clienteNombre: json['clienteNombre'] as String? ?? 'Comensal',
      numPersonas: json['numPersonas'] as int? ?? 2,
      fechaReserva: json['fechaReserva'] as String? ?? '',
      horaReserva: json['horaReserva'] as String? ?? '',
      notas: json['notas'] as String? ?? '',
      estado: json['estado'] as String? ?? 'pendiente',
      createdAt: dt,
    );
  }

  Map<String, dynamic> toJson() => {
        'restaurantId': restaurantId,
        'restaurantName': restaurantName,
        'clienteId': clienteId,
        'clienteNombre': clienteNombre,
        'numPersonas': numPersonas,
        'fechaReserva': fechaReserva,
        'horaReserva': horaReserva,
        'notas': notas,
        'estado': estado,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
