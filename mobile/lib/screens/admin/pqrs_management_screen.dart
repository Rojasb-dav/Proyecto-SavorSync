import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../core/services/api_service.dart';

class PqrsManagementScreen extends StatefulWidget {
  const PqrsManagementScreen({super.key});

  @override
  State<PqrsManagementScreen> createState() => _PqrsManagementScreenState();
}

class _PqrsManagementScreenState extends State<PqrsManagementScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _pqrsList = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPqrs();
  }

  Future<void> _loadPqrs() async {
    try {
      final list = await _apiService.getPQRS();
      if (mounted) {
        setState(() {
          _pqrsList = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showResponseModal(BuildContext context, Map<String, dynamic> data) {
    final responseCtrl = TextEditingController(text: data['respuesta'] as String? ?? '');
    String selectedEstado = 'resuelta';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 26),
                  const SizedBox(width: 10),
                  Text('Atender y Responder PQRS', style: AppTextStyles.headline),
                ],
              ),
              const SizedBox(height: 14),
              Text('Estado de Cierre:', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Resuelta ✅'),
                    selected: selectedEstado == 'resuelta',
                    onSelected: (_) => setDlgState(() => selectedEstado = 'resuelta'),
                  ),
                  const SizedBox(width: 10),
                  ChoiceChip(
                    label: const Text('En Gestión ⚙️'),
                    selected: selectedEstado == 'en_gestion',
                    onSelected: (_) => setDlgState(() => selectedEstado = 'en_gestion'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: responseCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Escribe la respuesta oficial al cliente...',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    label: const Text('Guardar y Notificar al Cliente', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      final responseText = responseCtrl.text.trim();
                      if (responseText.isEmpty) return;

                      await _apiService.updatePQRSStatus(data['id'] ?? '1', selectedEstado);

                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      _loadPqrs();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Respuesta enviada y cliente notificado'), backgroundColor: Colors.green),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bandeja de Gestión PQRS')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _pqrsList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.inbox_rounded, size: 64, color: AppColors.secondary),
                          const SizedBox(height: 16),
                          Text('No hay radicación de PQRS', style: AppTextStyles.headline),
                          const SizedBox(height: 6),
                          Text('Las solicitudes de los clientes aparecerán aquí.', style: AppTextStyles.subtle),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(24),
                      itemCount: _pqrsList.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, i) {
                        final data = _pqrsList[i];
                        final estado = data['status'] ?? data['estado'] ?? 'recibida';
                        final isClosed = estado == 'resuelta' || estado == 'cerrada';

                        Color estadoColor = Colors.orange;
                        if (estado == 'en_gestion') estadoColor = Colors.blue;
                        if (estado == 'resuelta' || estado == 'cerrada') estadoColor = Colors.green;

                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.divider),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      data['type']?.toString().toUpperCase() ?? 'PQRS',
                                      style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const Spacer(),
                                  Chip(
                                    label: Text(
                                      estado.toUpperCase(),
                                      style: TextStyle(color: estadoColor, fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                    backgroundColor: estadoColor.withValues(alpha: 0.15),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(data['subject'] ?? data['asunto'] ?? 'Sin Asunto', style: AppTextStyles.title.copyWith(fontSize: 16)),
                              const SizedBox(height: 4),
                              Text('Cliente: ${data['clienteNombre'] ?? 'Anónimo'}', style: AppTextStyles.caption),
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(data['description'] ?? data['descripcion'] ?? '', style: AppTextStyles.body),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: isClosed ? AppColors.secondary : AppColors.primary),
                                    icon: Icon(isClosed ? Icons.edit_note_rounded : Icons.reply_rounded, color: Colors.white, size: 18),
                                    label: Text(isClosed ? 'Editar Respuesta' : 'Responder Caso', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    onPressed: () => _showResponseModal(context, data),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
