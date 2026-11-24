import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../core/services/api_service.dart';
import '../../providers/auth_provider.dart';

class CreatePqrsScreen extends StatefulWidget {
  const CreatePqrsScreen({super.key});

  @override
  State<CreatePqrsScreen> createState() => _CreatePqrsScreenState();
}

class _CreatePqrsScreenState extends State<CreatePqrsScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _asuntoCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final ApiService _apiService = ApiService();

  String _tipo = 'peticion';
  bool _loading = false;
  late TabController _tabController;
  List<Map<String, dynamic>> _myPqrsList = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPqrs();
  }

  @override
  void dispose() {
    _asuntoCtrl.dispose();
    _descCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPqrs() async {
    try {
      final list = await _apiService.getPQRS();
      if (mounted) {
        setState(() => _myPqrsList = list);
      }
    } catch (_) {}
  }

  Future<void> _submitPqrs() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      await _apiService.createPQRS({
        'clienteId': user.id,
        'clienteEmail': user.email,
        'clienteNombre': user.fullName ?? user.username,
        'tipo': _tipo,
        'asunto': _asuntoCtrl.text.trim(),
        'descripcion': _descCtrl.text.trim(),
      });

      if (!mounted) return;
      _asuntoCtrl.clear();
      _descCtrl.clear();
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Radicado enviado con éxito. Te notificaremos cuando sea respondido.'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadPqrs();
      _tabController.animateTo(1);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar radicado: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Atención al Cliente - PQRS'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.note_add_rounded), text: 'Radicar PQRS'),
            Tab(icon: Icon(Icons.history_rounded), text: 'Mis Casos y Respuestas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Radicar Petición, Queja o Reclamo', style: AppTextStyles.headline),
                  const SizedBox(height: 6),
                  Text('Nuestro equipo de moderadores atenderá tu requerimiento en tiempo real.', style: AppTextStyles.subtle),
                  const SizedBox(height: 24),
                  Text('Tipo de Solicitud *', style: AppTextStyles.title),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _tipo,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.category_rounded, color: AppColors.primary),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'peticion', child: Text('Petición (Solicitud de información)')),
                      DropdownMenuItem(value: 'queja', child: Text('Queja (Inconformidad por servicio)')),
                      DropdownMenuItem(value: 'reclamo', child: Text('Reclamo (Disconformidad con producto)')),
                      DropdownMenuItem(value: 'sugerencia', child: Text('Sugerencia (Propuesta de mejora)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _tipo = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('Asunto del Caso *', style: AppTextStyles.title),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _asuntoCtrl,
                    decoration: const InputDecoration(hintText: 'Ej. Inconveniente con reserva en restaurante'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),
                  Text('Descripción Detallada *', style: AppTextStyles.title),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(hintText: 'Explica con detalle lo sucedido...'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _loading ? null : _submitPqrs,
                    icon: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, color: Colors.white),
                    label: const Text('Enviar Radicado Oficial', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),

          user == null
              ? const Center(child: Text('Debes iniciar sesión para ver tus radicados.'))
              : _myPqrsList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.inbox_outlined, size: 64, color: AppColors.secondary),
                          const SizedBox(height: 16),
                          Text('No tienes radicados registrados', style: AppTextStyles.headline),
                          const SizedBox(height: 6),
                          Text('Tus peticiones y sus respuestas aparecerán aquí.', style: AppTextStyles.subtle),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: _myPqrsList.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, i) {
                        final data = _myPqrsList[i];
                        final estado = data['status'] ?? data['estado'] ?? 'recibida';
                        final respuesta = data['respuesta'] as String? ?? '';

                        Color estadoColor = Colors.orange;
                        String estadoText = 'RECIBIDA ⏳';
                        if (estado == 'en_gestion') {
                          estadoColor = Colors.blue;
                          estadoText = 'EN GESTIÓN ⚙️';
                        } else if (estado == 'resuelta' || estado == 'cerrada') {
                          estadoColor = Colors.green;
                          estadoText = 'RESUELTA ✅';
                        }

                        return Container(
                          padding: const EdgeInsets.all(16),
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
                                      data['type']?.toString().toUpperCase() ?? data['tipo']?.toString().toUpperCase() ?? 'PQRS',
                                      style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const Spacer(),
                                  Chip(
                                    label: Text(estadoText, style: TextStyle(color: estadoColor, fontWeight: FontWeight.bold, fontSize: 10)),
                                    backgroundColor: estadoColor.withValues(alpha: 0.15),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(data['subject'] ?? data['asunto'] ?? 'Sin Asunto', style: AppTextStyles.title),
                              const SizedBox(height: 6),
                              Text(data['description'] ?? data['descripcion'] ?? '', style: AppTextStyles.body),
                              if (respuesta.isNotEmpty) ...[
                                const Divider(height: 24),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.green.shade200),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.support_agent_rounded, color: Colors.green, size: 18),
                                          const SizedBox(width: 8),
                                          Text('Respuesta Oficial del Moderador:', style: AppTextStyles.caption.copyWith(color: Colors.green.shade900, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(respuesta, style: AppTextStyles.body.copyWith(color: Colors.green.shade900)),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
        ],
      ),
    );
  }
}
