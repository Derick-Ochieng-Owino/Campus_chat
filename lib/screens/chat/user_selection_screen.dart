import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UserSelectionScreen extends StatefulWidget {
  const UserSelectionScreen({super.key});

  @override
  State<UserSelectionScreen> createState() => _UserSelectionScreenState();
}

class _UserSelectionScreenState extends State<UserSelectionScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  Map<String, dynamic>? _currentUserData;
  String _searchQuery = '';
  List<DocumentSnapshot> _userDocs = [];
  bool _isLoading = true;
  bool _hasMore = true;
  final int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    // 1. Fetch current user data to grab course, year, and DP for the "You" tile
    final doc = await _firestore.collection('users').doc(_currentUserId).get();
    if (mounted && doc.exists) {
      _currentUserData = doc.data();
    }
    // 2. Fetch the initial list of course-mates
    await _fetchUsers(isRefresh: true);
  }

  Future<void> _fetchUsers({bool isRefresh = false}) async {
    if ((!_hasMore && !isRefresh) || _currentUserData == null) return;

    setState(() => _isLoading = true);

    if (isRefresh) {
      _userDocs.clear();
      _hasMore = true;
    }

    Query query = _firestore.collection('users');

    if (_searchQuery.isNotEmpty) {
      // GLOBAL SEARCH: Ignore course/year, search entire database by name
      query = query
          .orderBy('first_name')
          .startAt([_searchQuery])
          .endAt(['$_searchQuery\uf8ff'])
          .limit(_pageSize);
    } else {
      // PEER VIEW: Filter by the current user's specific course and year
      final String course = _currentUserData?['course'] ?? '';
      final String year = _currentUserData?['year'] ?? '';

      query = query
          .where('course', isEqualTo: course)
          .where('year', isEqualTo: year)
          .orderBy('first_name')
          .limit(_pageSize);
    }

    if (!isRefresh && _userDocs.isNotEmpty) {
      query = query.startAfterDocument(_userDocs.last);
    }

    final snapshot = await query.get();

    if (mounted) {
      setState(() {
        _isLoading = false;
        // Filter out the current user from the main query list to avoid duplicates
        final newDocs = snapshot.docs.where((doc) => doc.id != _currentUserId).toList();
        _userDocs.addAll(newDocs);

        if (snapshot.docs.length < _pageSize) {
          _hasMore = false;
        }
      });
    }
  }

  // Helper widget to create the rounded square avatar
  Widget _buildRoundedSquareAvatar(String photoUrl, String name, ThemeData theme) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12), // Rounded square corner radius
      ),
      clipBehavior: Clip.antiAlias,
      child: photoUrl.isNotEmpty
          ? Image.network(photoUrl, fit: BoxFit.cover)
          : Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
    );
  }

  // WhatsApp-style "Message Yourself" tile
  Widget _buildSelfTile(ThemeData theme) {
    final name = '${_currentUserData?['first_name'] ?? ''} ${_currentUserData?['last_name'] ?? ''}'.trim();
    final photoUrl = _currentUserData?['profile_photo_url'] ?? '';

    return RepaintBoundary(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          alignment: Alignment.bottomRight,
          children: [
            _buildRoundedSquareAvatar(photoUrl, name, theme),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.bookmark, size: 14, color: theme.colorScheme.primary),
            ),
          ],
        ),
        title: Text(
          '$name (You)',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Message yourself',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.disabledColor),
        ),
        onTap: () => Navigator.pop(context, _currentUserId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Calculate total items (Self Tile + Users + Loading Indicator)
    int itemCount = _userDocs.length;
    final bool showSelfTile = _searchQuery.isEmpty && _currentUserData != null;

    if (showSelfTile) itemCount += 1;
    if (_isLoading && _currentUserData == null) {
      itemCount = 1; // Only show main loading spinner if completely blank
    } else if (_isLoading) {
      itemCount += 1; // Bottom pagination loader
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        title: const Text(
          'Select contact',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Search names or courses...',
                hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.7)),
                prefixIcon: Icon(Icons.search, color: colorScheme.primary),
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (val) {
                _searchQuery = val.trim();
                _fetchUsers(isRefresh: true);
              },
            ),
          ),
        ),
      ),
      body: _currentUserData == null && _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
            _fetchUsers();
          }
          return false;
        },
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            int dataIndex = index;

            // Handle the injection of the "You" tile at index 0
            if (showSelfTile) {
              if (index == 0) return _buildSelfTile(theme);
              dataIndex -= 1;
            }

            // Handle the pagination loader at the bottom of the list
            if (dataIndex == _userDocs.length) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator.adaptive()),
              );
            }

            // Render Peer Tiles
            final data = _userDocs[dataIndex].data() as Map<String, dynamic>;
            final userId = _userDocs[dataIndex].id;
            final name = '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim();
            final photoUrl = data['profile_photo_url'] ?? '';
            final userCourse = data['course'] ?? 'Student';
            final userYear = data['year'] ?? '';

            return RepaintBoundary(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: _buildRoundedSquareAvatar(photoUrl, name, theme),
                title: Text(
                  name.isNotEmpty ? name : 'Unknown User',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '$userCourse • $userYear',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.disabledColor),
                ),
                onTap: () => Navigator.pop(context, userId),
              ),
            );
          },
        ),
      ),
    );
  }
}