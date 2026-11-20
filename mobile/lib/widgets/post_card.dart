import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../core/constants/colors.dart';
import '../core/constants/text_styles.dart';
import '../core/services/notification_service.dart';
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

  @override
  void initState() {
    super.initState();
    _checkLikeAndSaveStatus();
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _post = widget.post;
      _checkLikeAndSaveStatus();
    }
  }

  Future<void> _checkLikeAndSaveStatus() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    try {
      final likeDocFuture = FirebaseFirestore.instance
          .collection('posts')
          .doc(_post.id)
          .collection('likes')
          .doc(user.id)
          .get();

      final savedDocFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .collection('saved_posts')
          .doc(_post.id)
          .get();

      final results = await Future.wait([likeDocFuture, savedDocFuture]);
      final isLiked = results[0].exists;
      final isSaved = results[1].exists;

      if (mounted) {
        setState(() {
          _post = _post.copyWith(
            likedByMe: isLiked,
            savedByMe: isSaved,
          );
        });
      }
    } catch (_) {}
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
      final postRef = FirebaseFirestore.instance.collection('posts').doc(_post.id);
      final likeDoc = postRef.collection('likes').doc(user.id);

      if (newLiked) {
        await likeDoc.set({
          'userId': user.id,
          'username': user.username,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await postRef.update({'likesCount': FieldValue.increment(1)});

        // Notificación solo al autor original si no es el mismo usuario
        if (_post.userId.isNotEmpty && _post.userId != user.id) {
          final cleanUsername = user.username.replaceAll('@', '');
          NotificationService.sendNotification(
            targetUserId: _post.userId,
            title: '¡Nuevo Me Gusta! 💖',
            body: 'A @$cleanUsername le gustó tu reseña de ${_post.restaurantName}',
            type: 'like',
            targetId: _post.id,
          );
        }
      } else {
        await likeDoc.delete();
        await postRef.update({'likesCount': FieldValue.increment(-1)});
      }
    } catch (e) {
      debugPrint('Error al guardar me gusta: $e');
    }
  }

  Future<void> _toggleSave() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final newSaved = !_post.savedByMe;

    setState(() {
      _post = _post.copyWith(savedByMe: newSaved);
    });

    try {
      final savedDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .collection('saved_posts')
          .doc(_post.id);

      if (newSaved) {
        await savedDoc.set({
          'postId': _post.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await savedDoc.delete();
      }
    } catch (e) {
      debugPrint('Error al guardar publicación: $e');
    }
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsModal(postId: _post.id),
    );
  }

  void _showLikesListModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.favorite_rounded, color: AppColors.primary, size: 24),
                const SizedBox(width: 8),
                Text('Personas a las que les gusta (${_post.likesCount})', style: AppTextStyles.title),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const Divider(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .doc(_post.id)
                    .collection('likes')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(child: Text('Aún no hay me gusta'));
                  }

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final userId = docs[i].data()['userId'] as String? ?? docs[i].id;
                      return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                        builder: (context, uSnap) {
                          final uData = uSnap.data?.data() ?? {};
                          final uName = (uData['username'] as String? ?? 'foodie').replaceAll('@', '');
                          final fName = uData['fullName'] as String? ?? uName;
                          final avatar = uData['avatarUrl'] as String?;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                              child: avatar == null ? Text(uName.isNotEmpty ? uName[0].toUpperCase() : '?') : null,
                            ),
                            title: Text(fName, style: AppTextStyles.title.copyWith(fontSize: 14)),
                            subtitle: Text('@$uName', style: AppTextStyles.caption),
                            onTap: () {
                              Navigator.pop(ctx);
                              Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)));
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
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

  Future<void> _showReportDialog() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicia sesión para enviar un reporte')),
      );
      return;
    }

    String selectedReason = 'Spam o información engañosa';
    final reasons = [
      'Spam o información engañosa',
      'Lenguaje ofensivo o inapropiado',
      'Fotografía falsa o inadecuada',
      'Infracción de normas comunitarias',
    ];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Reportar Publicación'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Selecciona el motivo de tu reporte:'),
              const SizedBox(height: 12),
              ...reasons.map((r) => RadioListTile<String>(
                    title: Text(r, style: const TextStyle(fontSize: 13)),
                    value: r,
                    groupValue: selectedReason,
                    onChanged: (v) => setDlgState(() => selectedReason = v!),
                  )),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enviar Reporte', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('reports').add({
          'postId': _post.id,
          'postContent': _post.content,
          'postImageUrl': _post.imageUrl,
          'restaurantName': _post.restaurantName,
          'reporterId': user.id,
          'reason': selectedReason,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reporte enviado a los moderadores. ¡Gracias por cuidar la comunidad!'), backgroundColor: Colors.green),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar reporte: $e')),
        );
      }
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
              child: Text(_post.fullName, style: AppTextStyles.username),
            ),
            subtitle: GestureDetector(
              onTap: _navigateToProfile,
              child: Text('@$cleanUsername', style: AppTextStyles.caption),
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz_rounded),
              onSelected: (val) async {
                if (val == 'delete') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Eliminar publicación'),
                      content: const Text('¿Estás seguro de que quieres eliminar esta reseña?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    try {
                      await FirebaseFirestore.instance.collection('posts').doc(_post.id).delete();
                      widget.onDeleted?.call();
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Error al eliminar')),
                      );
                    }
                  }
                } else if (val == 'report') {
                  _showReportDialog();
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
                if (!isMe)
                  const PopupMenuItem(
                    value: 'report',
                    child: Row(
                      children: [
                        Icon(Icons.flag_outlined, color: AppColors.error, size: 20),
                        SizedBox(width: 8),
                        Text('Reportar reseña'),
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
                GestureDetector(
                  onTap: _showLikesListModal,
                  child: Text(
                    _buildInstagramLikesText(),
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
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
