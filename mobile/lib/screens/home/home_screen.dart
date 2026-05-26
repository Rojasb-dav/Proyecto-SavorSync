import 'package:cached_network_image/cached_network_image.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../core/services/api_service.dart';
import '../../models/post_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/post_card.dart';
import '../posts/create_post_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  final GlobalKey<CurvedNavigationBarState> _navKey = GlobalKey();
  final List<PostModel> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _loading = true);
    try {
      final response = await ApiService().dio.get('/api/posts');
      final List data = response.data;
      final posts = data.map((e) => PostModel.fromJson(e)).toList();
      
      if (!mounted) return;
      setState(() {
        _posts
          ..clear()
          ..addAll(posts);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al cargar publicaciones')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _FeedTab(loading: _loading, posts: _posts, onRefresh: _loadPosts),
      const _PlaceholderTab(icon: Icons.search_rounded, title: 'Buscar'),
      const _PlaceholderTab(icon: Icons.add_rounded, title: 'Publicar'),
      const _PlaceholderTab(
        icon: Icons.location_on_rounded,
        title: 'Ubicaciones',
        message: 'Estamos trabajando en el mapa de restaurantes.',
      ),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: pages[_tab],
      bottomNavigationBar: CurvedNavigationBar(
        key: _navKey,
        index: _tab,
        height: 60,
        backgroundColor: Colors.transparent,
        color: Colors.white,
        buttonBackgroundColor: AppColors.primary,
        animationDuration: const Duration(milliseconds: 300),
        items: [
          Icon(Icons.home_rounded,
              color: _tab == 0 ? Colors.white : AppColors.primary),
          Icon(Icons.search_rounded,
              color: _tab == 1 ? Colors.white : AppColors.primary),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                if (_tab != 2)
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
          Icon(Icons.location_on_rounded,
              color: _tab == 3 ? Colors.white : AppColors.primary),
          Icon(Icons.person_rounded,
              color: _tab == 4 ? Colors.white : AppColors.primary),
        ],
        onTap: (i) async {
          if (i == 2) {
            final previousTab = _tab;
            setState(() => _tab = 2);

            final refresh = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreatePostScreen()),
            );

            if (!mounted) return;
            setState(() => _tab = previousTab);
            _navKey.currentState?.setPage(previousTab);

            if (refresh == true) {
              _loadPosts();
            }
          } else {
            setState(() => _tab = i);
          }
        },
      ),
    );
  }
}

class _FeedTab extends StatelessWidget {
  final bool loading;
  final List<PostModel> posts;
  final Future<void> Function() onRefresh;

  const _FeedTab({
    required this.loading,
    required this.posts,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.restaurant_menu_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 10),
                Text('SavorSync', style: AppTextStyles.headline),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: () {
                    // TODO: Implementar filtros
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_none_rounded),
                  onPressed: () {
                    // TODO: Implementar alertas
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: onRefresh,
              child: loading
                  ? ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: 3,
                      itemBuilder: (_, __) => const _SkeletonPost(),
                    )
                  : posts.isEmpty
                      ? _EmptyFeed(onRefresh: onRefresh)
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: posts.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                          itemBuilder: (_, i) => PostCard(
                    post: posts[i],
                    onDeleted: onRefresh,
                  )
                      .animate(delay: Duration(milliseconds: 80 * i))
                      .fadeIn(duration: 250.ms)
                      .slideY(begin: 0.15, curve: Curves.easeOutCubic),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _EmptyFeed({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.restaurant_rounded,
                    size: 48, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              Text('¡Bienvenido a SavorSync!', style: AppTextStyles.headline),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Aún no hay publicaciones en tu feed. ¡Sé el primero en compartir tu experiencia culinaria!',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subtle,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  final refresh = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreatePostScreen()),
                  );
                  if (refresh == true) onRefresh();
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Crear mi primera reseña'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SkeletonPost extends StatelessWidget {
  const _SkeletonPost();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Shimmer.fromColors(
        baseColor: const Color(0xFFEEEEEE),
        highlightColor: const Color(0xFFF8F8F8),
        child: Container(
          height: 360,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _PlaceholderTab({
    required this.icon,
    required this.title,
    this.message = 'Próximamente',
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(title, style: AppTextStyles.headline),
            const SizedBox(height: 6),
            Text(message, style: AppTextStyles.subtle),
          ],
        ),
      ),
    );
  }
}

