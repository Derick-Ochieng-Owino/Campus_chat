import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../widgets/loading_widget.dart';
import '../chat/user_selection_screen.dart';
import 'chat_screen.dart';

// Key for SharedPreferences caching
const String _CACHE_KEY = 'cached_chat_list';
const String _STATUS_VIEWS_KEY = 'status_views_cache';

class ChatHomeScreen extends StatefulWidget {
  const ChatHomeScreen({super.key});

  @override
  State<ChatHomeScreen> createState() => _ChatHomeScreenState();
}

class _ChatHomeScreenState extends State<ChatHomeScreen> with AutomaticKeepAliveClientMixin<ChatHomeScreen> {
  @override
  bool get wantKeepAlive => true;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();
  final Uuid _uuid = Uuid();

  String? _currentUserId;
  String? _currentUserRole;
  String? _currentUserName;

  // State to hold live stream data
  Stream<QuerySnapshot>? _chatStream;
  Stream<QuerySnapshot>? _statusStream;

  // State to hold cached map data while waiting for the stream
  List<Map<String, dynamic>>? _cachedChatMaps;

  // State for status stories
  Map<String, int> _statusViewCounts = {};
  Map<String, bool> _statusViewedByUser = {};

  // State to hold specific groups the user belongs to (Subdivided chats)
  List<Map<String, dynamic>> _userSpecificGroups = [];
  Map<String, String> _userNameCache = {};
  bool _userNameCachePreloaded = false;

  // Timer for status refresh
  Timer? _statusRefreshTimer;

  // Image picking state
  XFile? _selectedImage;
  bool _isUploadingImage = false;
  String? _mediaUrl;

  @override
  void initState() {
    super.initState();
    _loadUserProfileAndCache();
  }

  @override
  void dispose() {
    _statusRefreshTimer?.cancel();
    super.dispose();
  }

