import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../core/services/api_service.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import '../posts/post_detail_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _user;
  List<PostModel> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final targetId = widget.userId ?? auth.user?.id;

    if (targetId == null) return;

    try {
      final userRes = await ApiService().dio.get('/api/users/$targetId');
      final postsRes = await ApiService().dio.get('/api/posts/user/$targetId');

      if (!mounted) return;
      setState(() {
        _user = UserModel.fromJson(userRes.data);
        final List postsData = postsRes.data;
        _posts = postsData.map((e) => PostModel.fromJson(e)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isMe = widget.userId == null || widget.userId == auth.user?.id;
    final user = _user ?? auth.user;

    if (user == null && _loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (user == null) {
      return const Center(child: Text('Error al cargar perfil'));
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: AppColors.background,
              elevation: 0,
              pinned: true,
              title: Text('@${user.username}', style: AppTextStyles.title),
              actions: [
                if (isMe)
                  IconButton(
                    icon: const Icon(Icons.logout_rounded),
                    onPressed: () async {
                      await context.read<AuthProvider>().logout();
                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (_) => false,
                      );
                    },
                  ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.accent],
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 52,
                        backgroundColor: Colors.white,
                        backgroundImage: user.avatarUrl != null
                            ? CachedNetworkImageProvider(user.avatarUrl!)
                            : null,
                        child: user.avatarUrl == null
                            ? Text(
                                user.username.isNotEmpty
                                    ? user.username[0].toUpperCase()
                                    : '?',
                                style: AppTextStyles.displayMedium
                                    .copyWith(color: AppColors.primary),
                              )
                            : null,
                      ),
                    ).animate().fadeIn(duration: 350.ms).scale(
                          begin: const Offset(0.85, 0.85),
                          curve: Curves.easeOutBack,
                        ),
                    const SizedBox(height: 14),
                    Text(user.fullName ?? user.username, style: AppTextStyles.headline),
                    Text('@${user.username}', style: AppTextStyles.subtle),
                    if (user.bio != null && user.bio!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        user.bio!,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body,
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _Stat(label: 'Publicaciones', value: '${user.postsCount}'),
                        _Stat(label: 'Seguidores', value: '${user.followersCount}'),
                        _Stat(label: 'Seguidos', value: '${user.followingCount}'),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (isMe)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.divider),
                            foregroundColor: AppColors.textPrimary,
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            final updated = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                            );
                            if (updated == true) _loadData();
                          },
                          child: const Text('Editar perfil'),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              if (user.isFollowing == true) {
                                await ApiService().dio.delete('/api/follows/${user.id}');
                              } else {
                                await ApiService().dio.post('/api/follows/${user.id}');
                              }
                              _loadData();
                            } catch (e) {
                              // ignore
                            }
                          },
                          child: Text(user.isFollowing == true ? 'Siguiendo' : 'Seguir'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_posts.isEmpty && !_loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text('Aún no hay publicaciones'),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => InkWell(
                      onTap: () async {
                        final deleted = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PostDetailScreen(post: _posts[i]),
                          ),
                        );
                        if (deleted == true) _loadData();
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: _posts[i].imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: AppColors.divider),
                          errorWidget: (_, __, ___) =>
                              Container(color: AppColors.divider),
                        ),
                      ),
                    )
                        .animate(delay: Duration(milliseconds: 40 * i))
                        .fadeIn(duration: 250.ms),
                    childCount: _posts.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.title),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}
