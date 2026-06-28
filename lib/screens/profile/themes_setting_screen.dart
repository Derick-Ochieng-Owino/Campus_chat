// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/theme_provider.dart';
//
// class ThemeSettingsScreen extends StatelessWidget {
//   const ThemeSettingsScreen({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     final themeProvider = Provider.of<ThemeProvider>(context);
//
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Theme Settings'),
//         elevation: 0,
//       ),
//       body: ListView(
//         padding: const EdgeInsets.all(16.0),
//         children: [
//           Text(
//             'Select App Color Scheme',
//             style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
//           ),
//           const Divider(height: 30),
//
//           ...themeProvider.availableThemes.map((themeName) {
//             final isSelected = themeName == themeProvider.currentThemeName;
//             final themeData = themeProvider.themeData; // Use the currently applied theme for context
//
//             return Card(
//               // Use theme colors for visual preview
//               color: isSelected ? themeData.colorScheme.secondary.withOpacity(0.1) : themeData.cardColor,
//               margin: const EdgeInsets.only(bottom: 12),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(12),
//                 side: BorderSide(
//                   color: isSelected ? themeData.colorScheme.secondary : Colors.transparent,
//                   width: 2,
//                 ),
//               ),
//               child: ListTile(
//                 leading: CircleAvatar(
//                   backgroundColor: themeData.colorScheme.secondary,
//                   child: Icon(
//                     Icons.color_lens_rounded,
//                     color: isSelected ? themeData.colorScheme.onSecondary : Colors.white,
//                   ),
//                 ),
//                 title: Text(
//                   themeName,
//                   style: TextStyle(
//                     fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
//                     color: isSelected ? themeData.colorScheme.secondary : themeData.colorScheme.onSurface,
//                   ),
//                 ),
//                 trailing: isSelected
//                     ? Icon(Icons.check_circle, color: themeData.colorScheme.secondary)
//                     : null,
//                 onTap: () {
//                   themeProvider.setTheme(themeName);
//                 },
//               ),
//             );
//           }).toList(),
//         ],
//       ),
//     );
//   }
// }
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('App Color Themes'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 16),
            child: Text('Select App Color Scheme', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
          ...themeProvider.availableThemes.map((themeName) {
            final isSelected = themeName == themeProvider.currentThemeName;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all( // Use Border.all here
                  color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                color: isSelected ? theme.colorScheme.primaryContainer.withOpacity(0.3) : theme.colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                    child: Icon(Icons.color_lens_rounded, color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface),
                  ),
                  title: Text(themeName, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  trailing: isSelected ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary) : null,
                  onTap: () => themeProvider.setTheme(themeName),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}