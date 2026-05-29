import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../models/app_notification.dart';
import '../../providers/trip_provider.dart';
import '../../widgets/shared/empty_state.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  IconData _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.aiPlan:
        return Icons.auto_awesome_rounded;
      case NotificationType.tripUpdate:
        return Icons.map_rounded;
      case NotificationType.memberJoin:
        return Icons.person_add_rounded;
      case NotificationType.taskComplete:
        return Icons.check_circle_outline_rounded;
      case NotificationType.memoryUpload:
        return Icons.photo_library_rounded;
    }
  }

  Color _getColorForType(NotificationType type) {
    switch (type) {
      case NotificationType.aiPlan:
        return AppTheme.primaryBlue;
      case NotificationType.tripUpdate:
        return AppTheme.secondaryGreen;
      case NotificationType.memberJoin:
        return const Color(0xFF6B3A8B);
      case NotificationType.taskComplete:
        return Colors.green.shade600;
      case NotificationType.memoryUpload:
        return Colors.orange.shade700;
    }
  }

  void _handleTap(BuildContext context, AppNotification notif, TripProvider provider) {
    // Mark as read
    provider.markNotificationAsRead(notif.id);

    // Route to appropriate screen based on type
    switch (notif.type) {
      case NotificationType.aiPlan:
        // Navigates to AI Planner Results or Home shell
        Navigator.pushNamed(context, AppRoutes.navShell);
        break;
      case NotificationType.tripUpdate:
        Navigator.pushNamed(context, AppRoutes.navShell);
        break;
      case NotificationType.memberJoin:
        Navigator.pushNamed(context, AppRoutes.groupDashboard);
        break;
      case NotificationType.taskComplete:
        Navigator.pushNamed(context, AppRoutes.groupTasks);
        break;
      case NotificationType.memoryUpload:
        Navigator.pushNamed(context, AppRoutes.groupMemories);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TripProvider>();
    final notifs = provider.notifications;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryBlue,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.primaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (notifs.any((n) => n.isNew))
            TextButton.icon(
              icon: const Icon(Icons.done_all_rounded, size: 16, color: AppTheme.secondaryGreen),
              label: Text(
                'Mark all as read',
                style: GoogleFonts.outfit(
                  color: AppTheme.secondaryGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              onPressed: () {
                provider.markAllNotificationsAsRead();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'All notifications marked as read',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
                    ),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: AppTheme.primaryBlue,
                  ),
                );
              },
            ),
        ],
      ),
      body: notifs.isEmpty
          ? Center(
              child: EmptyState.notifications(),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spaceM,
                vertical: AppConstants.spaceS,
              ),
              itemCount: notifs.length,
              itemBuilder: (context, index) {
                final notif = notifs[index];
                final iconColor = _getColorForType(notif.type);
                final iconData = _getIconForType(notif.type);

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: notif.isNew
                        ? iconColor.withValues(alpha: 0.04)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: notif.isNew
                          ? iconColor.withValues(alpha: 0.15)
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                      width: 1,
                    ),
                    boxShadow: notif.isNew
                        ? [
                            BoxShadow(
                              color: iconColor.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      // Left border indicator for unread notifications per spec
                      decoration: BoxDecoration(
                        border: notif.isNew
                            ? Border(
                                left: BorderSide(
                                  color: iconColor,
                                  width: 4,
                                ),
                              )
                            : null,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.spaceM,
                          vertical: 8,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            iconData,
                            color: iconColor,
                            size: 20,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                notif.title,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (notif.isNew)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: iconColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              notif.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.7),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              notif.time,
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                        onTap: () => _handleTap(context, notif, provider),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
