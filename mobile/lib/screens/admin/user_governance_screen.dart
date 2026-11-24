import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../models/user_model.dart';

class UserGovernanceScreen extends StatefulWidget {
  const UserGovernanceScreen({super.key});

  @override
  State<UserGovernanceScreen> createState() => _UserGovernanceScreenState();
}

class _UserGovernanceScreenState extends State<UserGovernanceScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  List<UserModel> _users = [];
  List<UserModel> _filteredUsers = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final response = await _apiService.dio.get('/users');
      final list = response.data as List;
      final parsed = list.map((e) => UserModel.fromJson(Map<String, dynamic>.from(e))).toList();
      setState(() {
        _users = parsed;
        _applySearch();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _applySearch() {
    if (_searchQuery.trim().isEmpty) {
      _filteredUsers = List.from(_users);
    } else {
      final q = _searchQuery.toLowerCase().trim();
      _filteredUsers = _users.where((u) {
        final fn = (u.fullName ?? '').toLowerCase();
        final un = (u.username ?? '').toLowerCase();
        final em = (u.email ?? '').toLowerCase();
        final rl = (u.role ?? '').toLowerCase();
        return fn.contains(q) || un.contains(q) || em.contains(q) || rl.contains(q);
      }).toList();
    }
  }

  Future<void> _toggleUserStatus(UserModel user) async {
    try {
      await _apiService.dio.put('/users/${user.id}/status');
      _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Estado de ${user.fullName} actualizado')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cambiar estado: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _deleteUser(UserModel user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Usuario'),
        content: Text('¿Seguro que deseas eliminar definitivamente a ${user.fullName} (@${user.username})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _apiService.dio.delete('/users/${user.id}');
      _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Usuario ${user.fullName} eliminado')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar usuario: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _showCreateModeratorDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.shield_rounded, color: AppColors.primary, size: 26),
              const SizedBox(width: 10),
              Text('Crear Nuevo Moderador', style: AppTextStyles.title),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre completo'),
                    validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: usernameCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre de usuario (@moderador)'),
                    validator: (v) => v!.trim().length < 3 ? 'Mínimo 3 caracteres' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Correo electrónico'),
                    validator: (v) => !v!.contains('@') ? 'Correo inválido' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Contraseña'),
                    validator: (v) => v!.length < 6 ? 'Mínimo 6 caracteres' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDlgState(() => isSaving = true);
                      try {
                        await _authService.register(
                          email: emailCtrl.text.trim(),
                          username: usernameCtrl.text.trim(),
                          password: passwordCtrl.text,
                          fullName: nameCtrl.text.trim(),
                          role: 'moderador',
                        );

                        if (!mounted) return;
                        Navigator.pop(dialogCtx);
                        _loadUsers();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('¡Moderador creado con éxito!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        setDlgState(() => isSaving = false);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error al crear moderador: $e')),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Crear Moderador', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Usuarios & Moderadores'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: _showCreateModeratorDialog,
              icon: const Icon(Icons.person_add_rounded, color: Colors.white, size: 18),
              label: const Text('+ Crear Nuevo Moderador', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Buscador
            TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar usuario por nombre, @username, correo o rol...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                  _applySearch();
                });
              },
            ),
            const SizedBox(height: 20),

            // Lista / Tabla de Usuarios
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _filteredUsers.isEmpty
                      ? const Center(child: Text('No se encontraron usuarios.'))
                      : ListView.separated(
                          itemCount: _filteredUsers.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, index) {
                            final user = _filteredUsers[index];
                            final roleStr = (user.role ?? '').toLowerCase();
                            final isMod = roleStr == 'moderador' || roleStr == 'admin_sistema';
                            final isAdminRest = roleStr == 'restaurant_admin';

                            Color roleBg = Colors.blue.withValues(alpha: 0.1);
                            Color roleColor = Colors.blue;
                            String roleLabel = 'Foodie 🥑';

                            if (isMod) {
                              roleBg = Colors.purple.withValues(alpha: 0.1);
                              roleColor = Colors.purple;
                              roleLabel = 'Moderador 🛡️';
                            } else if (isAdminRest) {
                              roleBg = Colors.orange.withValues(alpha: 0.1);
                              roleColor = Colors.orange;
                              roleLabel = 'Admin Restaurante 🏪';
                            }

                            final fullNameStr = user.fullName ?? 'Usuario';
                            final displayInitial = fullNameStr.isNotEmpty ? fullNameStr[0].toUpperCase() : 'U';

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: roleBg,
                                child: Text(
                                  displayInitial,
                                  style: TextStyle(color: roleColor, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text(fullNameStr, style: AppTextStyles.title.copyWith(fontSize: 15)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: roleBg, borderRadius: BorderRadius.circular(8)),
                                    child: Text(roleLabel, style: TextStyle(color: roleColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              subtitle: Text('@${user.username} • ${user.email}', style: AppTextStyles.caption),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      user.isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                      color: user.isActive ? Colors.green : Colors.red,
                                    ),
                                    tooltip: user.isActive ? 'Activo (Clic para suspender)' : 'Suspendido (Clic para activar)',
                                    onPressed: () => _toggleUserStatus(user),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                                    tooltip: 'Eliminar Usuario',
                                    onPressed: () => _deleteUser(user),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
