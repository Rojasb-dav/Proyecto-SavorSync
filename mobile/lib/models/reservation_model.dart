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
    final createdAtField = json['createdAt'] ?? json['created_at'];
    DateTime dt = DateTime.now();
    if (createdAtField is String) {
      dt = DateTime.tryParse(createdAtField) ?? DateTime.now();
    }

    return ReservationModel(
      id: json['id'] as String? ?? '',
      restaurantId: (json['restaurantId'] ?? json['restaurante_id']) as String? ?? '',
      restaurantName: (json['restaurantName'] ?? json['restaurante_nombre']) as String? ?? 'Restaurante',
      clienteId: (json['clienteId'] ?? json['cliente_id']) as String? ?? '',
      clienteNombre: (json['clienteNombre'] ?? json['cliente_nombre']) as String? ?? 'Comensal',
      numPersonas: ((json['numPersonas'] ?? json['num_personas']) as num?)?.toInt() ?? 2,
      fechaReserva: (json['fechaReserva'] ?? json['fecha_reserva']) as String? ?? '',
      horaReserva: (json['horaReserva'] ?? json['hora_reserva']) as String? ?? '',
      notas: json['notas'] as String? ?? '',
      estado: (json['estado'] ?? json['status']) as String? ?? 'pendiente',
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
        'createdAt': createdAt.toIso8601String(),
      };
}
