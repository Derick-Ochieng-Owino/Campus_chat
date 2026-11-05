/**
 * Firebase Cloud Functions
 * Announcement Notifications (FCM)
 * FILTERED by year_key, semester_key, course, campus, etc.
 */

const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

admin.initializeApp();

const USERS_COLLECTION = 'users';

// ----------------- UTILITY: SEND FCM -----------------
async function sendMulticastNotification(tokens, data, notification) {
  if (!tokens.length) {
    console.log('No tokens to send');
    return null;
  }

  // FCM requires data values to be strings
  const stringData = {};
  Object.keys(data).forEach(key => {
    stringData[key] = String(data[key]);
  });

  const message = {
    tokens,
    notification, // shown when app is backgrounded
    data: stringData, // used by Flutter app
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`FCM Sent → Success: ${response.successCount}, Failed: ${response.failureCount}`);
    return response;
  } catch (error) {
    console.error('Error sending FCM:', error);
    return null;
  }
}

// ----------------- ANNOUNCEMENT TRIGGER -----------------
exports.onAnnouncementCreated = onDocumentCreated(
  'announcements/{announcementId}',
  async (event) => {
    const announcement = event.data?.data();
    const announcementId = event.params.announcementId;

    if (!announcement) return null;

    const {
      title = 'New Announcement',
      description = '',
      type = 'General',
      unit_code, // OPTIONAL
      unit_title, // OPTIONAL
      semester, // NEW: Filter by semester
      year, // NEW: Filter by year
      author_id, // NEW: The user who created the announcement
    } = announcement;

    console.log(`New announcement created: ${title}, Type: ${type}`);

    // 🔹 1. For General announcements - send to everyone (Admin broadcast)
    if (type === 'General') {
      console.log('General announcement - sending to all users');

      // Fetch all users with FCM tokens
      const usersSnap = await admin.firestore()
        .collection(USERS_COLLECTION)
        .get();

      const tokens = [];
      usersSnap.forEach(doc => {
        const user = doc.data();
        if (user.fcmToken && typeof user.fcmToken === 'string' && user.fcmToken.length > 0) {
          tokens.push(user.fcmToken);
        }
      });

      console.log(`Sending to ${tokens.length} users for general announcement`);

      return sendMulticastNotification(
        tokens,
        {
          type: 'General',
          announcementId,
          is_general: 'true',
        },
        {
          title: '📢 General Announcement',
          body: title.includes('\n') ? title.split('\n')[0] : title,
        }
      );
    }

    // 🔹 2. Get author's data to filter by course/campus/etc.
    let authorData = null;
    try {
      const authorDoc = await admin.firestore()
        .collection(USERS_COLLECTION)
        .doc(author_id)
        .get();

      if (authorDoc.exists) {
        authorData = authorDoc.data();
      }
    } catch (error) {
      console.error('Error fetching author data:', error);
    }

    if (!authorData) {
      console.log('Could not fetch author data, using default filters');
      return null;
    }

    const authorCourse = authorData.course || '';
    const authorCampus = authorData.campus || 'Main';
    const authorSchool = authorData.school || '';
    const authorDepartment = authorData.department || '';

    console.log(`Author info: Course=${authorCourse}, Campus=${authorCampus}, School=${authorSchool}`);

    // 🔹 3. Build query based on filters
    let usersQuery = admin.firestore()
      .collection(USERS_COLLECTION)
      .where('fcmToken', '!=', null)
      .where('fcmToken', '!=', '');

    // Filter by year and semester if provided
    if (year !== undefined && semester !== undefined) {
      console.log(`Filtering by year=${year}, semester=${semester}`);
      usersQuery = usersQuery
        .where('year', '==', year)
        .where('semester', '==', semester);
    }

    // Filter by course if available
    if (authorCourse && authorCourse.trim() !== '') {
      console.log(`Filtering by course=${authorCourse}`);
      usersQuery = usersQuery.where('course', '==', authorCourse);
    }

    // Filter by campus if available
    if (authorCampus && authorCampus.trim() !== '') {
      console.log(`Filtering by campus=${authorCampus}`);
      usersQuery = usersQuery.where('campus', '==', authorCampus);
    }

    // 🔹 4. Execute query and filter by unit registration
    const usersSnap = await usersQuery.get();
    const tokens = [];

    usersSnap.forEach(doc => {
      const user = doc.data();
      const fcmToken = user.fcmToken;

      if (!fcmToken || typeof fcmToken !== 'string' || fcmToken.length === 0) {
        return;
      }

      // For non-General types with unit_code, check if user is registered
      if (unit_code) {
        const registeredUnits = user.registered_units || [];
        const isRegistered = registeredUnits.some(
          u => u.code === unit_code
        );

        if (!isRegistered) {
          console.log(`User ${user.email} not registered for unit ${unit_code}`);
          return;
        }
      }

      // Additional school/department filters if needed
      if (authorSchool && user.school !== authorSchool) return;
      if (authorDepartment && user.department !== authorDepartment) return;

      tokens.push(fcmToken);
    });

    console.log(`Filtered tokens: ${tokens.length} users will receive this ${type} notification`);

    if (tokens.length === 0) {
      console.log('No users match the filters for this announcement');
      return null;
    }

    // 🔹 5. Notification title mapping
    const titleMap = {
      'Notes': '📚 New Notes',
      'Past Paper': '📄 Past Paper',
      'Assignment': '📝 New Assignment',
      'CAT': '⚠️ Upcoming CAT',
      'Class Confirmation': '🎓 Class Confirmation',
    };

    // Prepare notification body
    let notificationBody = '';
    if (unit_title) {
      // Show unit title in notification
      notificationBody = `${unit_code || ''} - ${description.substring(0, 100)}`;
    } else {
      notificationBody = description.substring(0, 120);
    }

    return sendMulticastNotification(
      tokens,
      {
        type,
        announcementId,
        unit_code: unit_code || '',
        year: year || '',
        semester: semester || '',
      },
      {
        title: titleMap[type] || '📢 Announcement',
        body: notificationBody,
      }
    );
  }
);

// ----------------- WELCOME NOTIFICATION FUNCTION -----------------
/**
 * Send welcome notification to new users
 * Trigger: onUserCreated (when profile_completed becomes true)
 */
exports.onUserProfileCompleted = onDocumentCreated(
  'users/{userId}',
  async (event) => {
    const userData = event.data?.data();
    const userId = event.params.userId;

    if (!userData) return null;

    // Check if profile is completed (based on your app logic)
    const profileCompleted = userData.profile_completed || false;
    const fcmToken = userData.fcmToken;
    const userName = userData.name || 'Student';
    const course = userData.course || '';

    if (!profileCompleted || !fcmToken) {
      console.log('Profile not completed or no FCM token');
      return null;
    }

    console.log(`Sending welcome notification to ${userName} (${course})`);

    // Send welcome notification only to this user
    const message = {
      token: fcmToken,
      notification: {
        title: '🎉 Welcome to Campus Chat!',
        body: `Hi ${userName}! Welcome to ${course || 'the app'}. Get started with your academic journey.`,
      },
      data: {
        type: 'welcome',
        user_id: userId,
        screen: 'home',
      },
    };

    try {
      const response = await admin.messaging().send(message);
      console.log('Welcome notification sent:', response);
      return response;
    } catch (error) {
      console.error('Error sending welcome notification:', error);
      return null;
    }
  }
);