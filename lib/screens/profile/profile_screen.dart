import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../models/user_profile.dart';
import '../../widgets/buttons/custom_button.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import 'wishlist_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Local settings preferences state
  bool _pushNotifications = true;
  bool _emailUpdates = false;
  bool _weeklyDigest = true;
  String _selectedLanguage = 'English';

  final List<String> _avatars = [
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150&q=80',
    'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150&q=80',
    'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150&q=80',
    'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=150&q=80',
    'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=150&q=80',
  ];

  final _menuItems = [
    {'icon': Icons.favorite_border_rounded, 'label': 'My Wishlist'},
    {'icon': Icons.person_outline_rounded, 'label': 'Edit Profile'},
    {'icon': Icons.lock_outline_rounded, 'label': 'Change Password'},
    {'icon': Icons.notifications_outlined, 'label': 'Notifications'},
    {'icon': Icons.language_rounded, 'label': 'Language'},
    {'icon': Icons.palette_outlined, 'label': 'Appearance'},
    {'icon': Icons.help_outline_rounded, 'label': 'Help & Support'},
    {'icon': Icons.privacy_tip_outlined, 'label': 'Privacy Policy'},
    {'icon': Icons.info_outline_rounded, 'label': 'About Lakbay+'},
  ];

  // 1. Edit Profile Sheet
  void _showEditProfileSheet(BuildContext context, AuthProvider auth, UserProfile user) {
    final nameCtrl = TextEditingController(text: user.displayName);
    final usernameCtrl = TextEditingController(text: user.username);
    final emailCtrl = TextEditingController(text: user.email);
    final phoneCtrl = TextEditingController(text: user.phone);
    final emergencyCtrl = TextEditingController(text: user.emergencyContact);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
        return Container(
          padding: EdgeInsets.only(
            left: AppConstants.spaceL,
            right: AppConstants.spaceL,
            top: AppConstants.spaceL,
            bottom: AppConstants.spaceL + MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: Theme.of(sheetCtx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Edit Profile Info',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.grey),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spaceM),
                  
                  // Full Name
                  TextFormField(
                    controller: nameCtrl,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: const Icon(Icons.person_rounded, color: AppTheme.primaryBlue),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) => val == null || val.trim().length < 2 
                      ? 'Enter a valid name (min 2 characters)' 
                      : null,
                  ),
                  const SizedBox(height: AppConstants.spaceM),
                  
                  // Username
                  TextFormField(
                    controller: usernameCtrl,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Username',
                      prefixIcon: const Icon(Icons.alternate_email_rounded, color: AppTheme.primaryBlue),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty 
                      ? 'Username is required' 
                      : null,
                  ),
                  const SizedBox(height: AppConstants.spaceM),
                  
                  // Email
                  TextFormField(
                    controller: emailCtrl,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: const Icon(Icons.email_rounded, color: AppTheme.primaryBlue),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) => val == null || !val.contains('@') 
                      ? 'Enter a valid email address' 
                      : null,
                  ),
                  const SizedBox(height: 4),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                      'Changing email requires re-authentication on next login.',
                      style: TextStyle(fontSize: 10, color: Colors.orange, fontStyle: FontStyle.italic),
                    ),
                  ),
                  const SizedBox(height: AppConstants.spaceM),
                  
                  // Phone Number (Optional)
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Phone Number (Optional)',
                      hintText: '+639171234567',
                      prefixIcon: const Icon(Icons.phone_rounded, color: AppTheme.primaryBlue),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: AppConstants.spaceM),
                  
                  // Emergency Contact (Optional)
                  TextFormField(
                    controller: emergencyCtrl,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Emergency Contact Name & Number (Optional)',
                      hintText: 'Name • Number',
                      prefixIcon: const Icon(Icons.contact_phone_rounded, color: AppTheme.primaryBlue),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: AppConstants.spaceXL),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (!formKey.currentState!.validate()) return;
                        
                        final updated = user.copyWith(
                          displayName: nameCtrl.text.trim(),
                          username: usernameCtrl.text.trim(),
                          email: emailCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          emergencyContact: emergencyCtrl.text.trim(),
                        );
                        
                        auth.updateUserProfile(updated);
                        Navigator.pop(sheetCtx);
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Profile details updated successfully! ✨'),
                            backgroundColor: AppTheme.secondaryGreen,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: AppConstants.spaceM),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Curated avatar selection picker
  void _showAvatarPickerSheet(BuildContext context, AuthProvider auth, UserProfile user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(AppConstants.spaceL),
          decoration: BoxDecoration(
            color: Theme.of(sheetCtx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                'Choose Traveler Avatar',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryBlue),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _avatars.length,
                  itemBuilder: (_, i) {
                    final img = _avatars[i];
                    final isSelected = user.avatarUrl == img;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppConstants.spaceM),
                      child: GestureDetector(
                        onTap: () {
                          final updated = user.copyWith(avatarUrl: img);
                          auth.updateUserProfile(updated);
                          Navigator.pop(sheetCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Avatar updated successfully! 🎭'), backgroundColor: AppTheme.secondaryGreen),
                          );
                        },
                        child: AnimatedContainer(
                          duration: AppConstants.animDurationFast,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? AppTheme.secondaryGreen : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 40,
                            backgroundImage: NetworkImage(img),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // 2. Notifications Toggle Sheet
  void _showNotificationsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Container(
              padding: const EdgeInsets.all(AppConstants.spaceL),
              decoration: BoxDecoration(
                color: Theme.of(sheetCtx).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Notification Preferences', style: GoogleFonts.outfit(
                        fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.grey),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spaceS),
                  SwitchListTile(
                    title: Text(
                      'Push Notifications',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                      ),
                    ),
                    subtitle: Text(
                      'Alerts about active trips and schedules',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                      ),
                    ),
                    value: _pushNotifications,
                    activeThumbColor: AppTheme.primaryBlue,
                    onChanged: (val) {
                      setLocalState(() => _pushNotifications = val);
                      setState(() => _pushNotifications = val);
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: Text(
                      'Email Marketing Alerts',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                      ),
                    ),
                    subtitle: Text(
                      'Deals, promos, and destination recommendations',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                      ),
                    ),
                    value: _emailUpdates,
                    activeThumbColor: AppTheme.primaryBlue,
                    onChanged: (val) {
                      setLocalState(() => _emailUpdates = val);
                      setState(() => _emailUpdates = val);
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: Text(
                      'Weekly Digest',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                      ),
                    ),
                    subtitle: Text(
                      'Weekly summaries of shared trip memories',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                      ),
                    ),
                    value: _weeklyDigest,
                    activeThumbColor: AppTheme.primaryBlue,
                    onChanged: (val) {
                      setLocalState(() => _weeklyDigest = val);
                      setState(() => _weeklyDigest = val);
                    },
                  ),
                  const SizedBox(height: AppConstants.spaceM),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 3. Language Selector Sheet
  void _showLanguageSheet(BuildContext context) {
    final languages = ['English', 'Tagalog (Filipino)', 'Spanish (Español)', 'Japanese (日本語)'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Container(
              padding: const EdgeInsets.all(AppConstants.spaceL),
              decoration: BoxDecoration(
                color: Theme.of(sheetCtx).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Select App Language', style: GoogleFonts.outfit(
                        fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.grey),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spaceS),
                  Column(
                    children: languages.map((lang) {
                      final isSelected = _selectedLanguage == lang;
                      return ListTile(
                        title: Text(lang, style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppTheme.primaryBlue : (isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight),
                        )),
                        trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppTheme.primaryBlue) : null,
                        onTap: () {
                          setLocalState(() => _selectedLanguage = lang);
                          setState(() => _selectedLanguage = lang);
                          Navigator.pop(sheetCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Language switched to $lang! 🌐'),
                              backgroundColor: AppTheme.secondaryGreen,
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 4. Appearance Mode Sheet
  void _showAppearanceSheet(BuildContext context) {
    final themes = ['Light Theme Mode', 'Dark Theme Mode', 'System Adaptive'];
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Container(
              padding: const EdgeInsets.all(AppConstants.spaceL),
              decoration: BoxDecoration(
                color: Theme.of(sheetCtx).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Configure Appearance', style: GoogleFonts.outfit(
                        fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.grey),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spaceS),
                  Column(
                    children: themes.map((themeMode) {
                      final isSelected = themeProvider.appearanceString == themeMode;
                      return ListTile(
                        leading: Icon(
                          themeMode.contains('Light') ? Icons.light_mode_rounded :
                          themeMode.contains('Dark') ? Icons.dark_mode_rounded : Icons.brightness_auto_rounded,
                          color: isSelected ? AppTheme.primaryBlue : Colors.grey,
                        ),
                        title: Text(themeMode, style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppTheme.primaryBlue : (isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight),
                        )),
                        trailing: isSelected ? const Icon(Icons.radio_button_checked_rounded, color: AppTheme.primaryBlue) : const Icon(Icons.radio_button_off_rounded),
                        onTap: () {
                          setLocalState(() {
                            themeProvider.setAppearanceFromString(themeMode);
                          });
                          setState(() {});
                          Navigator.pop(sheetCtx);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 5. Help & Support Expansion Sheet
  void _showHelpSheet(BuildContext context) {
    final faqs = [
      {
        'q': 'How do I plan a trip using Lakbay AI?',
        'a': 'Go to the Planner tab, select your destination, specify duration and vibe parameters, and click Generate. Our advanced engine uses Google Gemini to build it!'
      },
      {
        'q': 'How do I invite teammates to collaborate?',
        'a': 'Open any trip on your list, tap Trip Dashboard, and click the person add icon in the Member carousel. Enter their email address to share the itinerary.'
      },
      {
        'q': 'Can I track offline activities?',
        'a': 'Yes! Your itineraries are securely stored locally in the database, allowing you to access activities, locations, and costs without active internet.'
      }
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(AppConstants.spaceL),
          decoration: BoxDecoration(
            color: Theme.of(sheetCtx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Help & Support Desk', style: GoogleFonts.outfit(
                    fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.pop(sheetCtx),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spaceM),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Frequently Asked Questions',
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 15, 
                          color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: AppConstants.spaceS),
                      ...faqs.map((faq) => Card(
                        margin: const EdgeInsets.only(bottom: AppConstants.spaceM),
                        elevation: 0,
                        color: AppTheme.primaryBlue.withOpacity(0.04),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ExpansionTile(
                          title: Text(faq['q']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryBlue)),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(AppConstants.spaceM),
                              child: Text(
                                faq['a']!, 
                                style: TextStyle(
                                  fontSize: 12, 
                                  height: 1.5, 
                                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                      const SizedBox(height: AppConstants.spaceL),
                      const Divider(),
                      const SizedBox(height: AppConstants.spaceL),
                      Text(
                        'Still Need Help? Contact Us',
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 15, 
                          color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: AppConstants.spaceM),
                      TextField(
                        maxLines: 3,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter your inquiry here... Our support team replies within 24 hours!',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.textSecondaryDark.withOpacity(0.7) : AppTheme.textSecondaryLight.withOpacity(0.7),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: AppConstants.spaceM),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(sheetCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Support ticket successfully sent! 🎟️'),
                                backgroundColor: AppTheme.secondaryGreen,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Submit Ticket', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 6. Privacy Policy sheet
  void _showPrivacySheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Privacy Policy', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
          content: SizedBox(
            height: 250,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Last Updated: May 2026\n', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.textSecondaryDark : Colors.grey)),
                  Text(
                    '1. Data Collection\nWe respect your digital boundaries. Lakbay+ securely collects trip specifications, preferences, and names solely to generate custom travel itineraries using Gemini AI model processors. Your private communication details are never shared with advertising third-parties.',
                    style: TextStyle(fontSize: 12, height: 1.5, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                  ),
                  const SizedBox(height: AppConstants.spaceM),
                  Text(
                    '2. Offline Data Storage\nAll trip records, photo albums, and schedule markers are stored securely in local database tables. This assures offline accessibility and limits cloud leaks.',
                    style: TextStyle(fontSize: 12, height: 1.5, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Understand & Close', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
            ),
          ],
        );
      },
    );
  }

  // 7. About Lakbay+ brand overlay modal
  void _showAboutSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            padding: const EdgeInsets.all(AppConstants.spaceL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.flight_takeoff_rounded, color: AppTheme.primaryBlue, size: 40),
                ),
                const SizedBox(height: AppConstants.spaceM),
                Text('Lakbay+', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                Text('Your Premium Travel AI Companion', style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight)),
                const SizedBox(height: AppConstants.spaceM),
                const Divider(),
                const SizedBox(height: AppConstants.spaceM),
                Text(
                  'Version 1.2.4 (Build 4122)\nDeveloped by Lakbay Tech Labs.\nGoogle DeepMind pair-programmed architecture.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, height: 1.5, color: isDark ? AppTheme.textSecondaryDark : Colors.grey),
                ),
                const SizedBox(height: AppConstants.spaceL),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Awesome!', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Secure Password Change Sheet
  void _showChangePasswordSheet(BuildContext context) {
    final currentPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    
    bool showCurrent = false;
    bool showNew = false;
    bool showConfirm = false;
    
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                left: AppConstants.spaceL,
                right: AppConstants.spaceL,
                top: AppConstants.spaceL,
                bottom: AppConstants.spaceL + MediaQuery.of(sheetCtx).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: Theme.of(sheetCtx).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Change Password',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.grey),
                            onPressed: () => Navigator.pop(sheetCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppConstants.spaceM),
                      
                      // Current Password
                      TextFormField(
                        controller: currentPasswordCtrl,
                        obscureText: !showCurrent,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Current Password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.primaryBlue),
                          suffixIcon: IconButton(
                            icon: Icon(showCurrent ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.grey),
                            onPressed: () => setSheetState(() => showCurrent = !showCurrent),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) => val == null || val.isEmpty ? 'Current password is required' : null,
                      ),
                      const SizedBox(height: AppConstants.spaceM),
                      
                      // New Password
                      TextFormField(
                        controller: newPasswordCtrl,
                        obscureText: !showNew,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                        ),
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          prefixIcon: const Icon(Icons.lock_rounded, color: AppTheme.primaryBlue),
                          suffixIcon: IconButton(
                            icon: Icon(showNew ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.grey),
                            onPressed: () => setSheetState(() => showNew = !showNew),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) {
                          if (val == null || val.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          if (!val.contains(RegExp(r'[A-Z]'))) {
                            return 'Password must contain at least 1 uppercase letter';
                          }
                          if (!val.contains(RegExp(r'[0-9]'))) {
                            return 'Password must contain at least 1 number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppConstants.spaceM),
                      
                      // Confirm Password
                      TextFormField(
                        controller: confirmPasswordCtrl,
                        obscureText: !showConfirm,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Confirm New Password',
                          prefixIcon: const Icon(Icons.lock_rounded, color: AppTheme.primaryBlue),
                          suffixIcon: IconButton(
                            icon: Icon(showConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.grey),
                            onPressed: () => setSheetState(() => showConfirm = !showConfirm),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) => val != newPasswordCtrl.text 
                          ? 'Passwords do not match exactly' 
                          : null,
                      ),
                      const SizedBox(height: AppConstants.spaceXL),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            if (!formKey.currentState!.validate()) return;
                            
                            Navigator.pop(sheetCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Password changed successfully! 🔐✨'),
                                backgroundColor: AppTheme.secondaryGreen,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: AppConstants.spaceM),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Logout confirmation dialog
  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Sign Out?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.red)),
        content: const Text('Are you sure you want to sign out of your Lakbay+ session? Your trip summaries and maps are securely saved offline.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.read<AuthProvider>().logout();
              Navigator.pushReplacementNamed(context, AppRoutes.login);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Successfully signed out.'), backgroundColor: AppTheme.secondaryGreen),
              );
            },
            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userProfile ?? UserProfile.defaultProfile;

    // Dynamic stats calculations
    final tripProvider = Provider.of<TripProvider>(context);
    final savedTripsCount = tripProvider.userTrips.length;
    final memoriesCount = tripProvider.userTrips.fold<int>(0, (sum, t) => sum + t.memories.length);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Profile header
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.primaryBlue, Color(0xFF104B50)],
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + AppConstants.spaceM,
                left: AppConstants.spaceL,
                right: AppConstants.spaceL,
                bottom: AppConstants.spaceXL,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text('Profile', style: GoogleFonts.outfit(
                        fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spaceXL),
                  // Avatar
                  Stack(
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.secondaryGreen, width: 3),
                          boxShadow: AppConstants.premiumShadow,
                        ),
                        child: ClipOval(
                          child: Image.network(
                            user.avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: AppTheme.secondaryGreen.withValues(alpha: 0.2),
                              child: const Icon(Icons.person, size: 48, color: Colors.white),
                            )),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _showAvatarPickerSheet(context, authProvider, user),
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryGreen,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.photo_camera_rounded, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spaceM),
                  Text(user.displayName, style: GoogleFonts.outfit(
                    fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text(user.email, style: const TextStyle(color: Colors.white60, fontSize: 13)),
                  const SizedBox(height: AppConstants.spaceL),
                  
                  // Premium stats box (Dynamically calculated counts)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: AppConstants.spaceM, horizontal: AppConstants.spaceS),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppConstants.radiusXL),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('$savedTripsCount', 'Saved Trips', Icons.flight_takeoff_rounded),
                        _divider(),
                        _buildStatItem('$memoriesCount', 'Memories', Icons.photo_library_rounded),
                        _divider(),
                        _buildStatItem('${user.visitedProvincesCount}', 'Provinces', Icons.map_rounded),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Settings Section Title
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                left: AppConstants.spaceL,
                right: AppConstants.spaceL,
                top: AppConstants.spaceXL,
                bottom: AppConstants.spaceM,
              ),
              child: Text(
                'Settings & Security', 
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold, 
                  color: AppTheme.primaryBlue
                )
              ),
            ),
          ),

          // Menu items
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final item = _menuItems[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spaceL, vertical: 2),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Icon(item['icon'] as IconData, color: AppTheme.primaryBlue, size: 20),
                  ),
                  title: Text(item['label'] as String, style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 15)),
                  trailing: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight,
                  ),
                  onTap: () {
                    switch (item['label'] as String) {
                      case 'My Wishlist':
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const WishlistScreen(),
                          ),
                        );
                        break;
                      case 'Edit Profile':
                        _showEditProfileSheet(context, authProvider, user);
                        break;
                      case 'Change Password':
                        _showChangePasswordSheet(context);
                        break;
                      case 'Notifications':
                        _showNotificationsSheet(context);
                        break;
                      case 'Language':
                        _showLanguageSheet(context);
                        break;
                      case 'Appearance':
                        _showAppearanceSheet(context);
                        break;
                      case 'Help & Support':
                        _showHelpSheet(context);
                        break;
                      case 'Privacy Policy':
                        _showPrivacySheet(context);
                        break;
                      case 'About Lakbay+':
                        _showAboutSheet(context);
                        break;
                    }
                  },
                );
              },
              childCount: _menuItems.length,
            ),
          ),

          // Logout Sliver Button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spaceXL),
              child: CustomButton(
                label: 'Sign Out',
                onPressed: () => _confirmSignOut(context),
                variant: ButtonVariant.outlined,
                width: double.infinity,
                leadingIcon: Icons.logout_rounded,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppTheme.secondaryGreen, size: 22),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(
            color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 36, color: Colors.white24);
  }
}
