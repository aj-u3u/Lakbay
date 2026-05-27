import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';

class GroupTasksScreen extends StatefulWidget {
  const GroupTasksScreen({Key? key}) : super(key: key);

  @override
  State<GroupTasksScreen> createState() => _GroupTasksScreenState();
}

class _GroupTasksScreenState extends State<GroupTasksScreen> {
  final List<Map<String, dynamic>> _tasks = [
    {'task': 'Book Pearl Farm ferry tickets', 'assignee': 'Arjane', 'done': true, 'category': 'Booking'},
    {'task': 'Reserve 2 Samal House cabins', 'assignee': 'Bea', 'done': true, 'category': 'Booking'},
    {'task': 'Buy snorkeling gear for 4 people', 'assignee': 'Carlo', 'done': false, 'category': 'Packing'},
    {'task': 'Pack emergency first aid kit', 'assignee': 'Dana', 'done': false, 'category': 'Packing'},
    {'task': 'Confirm Hagimit Falls entry fees', 'assignee': 'Arjane', 'done': false, 'category': 'Research'},
    {'task': 'Book a habal-habal to Monfort Bats', 'assignee': 'Bea', 'done': false, 'category': 'Transport'},
    {'task': 'Prepare ₱3,000 cash emergency fund', 'assignee': 'Carlo', 'done': true, 'category': 'Finance'},
  ];

  int get _completed => _tasks.where((t) => t['done'] == true).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Group Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppTheme.secondaryGreen, size: 28),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar header
          Container(
            margin: const EdgeInsets.all(AppConstants.spaceM),
            padding: const EdgeInsets.all(AppConstants.spaceL),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppConstants.radiusXL),
              boxShadow: AppConstants.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Progress', style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, fontSize: 16)),
                    const Spacer(),
                    Text('$_completed/${_tasks.length} done',
                      style: const TextStyle(color: AppTheme.textSecondaryLight, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: AppConstants.spaceM),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
                  child: LinearProgressIndicator(
                    value: _completed / _tasks.length,
                    minHeight: 10,
                    backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.secondaryGreen),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM),
              itemCount: _tasks.length,
              itemBuilder: (_, i) {
                final task = _tasks[i];
                return GestureDetector(
                  onTap: () => setState(() => task['done'] = !task['done']),
                  child: AnimatedContainer(
                    duration: AppConstants.animDurationFast,
                    margin: const EdgeInsets.only(bottom: AppConstants.spaceM),
                    padding: const EdgeInsets.all(AppConstants.spaceM),
                    decoration: BoxDecoration(
                      color: task['done'] == true
                          ? AppTheme.secondaryGreen.withOpacity(0.06)
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppConstants.radiusL),
                      border: Border.all(
                        color: task['done'] == true
                            ? AppTheme.secondaryGreen.withOpacity(0.3)
                            : Colors.transparent,
                      ),
                      boxShadow: task['done'] == true ? [] : AppConstants.cardShadow,
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: AppConstants.animDurationFast,
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: task['done'] == true ? AppTheme.secondaryGreen : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: task['done'] == true
                                  ? AppTheme.secondaryGreen
                                  : AppTheme.textSecondaryLight.withOpacity(0.4),
                              width: 2,
                            ),
                          ),
                          child: task['done'] == true
                              ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                              : null,
                        ),
                        const SizedBox(width: AppConstants.spaceM),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task['task'],
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: task['done'] == true
                                      ? AppTheme.textSecondaryLight
                                      : AppTheme.primaryBlue,
                                  decoration: task['done'] == true ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryBlue.withOpacity(0.07),
                                      borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
                                    ),
                                    child: Text(task['category'],
                                      style: const TextStyle(fontSize: 10, color: AppTheme.primaryBlue, fontWeight: FontWeight.w600)),
                                  ),
                                  const SizedBox(width: AppConstants.spaceS),
                                  const Icon(Icons.person_outline, size: 12, color: AppTheme.textSecondaryLight),
                                  const SizedBox(width: 3),
                                  Text(task['assignee'],
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryLight)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
