import 'package:flutter/material.dart';
import 'chat_home_screen.dart'; // your chat list file
import 'chat_screen.dart';      // your chat messages view file

class ResponsiveChatDashboard extends StatefulWidget {
  const ResponsiveChatDashboard({super.key});

  @override
  State<ResponsiveChatDashboard> createState() => _ResponsiveChatDashboardState();
}

class _ResponsiveChatDashboardState extends State<ResponsiveChatDashboard> {
  String? _selectedChatId;
  String? _selectedChatName;
  String? _selectedOtherUserId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Breakpoint where split-screen makes design sense
        final bool isWideScreen = constraints.maxWidth >= 800;

        if (!isWideScreen) {
          // Mobile Mode: Render standard single-column list view
          return const ChatHomeScreen();
        }

        // WhatsApp Web Mode: Multi-Pane Split View
        return Scaffold(
          body: Row(
            children: [
              // Left Column: Chat Preview Panel (Fixed Width)
              SizedBox(
                width: 380,
                child: ChatHomeScreen(
                  onChatSelected: (id, name, otherUser) {
                    setState(() {
                      _selectedChatId = id;
                      _selectedChatName = name;
                      _selectedOtherUserId = otherUser;
                    });
                  },
                ),
              ),

              // Vertical Divider Line between lists and active conversations
              VerticalDivider(width: 1, thickness: 1, color: theme.dividerColor.withOpacity(0.4)),

              // Right Column: Dynamic Message Display Window
              Expanded(
                child: _selectedChatId != null
                    ? KeyedSubtree(
                  key: ValueKey(_selectedChatId), // Clear text controllers and reload stream on swap
                  child: ChatScreen(
                    chatId: _selectedChatId!,
                    chatName: _selectedChatName,
                    otherUserId: _selectedOtherUserId,
                    isCompactMode: true, // Disables mobile appbar features if needed
                  ),
                )
                    : Container(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.laptop_mac_outlined,
                          size: 80,
                          color: theme.disabledColor.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Select a conversation to start messaging',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.disabledColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}