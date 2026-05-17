import 'package:flutter/material.dart';

class CommentsPlaceholderPanel extends StatelessWidget {
  const CommentsPlaceholderPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.comment_outlined, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text('Comments coming soon', style: TextStyle(color: Colors.grey)),
          SizedBox(height: 8),
          Text(
            'In-app comments will appear here',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
