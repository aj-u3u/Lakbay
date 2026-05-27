import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../models/user_profile.dart';
import '../../widgets/buttons/custom_button.dart';
import '../../widgets/inputs/preference_selector.dart';
import '../../providers/theme_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = UserProfile.defaultProfile;
  List<String> _selectedPrefs = ['Nature', 'Beach', 'Food & Culture'];

  // Local state for interactive settings
  late String _displayName;
  late String _email;
  bool _pushNotifications = true;
  bool _emailUpdates = false;
  bool _weeklyDigest = true;
  String _selectedLanguage = 'English';

  @override
  void initState() {
    super.initState();
    _displayName = user.displayName;
    _email = user.email;
  }

  final _menuItems = [
    {'icon': Icons.person_outline_rounded, 'label': 'Edit Profile'},
    {'icon': Icons.notifications_outlined, 'label': 'Notifications'},
    {'icon': Icons.language_rounded, 'label': 'Language'},
    {'icon': Icons.palette_outlined, 'label': 'Appearance'},
    {'icon': Icons.help_outline_rounded, 'label': 'Help & Support'},
    {'icon': Icons.privacy_tip_outlined, 'label': 'Privacy Policy'},
    {'icon': Icons.info_outline_rounded, 'label': 'About Lakbay+'},
  ];

  // 1. Edit Profile Sheet
  void _showEditProfileSheet(BuildContext context) {
    final titleCtrl = TextEditingController(text: _displayName);
    final emailCtrl = TextEditingController(text: _email);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          padding: EdgeInsets.only(
            left: AppConstants.spaceL,
            right: AppConstants.spaceL,
            top: AppConstants.spaceL,
            bottom: AppConstants.spaceL + MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  TextFormField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: const Icon(Icons.person_rounded, color: AppTheme.primaryBlue),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Enter your name' : null,
                  ),
                  const SizedBox(height: AppConstants.spaceM),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: const Icon(Icons.email_rounded, color: AppTheme.primaryBlue),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) => val == null || !val.contains('@') ? 'Enter valid email' : null,
                  ),
                  const SizedBox(height: AppConstants.spaceXL),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (!formKey.currentState!.validate()) return;
                        setState(() {
                          _displayName = titleCtrl.text.trim();
                          _email = emailCtrl.text.trim();
                        });
                        Navigator.pop(sheetCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Profile details updated! ✨'),
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

  // 2. Notifications Toggle Sheet
  void _showNotificationsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Container(
              padding: const EdgeInsets.all(AppConstants.spaceL),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                    title: const Text('Push Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Alerts about active trips and schedules', style: TextStyle(fontSize: 12)),
                    value: _pushNotifications,
                    activeColor: AppTheme.primaryBlue,
                    onChanged: (val) {
                      setLocalState(() => _pushNotifications = val);
                      setState(() => _pushNotifications = val);
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Email Marketing Alerts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Deals, promos, and destination recommendations', style: TextStyle(fontSize: 12)),
                    value: _emailUpdates,
                    activeColor: AppTheme.primaryBlue,
                    onChanged: (val) {
                      setLocalState(() => _emailUpdates = val);
                      setState(() => _emailUpdates = val);
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Weekly Digest', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Weekly summaries of shared trip memories', style: TextStyle(fontSize: 12)),
                    value: _weeklyDigest,
                    activeColor: AppTheme.primaryBlue,
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
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Container(
              padding: const EdgeInsets.all(AppConstants.spaceL),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                          color: isSelected ? AppTheme.primaryBlue : AppTheme.textPrimaryLight,
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
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Container(
              padding: const EdgeInsets.all(AppConstants.spaceL),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                          color: isSelected ? AppTheme.primaryBlue : AppTheme.textPrimaryLight,
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
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(AppConstants.spaceL),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                      const Text(
                        'Frequently Asked Questions',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimaryLight),
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
                              child: Text(faq['a']!, style: const TextStyle(fontSize: 12, height: 1.5, color: AppTheme.textSecondaryLight)),
                            ),
                          ],
                        ),
                      )).toList(),
                      const SizedBox(height: AppConstants.spaceL),
                      const Divider(),
                      const SizedBox(height: AppConstants.spaceL),
                      const Text(
                        'Still Need Help? Contact Us',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimaryLight),
                      ),
                      const SizedBox(height: AppConstants.spaceM),
                      TextField(
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Enter your inquiry here... Our support team replies within 24 hours!',
                          hintStyle: const TextStyle(fontSize: 12),
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
                children: const [
                  Text('Last Updated: May 2026\n', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  Text(
                    '1. Data Collection\nWe respect your digital boundaries. Lakbay+ securely collects trip specifications, preferences, and names solely to generate custom travel itineraries using Gemini AI model processors. Your private communication details are never shared with advertising third-parties.',
                    style: TextStyle(fontSize: 12, height: 1.5, color: AppTheme.textSecondaryLight),
                  ),
                  SizedBox(height: AppConstants.spaceM),
                  Text(
                    '2. Offline Data Storage\nAll trip records, photo albums, and schedule markers are stored securely in local database tables. This assures offline accessibility and limits cloud leaks.',
                    style: TextStyle(fontSize: 12, height: 1.5, color: AppTheme.textSecondaryLight),
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
                const Text('Your Premium Travel AI Companion', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryLight)),
                const SizedBox(height: AppConstants.spaceM),
                const Divider(),
                const SizedBox(height: AppConstants.spaceM),
                const Text(
                  'Version 1.2.4 (Build 4122)\nDeveloped by Lakbay Tech Labs.\nGoogle DeepMind pair-programmed architecture.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, height: 1.5, color: Colors.grey),
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

  @override
  Widget build(BuildContext context) {
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
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined, color: Colors.white70),
                        onPressed: () => _showEditProfileSheet(context),
                      ),
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
                          child: Image.network(user.avatarUrl, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppTheme.secondaryGreen.withOpacity(0.2),
                              child: const Icon(Icons.person, size: 48, color: Colors.white),
                            )),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Camera roll connection is simulated! 📷'),
                                backgroundColor: AppTheme.secondaryGreen,
                              ),
                            );
                          },
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryGreen,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.edit_rounded, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spaceM),
                  Text(_displayName, style: GoogleFonts.outfit(
                    fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text(_email, style: const TextStyle(color: Colors.white60, fontSize: 13)),
                  const SizedBox(height: AppConstants.spaceL),
                  const SizedBox(height: AppConstants.spaceM),
                  // Premium stats box
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: AppConstants.spaceM, horizontal: AppConstants.spaceS),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(AppConstants.radiusXL),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('${user.completedTripsCount}', 'Trips', Icons.flight_takeoff_rounded),
                        _divider(),
                        _buildStatItem('${user.visitedDestinationsCount}', 'Destinations', Icons.place_rounded),
                        _divider(),
                        _buildStatItem('${user.visitedProvincesCount}', 'Provinces', Icons.map_rounded),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Travel preferences
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spaceL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Travel Preferences', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                  const SizedBox(height: AppConstants.spaceM),
                  PreferenceSelector(
                    options: ['Nature', 'Beach', 'Mountain', 'Food & Culture', 'Adventure', 'Luxury'],
                    selected: _selectedPrefs,
                    onToggle: (p) => setState(() =>
                      _selectedPrefs.contains(p) ? _selectedPrefs.remove(p) : _selectedPrefs.add(p)),
                  ),
                  const SizedBox(height: AppConstants.spaceXL),
                  Text('Settings', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                  const SizedBox(height: AppConstants.spaceM),
                ],
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
                      color: AppTheme.primaryBlue.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item['icon'] as IconData, color: AppTheme.primaryBlue, size: 20),
                    clipBehavior: Clip.antiAlias,
                  ),
                  title: Text(item['label'] as String, style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 15)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textSecondaryLight),
                  onTap: () {
                    switch (item['label'] as String) {
                      case 'Edit Profile':
                        _showEditProfileSheet(context);
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

          // Logout
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spaceXL),
              child: CustomButton(
                label: 'Sign Out',
                onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
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
