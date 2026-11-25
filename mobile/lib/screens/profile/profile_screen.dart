import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/token_storage.dart';
import '../../models/post_model.dart';
import '../../models/reservation_model.dart';
import '../../models/restaurant_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../admin/restaurant_admin_dashboard.dart';
import '../auth/login_screen.dart';
import '../posts/post_detail_screen.dart';
import '../restaurants/reservation_ticket_modal.dart';
import '../restaurants/restaurant_detail_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  UserModel? _user;
  List<PostModel> _posts = [];
  List<RestaurantModel> _favorites = [];
  List<ReservationModel> _reservations = [];
  bool _isFollowing = false;
  bool _loading = true;
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final currentUserId = auth.user?.id;
    final targetId = widget.userId ?? currentUserId;

    if (targetId == null) return;

    try {
      final userObj = await _apiService.dio.get('/users/$targetId');
      final fetchedUser = UserModel.fromJson(Map<String, dynamic>.from(userObj.data));
      final postsList = await _apiService.getUserPosts(targetId);
      final resList = targetId == currentUserId
          ? await _apiService.getReservations(userId: targetId)
          : <ReservationModel>[];
      final allRestaurants = await _apiService.getRestaurants();

      final favoriteIds = await TokenStorage().getFavoriteRestaurantIds();
      final userFavorites = allRestaurants.where((r) => favoriteIds.contains(r.id)).toList();

      final restMap = {for (var r in allRestaurants) r.id: r.name};

      final enrichedReservations = resList.map((r) {
        final realName = restMap[r.restaurantId] ??
            (r.restaurantName.isNotEmpty && r.restaurantName != 'Restaurante'
                ? r.restaurantName
                : 'Restaurante Bogotá');
        return ReservationModel(
          id: r.id,
          restaurantId: r.restaurantId,
          restaurantName: realName,
          clienteId: r.clienteId,
          clienteNombre: r.clienteNombre,
          numPersonas: r.numPersonas,
          fechaReserva: r.fechaReserva,
          horaReserva: r.horaReserva,
          notas: r.notas,
          estado: r.estado,
          createdAt: r.createdAt,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _user = fetchedUser;
        _posts = postsList;
        _reservations = enrichedReservations;
        _favorites = userFavorites;
        _isFollowing = fetchedUser.isFollowing ?? false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _user = auth.user;
        _loading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_user == null) return;

    final targetId = _user!.id;
    final newFollowing = !_isFollowing;

    setState(() {
      _isFollowing = newFollowing;
    });

    try {
      if (newFollowing) {
        await _apiService.dio.post('/follows/$targetId');
      } else {
        await _apiService.dio.delete('/follows/$targetId');
      }
    } catch (_) {}
  }

  Widget _buildRoleBadge(String? role) {
    if (role == 'RESTAURANT_ADMIN' || role == 'restaurant_admin') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        margin: const EdgeInsets.only(top: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_rounded, color: AppColors.primary, size: 14),
            SizedBox(width: 4),
            Text(
              'Administrador de Restaurante',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, color: AppColors.primary, size: 14),
          SizedBox(width: 4),
          Text(
            '🥑 Foodie Crítico de Bogotá',
            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = _user ?? auth.user;
    final isMe = widget.userId == null || widget.userId == auth.user?.id;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textPrimary;

    if (_loading && user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Usuario no encontrado')));
    }

    final cleanUsername = user.username.replaceAll('@', '');

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      height: 140,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                      ),
                      child: const Center(
                        child: Icon(Icons.restaurant_rounded, color: Colors.white24, size: 60),
                      ),
                    ),
                    if (isMe)
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                            tooltip: 'Cerrar Sesión',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Cerrar Sesión'),
                                  content: const Text('¿Estás seguro de que deseas salir de tu cuenta en SavorSync?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await auth.logout();
                                if (!context.mounted) return;
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                                  (_) => false,
                                );
                              }
                            },
                          ),
                        ),
                      ),
                  ],
                ),

                Transform.translate(
                  offset: const Offset(0, -40),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cardColor,
                        ),
                        child: CircleAvatar(
                          radius: 46,
                          backgroundColor: cardColor,
                          backgroundImage: (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                              ? CachedNetworkImageProvider(user.avatarUrl!)
                              : null,
                          child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                              ? Text(
                                  cleanUsername.isNotEmpty ? cleanUsername[0].toUpperCase() : '?',
                                  style: AppTextStyles.displayMedium.copyWith(color: AppColors.primary),
                                )
                              : null,
                        ),
                      ).animate().fadeIn(duration: 350.ms).scale(begin: const Offset(0.85, 0.85)),

                      const SizedBox(height: 8),
                      Text(user.fullName ?? cleanUsername, style: AppTextStyles.headline.copyWith(color: textColor)),
                      Text('@$cleanUsername', style: AppTextStyles.subtle.copyWith(color: textColor.withValues(alpha: 0.7))),
                      _buildRoleBadge(user.role),

                      if (user.bio != null && user.bio!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            user.bio!,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.body.copyWith(color: textColor),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _Stat(label: 'Publicaciones', value: '${_posts.length}', textColor: textColor),
                          _Stat(label: 'Seguidores', value: '${user.followersCount}', textColor: textColor),
                          _Stat(label: 'Seguidos', value: '${user.followingCount}', textColor: textColor),
                        ],
                      ).animate(delay: 150.ms).fadeIn().slideY(begin: 0.1),
                      const SizedBox(height: 16),

                      if (isMe) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: [
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Theme.of(context).dividerColor),
                                  foregroundColor: textColor,
                                  minimumSize: const Size.fromHeight(42),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () async {
                                  final updated = await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                                  );
                                  if (updated == true) _loadData();
                                },
                                child: Text('Editar perfil & Portada', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                              ),
                              if (user.role == 'restaurant_admin' || user.role == 'RESTAURANT_ADMIN') ...[
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    minimumSize: const Size.fromHeight(42),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const RestaurantAdminDashboard()),
                                    );
                                  },
                                  icon: const Icon(Icons.storefront_rounded, color: Colors.white, size: 18),
                                  label: const Text('Panel de Mi Restaurante', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ] else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isFollowing ? Colors.grey.shade400 : AppColors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(44),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _toggleFollow,
                            child: Text(_isFollowing ? 'Siguiendo ✅' : 'Seguir', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),

                      const SizedBox(height: 16),

                      TabBar(
                        controller: _tabController,
                        labelColor: AppColors.primary,
                        unselectedLabelColor: textColor.withValues(alpha: 0.6),
                        indicatorColor: AppColors.primary,
                        tabs: const [
                          Tab(icon: Icon(Icons.grid_on_rounded), text: 'Reseñas'),
                          Tab(icon: Icon(Icons.favorite_rounded), text: 'Favoritos'),
                          Tab(icon: Icon(Icons.confirmation_number_rounded), text: 'Reservas QR'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _posts.isEmpty
                ? Center(child: Text('Aún no hay reseñas publicadas', style: TextStyle(color: textColor)))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _posts.length,
                    itemBuilder: (context, i) => InkWell(
                      onTap: () async {
                        final deleted = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PostDetailScreen(post: _posts[i])),
                        );
                        if (deleted == true) _loadData();
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: _posts[i].imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: AppColors.divider),
                          errorWidget: (_, __, ___) => Container(color: AppColors.divider),
                        ),
                      ),
                    ).animate(delay: Duration(milliseconds: 30 * i)).fadeIn(duration: 200.ms),
                  ),

            _favorites.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.favorite_border_rounded, size: 54, color: AppColors.primary),
                          const SizedBox(height: 12),
                          Text('Aún no tienes restaurantes en favoritos', style: AppTextStyles.title.copyWith(color: textColor)),
                          const SizedBox(height: 4),
                          Text('Explora la app y presiona el ❤️ en la ficha del restaurante para guardarlo aquí.', style: AppTextStyles.caption.copyWith(color: textColor.withValues(alpha: 0.7)), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _favorites.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final r = _favorites[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.all(8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Theme.of(context).dividerColor)),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(r.imageUrl, width: 54, height: 54, fit: BoxFit.cover),
                        ),
                        title: Text(r.name, style: AppTextStyles.title.copyWith(color: textColor)),
                        subtitle: Text('${r.category} • ${r.ratingAverage} ★', style: TextStyle(color: textColor.withValues(alpha: 0.7))),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => RestaurantDetailScreen(restaurant: r)));
                        },
                      );
                    },
                  ),

            _reservations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.confirmation_number_outlined, size: 54, color: AppColors.secondary),
                        const SizedBox(height: 12),
                        Text('Aún no registras solicitudes de reserva', style: AppTextStyles.title.copyWith(color: textColor)),
                        const SizedBox(height: 4),
                        Text('Tus tickets digitales con código QR aparecerán aquí.', style: AppTextStyles.caption.copyWith(color: textColor.withValues(alpha: 0.7))),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reservations.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final res = _reservations[i];
                      final isConfirmed = res.estado == 'confirmada';
                      final isCanceled = res.estado == 'cancelada';

                      Color estadoColor = Colors.orange;
                      if (isConfirmed) estadoColor = Colors.green;
                      if (isCanceled) estadoColor = Colors.red;

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: estadoColor.withValues(alpha: 0.4), width: 1.5),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.confirmation_number_rounded, color: AppColors.primary, size: 28),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(res.restaurantName, style: AppTextStyles.title.copyWith(fontSize: 16, color: textColor)),
                                ),
                                Chip(
                                  label: Text(res.estado.toUpperCase(), style: TextStyle(color: estadoColor, fontWeight: FontWeight.bold, fontSize: 10)),
                                  backgroundColor: estadoColor.withValues(alpha: 0.15),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('📅 ${res.fechaReserva} • ⏰ ${res.horaReserva} (${res.numPersonas} personas)', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, color: textColor)),
                            if (res.notas.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('Notas: ${res.notas}', style: AppTextStyles.caption.copyWith(color: textColor.withValues(alpha: 0.7))),
                              ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    minimumSize: const Size(140, 38),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => ReservationTicketModal(
                                        reservationId: res.id,
                                        restaurantName: res.restaurantName,
                                        clienteNombre: res.clienteNombre,
                                        fechaReserva: res.fechaReserva,
                                        horaReserva: res.horaReserva,
                                        numPersonas: res.numPersonas,
                                        estado: res.estado,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 20),
                                  label: const Text('Ver Ticket QR 🎟️', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color textColor;
  const _Stat({required this.label, required this.value, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.title.copyWith(color: textColor)),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.caption.copyWith(color: textColor.withValues(alpha: 0.7))),
      ],
    );
  }
}