  void _setupStatusRefreshTimer() {
    // Refresh status every 5 minutes
    _statusRefreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted) {
        _checkStatusAvailability();
      }
    });
  }

  void _debugStatusInfo(AsyncSnapshot<QuerySnapshot> statusSnap) {
    debugPrint('=== STATUS DEBUG INFO ===');
    debugPrint('Connection state: ${statusSnap.connectionState}');
    debugPrint('Has data: ${statusSnap.hasData}');
    debugPrint('Has error: ${statusSnap.hasError}');
    if (statusSnap.hasError) {
      debugPrint('Error: ${statusSnap.error}');
    }
    if (statusSnap.hasData) {
      debugPrint('Number of documents: ${statusSnap.data!.docs.length}');
      for (var doc in statusSnap.data!.docs) {
        final data = doc.data() as Map<String, dynamic>;
        debugPrint('Status ${doc.id}: ${data['content']}');
        debugPrint('  - expiresAt: ${data['expiresAt']}');
        debugPrint('  - reachLimit: ${data['reachLimit']}');
        debugPrint('  - type: ${data['type']}');
        debugPrint('  - mediaUrl: ${data['mediaUrl']}');
      }
    }
    debugPrint('=== END DEBUG INFO ===');
  }

  void _createTestStatusManually() async {
    try {
      debugPrint('=== CREATING TEST STATUS MANUALLY ===');

      final expiresAt = DateTime.now().add(const Duration(hours: 24));
      debugPrint('Expires at: $expiresAt');

      final docRef = await _firestore.collection('statuses').add({
        'content': 'TEST STATUS - This is a test ad',
        'createdBy': _currentUserId,
        'createdByName': _currentUserName ?? 'Test Admin',
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'reachLimit': 300,
        'type': 'ad',
        'mediaUrl': null,
      });

      debugPrint('Test status created with ID: ${docRef.id}');
      debugPrint('=== TEST STATUS CREATED ===');

      // Refresh the stream
      _setupStatusStream();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test status created: ${docRef.id}'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      debugPrint('Error creating test status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _checkFirestoreAccess() async {
    try {
      debugPrint('=== CHECKING FIRESTORE ACCESS ===');

      // Try to read statuses
      final snapshot = await _firestore.collection('statuses').limit(1).get();
      debugPrint('Can read statuses: ${snapshot.docs.length} documents found');

      // Try to read users
      final userSnapshot = await _firestore.collection('users').doc(_currentUserId).get();
      debugPrint('Can read user document: ${userSnapshot.exists}');
      if (userSnapshot.exists) {
        debugPrint('User role: ${userSnapshot.data()?['role']}');
      }

      debugPrint('=== FIRESTORE ACCESS CHECK COMPLETE ===');

    } catch (e) {
      debugPrint('Firestore access error: $e');
    }
  }

  // --- CACHING & DATA LOADING ---
  Future<void> _loadUserProfileAndCache() async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('No user logged in');
      return;
    }

    _currentUserId = user.uid;
    debugPrint('Loading profile for user: $_currentUserId');

    try {
      // 1. Load User Data
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        debugPrint('User document does not exist');
        return;
      }

      final data = doc.data();
      if (data == null) {
        debugPrint('User data is null');
        return;
      }

      final userData = data as Map<String, dynamic>;

      setState(() {
        _currentUserRole = userData['role'] as String?;
        _currentUserName = userData['name'] as String?;
      });

      debugPrint('User role: $_currentUserRole, name: $_currentUserName');

      // 2. Load Cache Immediately
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_CACHE_KEY);
      if (cachedJson != null) {
        try {
          final List<dynamic> list = jsonDecode(cachedJson);
          setState(() {
            _cachedChatMaps = list.cast<Map<String, dynamic>>();
          });
          debugPrint('Loaded ${_cachedChatMaps!.length} cached chats');
        } catch (e) {
          debugPrint("Error loading chat cache: $e");
        }
      }

      // 3. Setup General Course Chat, Load Groups, and Initialize Live Stream
      await _ensureGeneralCourseChat(userData);
      await _loadUserSpecificGroups(userData['groupId'] as String?, userData['subdivision'] as String?);

      // 4. Setup streams
      _setupStream();
      _setupStatusStream();

      // 5. Setup timer
      _setupStatusRefreshTimer();

      // 6. Load status view counts from cache
      await _loadStatusViewCounts();

    } catch (e) {
      debugPrint("Error in _loadUserProfileAndCache: $e");
    }
  }

  void _setupStream() {
    final isAdmin = _currentUserRole == 'admin';
    Query query = _firestore.collection('chats');

    if (isAdmin) {
      query = query.where('type', whereIn: ['group', 'general']).orderBy('lastMessageAt', descending: true);
    } else {
      query = query.where('participants', arrayContains: _currentUserId).orderBy('lastMessageAt', descending: true);
    }

    setState(() {
      _chatStream = query.snapshots().map((snapshot) {
        _saveCache(snapshot.docs);
        return snapshot;
      });
    });
  }

  void _setupStatusStream() {
    debugPrint('Setting up status stream...');

    if (_currentUserId == null) {
      debugPrint('Cannot setup status stream: currentUserId is null');
      return;
    }

    try {
      final now = DateTime.now();

      debugPrint('Current time: $now');
      debugPrint('Looking for statuses expiring after: $now');

      Query query = _firestore
          .collection('statuses')
          .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
          .orderBy('expiresAt', descending: true);

      setState(() {
        _statusStream = query.snapshots().handleError((error) {
          debugPrint('Error in status stream: $error');
        });
      });

      debugPrint('Status stream setup complete');

      // Test the query
      query.get().then((snapshot) {
        debugPrint('Test query found ${snapshot.docs.length} statuses');
      }).catchError((error) {
        debugPrint('Test query error: $error');
      });

    } catch (e) {
      debugPrint('Error setting up status stream: $e');
    }
  }

  Future<void> _loadStatusViewCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final viewsJson = prefs.getString(_STATUS_VIEWS_KEY);

    if (viewsJson != null) {
      try {
        final Map<String, dynamic> viewsMap = jsonDecode(viewsJson);
        setState(() {
          _statusViewedByUser = Map<String, bool>.from(viewsMap);
        });
      } catch (e) {
        debugPrint("Error loading status views cache: $e");
      }
    }
  }

  Future<void> _saveStatusViewsCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_STATUS_VIEWS_KEY, jsonEncode(_statusViewedByUser));
  }

  Future<void> _incrementStatusView(String statusId, String userId) async {
    if (_statusViewedByUser.containsKey('${statusId}_$userId')) {
      return;
    }

    final statusRef = _firestore.collection('statuses').doc(statusId);
    final viewersRef = statusRef.collection('viewers');

    await _firestore.runTransaction((transaction) async {
      final countDoc = await transaction.get(viewersRef.doc('count'));
      final currentCount = countDoc.data()?['count'] as int? ?? 0;

      transaction.set(
        viewersRef.doc('count'),
        {'count': currentCount + 1},
        SetOptions(merge: true),
      );

      transaction.set(
        viewersRef.doc(userId),
        {'viewedAt': FieldValue.serverTimestamp()},
      );
    });

    _statusViewedByUser['${statusId}_$userId'] = true;
    await _saveStatusViewsCache();

    final currentCount = _statusViewCounts[statusId] ?? 0;
    _statusViewCounts[statusId] = currentCount + 1;
  }

  Future<void> _checkStatusAvailability() async {
    if (_statusStream == null) return;
    _setupStatusStream();
  }

  Future<void> _saveCache(List<QueryDocumentSnapshot> docs) async {
    final prefs = await SharedPreferences.getInstance();

    final serializableList = docs.map((doc) {
      final dataMap = doc.data() as Map<String, dynamic>? ?? {};

      final cleanedMap = dataMap.map((key, value) {
        if (value is Timestamp) {
          return MapEntry(key, value.toDate().toIso8601String());
        }
        return MapEntry(key, value);
      });

      return {'id': doc.id, ...cleanedMap};
    }).toList();

    await prefs.setString(_CACHE_KEY, jsonEncode(serializableList));
  }

  // --- IMAGE PICKING AND UPLOAD ---
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = pickedFile;
          _mediaUrl = null; // Clear any existing URL when new image is selected
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _uploadImageToFirebase(File imageFile) async {
    try {
      setState(() {
        _isUploadingImage = true;
      });

      final fileName = 'status_images/${_uuid.v4()}.jpg';
      final Reference storageRef = _storage.ref().child(fileName);

      final UploadTask uploadTask = storageRef.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final TaskSnapshot snapshot = await uploadTask.whenComplete(() => null);
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        _isUploadingImage = false;
      });

      return downloadUrl;
    } catch (e) {
      debugPrint("Error uploading image: $e");
      setState(() {
        _isUploadingImage = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _removeSelectedImage() async {
    setState(() {
      _selectedImage = null;
      _mediaUrl = null;
    });
  }

  // --- GROUP LOGIC ---
  Future<void> _ensureGeneralCourseChat(Map<String, dynamic> user) async {
    final course = user['course'] ?? 'default';
    final year = user['year_key'] ?? 'year1';
    final semester = user['semester_key'] ?? 'semester1';

    final chatId = 'course_${course}_${year}_${semester}';

    final ref = _firestore.collection('chats').doc(chatId);
    final doc = await ref.get();

    if (!doc.exists) {
      await ref.set({
        'name': 'General Course Chat',
        'type': 'general',
        'participants': [_currentUserId],
        'lastMessage': "Welcome to the course chat!",
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
    } else {
      if (!(doc.data()?['participants'] ?? []).contains(_currentUserId)) {
        await ref.update({
          'participants': FieldValue.arrayUnion([_currentUserId])
        });
      }
    }
  }

  void _preloadUserNames(List<Map<String, dynamic>> chatDataList) {
    final unknownUids = <String>{};

    for (var chat in chatDataList) {
      final type = chat['type'] ?? 'dm';
      if (type != 'dm') continue;

      final participants = (chat['participants'] ?? []).cast<String>();
      final otherUid = participants.firstWhere((id) => id != _currentUserId, orElse: () => '');
      if (otherUid.isNotEmpty && !_userNameCache.containsKey(otherUid)) {
        unknownUids.add(otherUid);
      }
    }

    if (unknownUids.isEmpty) return;

    for (var uid in unknownUids) {
      _firestore.collection('users').doc(uid).get().then((doc) {
        if (doc.exists) {
          final name = (doc.data()?['nickname'] ?? doc.data()?['name'] ?? uid) as String;
          _userNameCache[uid] = name;
          if (mounted) setState(() {});
        }
      });
    }
  }

  Future<void> _loadUserSpecificGroups(String? groupId, String? subdivision) async {
    if (groupId == null) {
      setState(() => _userSpecificGroups = []);
      return;
    }

    try {
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      final groupName = groupDoc.data()?['name'] ?? 'Group';

      final List<Map<String, dynamic>> chats = [];
      final Map<String, dynamic>? groupData = groupDoc.data();

      if (groupData == null) {
        setState(() => _userSpecificGroups = []);
        return;
      }

      final List<Map<String, dynamic>> membersA =
          (groupData['A'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

      final List<Map<String, dynamic>> membersB =
          (groupData['B'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

      final List<String> uidsA = membersA.map((m) => m['uid'] as String).toList();
      final List<String> uidsB = membersB.map((m) => m['uid'] as String).toList();

      final List<String> allGroupUids = [
        ...uidsA,
        ...uidsB,
      ];

      chats.add({
        'name': '$groupName (General)',
        'type': 'group',
        'chatId': '${groupId}_general',
        'participants': allGroupUids,
      });

      if (subdivision == 'A' || _currentUserRole == 'admin') {
        chats.add({
          'name': '$groupName (A)',
          'type': 'group',
          'chatId': '${groupId}_A',
          'subdivision': 'A',
          'participants': uidsA,
        });
      }

      if (subdivision == 'B' || _currentUserRole == 'admin') {
        chats.add({
          'name': '$groupName (B)',
          'type': 'group',
          'chatId': '${groupId}_B',
          'subdivision': 'B',
          'participants': uidsB,
        });
      }

      setState(() {
        _userSpecificGroups = chats;
      });

    } catch (e) {
      debugPrint("Error loading specific groups: $e");
      setState(() => _userSpecificGroups = []);
    }
  }

  // --- STATUS/STORY FUNCTIONS ---
  void _viewStatus(BuildContext context, Map<String, dynamic> status) async {
    final statusId = status['id'];
    final content = status['content'] ?? '';
    final mediaUrl = status['mediaUrl'] as String?;
    final reachLimit = status['reachLimit'] as int?;
    final currentViews = _statusViewCounts[statusId] ?? 0;

    if (reachLimit != null && currentViews >= reachLimit) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('This ad has reached its maximum views'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _StatusViewerDialog(
        status: status,
        mediaUrl: mediaUrl,
        content: content,
        isAdmin: _currentUserRole == 'admin',
        viewCount: currentViews,
        reachLimit: reachLimit,
        onViewComplete: () async {
          if (_currentUserId != null) {
            await _incrementStatusView(statusId, _currentUserId!);
            if (mounted) setState(() {});
          }
        },
      ),
    );
  }

  Widget _buildStatusItem(BuildContext context, Map<String, dynamic> status) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusId = status['id'];
    final content = status['content'] ?? '';
    final mediaUrl = status['mediaUrl'] as String?;
    final hasViewed = _statusViewedByUser.containsKey('${statusId}_$_currentUserId');

    // Expiration logic...
    final isExpired = (status['expiresAt'] as Timestamp?)?.toDate().isBefore(DateTime.now()) ?? false;
    if (isExpired) return const SizedBox();

    return GestureDetector(
      onTap: () => _viewStatus(context, status),
      child: Container(
        width: 76, // Fixed width constraints
        margin: const EdgeInsets.symmetric(horizontal: 4), // Tighter spacing like WhatsApp
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // Center vertically
          children: [
            // 1. The Ring + Image
            Container(
              padding: const EdgeInsets.all(2), // Space between ring and image
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  // WhatsApp uses grey for viewed, green (your primary) for new
                  color: hasViewed ? theme.dividerColor : colorScheme.primary,
                  width: 2,
                ),
              ),
              child: Container(
                width: 60, // Fixed size
                height: 60,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                clipBehavior: Clip.hardEdge,
                child: mediaUrl != null
                    ? Image.network(
                  mediaUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: colorScheme.surfaceVariant,
                    child: Icon(Icons.broken_image, size: 20, color: colorScheme.onSurfaceVariant),
                  ),
                )
                    : Container(
                  color: colorScheme.primaryContainer, // Colored background for text-only status
                  child: Center(
                    child: Icon(
                      Icons.text_fields_rounded,
                      color: colorScheme.onPrimaryContainer,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 6),

            // 2. The Name/Caption (Truncated)
            Text(
              // Use the creator's name instead of content preview (Standard UX)
              status['createdByName']?.split(' ')[0] ?? 'Admin',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                // Dimmed text for viewed, Bold for new
                color: hasViewed ? theme.textTheme.bodySmall?.color : colorScheme.onSurface,
                fontWeight: hasViewed ? FontWeight.normal : FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // --- CREATE STATUS DIALOG WITH IMAGE UPLOAD ---
  void _showCreateStatusDialog(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String content = '';
    String? mediaUrl;
    int? reachLimit;
    int durationHours = 24;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Create Status/Ad'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Content Text Field
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Content/Message',
                        hintText: 'Enter your ad message here...',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => content = value,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // Image Selection Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Image (Optional)',
                          style: theme.textTheme.bodyMedium!.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Selected Image Preview
                        if (_selectedImage != null)
                          Column(
                            children: [
                              Container(
                                height: 150,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: colorScheme.primary),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(_selectedImage!.path),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => _removeSelectedImage(),
                                    icon: const Icon(Icons.delete, size: 18),
                                    label: const Text('Remove'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.shade50,
                                      foregroundColor: Colors.red,
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () => _pickImageFromGallery(),
                                    icon: const Icon(Icons.change_circle, size: 18),
                                    label: const Text('Change'),
                                  ),
                                ],
                              ),
                            ],
                          )
                        else if (_isUploadingImage)
                          Column(
                            children: [
                              Container(
                                height: 150,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey),
                                ),
                                child: const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(),
                                      SizedBox(height: 8),
                                      Text('Uploading image...'),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: () async {
                              await _pickImageFromGallery();
                              setStateDialog(() {});
                            },
                            icon: const Icon(Icons.image),
                            label: const Text('Pick Image from Gallery'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Reach Limit
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Reach Limit (optional)',
                        hintText: 'e.g., 300 for first 300 users',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          reachLimit = int.tryParse(value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Duration Slider
                    Row(
                      children: [
                        Text('Duration: ', style: theme.textTheme.bodyMedium),
                        Expanded(
                          child: Slider(
                            value: durationHours.toDouble(),
                            min: 1,
                            max: 168,
                            divisions: 167,
                            label: '$durationHours hours',
                            onChanged: (value) {
                              setStateDialog(() {
                                durationHours = value.toInt();
                              });
                            },
                          ),
                        ),
                        Text('${durationHours}h',
                            style: theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    if (reachLimit != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Ad will be shown to first $reachLimit users only',
                          style: theme.textTheme.bodySmall!.copyWith(color: Colors.orange),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _removeSelectedImage();
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isUploadingImage
                      ? null
                      : () async {
                    if (content.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter content')),
                      );
                      return;
                    }

                    String? finalMediaUrl;

                    // Upload image if selected
                    if (_selectedImage != null) {
                      final imageFile = File(_selectedImage!.path);
                      finalMediaUrl = await _uploadImageToFirebase(imageFile);
                      if (finalMediaUrl == null) {
                        // Upload failed
                        return;
                      }
                    }

                    final expiresAt = DateTime.now().add(Duration(hours: durationHours));

                    try {
                      await _firestore.collection('statuses').add({
                        'content': content,
                        'mediaUrl': finalMediaUrl,
                        'reachLimit': reachLimit,
                        'createdBy': _currentUserId,
                        'createdByName': _currentUserName,
                        'createdAt': FieldValue.serverTimestamp(),
                        'expiresAt': Timestamp.fromDate(expiresAt),
                        'type': 'ad',
                      });

                      // Clear selected image after successful creation
                      _removeSelectedImage();

                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Status/Ad created successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      debugPrint('Error creating status: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error creating status: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    disabledBackgroundColor: Colors.grey,
                  ),
                  child: _isUploadingImage
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : const Text('Create', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_currentUserId == null || _chatStream == null) {
      return Center(child: AppLogoLoadingWidget(size: 80));
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Alma Mater Chats"),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.blue),
            tooltip: 'Refresh status stream',
            onPressed: () {
              debugPrint('=== MANUAL REFRESH ===');
              debugPrint('Current user ID: $_currentUserId');
              debugPrint('Current user role: $_currentUserRole');
              debugPrint('Status stream: $_statusStream');
              _setupStatusStream();
              if (mounted) setState(() {});
            },
          ),
          IconButton(
            icon: Icon(Icons.bug_report, color: Colors.orange),
            tooltip: 'Check Firestore access',
            onPressed: _checkFirestoreAccess,
          ),
          if (_currentUserRole == 'admin') ...[
            IconButton(
              icon: Icon(Icons.add, color: Colors.green),
              tooltip: 'Create test status',
              onPressed: _createTestStatusManually,
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Create Status/Ad',
              onPressed: () => _showCreateStatusDialog(context),
            ),
          ],
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _chatStream,
        builder: (context, snap) {
          List<Map<String, dynamic>> chatDataList;

          if (snap.hasData) {
            chatDataList = snap.data!.docs.map((doc) {
              return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
            }).toList();
          } else if (_cachedChatMaps != null) {
            chatDataList = _cachedChatMaps!;
          } else {
            chatDataList = [];
          }

          if (chatDataList.isNotEmpty && !_userNameCachePreloaded) {
            _userNameCachePreloaded = true;
            _preloadUserNames(chatDataList);
          }

          return Column(
            children: [
              // Status/Stories Section
              StreamBuilder<QuerySnapshot>(
                stream: _statusStream,
                builder: (context, statusSnap) {
                  _debugStatusInfo(statusSnap);
                  if (statusSnap.connectionState == ConnectionState.waiting) {
                    return const SizedBox(height: 100);
                  }

                  if (statusSnap.hasData && statusSnap.data!.docs.isNotEmpty) {
                    final statuses = statusSnap.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return {'id': doc.id, ...data};
                    }).toList();

                    return Container(
                      height: 120,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                Text(
                                  "Status & Ads",
                                  style: theme.textTheme.titleMedium!.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "${statuses.length} active",
                                    style: theme.textTheme.bodySmall!.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: statuses.length,
                              itemBuilder: (context, index) {
                                return _buildStatusItem(context, statuses[index]);
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return const SizedBox(height: 16);
                },
              ),

              Divider(color: theme.dividerColor, height: 1),

              // Chats List
              Expanded(
                child: (snap.connectionState == ConnectionState.waiting && chatDataList.isEmpty)
                    ? Center(child: AppLogoLoadingWidget(size: 80))
                    : (chatDataList.isEmpty && _userSpecificGroups.isEmpty)
                    ? Center(child: Text("No chats available", style: theme.textTheme.bodyMedium))
                    : ListView(
                  children: [
                    _buildSectionHeader(context, "Direct Messages & Course Chat", colorScheme.primary),
                    ...chatDataList.map((chatMap) => _buildChatEntry(context, chatMap)).toList(),

                    if (_userSpecificGroups.isNotEmpty) ...[
                      Divider(color: theme.dividerColor, height: 20),
                      _buildSectionHeader(context, "Your Group Subdivisions", colorScheme.secondary),
                      ..._userSpecificGroups
                          .map((groupData) => _buildSpecificGroupTile(context, groupData))
                          .toList(),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'chatDmButton',
        backgroundColor: colorScheme.primary,
        onPressed: () => _startNewDm(context),
        child: Icon(Icons.message_rounded, color: colorScheme.onPrimary),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium!.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildChatEntry(BuildContext context, Map<String, dynamic> chat) {
    final chatId = chat['id'] as String? ?? 'tempId';
    final type = chat['type'] ?? 'dm';
    final participants = (chat['participants'] ?? []).cast<String>();
    final subtitle = chat['lastMessage'] ?? "No messages";

    if (type == 'dm') {
      final otherUid = participants.firstWhere((id) => id != _currentUserId, orElse: () => '');
      if (otherUid.isEmpty) return const SizedBox();

      final title = _userNameCache[otherUid] ?? otherUid;

      return _chatTile(
        context,
        chatId: chatId,
        title: title,
        subtitle: subtitle,
        type: type,
        otherUserId: otherUid,
      );
    }

    final name = chat['name'] ?? "Chat";
    return _chatTile(
      context,
      chatId: chatId,
      title: name,
      subtitle: subtitle,
      type: type,
    );
  }

  Widget _buildSpecificGroupTile(BuildContext context, Map<String, dynamic> groupData) {
    return _chatTile(
      context,
      chatId: groupData['chatId'] as String,
      title: groupData['name'] as String,
      subtitle: "Tap to chat in ${groupData['subdivision'] ?? 'General'} subdivision.",
      type: 'group',
    );
  }

  Widget _chatTile(
      BuildContext context, {
        required String chatId,
        required String title,
        required String subtitle,
        required String type,
        String? otherUserId,
      }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final icon = _getIconForChatType(type);
    final isGroup = type != 'dm';

    return Card(
      color: theme.cardColor,
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isGroup ? colorScheme.secondary.withOpacity(0.8) : colorScheme.primary.withOpacity(0.7),
          child: Icon(icon, color: colorScheme.onPrimary),
        ),
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                chatId: chatId,
                chatName: title,
                otherUserId: otherUserId,
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _getIconForChatType(String type) {
    switch (type) {
      case 'group':
        return Icons.group_rounded;
      case 'general':
        return Icons.public_rounded;
      case 'dm':
      default:
        return Icons.person_rounded;
    }
  }

  String _dmId(String a, String b) {
    final ids = [a, b]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  void _startNewDm(BuildContext context) {
    if (_currentUserId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UserSelectionScreen()),
    ).then((uid) async {
      final otherUid = uid as String?;
      if (otherUid == null || otherUid == _currentUserId) return;

      final chatId = _dmId(_currentUserId!, otherUid);
      final ref = _firestore.collection('chats').doc(chatId);

      final doc = await ref.get();
      if (!doc.exists) {
        await ref.set({
          'type': 'dm',
          'participants': [_currentUserId, otherUid],
          'lastMessage': "Chat created by $_currentUserName",
          'lastMessageAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            otherUserId: otherUid,
          ),
        ),
      );
    });
  }
}

class _StatusViewerDialog extends StatefulWidget {
  // ... (keep your existing constructor and fields)
  final Map<String, dynamic> status;
  final String? mediaUrl;
  final String content;
  final bool isAdmin;
  final int viewCount;
  final int? reachLimit;
  final VoidCallback onViewComplete;

  const _StatusViewerDialog({
    required this.status,
    required this.mediaUrl,
    required this.content,
    required this.isAdmin,
    required this.viewCount,
    required this.reachLimit,
    required this.onViewComplete,
  });

  @override
  State<_StatusViewerDialog> createState() => __StatusViewerDialogState();
}

class __StatusViewerDialogState extends State<_StatusViewerDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5), // Standard 5s duration
    )..forward().whenComplete(() {
      widget.onViewComplete();
      if (mounted) Navigator.of(context).pop(); // Auto-close
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final timeSent = (widget.status['createdAt'] as Timestamp?)?.toDate();
    final timeString = timeSent != null ? "${timeSent.hour}:${timeSent.minute.toString().padLeft(2, '0')}" : "";

    return Scaffold(
      backgroundColor: Colors.black, // Immersive background
      body: Stack(
        children: [
          // A. MEDIA LAYER
          Center(
            child: widget.mediaUrl != null
                ? Image.network(
              widget.mediaUrl!,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return CircularProgressIndicator(color: colorScheme.primary);
              },
            )
                : Container(
              color: Colors.blueGrey.shade900, // Background for text-only status
              alignment: Alignment.center,
              padding: const EdgeInsets.all(30),
              child: Text(
                widget.content,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontFamily: 'sans-serif-light',
                ),
              ),
            ),
          ),

          // B. CAPTION OVERLAY (Bottom Gradient)
          if (widget.mediaUrl != null && widget.content.isNotEmpty)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 40, 16, 40), // Safe area + gradient space
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: Text(
                  widget.content,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),

          // C. TOP CONTROLS (Progress + User Info)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 0, right: 0,
            child: Column(
              children: [
                // 1. Progress Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return LinearProgressIndicator(
                          value: _controller.value,
                          minHeight: 3,
                          backgroundColor: Colors.grey.withOpacity(0.5),
                          valueColor: const AlwaysStoppedAnimation(Colors.white),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 2. Header Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: colorScheme.primary,
                        child: Text(
                          (widget.status['createdByName'] ?? 'A')[0].toUpperCase(),
                          style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.status['createdByName'] ?? 'Admin',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
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
          ),

          // D. ADMIN METRICS (Optional)
          if (widget.isAdmin)
            Positioned(
              bottom: 40,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.black54,
                child: Row(
                  children: [
                    const Icon(Icons.remove_red_eye, color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.viewCount} views',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}