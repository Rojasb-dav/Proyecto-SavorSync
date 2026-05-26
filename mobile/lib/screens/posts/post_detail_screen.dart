import 'package:flutter/material.dart';
import '../../models/post_model.dart';
import '../../widgets/post_card.dart';

class PostDetailScreen extends StatelessWidget {
  final PostModel post;
  const PostDetailScreen({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Publicación'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: PostCard(
            post: post,
            onDeleted: () => Navigator.pop(context, true),
          ),
        ),
      ),
    );
  }
}
