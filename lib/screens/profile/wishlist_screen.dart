import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../models/destination.dart';
import '../../providers/trip_provider.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tripProvider = Provider.of<TripProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final allDestinations = tripProvider.destinations;

    final bookmarkedIds = tripProvider.bookmarkedDestinationIds;

    // Filter list to only bookmarked destinations
    final wishlistDestinations = allDestinations
        .where((dest) => bookmarkedIds.contains(dest.id))
        .toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            backgroundColor: AppTheme.primaryBlue,
            title: Text(
              'My Wishlist',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryBlue, Color(0xFF104B50)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppConstants.spaceL,
                      56,
                      AppConstants.spaceL,
                      0,
                    ),
                    child: Text(
                      '${wishlistDestinations.length} saved inspiration spots',
                      style: GoogleFonts.outfit(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (wishlistDestinations.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.spaceXL),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite_border_rounded,
                          color: AppTheme.primaryBlue,
                          size: 64,
                        ),
                      ),
                      const SizedBox(height: AppConstants.spaceXL),
                      Text(
                        'Your wishlist is empty',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppTheme.textPrimaryDark
                              : AppTheme.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: AppConstants.spaceS),
                      Text(
                        'No saved destinations yet. Tap the heart icon on any destination to save it here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppTheme.textSecondaryDark
                              : AppTheme.textSecondaryLight,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(AppConstants.spaceM),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final dest = wishlistDestinations[index];
                  return Dismissible(
                    key: Key('wishlist-${dest.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      margin: const EdgeInsets.only(
                        bottom: AppConstants.spaceM,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusL,
                        ),
                      ),
                      child: const Icon(
                        Icons.delete_rounded,
                        color: Colors.white,
                      ),
                    ),
                    onDismissed: (direction) async {
                      final success = await tripProvider.toggleBookmark(
                        dest.id,
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).clearSnackBars();
                      if (!success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              tripProvider.errorMessage ??
                                  'Could not update your wishlist.',
                            ),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Removed ${dest.name} from Wishlist'),
                          action: SnackBarAction(
                            label: 'Undo',
                            textColor: Colors.white,
                            onPressed: () async {
                              final restored = await tripProvider
                                  .toggleBookmark(dest.id);
                              if (!context.mounted || restored) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    tripProvider.errorMessage ??
                                        'Could not restore this wishlist item.',
                                  ),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            },
                          ),
                          backgroundColor: Colors.grey[850],
                        ),
                      );
                    },
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.destinationDetail,
                          arguments: dest,
                        );
                      },
                      onLongPress: () {
                        _confirmRemove(context, tripProvider, dest);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(
                          bottom: AppConstants.spaceM,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Theme.of(context).cardColor
                              : Colors.white,
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusL,
                          ),
                          border: Border.all(
                            color: isDark
                                ? Colors.white10
                                : Colors.grey.withValues(alpha: 0.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Row(
                          children: [
                            // Image
                            SizedBox(
                              width: 110,
                              height: 110,
                              child: Destination.loadImage(
                                dest.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  color: AppTheme.primaryBlue.withValues(
                                    alpha: 0.1,
                                  ),
                                  child: const Icon(
                                    Icons.landscape,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppConstants.spaceM),
                            // Details
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppConstants.spaceS,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryBlue.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        dest.category,
                                        style: const TextStyle(
                                          color: AppTheme.primaryBlue,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      dest.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isDark
                                            ? AppTheme.textPrimaryDark
                                            : AppTheme.textPrimaryLight,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on_rounded,
                                          color: AppTheme.secondaryGreen,
                                          size: 12,
                                        ),
                                        const SizedBox(width: 3),
                                        Expanded(
                                          child: Text(
                                            dest.district,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: isDark
                                                  ? AppTheme.textSecondaryDark
                                                  : AppTheme.textSecondaryLight,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Filled heart icon on tap unbookmarks
                            IconButton(
                              icon: const Icon(
                                Icons.favorite_rounded,
                                color: Colors.redAccent,
                              ),
                              onPressed: () {
                                _confirmRemove(context, tripProvider, dest);
                              },
                            ),
                            const SizedBox(width: AppConstants.spaceS),
                          ],
                        ),
                      ),
                    ),
                  );
                }, childCount: wishlistDestinations.length),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmRemove(
    BuildContext context,
    TripProvider tripProvider,
    Destination dest,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(
          'Remove from Wishlist?',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.redAccent,
          ),
        ),
        content: Text(
          'Are you sure you want to remove ${dest.name} from your saved inspirations?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final success = await tripProvider.toggleBookmark(dest.id);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? 'Removed ${dest.name} from Wishlist'
                        : (tripProvider.errorMessage ??
                              'Could not update your wishlist.'),
                  ),
                  backgroundColor: success
                      ? Colors.grey[850]
                      : Colors.redAccent,
                ),
              );
            },
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
