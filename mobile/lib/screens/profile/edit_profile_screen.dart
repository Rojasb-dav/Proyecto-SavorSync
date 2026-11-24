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
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _usernameController;
  late TextEditingController _phoneController;

  XFile? _avatarFile;
  XFile? _bannerFile;
  String? _avatarUrl;
  String? _bannerUrl;
  bool _loading = false;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameController = TextEditingController(text: user?.fullName);
    _bioController = TextEditingController(text: user?.bio);
    _usernameController = TextEditingController(text: user?.username);
    _phoneController = TextEditingController(text: user?.phone);
    _avatarUrl = user?.avatarUrl;
  }

  Future<void> _pickAvatar() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() => _avatarFile = picked);
    }
  }

  Future<void> _pickBanner() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() => _bannerFile = picked);
    }
  }

  Future<void> _linkGoogleAccount() async {
    try {
      final result = await _authService.signInWithGoogle();
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.link_rounded, color: Colors.green, size: 26),
              const SizedBox(width: 10),
              Expanded(child: Text('¡Cuenta de Google Enlazada! 🔗', style: AppTextStyles.title)),
            ],
          ),
          content: Text(
            'Tu perfil de Foodie ha sido enlazado exitosamente con la cuenta verificada de Google: ${result.user.email}. Ahora podrás iniciar sesión con un solo clic usando el botón de Google.',
            style: AppTextStyles.body.copyWith(fontSize: 14, color: AppColors.textSecondary),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Excelente', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 26),
              const SizedBox(width: 10),
              Expanded(child: Text('Aviso de Vinculación', style: AppTextStyles.title)),
            ],
          ),
          content: Text(
            e.toString().replaceAll('Exception: ', ''),
            style: AppTextStyles.body.copyWith(fontSize: 14, color: AppColors.textSecondary),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      String? finalAvatarUrl = _avatarUrl;
      String? finalBannerUrl = _bannerUrl;

      if (_avatarFile != null) {
        final uploaded = await CloudinaryService.uploadImageXFile(_avatarFile!);
        if (uploaded != null) finalAvatarUrl = uploaded;
      }

      if (_bannerFile != null) {
        final uploaded = await CloudinaryService.uploadImageXFile(_bannerFile!);
        if (uploaded != null) finalBannerUrl = uploaded;
      }

      final updateData = {
        'fullName': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'username': _usernameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'avatarUrl': finalAvatarUrl,
        'bannerUrl': finalBannerUrl,
      };

      try {
        await _apiService.dio.put('/users/${user.id}', data: updateData);
      } catch (_) {}

      if (!mounted) return;
      context.read<AuthProvider>().updateUser({
        'id': user.id,
        'email': user.email,
        'username': _usernameController.text.trim(),
        'fullName': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'phone': _phoneController.text.trim(),
        'avatarUrl': finalAvatarUrl,
        'role': user.role,
      });

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
              Text('Foto de Portada / Banner (Cloudinary)', style: AppTextStyles.title),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickBanner,
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                    image: _bannerFile != null
                        ? DecorationImage(image: NetworkImage(_bannerFile!.path), fit: BoxFit.cover)
                        : (_bannerUrl != null && _bannerUrl!.isNotEmpty
                            ? DecorationImage(image: NetworkImage(_bannerUrl!), fit: BoxFit.cover)
                            : null),
                  ),
                  child: (_bannerFile == null && (_bannerUrl == null || _bannerUrl!.isEmpty))
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_photo_alternate_outlined, size: 36, color: AppColors.primary),
                            const SizedBox(height: 4),
                            Text('Toca para elegir banner de portada', style: AppTextStyles.caption),
                          ],
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 24),

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

              Text('Nombre Completo', style: AppTextStyles.title),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(hintText: 'Tu nombre y apellido'),
              ),
              const SizedBox(height: 16),

              Text('Nombre de usuario', style: AppTextStyles.title),
              const SizedBox(height: 8),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(hintText: 'usuario'),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),

              Text('Teléfono de contacto', style: AppTextStyles.title),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(hintText: 'Ej. +57 300 1234567'),
              ),
              const SizedBox(height: 16),

              Text('Biografía', style: AppTextStyles.title),
              const SizedBox(height: 8),
              TextFormField(
                controller: _bioController,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Cuéntale a la comunidad foodie sobre tus gustos culinarios...'),
              ),

              if (isFoodie) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                Text('Enlazar Cuenta de Google 🔗', style: AppTextStyles.title),
                const SizedBox(height: 6),
                Text('Vincula tu perfil de SavorSync a tu cuenta de Google para iniciar sesión con un solo clic.', style: AppTextStyles.subtle),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _linkGoogleAccount,
                  icon: const Icon(Icons.g_mobiledata_rounded, color: Colors.red, size: 28),
                  label: const Text('Enlazar con Google ahora 🔗', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
