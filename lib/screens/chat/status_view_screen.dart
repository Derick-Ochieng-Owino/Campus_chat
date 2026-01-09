import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StatusViewScreen extends StatefulWidget {
  final List<List<Map<String, dynamic>>> groupedStatuses;
  final int initialUserIndex;

  const StatusViewScreen({
    super.key,
    required this.groupedStatuses,
    required this.initialUserIndex,
  });

  @override
  State<StatusViewScreen> createState() => _StatusViewScreenState();
}

class _StatusViewScreenState extends State<StatusViewScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialUserIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextUser() {
    if (_pageController.page!.toInt() < widget.groupedStatuses.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context); // Close if no more users
    }
  }

  void _previousUser() {
    if (_pageController.page!.toInt() > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context); // Close if at start
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.groupedStatuses.length,
        itemBuilder: (context, index) {
          return UserStoryPage(
            userStatuses: widget.groupedStatuses[index],
            onComplete: _nextUser,
            onPreviousUser: _previousUser,
          );
        },
      ),
    );
  }
}

class UserStoryPage extends StatefulWidget {
  final List<Map<String, dynamic>> userStatuses;
  final VoidCallback onComplete;
  final VoidCallback onPreviousUser;

  const UserStoryPage({
    super.key,
    required this.userStatuses,
    required this.onComplete,
    required this.onPreviousUser,
  });

  @override
  State<UserStoryPage> createState() => _UserStoryPageState();
}

class _UserStoryPageState extends State<UserStoryPage> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // 5 seconds per story
    _animController = AnimationController(vsync: this, duration: const Duration(seconds: 5));
    _loadStory();
  }

  void _loadStory() {
    _animController.stop();
    _animController.reset();
    _animController.forward().whenComplete(_onTimerComplete);
  }

  void _onTimerComplete() {
    _nextStory();
  }

  void _nextStory() {
    if (_currentIndex < widget.userStatuses.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _loadStory();
    } else {
      // Finished all stories for this user, go to next user
      widget.onComplete();
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _loadStory();
    } else {
      // At first story, go to previous user
      widget.onPreviousUser();
    }
  }

  void _onTapDown(TapDownDetails details) {
    _animController.stop();
  }

  void _onTapUp(TapUpDetails details) {
    _animController.forward();

    final screenWidth = MediaQuery.of(context).size.width;
    final dx = details.globalPosition.dx;

    // Tap Left (First 25% of screen) -> Previous
    if (dx < screenWidth * 0.25) {
      _previousStory();
    } else {
      // Tap Right (Rest of screen) -> Next
      _nextStory();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.userStatuses[_currentIndex];
    final mediaUrl = status['mediaUrl'] as String?;
    final content = status['content'] ?? '';
    final createdAt = (status['createdAt'] as Timestamp?)?.toDate();
    final timeString = createdAt != null
        ? "${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}"
        : "";

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      // We don't handle horizontal drag so PageView can handle the user swipe
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. BACKGROUND / MEDIA
          Container(
            color: Colors.black,
            child: Center(
              child: mediaUrl != null
                  ? Image.network(
                mediaUrl,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return const CircularProgressIndicator();
                },
              )
                  : Container(
                color: Colors.blueGrey.shade900,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(30),
                child: Text(
                  content,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontFamily: 'sans-serif-light',
                  ),
                ),
              ),
            ),
          ),

          // 2. GRADIENT TEXT OVERLAY (If image exists)
          if (mediaUrl != null && content.isNotEmpty)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 60, 16, 40),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      content,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    const Icon(Icons.keyboard_arrow_up, color: Colors.white70),
                  ],
                ),
              ),
            ),

          // 3. PROGRESS BARS (Top)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10, right: 10,
            child: Row(
              children: List.generate(widget.userStatuses.length, (index) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: SizedBox(
                        height: 4,
                        child: _buildProgressBar(index),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          // 4. USER INFO HEADER
          Positioned(
            top: MediaQuery.of(context).padding.top + 25,
            left: 16,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    (status['createdByName'] ?? 'A')[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status['createdByName'] ?? 'Admin',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      timeString,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(int index) {
    if (index < _currentIndex) {
      // Previous story - Full
      return Container(color: Colors.white);
    } else if (index == _currentIndex) {
      // Current story - Animated
      return AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          return LinearProgressIndicator(
            value: _animController.value,
            valueColor: const AlwaysStoppedAnimation(Colors.white),
            backgroundColor: Colors.white24,
          );
        },
      );
    } else {
      // Future story - Empty
      return Container(color: Colors.white24);
    }
  }
}