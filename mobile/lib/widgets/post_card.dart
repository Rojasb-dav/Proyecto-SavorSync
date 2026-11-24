import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../core/constants/colors.dart';
import '../core/constants/text_styles.dart';
import '../core/services/api_service.dart';
import '../models/post_model.dart';
import '../providers/auth_provider.dart';
import '../screens/profile/profile_screen.dart';
import 'comments_modal.dart';

class PostCard extends StatefulWidget {
  final PostModel post;
  final VoidCallback? onDeleted;
  const PostCard({super.key, required this.post, this.onDeleted});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late PostModel _post = widget.post;
  bool _expanded = false;
  bool _likeBurst = false;
  final ApiService _apiService = ApiService();

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _post = widget.post;
    }
  }

  Future<void> _toggleLike() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicia sesión para dar me gusta')),
      );
      return;
    }

    final newLiked = !_post.likedByMe;
    final newCount = newLiked ? _post.likesCount + 1 : _post.likesCount - 1;

    setState(() {
      _post = _post.copyWith(
        likedByMe: newLiked,
        likesCount: newCount < 0 ? 0 : newCount,
      );
      if (newLiked) _likeBurst = true;
    });

    if (_likeBurst) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _likeBurst = false);
      });
    }

    try {
      await _apiService.toggleLikePost(_post.id);
    } catch (e) {
      debugPrint('Error al guardar me gusta: $e');
    }
  }

  Future<void> _toggleSave() async {
    final newSaved = !_post.savedByMe;
    setState(() {
      _post = _post.copyWith(savedByMe: newSaved);
    });
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsModal(postId: _post.id),
    );
  }

  String _buildInstagramLikesText() {
    if (_post.likesCount == 0) return 'Sé el primero en dar me gusta';
    if (_post.likedByMe) {
      if (_post.likesCount == 1) return 'Les gusta a ti';
      return 'Les gusta a ti y a ${_post.likesCount - 1} personas más';
    } else {
      if (_post.likesCount == 1) return 'Le gusta a 1 persona';
      return 'Le gusta a ${_post.likesCount} personas';
    }
  }

  void _navigateToProfile() {
    if (_post.userId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(userId: _post.userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final isMe = auth.user?.id == _post.userId;
    final cleanUsername = _post.username.replaceAll('@', '');

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
            leading: GestureDetector(
              onTap: _navigateToProfile,
              child: CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.background,
                backgroundImage: _post.userAvatarUrl != null
                    ? CachedNetworkImageProvider(_post.userAvatarUrl!)
                    : null,
                child: _post.userAvatarUrl == null
                    ? Text(
                        cleanUsername.isNotEmpty
                            ? cleanUsername[0].toUpperCase()
                            : '?',
                        style: AppTextStyles.title.copyWith(color: AppColors.primary),
                      )
                    : null,
              ),
            ),
            title: GestureDetector(
              onTap: _navigateToProfile,
              child: Text(_post.fullName.isNotEmpty ? _post.fullName : cleanUsername, style: AppTextStyles.username),
            ),
            subtitle: GestureDetector(
              onTap: _navigateToProfile,
              child: Text('@$cleanUsername', style: AppTextStyles.caption),
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz_rounded),
              onSelected: (val) async {
                if (val == 'delete') {
                  try {
                    await _apiService.deletePost(_post.id);
                    widget.onDeleted?.call();
                  } catch (_) {}
                }
              },
              itemBuilder: (ctx) => [
                if (isMe)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Eliminar', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
              ],
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
                    const SizedBox(width: 14),
                    _IconAction(
                      icon: Icons.mode_comment_outlined,
                      onTap: _openComments,
                    ),
                    const SizedBox(width: 6),
                    Text('${_post.commentsCount}', style: AppTextStyles.caption),
                    const Spacer(),
                    _IconAction(
                      icon: _post.savedByMe
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      color: _post.savedByMe ? AppColors.accent : AppColors.secondary,
                      onTap: _toggleSave,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _buildInstagramLikesText(),
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
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
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, curve: Curves.easeOutCubic);
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
