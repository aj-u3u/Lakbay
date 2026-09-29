import 'package:flutter/material.dart';

class LanguageProvider extends ChangeNotifier {
  String _currentLanguage = 'English';

  String get currentLanguage => _currentLanguage;

  void setLanguage(String language) {
    if (_currentLanguage != language) {
      _currentLanguage = language;
      notifyListeners();
    }
  }

  // A simple dictionary for translations
  static const Map<String, Map<String, String>> _translations = {
    'English': {
      'My Wishlist': 'My Wishlist',
      'Edit Profile': 'Edit Profile',
      'Change Password': 'Change Password',
      'Notifications': 'Notifications',
      'Language': 'Language',
      'Appearance': 'Appearance',
      'Help & Support': 'Help & Support',
      'Privacy Policy': 'Privacy Policy',
      'About Lakbay+': 'About Lakbay+',
      'Select App Language': 'Select App Language',
      'Push Notifications': 'Push Notifications',
      'Email Updates': 'Email Updates',
      'Weekly Digest': 'Weekly Digest',
      'Log Out': 'Log Out',
    },
    'Filipino': {
      'My Wishlist': 'Aking Wishlist',
      'Edit Profile': 'I-edit ang Profile',
      'Change Password': 'Palitan ang Password',
      'Notifications': 'Mga Abiso',
      'Language': 'Wika',
      'Appearance': 'Hitsura',
      'Help & Support': 'Tulong at Suporta',
      'Privacy Policy': 'Patakaran sa Privacy',
      'About Lakbay+': 'Tungkol sa Lakbay+',
      'Select App Language': 'Piliin ang Wika ng App',
      'Push Notifications': 'Mga Push Notification',
      'Email Updates': 'Mga Update sa Email',
      'Weekly Digest': 'Lingguhang Buod',
      'Log Out': 'Mag-log Out',
    },
  };

  String translate(String key) {
    return _translations[_currentLanguage]?[key] ?? key;
  }
}
