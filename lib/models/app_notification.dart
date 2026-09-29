enum NotificationType {
  aiPlan,
  tripUpdate,
  memberJoin,
  taskComplete,
  memoryUpload,
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String time; // Relative time (e.g., "10 mins ago", "2 hours ago")
  final String icon;
  final bool isNew;
  final NotificationType type;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    required this.icon,
    required this.isNew,
    required this.type,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    NotificationType type;
    switch (json['type']) {
      case 'aiPlan':
        type = NotificationType.aiPlan;
        break;
      case 'tripUpdate':
        type = NotificationType.tripUpdate;
        break;
      case 'memberJoin':
        type = NotificationType.memberJoin;
        break;
      case 'taskComplete':
        type = NotificationType.taskComplete;
        break;
      case 'memoryUpload':
        type = NotificationType.memoryUpload;
        break;
      default:
        type = NotificationType.tripUpdate;
    }

    return AppNotification(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      time: json['time'] ?? 'Just now',
      icon: json['icon'] ?? '🔔',
      isNew: json['isNew'] ?? true,
      type: type,
    );
  }

  static final List<AppNotification> mockNotifications = [
    AppNotification(
      id: 'notif-1',
      title: 'Gemini AI Planner Ready',
      body: 'Your AI itinerary for Mt. Apo is ready!',
      time: '10 mins ago',
      icon: '⚡',
      isNew: true,
      type: NotificationType.aiPlan,
    ),
    AppNotification(
      id: 'notif-2',
      title: 'Member Joined',
      body: 'Maria joined your Davao Oriental coastal trip.',
      time: '2 hours ago',
      icon: '👥',
      isNew: true,
      type: NotificationType.memberJoin,
    ),
    AppNotification(
      id: 'notif-3',
      title: 'Trip Updated',
      body: 'Your Samal Island trip has been updated.',
      time: 'Yesterday',
      icon: '🏖️',
      isNew: false,
      type: NotificationType.tripUpdate,
    ),
    AppNotification(
      id: 'notif-4',
      title: 'Task Completed',
      body: 'Juan completed: Book accommodation.',
      time: 'Yesterday',
      icon: '✅',
      isNew: false,
      type: NotificationType.taskComplete,
    ),
    AppNotification(
      id: 'notif-5',
      title: 'Memory Uploaded',
      body: 'A new memory photo was added to Samal Trip.',
      time: '2 days ago',
      icon: '📸',
      isNew: false,
      type: NotificationType.memoryUpload,
    ),
  ];
}
