import 'package:cached_network_image/cached_network_image.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../core/services/api_service.dart';
import '../../models/post_model.dart';
import '../posts/create_post_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
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
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: pages[_tab],
      bottomNavigationBar: CurvedNavigationBar(
        index: _tab,
        height: 60,
        backgroundColor: Colors.transparent,
        color: Colors.white,
        buttonBackgroundColor: AppColors.primary,
        animationDuration: const Duration(milliseconds: 300),
        items: const [
          Icon(Icons.home_rounded, color: AppColors.primary),
          Icon(Icons.search_rounded, color: AppColors.primary),
          Icon(Icons.add_rounded, color: Colors.white, size: 28),
          Icon(Icons.person_rounded, color: AppColors.primary),
        ],
        onTap: (i) async {
          if (i == 2) {
            final refresh = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreatePostScreen()),
            );
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
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_none_rounded),
                  onPressed: () {},
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
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: posts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (_, i) => _PostCard(post: posts[i])
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

class _PostCard extends StatefulWidget {
  final PostModel post;
  const _PostCard({required this.post});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  late PostModel _post = widget.post;
  bool _expanded = false;
  bool _likeBurst = false;

  void _toggleLike() {
    setState(() {
      _post = _post.copyWith(
        likedByMe: !_post.likedByMe,
        likesCount: _post.likedByMe ? _post.likesCount - 1 : _post.likesCount + 1,
      );
      if (_post.likedByMe) _likeBurst = true;
    });
    if (_likeBurst) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _likeBurst = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(14, 10, 8, 0),
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.background,
              backgroundImage: _post.userAvatarUrl != null
                  ? CachedNetworkImageProvider(_post.userAvatarUrl!)
                  : null,
              child: _post.userAvatarUrl == null
                  ? Text(
                      _post.username.isNotEmpty
                          ? _post.username[0].toUpperCase()
                          : '?',
                      style: AppTextStyles.title.copyWith(color: AppColors.primary),
                    )
                  : null,
            ),
            title: Text(_post.fullName, style: AppTextStyles.username),
            subtitle: Text('@${_post.username}', style: AppTextStyles.caption),
            trailing: IconButton(
              icon: const Icon(Icons.more_horiz_rounded),
              onPressed: () {},
            ),
          ),
          GestureDetector(
            onDoubleTap: _toggleLike,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  child: SizedBox(
                    width: double.infinity,
                    height: 250,
                    child: CachedNetworkImage(
                      imageUrl: _post.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Shimmer.fromColors(
                        baseColor: const Color(0xFFEEEEEE),
                        highlightColor: const Color(0xFFF8F8F8),
                        child: Container(color: Colors.white),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.background,
                        child: const Icon(Icons.broken_image_outlined,
                            color: AppColors.textSecondary, size: 32),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.35),
                          ],
                          stops: const [0.6, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _post.restaurantName,
                          style: AppTextStyles.title.copyWith(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      RatingBarIndicator(
                        rating: _post.rating,
                        itemCount: 5,
                        itemSize: 14,
                        unratedColor: Colors.white24,
                        itemBuilder: (_, __) =>
                            const Icon(Icons.star_rounded, color: AppColors.accent),
                      ),
                    ],
                  ),
                ),
                if (_likeBurst)
                  Icon(
                    Icons.favorite_rounded,
                    color: AppColors.primary.withValues(alpha: 0.9),
                    size: 110,
                  )
                      .animate()
                      .scale(
                        begin: const Offset(0.4, 0.4),
                        end: const Offset(1.2, 1.2),
                        duration: 350.ms,
                        curve: Curves.easeOutBack,
                      )
                      .then()
                      .fadeOut(duration: 250.ms),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _IconAction(
                      icon: _post.likedByMe
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: _post.likedByMe ? AppColors.primary : AppColors.secondary,
                      onTap: _toggleLike,
                    ),
                    const SizedBox(width: 6),
                    Text('${_post.likesCount}', style: AppTextStyles.caption),
                    const SizedBox(width: 16),
                    _IconAction(
                      icon: Icons.mode_comment_outlined,
                      onTap: () {},
                    ),
                    const SizedBox(width: 6),
                    Text('${_post.commentsCount}', style: AppTextStyles.caption),
                    const Spacer(),
                    _IconAction(
                      icon: _post.savedByMe
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      color: _post.savedByMe ? AppColors.accent : AppColors.secondary,
                      onTap: () {
                        setState(() => _post = _post.copyWith(savedByMe: !_post.savedByMe));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.topLeft,
                  child: Text(
                    _post.content,
                    maxLines: _expanded ? null : 3,
                    overflow: _expanded ? null : TextOverflow.ellipsis,
                    style: AppTextStyles.body,
                  ),
                ),
                if (_post.content.length > 100)
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _expanded ? 'ver menos' : 'ver más',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconAction extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IconAction({
    required this.icon,
    required this.onTap,
    this.color = AppColors.secondary,
  });

  @override
  State<_IconAction> createState() => _IconActionState();
}

class _IconActionState extends State<_IconAction> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.85),
      onTapCancel: () => setState(() => _scale = 1),
      onTapUp: (_) {
        setState(() => _scale = 1);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        child: Icon(widget.icon, color: widget.color, size: 24),
      ),
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
  const _PlaceholderTab({required this.icon, required this.title});

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
            Text('Próximamente', style: AppTextStyles.subtle),
          ],
        ),
      ),
    );
  }
}

