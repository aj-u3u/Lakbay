import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../models/trip.dart';
import '../../providers/trip_provider.dart';

class GroupTasksScreen extends StatefulWidget {
  final Trip? trip;
  const GroupTasksScreen({super.key, this.trip});

  @override
  State<GroupTasksScreen> createState() => _GroupTasksScreenState();
}

class _GroupTasksScreenState extends State<GroupTasksScreen> {
  Trip _getTrip(BuildContext context) {
    if (widget.trip != null) {
      final trips = context.watch<TripProvider>().userTrips;
      return trips.firstWhere((t) => t.id == widget.trip!.id, orElse: () => widget.trip!);
    }
    final trips = context.watch<TripProvider>().userTrips;
    return trips.isNotEmpty ? trips.first : Trip.mockTrips[0];
  }

  void _toggleTask(Trip activeTrip, int index) {
    final updatedTasks = List<Map<String, dynamic>>.from(
      activeTrip.tasks.map((t) => Map<String, dynamic>.from(t))
    );
    updatedTasks[index]['done'] = !updatedTasks[index]['done'];
    
    final updatedTrip = activeTrip.copyWith(tasks: updatedTasks);
    Provider.of<TripProvider>(context, listen: false).updateTrip(updatedTrip);
    
    final isDone = updatedTasks[index]['done'];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isDone ? 'Task marked as completed! 🎉' : 'Task marked as incomplete.'),
        backgroundColor: isDone ? AppTheme.secondaryGreen : AppTheme.primaryBlue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showAddTaskSheet(BuildContext context, Trip activeTrip) {
    final taskController = TextEditingController();
    String selectedCategory = 'Booking';
    
    // Dynamic assignees list based on trip travelers
    final List<String> assignees = [];
    if (activeTrip.isGroup) {
      if (activeTrip.numTravelers >= 1) assignees.add('Arjane');
      if (activeTrip.numTravelers >= 2) assignees.add('Bea');
      if (activeTrip.numTravelers >= 3) assignees.add('Carlo');
      if (activeTrip.numTravelers >= 4) assignees.add('Dana');
      for (int i = 5; i <= activeTrip.numTravelers; i++) {
        assignees.add('Traveler $i');
      }
    } else {
      assignees.add('Arjane');
    }
    
    String selectedAssignee = assignees.first;
    final categories = ['Booking', 'Packing', 'Research', 'Transport', 'Finance'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                left: 24, right: 24, top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surface,
                borderRadius: const BorderRadius.only(
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
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Create Group Task',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryBlue),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: taskController,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Task Title',
                      hintText: 'e.g. Confirm hotel shuttle timing',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Category Chips
                  Text('Category', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: categories.map((cat) {
                      final isSelected = selectedCategory == cat;
                      return ChoiceChip(
                        label: Text(
                          cat, 
                          style: TextStyle(
                            color: isSelected ? Colors.white : (isDark ? AppTheme.textSecondaryDark : AppTheme.primaryBlue), 
                            fontSize: 11,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppTheme.primaryBlue,
                        backgroundColor: isDark ? Colors.white10 : AppTheme.primaryBlue.withOpacity(0.05),
                        onSelected: (val) {
                          if (val) setSheetState(() => selectedCategory = cat);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  
                  // Assignee Dropdown
                  Text('Assign to Member', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? Colors.white24 : Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedAssignee,
                        isExpanded: true,
                        dropdownColor: Theme.of(ctx).colorScheme.surface,
                        items: assignees.map((name) => DropdownMenuItem(
                          value: name,
                          child: Text(
                            name, 
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                            ),
                          ),
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setSheetState(() => selectedAssignee = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Save Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      if (taskController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a task title.'), backgroundColor: Colors.red),
                        );
                        return;
                      }
                      
                      final newTask = {
                        'task': taskController.text.trim(),
                        'assignee': selectedAssignee,
                        'done': false,
                        'category': selectedCategory,
                      };
                      
                      final updatedTasks = List<Map<String, dynamic>>.from(activeTrip.tasks);
                      updatedTasks.add(newTask);
                      
                      final updatedTrip = activeTrip.copyWith(tasks: updatedTasks);
                      Provider.of<TripProvider>(context, listen: false).updateTrip(updatedTrip);
                      
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Task added successfully!'), backgroundColor: AppTheme.secondaryGreen),
                      );
                    },
                    child: Text('Add Task', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTrip = _getTrip(context);
    final tasksList = activeTrip.tasks;
    final int completed = tasksList.where((t) => t['done'] == true).length;
    final double completionRate = tasksList.isNotEmpty ? completed / tasksList.length : 0.0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(activeTrip.isGroup ? 'Group Tasks' : 'My Tasks', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppTheme.secondaryGreen, size: 28),
            onPressed: () => _showAddTaskSheet(context, activeTrip),
          ),
        ],
      ),
      body: tasksList.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(color: AppTheme.primaryBlue.withValues(alpha: 0.05), shape: BoxShape.circle),
                    child: const Icon(Icons.playlist_add_check_rounded, color: AppTheme.primaryBlue, size: 36),
                  ),
                  const SizedBox(height: 16),
                  Text('No tasks created yet.', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryBlue)),
                  const SizedBox(height: 6),
                  const Text('Click the "+" button to add your first checklist item.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryLight)),
                ],
              ),
            )
          : Column(
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
                          Text('$completed/${tasksList.length} done',
                            style: const TextStyle(color: AppTheme.textSecondaryLight, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: AppConstants.spaceM),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
                        child: LinearProgressIndicator(
                          value: completionRate,
                          minHeight: 10,
                          backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.secondaryGreen),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM),
                    itemCount: tasksList.length,
                    itemBuilder: (_, i) {
                      final task = tasksList[i];
                      final isDone = task['done'] == true;
                      return GestureDetector(
                        onTap: () => _toggleTask(activeTrip, i),
                        child: AnimatedContainer(
                          duration: AppConstants.animDurationFast,
                          margin: const EdgeInsets.only(bottom: AppConstants.spaceM),
                          padding: const EdgeInsets.all(AppConstants.spaceM),
                          decoration: BoxDecoration(
                            color: isDone
                                ? AppTheme.secondaryGreen.withValues(alpha: 0.06)
                                : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(AppConstants.radiusL),
                            border: Border.all(
                              color: isDone
                                  ? AppTheme.secondaryGreen.withValues(alpha: 0.3)
                                  : Colors.transparent,
                            ),
                            boxShadow: isDone ? [] : AppConstants.cardShadow,
                          ),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: AppConstants.animDurationFast,
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: isDone ? AppTheme.secondaryGreen : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDone
                                        ? AppTheme.secondaryGreen
                                        : AppTheme.textSecondaryLight.withValues(alpha: 0.4),
                                    width: 2,
                                  ),
                                ),
                                child: isDone
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
                                        color: isDone
                                            ? AppTheme.textSecondaryLight
                                            : AppTheme.primaryBlue,
                                        decoration: isDone ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryBlue.withValues(alpha: 0.07),
                                            borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
                                          ),
                                          child: Text(task['category'] ?? 'General',
                                            style: const TextStyle(fontSize: 10, color: AppTheme.primaryBlue, fontWeight: FontWeight.w600)),
                                        ),
                                        const SizedBox(width: AppConstants.spaceS),
                                        const Icon(Icons.person_outline, size: 12, color: AppTheme.textSecondaryLight),
                                        const SizedBox(width: 3),
                                        Text(task['assignee'] ?? 'Unassigned',
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
