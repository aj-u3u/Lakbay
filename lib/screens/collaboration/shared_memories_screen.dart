import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../models/trip.dart';
import '../../providers/trip_provider.dart';

class SharedMemoriesScreen extends StatefulWidget {
  final Trip? trip;
  const SharedMemoriesScreen({super.key, this.trip});

  @override
  State<SharedMemoriesScreen> createState() => _SharedMemoriesScreenState();
}

class _SharedMemoriesScreenState extends State<SharedMemoriesScreen> {
  // Random pool of beautiful travel stock photos in Davao Region
  final List<String> _stockImages = [
    'https://images.unsplash.com/photo-1506929562872-bb421503ef21?w=800&q=80',
    'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&q=80',
    'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=800&q=80',
    'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=800&q=80',
    'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800&q=80',
    'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=800&q=80',
  ];

  Trip _getTrip(BuildContext context) {
    if (widget.trip != null) {
      final trips = context.watch<TripProvider>().userTrips;
      return trips.firstWhere((t) => t.id == widget.trip!.id, orElse: () => widget.trip!);
    }
    final trips = context.watch<TripProvider>().userTrips;
    return trips.isNotEmpty ? trips.first : Trip.mockTrips[0];
  }

  void _showAddMemorySheet(BuildContext context, Trip activeTrip) {
    final captionController = TextEditingController();
    final locationController = TextEditingController(text: activeTrip.destinationName.split(',').first);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                left: 24, right: 24, top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 50, height: 5,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Upload Travel Memory',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryBlue),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: captionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Caption',
                      hintText: 'Share details of this amazing moment...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(
                      labelText: 'Location Tag',
                      hintText: 'e.g. Pearl Farm Beach Resort',
                      prefixIcon: Icon(Icons.pin_drop_rounded, color: Colors.redAccent),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Save Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      if (captionController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a caption.'), backgroundColor: Colors.red),
                        );
                        return;
                      }

                      // Pick a randomized stock image
                      final randomImage = _stockImages[
                        (captionController.text.length + locationController.text.length) % _stockImages.length
                      ];

                      final newMemory = {
                        'id': 'mem-${DateTime.now().millisecondsSinceEpoch}',
                        'user': 'Arjane',
                        'avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&q=80',
                        'time': 'Just now',
                        'caption': captionController.text.trim(),
                        'image': randomImage,
                        'likes': '0',
                        'comments': '0',
                        'location': locationController.text.trim(),
                      };

                      final updatedMemories = List<Map<String, dynamic>>.from(activeTrip.memories);
                      updatedMemories.insert(0, newMemory);

                      final updatedTrip = activeTrip.copyWith(memories: updatedMemories);
                      Provider.of<TripProvider>(context, listen: false).updateTrip(updatedTrip);

                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Memory uploaded successfully! 🌅📸'), backgroundColor: AppTheme.secondaryGreen),
                      );
                    },
                    icon: const Icon(Icons.add_photo_alternate_rounded),
                    label: Text('Upload Memory', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteMemory(BuildContext context, Trip activeTrip, int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Memory?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.red)),
        content: const Text('Are you sure you want to remove this photo from your travel memories?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              final updatedMemories = List<Map<String, dynamic>>.from(activeTrip.memories);
              updatedMemories.removeAt(index);

              final updatedTrip = activeTrip.copyWith(memories: updatedMemories);
              Provider.of<TripProvider>(context, listen: false).updateTrip(updatedTrip);

              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Memory deleted.'), backgroundColor: AppTheme.secondaryGreen),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTrip = _getTrip(context);
    final memoriesList = activeTrip.memories;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          activeTrip.isGroup ? 'Group Memories' : 'Personal Memories',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_rounded, color: AppTheme.secondaryGreen, size: 28),
            onPressed: () => _showAddMemorySheet(context, activeTrip),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: memoriesList.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(color: AppTheme.accentTeal.withValues(alpha: 0.05), shape: BoxShape.circle),
                    child: const Icon(Icons.add_a_photo_rounded, color: AppTheme.accentTeal, size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text('No memories captured yet.', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryBlue)),
                  const SizedBox(height: 6),
                  const Text('Capture and upload your first photo of the trip!', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryLight)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppConstants.spaceM),
              itemCount: memoriesList.length,
              itemBuilder: (_, i) {
                final post = memoriesList[i];
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
                                errorBuilder: (_, _, _) => Container(
                                  width: 40, height: 40,
                                  color: AppTheme.secondaryGreen.withValues(alpha: 0.2),
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
                            if (post['location'] != null && post['location'].toString().isNotEmpty) ...[
                              const Icon(Icons.pin_drop_rounded, size: 14, color: Colors.redAccent),
                              const SizedBox(width: 3),
                              Text(post['location'], style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryLight)),
                              const SizedBox(width: 8),
                            ],
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                              onPressed: () => _confirmDeleteMemory(context, activeTrip, i),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                      // Post image
                      ClipRRect(
                        borderRadius: BorderRadius.zero,
                        child: Image.network(post['image']!, width: double.infinity, height: 220, fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            height: 220,
                            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
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
                                _actionButton(Icons.favorite_border_rounded, post['likes'] ?? '0', Colors.red),
                                const SizedBox(width: AppConstants.spaceL),
                                _actionButton(Icons.chat_bubble_outline_rounded, post['comments'] ?? '0', AppTheme.primaryBlue),
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
