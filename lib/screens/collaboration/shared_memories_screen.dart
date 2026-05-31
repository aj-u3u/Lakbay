import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
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

  Future<void> _showAddMemorySheet(BuildContext context, Trip activeTrip) async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    final result = await _showAddPhotoDialog(file, activeTrip.destinationName);
    if (result == null) return;

    final caption = result['caption'] ?? '';
    final location = result['location'] ?? '';

    final newMemory = {
      'id': 'mem-${DateTime.now().millisecondsSinceEpoch}',
      'user': 'Arjane',
      'avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&q=80',
      'time': 'Just now',
      'caption': caption,
      'image': file.path,
      'likes': '0',
      'comments': '0',
      'location': location.isNotEmpty ? location : activeTrip.destinationName.split(',').first,
    };

    final updatedMemories = List<Map<String, dynamic>>.from(activeTrip.memories);
    updatedMemories.insert(0, newMemory);

    final updatedTrip = activeTrip.copyWith(memories: updatedMemories);
    Provider.of<TripProvider>(context, listen: false).updateTrip(updatedTrip);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Memory uploaded successfully! 🌅📸'), backgroundColor: AppTheme.secondaryGreen),
    );
  }

  Future<Map<String, String>?> _showAddPhotoDialog(File imageFile, String defaultLocation) async {
    final captionCtrl = TextEditingController();
    final locationCtrl = TextEditingController(text: defaultLocation.split(',').first);

    return showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardColorDark : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(AppConstants.spaceL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppConstants.spaceL),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Add Photo Memory',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppConstants.spaceM),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppConstants.radiusM),
                  child: Image.file(
                    imageFile,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: AppConstants.spaceM),
                TextField(
                  controller: captionCtrl,
                  decoration: InputDecoration(
                    labelText: 'Caption (optional)',
                    prefixIcon: const Icon(Icons.edit_note_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusM),
                    ),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: AppConstants.spaceS),
                TextField(
                  controller: locationCtrl,
                  decoration: InputDecoration(
                    labelText: 'Location Tag (optional)',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusM),
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.spaceL),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppConstants.radiusM),
                          ),
                        ),
                        child: Text('Cancel', style: GoogleFonts.outfit()),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spaceM),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, {
                          'caption': captionCtrl.text.trim(),
                          'location': locationCtrl.text.trim(),
                        }),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppConstants.radiusM),
                          ),
                        ),
                        child: Text(
                          'Upload',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
                        child: !post['image']!.startsWith('http')
                            ? Image.file(
                                File(post['image']!),
                                width: double.infinity,
                                height: 220,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  height: 220,
                                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                ),
                              )
                            : Image.network(
                                post['image']!,
                                width: double.infinity,
                                height: 220,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  height: 220,
                                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                ),
                              ),
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
