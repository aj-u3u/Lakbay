import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../models/trip.dart';
import '../../providers/trip_provider.dart';
import '../../widgets/shared/empty_state.dart';

// Represents a memory returned by the trip memories API.
class _MemoryItem {
  final Map<String, dynamic> networkMemory;
  final String caption;
  final String location;

  _MemoryItem.fromNetwork(this.networkMemory)
    : caption = networkMemory['caption'] as String? ?? '',
      location = networkMemory['location'] as String? ?? '';

  String get uploader => networkMemory['user'] as String? ?? 'You';
  String get time => networkMemory['time'] as String? ?? 'Just now';
}

class OpenedAlbumScreen extends StatefulWidget {
  final Trip trip;

  const OpenedAlbumScreen({super.key, required this.trip});

  @override
  State<OpenedAlbumScreen> createState() => _OpenedAlbumScreenState();
}

class _OpenedAlbumScreenState extends State<OpenedAlbumScreen> {
  final ImagePicker _picker = ImagePicker();
  late List<_MemoryItem> _items;
  bool _isUploading = false;
  bool _isRefreshing = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    // Seed from the trip's existing network memories
    _items = widget.trip.memories
        .map((m) => _MemoryItem.fromNetwork(m))
        .toList();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshMemories());
  }

  Future<void> _refreshMemories() async {
    if (!mounted) return;
    if (!_isRefreshing) setState(() => _isRefreshing = true);
    final provider = context.read<TripProvider>();
    if (!provider.isPersistedTrip(widget.trip)) {
      setState(() => _isRefreshing = false);
      return;
    }
    final loaded = await provider.refreshTripMemories(widget.trip);
    if (!mounted) return;
    final trip = provider.userTrips.firstWhere(
      (candidate) => candidate.id == widget.trip.id,
      orElse: () => widget.trip,
    );
    setState(() {
      if (loaded) {
        _items = trip.memories.map(_MemoryItem.fromNetwork).toList();
      }
      _loadFailed = !loaded;
      _isRefreshing = false;
    });
  }

  // ── Gallery picker ────────────────────────────────────────────────────────
  Future<void> _pickFromGallery() async {
    if (_isUploading || _isRefreshing) return;
    final tripProvider = context.read<TripProvider>();
    if (!tripProvider.isPersistedTrip(widget.trip)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save this trip before adding memories.')),
      );
      return;
    }

    try {
      final picked = await _picker.pickMultiImage(imageQuality: 85);
      if (picked.isEmpty || !mounted) return;
      setState(() => _isUploading = true);

      var savedCount = 0;
      String? failure;
      for (final xFile in picked) {
        if (!mounted) break;
        final result = await _showAddMemoryDialog(File(xFile.path));
        if (result == null || !mounted) continue;

        final currentTrip = tripProvider.userTrips.firstWhere(
          (candidate) => candidate.id == widget.trip.id,
          orElse: () => widget.trip,
        );
        final saved = await tripProvider.addMemoryToTrip(
          currentTrip,
          filePath: xFile.path,
          caption: result['caption'] ?? '',
          location: (result['location'] ?? '').isNotEmpty
              ? result['location']!
              : currentTrip.destinationName.split(',').first,
        );
        if (!mounted) break;
        if (!saved) {
          failure = tripProvider.errorMessage ?? 'Failed to save memory.';
          break;
        }
        savedCount++;
        final updatedTrip = tripProvider.userTrips.firstWhere(
          (candidate) => candidate.id == widget.trip.id,
          orElse: () => widget.trip,
        );
        setState(() {
          _items = updatedTrip.memories.map(_MemoryItem.fromNetwork).toList();
        });
      }

      if (!mounted || (savedCount == 0 && failure == null)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failure == null
                ? '$savedCount photo${savedCount == 1 ? '' : 's'} saved to album.'
                : '$savedCount saved. $failure',
          ),
          backgroundColor: failure == null
              ? AppTheme.secondaryGreen
              : Colors.redAccent,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not add photos. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<Map<String, String>?> _showAddMemoryDialog(File imageFile) async {
    final captionCtrl = TextEditingController();
    final locationCtrl = TextEditingController();

    return showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardColorDark : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.all(AppConstants.spaceL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
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
                  'Add to Album',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppConstants.spaceM),
                // Thumbnail preview
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
                // Caption field
                TextField(
                  controller: captionCtrl,
                  maxLength: 500,
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
                // Location field
                TextField(
                  controller: locationCtrl,
                  maxLength: 255,
                  decoration: InputDecoration(
                    labelText: 'Location (optional)',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusM),
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.spaceL),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusM,
                            ),
                          ),
                        ),
                        child: Text('Skip', style: GoogleFonts.outfit()),
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
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusM,
                            ),
                          ),
                        ),
                        child: Text(
                          'Add to Album',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                          ),
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

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.trip.destinationName.split(',')[0],
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        actions: [
          // Quick-add button in AppBar too
          IconButton(
            onPressed: _isUploading || _isRefreshing ? null : _pickFromGallery,
            icon: const Icon(Icons.add_photo_alternate_rounded),
            tooltip: 'Add from Gallery',
          ),
        ],
      ),
      body: _isRefreshing && _items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? Center(
              child: EmptyState(
                icon: Icons.photo_album_rounded,
                iconColor: AppTheme.secondaryGreen,
                title: _loadFailed
                    ? 'Could not load this album.'
                    : 'Your travel album is empty.',
                subtitle: _loadFailed
                    ? 'Check your connection and try again.'
                    : 'Tap the + button to add photos from your gallery.',
                ctaLabel: _loadFailed ? 'Retry' : null,
                onCta: _loadFailed ? _refreshMemories : null,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.spaceM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildScrapbookHeader(context, isDark),
                  const SizedBox(height: AppConstants.spaceL),

                  if (widget.trip.isGroup &&
                      widget.trip.members.isNotEmpty) ...[
                    _buildGroupMembersRow(context, isDark),
                    const SizedBox(height: AppConstants.spaceL),
                  ],

                  _buildPolaroidGrid(_items),
                  const SizedBox(height: AppConstants.spaceXXL),
                ],
              ),
            ),
      // FAB to add from gallery
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUploading || _isRefreshing ? null : _pickFromGallery,
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        icon: _isUploading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.add_photo_alternate_rounded),
        label: Text(
          _isUploading ? 'Saving...' : 'Add Photo',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ── Sub-widgets ───────────────────────────────────────────────────────────
  Widget _buildScrapbookHeader(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spaceL),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardColorDark : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusXL),
        boxShadow: AppConstants.premiumShadow,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: widget.trip.isGroup
                      ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                      : AppTheme.secondaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppConstants.radiusS),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.trip.isGroup
                          ? Icons.people_rounded
                          : Icons.person_rounded,
                      size: 14,
                      color: widget.trip.isGroup
                          ? AppTheme.primaryBlue
                          : AppTheme.secondaryGreen,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.trip.isGroup ? 'Group Album' : 'Solo Album',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: widget.trip.isGroup
                            ? AppTheme.primaryBlue
                            : AppTheme.secondaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Completed',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppTheme.textSecondaryDark
                      : AppTheme.textSecondaryLight,
                ),
              ),
              const Spacer(),
              // Photo count chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppConstants.radiusS),
                ),
                child: Text(
                  '${_items.length} photo${_items.length == 1 ? '' : 's'}',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.trip.title,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: AppTheme.primaryBlue,
              ),
              const SizedBox(width: 6),
              Text(
                widget.trip.dateRange,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: isDark
                      ? AppTheme.textSecondaryDark
                      : AppTheme.textSecondaryLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGroupMembersRow(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Travel Buddies',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondaryLight,
            ),
          ),
        ),
        SizedBox(
          height: 64,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: widget.trip.members.length,
            itemBuilder: (context, idx) {
              final member = widget.trip.members[idx];
              final name = member['name'] ?? '';
              final role = member['role'] ?? 'Member';
              final avatar = member['avatar'] ?? '';
              final isOrg = role == 'Organizer';

              return Container(
                margin: const EdgeInsets.only(right: AppConstants.spaceM),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardColorDark : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.04),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.primaryBlue.withValues(
                        alpha: 0.15,
                      ),
                      backgroundImage: avatar.isNotEmpty
                          ? NetworkImage(avatar)
                          : null,
                      child: avatar.isEmpty
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'T',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlue,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          role,
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            color: isOrg
                                ? AppTheme.secondaryGreen
                                : (isDark
                                      ? AppTheme.textSecondaryDark
                                      : AppTheme.textSecondaryLight),
                            fontWeight: isOrg
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPolaroidGrid(List<_MemoryItem> items) {
    final leftItems = <_MemoryItem>[];
    final rightItems = <_MemoryItem>[];

    for (int i = 0; i < items.length; i++) {
      if (i % 2 == 0) {
        leftItems.add(items[i]);
      } else {
        rightItems.add(items[i]);
      }
    }

    final rotations = [-0.04, 0.03, -0.02, 0.04, -0.03];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: List.generate(leftItems.length, (idx) {
              final originalIndex = idx * 2;
              final double angle = rotations[originalIndex % rotations.length];
              return _buildPolaroidCard(leftItems[idx], angle);
            }),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: List.generate(rightItems.length, (idx) {
              final originalIndex = idx * 2 + 1;
              final double angle = rotations[originalIndex % rotations.length];
              return Padding(
                padding: const EdgeInsets.only(top: 24),
                child: _buildPolaroidCard(rightItems[idx], angle),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildPolaroidCard(_MemoryItem item, double angle) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Polaroid Image Slot
            AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                color: Colors.grey.shade100,
                child: () {
                  final imgUrl = item.networkMemory['image'] as String? ?? '';
                  if (imgUrl.isEmpty) {
                    return Container(color: Colors.grey.shade200);
                  }
                  if (imgUrl.startsWith('http://') ||
                      imgUrl.startsWith('https://')) {
                    return Image.network(
                      imgUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, e, s) => Container(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                        child: const Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  } else {
                    return Image.file(
                      File(imgUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (_, e, s) => Container(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                        child: const Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  }
                }(),
              ),
            ),
            const SizedBox(height: 12),

            // Caption
            if (item.caption.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  item.caption,
                  style: GoogleFonts.caveat(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2C3E50),
                    height: 1.1,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Metadata Footer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.location.isNotEmpty)
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 10,
                          color: Color(0xFF7F8C8D),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            item.location,
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF7F8C8D),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.time,
                        style: GoogleFonts.outfit(
                          fontSize: 8,
                          color: const Color(0xFFBDC3C7),
                        ),
                      ),
                      if (widget.trip.isGroup)
                        Text(
                          'By: ${item.uploader}',
                          style: GoogleFonts.outfit(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
