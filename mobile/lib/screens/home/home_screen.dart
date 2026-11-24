import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../core/services/api_service.dart';
import '../../core/services/notification_service.dart';
import '../../models/notification_model.dart';
import '../../models/post_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/post_card.dart';
import '../map/restaurant_map_screen.dart';
import '../notifications/notification_center_screen.dart';
import '../posts/create_post_screen.dart';
import '../profile/profile_screen.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';

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
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _loading = true);
    try {
      final posts = await _apiService.getPosts();
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
        SnackBar(content: Text('Error al cargar publicaciones: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _FeedTab(loading: _loading, posts: _posts, onRefresh: _loadPosts),
      const SearchScreen(),
      const _PlaceholderTab(icon: Icons.add_rounded, title: 'Publicar'),
      const RestaurantMapScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.05, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_tab),
          child: pages[_tab],
        ),
      ),
      bottomNavigationBar: CurvedNavigationBar(
        key: _navKey,
        index: _tab,
        height: 60,
        backgroundColor: Colors.transparent,
        color: Theme.of(context).cardColor,
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
                const _NotificationBell(),
                IconButton(
                  icon: const Icon(Icons.settings_outlined, size: 24),
                  tooltip: 'Ajustes y Configuración',
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
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
                  ? const _FeedSkeleton()
                  : posts.isEmpty
                      ? const _EmptyFeedState()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: posts.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, i) {
                            return PostCard(
                              post: posts[i],
                              onDeleted: onRefresh,
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) {
      return IconButton(
        icon: const Icon(Icons.notifications_outlined),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationCenterScreen()));
        },
      );
    }

    return StreamBuilder<List<NotificationModel>>(
      stream: NotificationService.streamNotifications(user.id),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data?.where((n) => !n.read).length ?? 0;

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, size: 26),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationCenterScreen()));
              },
            ),
            if (unreadCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Shimmer.fromColors(
          baseColor: const Color(0xFFEEEEEE),
          highlightColor: const Color(0xFFF8F8F8),
          child: Container(
            height: 320,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyFeedState extends StatelessWidget {
  const _EmptyFeedState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            children: [
              const Icon(Icons.restaurant_rounded,
                  size: 64, color: AppColors.secondary),
              const SizedBox(height: 16),
              Text('Aún no hay publicaciones', style: AppTextStyles.headline),
              const SizedBox(height: 6),
              Text(
                '¡Sé el primero en compartir tu experiencia!',
                style: AppTextStyles.subtle,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String title;
  const _PlaceholderTab({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(title, style: AppTextStyles.headline),
          ],
        ),
      ),
    );
  }
}
