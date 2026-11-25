import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../providers/auth_provider.dart';
import '../../services/cloudinary_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final _verificationCode = TextEditingController();
  final _restaurantDescription = TextEditingController();
  bool _identityBusy = false;
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _usernameController;
  late TextEditingController _phoneController;

  XFile? _avatarFile;
  String? _avatarUrl;
  bool _loading = false;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameController = TextEditingController(text: user?.fullName ?? user?.username ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
    _usernameController = TextEditingController(text: user?.username ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _avatarUrl = user?.avatarUrl;
  }

  Future<void> _pickAvatar() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() => _avatarFile = picked);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _verificationCode.dispose();
    _restaurantDescription.dispose();
    super.dispose();
  }

  Future<void> _identityAction(Future<String> Function() operation) async {
    if (_identityBusy) return;
    setState(() => _identityBusy = true);
    try {
      final message = await operation();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      if (mounted) {
        final message = error.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _identityBusy = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      String? finalAvatarUrl = _avatarUrl;

      if (_avatarFile != null) {
        final uploaded = await CloudinaryService.uploadImageXFile(_avatarFile!);
        if (uploaded != null) finalAvatarUrl = uploaded;
      }

      final updateData = {
        'bio': _bioController.text.trim(),
        'phone': _phoneController.text.trim(),
        'avatarUrl': finalAvatarUrl,
      };

      final response = await _apiService.dio.put('/users/${user.id}', data: updateData);

      if (!mounted) return;
      if (response.data != null) {
        context.read<AuthProvider>().updateUser(Map<String, dynamic>.from(response.data));
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado correctamente'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar perfil: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isFoodie = user?.role == 'foodie' || user?.role == 'FOODIE';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        actions: [
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 46,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        backgroundImage: _avatarFile != null
                            ? NetworkImage(_avatarFile!.path)
                            : (_avatarUrl != null && _avatarUrl!.isNotEmpty ? NetworkImage(_avatarUrl!) : null),
                        child: (_avatarFile == null && (_avatarUrl == null || _avatarUrl!.isEmpty))
                            ? const Icon(Icons.person, size: 48, color: AppColors.primary)
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text('Nombre Completo 🔒', style: AppTextStyles.title),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                enabled: false,
                decoration: InputDecoration(
                  hintText: 'Tu nombre y apellido',
                  fillColor: Colors.grey.shade100,
                  filled: true,
                  prefixIcon: const Icon(Icons.lock_rounded, color: Colors.grey),
                  helperText: 'El nombre completo está protegido y no se puede modificar.',
                  helperStyle: AppTextStyles.caption.copyWith(color: Colors.grey.shade600),
                ),
              ),
              const SizedBox(height: 16),

              Text('Nombre de usuario 🔒', style: AppTextStyles.title),
              const SizedBox(height: 8),
              TextFormField(
                controller: _usernameController,
                enabled: false,
                decoration: InputDecoration(
                  hintText: 'usuario',
                  fillColor: Colors.grey.shade100,
                  filled: true,
                  prefixIcon: const Icon(Icons.lock_rounded, color: Colors.grey),
                  helperText: 'El nombre de usuario (@username) está bloqueado por seguridad.',
                  helperStyle: AppTextStyles.caption.copyWith(color: Colors.grey.shade600),
                ),
              ),
              const SizedBox(height: 16),

              Text('Teléfono de contacto ✏️', style: AppTextStyles.title),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: 'Ej. +57 300 1234567',
                  prefixIcon: Icon(Icons.phone_outlined, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 16),

              Text('Biografía ✏️', style: AppTextStyles.title),
              const SizedBox(height: 8),
              TextFormField(
                controller: _bioController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Cuéntale a la comunidad foodie sobre tus gustos culinarios...',
                  prefixIcon: Icon(Icons.edit_note_rounded, color: AppColors.primary),
                ),
              ),

              if (user != null) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                Text('Verificación de correo', style: AppTextStyles.title),
                const SizedBox(height: 6),
                Text(
                  user.emailVerified ? 'Correo verificado' : 'Verifica el correo de tu cuenta.',
                  style: AppTextStyles.subtle,
                ),
                if (!user.emailVerified || isFoodie) ...[
                  OutlinedButton(
                    onPressed: _identityBusy ? null : () => _identityAction(() async {
                      await _authService.sendVerificationCode();
                      return 'Código enviado al correo de tu cuenta.';
                    }),
                    child: const Text('Enviar código al correo'),
                  ),
                  TextField(
                    controller: _verificationCode,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(labelText: 'Código de verificación'),
                  ),
                  if (!user.emailVerified)
                    OutlinedButton(
                      onPressed: _identityBusy ? null : () => _identityAction(() async {
                        final data = await _authService.verifyEmail(_verificationCode.text);
                        if (mounted && context.read<AuthProvider>().user?.id == user.id) {
                          context.read<AuthProvider>().updateUser(data);
                        }
                        return 'Correo verificado.';
                      }),
                      child: const Text('Confirmar correo'),
                    ),
                ],
                if (isFoodie) ...[
                  const SizedBox(height: 24),
                  Text('Administración de restaurante', style: AppTextStyles.title),
                  Text(
                    'Indica qué establecimiento deseas administrar. Usa un código de correo vigente. Si se aprueba la solicitud, vuelve a iniciar sesión desde la web.',
                    style: AppTextStyles.subtle,
                  ),
                  TextField(
                    controller: _restaurantDescription,
                    maxLines: 3,
                    maxLength: 2000,
                    decoration: const InputDecoration(labelText: 'Describe tu solicitud'),
                  ),
                  OutlinedButton(
                    onPressed: _identityBusy ? null : () => _identityAction(() async {
                      await _authService.requestRestaurantAdmin(
                        _verificationCode.text,
                        _restaurantDescription.text,
                      );
                      return 'Solicitud registrada. Puedes seguirla en PQRS.';
                    }),
                    child: const Text('Solicitar administración de restaurante'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
