import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';

class SharedMemoriesScreen extends StatelessWidget {
  const SharedMemoriesScreen({Key? key}) : super(key: key);

  static const _posts = [
    {
      'user': 'Arjane', 'avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&q=80',
      'time': '2 hours ago',
      'caption': 'Pearl Farm morning vibes 🌊✨ The stilt bungalows are absolutely dreamy!',
      'image': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&q=80',
      'likes': '18', 'comments': '4',
    },
    {
      'user': 'Bea', 'avatar': 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=100&q=80',
      'time': '5 hours ago',
      'caption': 'Hagimit Falls was COLD and refreshing! The tiered pools were a surprise.',
      'image': 'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=800&q=80',
      'likes': '24', 'comments': '7',
    },
    {
      'user': 'Carlo', 'avatar': 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=100&q=80',
      'time': 'Yesterday',
      'caption': 'Spotted a million bats flying out at sunset from Monfort Sanctuary! 🦇',
      'image': 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=800&q=80',
      'likes': '31', 'comments': '9',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Shared Memories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_rounded, color: AppTheme.secondaryGreen),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(AppConstants.spaceM),
        itemCount: _posts.length,
        itemBuilder: (_, i) {
          final post = _posts[i];
          return Container(
            margin: const EdgeInsets.only(bottom: AppConstants.spaceM),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppConstants.radiusXL),
              boxShadow: AppConstants.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User header
                Padding(
                  padding: const EdgeInsets.all(AppConstants.spaceM),
                  child: Row(
                    children: [
                      ClipOval(
                        child: Image.network(post['avatar']!, width: 40, height: 40, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 40, height: 40,
                            color: AppTheme.secondaryGreen.withOpacity(0.2),
                            child: const Icon(Icons.person, color: AppTheme.primaryBlue, size: 20),
                          )),
                      ),
                      const SizedBox(width: AppConstants.spaceM),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(post['user']!, style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryBlue)),
                          Text(post['time']!, style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondaryLight)),
                        ],
                      ),
                      const Spacer(),
                      const Icon(Icons.more_horiz_rounded, color: AppTheme.textSecondaryLight),
                    ],
                  ),
                ),
                // Post image
                ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: Image.network(post['image']!, width: double.infinity, height: 220, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 220,
                      color: AppTheme.primaryBlue.withOpacity(0.1),
                    )),
                ),
                // Caption and actions
                Padding(
                  padding: const EdgeInsets.all(AppConstants.spaceM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post['caption']!, style: const TextStyle(
                        fontSize: 13, color: AppTheme.textSecondaryLight, height: 1.5)),
                      const SizedBox(height: AppConstants.spaceM),
                      Row(
                        children: [
                          _actionButton(Icons.favorite_border_rounded, post['likes']!, Colors.red),
                          const SizedBox(width: AppConstants.spaceL),
                          _actionButton(Icons.chat_bubble_outline_rounded, post['comments']!, AppTheme.primaryBlue),
                          const Spacer(),
                          const Icon(Icons.share_outlined, size: 20, color: AppTheme.textSecondaryLight),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _actionButton(IconData icon, String count, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 4),
        Text(count, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
