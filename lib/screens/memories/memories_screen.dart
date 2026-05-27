import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/shared/section_header.dart';

class MemoriesScreen extends StatelessWidget {
  const MemoriesScreen({Key? key}) : super(key: key);

  static final List<Map<String, String>> _memories = [
    {
      'title': 'Golden Hour at Eden Nature Park',
      'location': 'Toril, Davao City',
      'date': 'March 14, 2026',
      'image': 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=600&q=80',
      'note': 'The sunset from the mountain viewpoint was absolutely breathtaking. Pine forests everywhere!',
    },
    {
      'title': 'Pearl Farm Overwater Villa',
      'location': 'Samal Island, Davao del Norte',
      'date': 'February 8, 2026',
      'image': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=600&q=80',
      'note': 'Waking up to the sound of waves under our stilt bungalow — pure paradise.',
    },
    {
      'title': 'Skimboarding at Dahican',
      'location': 'Mati, Davao Oriental',
      'date': 'January 20, 2026',
      'image': 'https://images.unsplash.com/photo-1506929562872-bb421503ef21?w=600&q=80',
      'note': 'Tried skimboarding for the first time! Fell a dozen times but loved every second.',
    },
    {
      'title': 'Night Market Feast',
      'location': 'Roxas Ave, Davao City',
      'date': 'December 31, 2025',
      'image': 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=600&q=80',
      'note': 'Ended the year with durian ice cream and grilled tuna. Davao at midnight is electric!',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Memories', style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold, fontSize: 24, color: AppTheme.primaryBlue)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_rounded, color: AppTheme.secondaryGreen, size: 26),
            onPressed: () {},
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Stats banner
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spaceM),
              child: Container(
                padding: const EdgeInsets.all(AppConstants.spaceL),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryBlue, Color(0xFF104B50)],
                  ),
                  borderRadius: BorderRadius.circular(AppConstants.radiusXL),
                  boxShadow: AppConstants.premiumShadow,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statItem('28', 'Memories'),
                    Container(width: 1, height: 36, color: Colors.white24),
                    _statItem('12', 'Trips'),
                    Container(width: 1, height: 36, color: Colors.white24),
                    _statItem('5', 'Provinces'),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: SectionHeader(title: 'Travel Journal', onActionPressed: () {}),
          ),

          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _MemoryCard(memory: _memories[i]),
              childCount: _memories.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppConstants.spaceXL)),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(
          color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}

class _MemoryCard extends StatelessWidget {
  final Map<String, String> memory;
  const _MemoryCard({required this.memory});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppConstants.spaceM, 0, AppConstants.spaceM, AppConstants.spaceM),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusXL),
        boxShadow: AppConstants.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: Image.network(memory['image']!, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: AppTheme.primaryBlue.withOpacity(0.15))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppConstants.spaceM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(memory['title']!, style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryBlue)),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.location_on_rounded, size: 13, color: AppTheme.textSecondaryLight),
                  const SizedBox(width: 3),
                  Text(memory['location']!, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryLight)),
                  const Spacer(),
                  const Icon(Icons.calendar_today_rounded, size: 12, color: AppTheme.textSecondaryLight),
                  const SizedBox(width: 3),
                  Text(memory['date']!, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryLight)),
                ]),
                const SizedBox(height: AppConstants.spaceM),
                Container(
                  padding: const EdgeInsets.all(AppConstants.spaceM),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(AppConstants.radiusM),
                    border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.08)),
                  ),
                  child: Text(
                    '"${memory['note']!}"',
                    style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondaryLight,
                      fontStyle: FontStyle.italic, height: 1.5),
                  ),
                ),
                const SizedBox(height: AppConstants.spaceM),
                Row(
                  children: [
                    Icon(Icons.favorite_rounded, color: Colors.red.shade300, size: 18),
                    const SizedBox(width: 4),
                    const Text('24', style: TextStyle(color: AppTheme.textSecondaryLight, fontSize: 12)),
                    const Spacer(),
                    const Icon(Icons.share_rounded, color: AppTheme.textSecondaryLight, size: 18),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
