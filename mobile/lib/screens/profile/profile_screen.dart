import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
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
  bool _isFollowing = false;
  bool _loading = true;
  String? _bannerUrl;
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
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(targetId).get();
      final userData = userDoc.data() ?? {};
      final username = (userData['username'] as String?) ?? auth.user?.username ?? '';

      final postsQueryById = await FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: targetId)
          .get();

      final postsQueryByUsername = username.isNotEmpty
          ? await FirebaseFirestore.instance
              .collection('posts')
              .where('username', isEqualTo: username)
              .get()
          : null;

      final favsQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetId)
          .collection('favorites')
          .get();

      _bannerUrl = userData['bannerUrl'] as String?;

      final Map<String, PostModel> map = {};

      final allDocs = [
        ...postsQueryById.docs,
        if (postsQueryByUsername != null) ...postsQueryByUsername.docs,
      ];

      for (final doc in allDocs) {
        final data = doc.data();
        final createdAtField = data['createdAt'];
        DateTime dt = DateTime.now();
        if (createdAtField is Timestamp) {
          dt = createdAtField.toDate();
        }
        map[doc.id] = PostModel.fromJson({
          'id': doc.id,
          ...data,
          'createdAt': dt.toIso8601String(),
        });
      }

      final postsList = map.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final List<RestaurantModel> favsList = [];
      for (final fDoc in favsQuery.docs) {
        final rId = fDoc.data()['restaurantId'] as String? ?? fDoc.id;
        final rSnap = await FirebaseFirestore.instance.collection('restaurants').doc(rId).get();
        if (rSnap.exists) {
          favsList.add(RestaurantModel.fromJson({'id': rSnap.id, ...rSnap.data()!}));
        }
      }

      bool following = false;
      if (currentUserId != null && targetId != currentUserId) {
        final fDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('following')
            .doc(targetId)
            .get();
        following = fDoc.exists;
      }

      if (!mounted) return;
      setState(() {
        _user = UserModel.fromJson({'id': targetId, ...userData});
        _posts = postsList;
        _favorites = favsList;
        _isFollowing = following;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow() async {
    final currentUserId = context.read<AuthProvider>().user?.id;
    if (currentUserId == null || _user == null) return;

    final targetId = _user!.id;
    final newFollowing = !_isFollowing;

    setState(() {
      _isFollowing = newFollowing;
    });

    try {
      final myFollowingRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(targetId);

      final targetFollowersRef = FirebaseFirestore.instance
          .collection('users')
          .doc(targetId)
          .collection('followers')
          .doc(currentUserId);

      final myUserRef = FirebaseFirestore.instance.collection('users').doc(currentUserId);
      final targetUserRef = FirebaseFirestore.instance.collection('users').doc(targetId);

      if (newFollowing) {
        await myFollowingRef.set({'userId': targetId, 'createdAt': FieldValue.serverTimestamp()});
        await targetFollowersRef.set({'userId': currentUserId, 'createdAt': FieldValue.serverTimestamp()});
        await myUserRef.update({'followingCount': FieldValue.increment(1)});
        await targetUserRef.update({'followersCount': FieldValue.increment(1)});
      } else {
        await myFollowingRef.delete();
        await targetFollowersRef.delete();
        await myUserRef.update({'followingCount': FieldValue.increment(-1)});
        await targetUserRef.update({'followersCount': FieldValue.increment(-1)});
      }
    } catch (e) {
      debugPrint('Error al actualizar seguimiento: $e');
    }
  }

  Widget _buildRoleBadge(String? role) {
    if (role == 'restaurant_admin') {
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

    if (role == 'moderador' || role == 'admin_sistema') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        margin: const EdgeInsets.only(top: 6),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.amber.shade700),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_rounded, color: Colors.amber.shade800, size: 14),
            const SizedBox(width: 4),
            Text(
              '🛡️ Moderador Oficial',
              style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontSize: 11),
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

    final content = Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        image: _bannerUrl != null && _bannerUrl!.isNotEmpty
                            ? DecorationImage(
                                image: CachedNetworkImageProvider(_bannerUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _bannerUrl == null
                          ? const Center(
                              child: Icon(Icons.restaurant_rounded, color: Colors.white24, size: 60),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: -40,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cardColor,
                        ),
                        child: CircleAvatar(
                          radius: 46,
                          backgroundColor: cardColor,
                          backgroundImage: user.avatarUrl != null
                              ? CachedNetworkImageProvider(user.avatarUrl!)
                              : null,
                          child: user.avatarUrl == null
                              ? Text(
                                  cleanUsername.isNotEmpty ? cleanUsername[0].toUpperCase() : '?',
                                  style: AppTextStyles.displayMedium.copyWith(color: AppColors.primary),
                                )
                              : null,
                        ),
                      ).animate().fadeIn(duration: 350.ms).scale(begin: const Offset(0.85, 0.85)),
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
                const SizedBox(height: 48),

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
                        if (user.role == 'restaurant_admin') ...[
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

                // TabBar de Navegación por Contenidos
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
        body: TabBarView(
          controller: _tabController,
          children: [
            // 1. Reseñas en Tiempo Real
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && _loading) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }

                final targetId = widget.userId ?? auth.user?.id ?? user.id;
                final docs = snapshot.data?.docs ?? [];
                final userPosts = docs.map((doc) {
                  final data = doc.data();
                  final createdAtField = data['createdAt'];
                  DateTime dt = DateTime.now();
                  if (createdAtField is Timestamp) {
                    dt = createdAtField.toDate();
                  }
                  return PostModel.fromJson({
                    'id': doc.id,
                    ...data,
                    'createdAt': dt.toIso8601String(),
                  });
                }).where((p) => p.userId == targetId).toList();

                if (userPosts.isEmpty) {
                  return Center(child: Text('Aún no has publicado reseñas', style: TextStyle(color: textColor)));
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: userPosts.length,
                  itemBuilder: (context, i) => InkWell(
                    onTap: () async {
                      final deleted = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => PostDetailScreen(post: userPosts[i])),
                      );
                      if (deleted == true) _loadData();
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: userPosts[i].imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: AppColors.divider),
                        errorWidget: (_, __, ___) => Container(color: AppColors.divider),
                      ),
                    ),
                  ).animate(delay: Duration(milliseconds: 30 * i)).fadeIn(duration: 200.ms),
                );
              },
            ),

            // 2. Favoritos
            _favorites.isEmpty
                ? Center(child: Text('Aún no tienes restaurantes en favoritos', style: TextStyle(color: textColor)))
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

            // 3. Reservas QR en Tiempo Real
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('reservations')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }

                final targetId = widget.userId ?? auth.user?.id ?? user.id;
                final docs = snapshot.data?.docs ?? [];
                final userReservations = docs.map((d) => ReservationModel.fromJson({'id': d.id, ...d.data()})).where((r) {
                  final cId = r.clienteId.toLowerCase();
                  final tId = targetId.toLowerCase();
                  final myId = (auth.user?.id ?? '').toLowerCase();
                  final myEmail = (auth.user?.email ?? '').toLowerCase();
                  return cId.isNotEmpty && (cId == tId || cId == myId || cId == myEmail);
                }).toList();

                if (userReservations.isEmpty) {
                  return Center(
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
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: userReservations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final res = userReservations[i];
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
                );
              },
            ),
          ],
        ),
      ),
    );

    if (widget.userId != null) {
      return Scaffold(body: content);
    }

    return content;
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
