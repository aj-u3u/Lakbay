import 'package:flutter/material.dart';
import '../main.dart';
import '../widgets/admin_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => AdminPage(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AdminPageHeader(
          title: 'Appearance',
          description: 'Choose a comfortable theme for your admin workspace.',
        ),
        const SizedBox(height: 24),
        AdminPanel(
          child: ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (context, mode, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Workspace theme',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text('Your preference is saved on this browser.'),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final choice in const [
                      (ThemeMode.light, 'Light', Icons.light_mode_outlined),
                      (ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
                      (
                        ThemeMode.system,
                        'System',
                        Icons.brightness_auto_outlined,
                      ),
                    ])
                      ChoiceChip(
                        label: Text(choice.$2),
                        avatar: Icon(choice.$3, size: 18),
                        selected: mode == choice.$1,
                        onSelected: (_) => setAdminTheme(choice.$1),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
