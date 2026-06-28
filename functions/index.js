const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

admin.initializeApp();

exports.onAnnouncementCreated = onDocumentCreated(
  '{path=**}/notices/{noticeId}',
  async (event) => {
    const announcement = event.data?.data();
    const noticeId = event.params.noticeId;

    if (!announcement) return null;

    // Parse specific nested path segments directly from the database write pattern
    const pathSegments = event.document.split('/');
    if (pathSegments[0] !== 'announcements') return null;

    const campus = pathSegments[1] || '';
    const course = pathSegments[5] || '';
    const year = pathSegments[6] || '';
    const semester = pathSegments[7] || '';

    const { title = 'New Announcement', description = '', type = 'General', unit_code } = announcement;

    console.log(`FCM Engine → Processing ${type}: "${title}"`);

    // Target active student profile nodes explicitly
    let usersQuery = admin.firestore().collection('users')
      .where('fcmToken', '!=', null)
      .where('fcmToken', '!=', '');

    if (type !== 'General') {
      if (campus) usersQuery = usersQuery.where('campus', '==', campus);
      if (course) usersQuery = usersQuery.where('course', '==', course);

      const cleanYear = String(year).replace('YEAR_', '');
      const cleanSem = String(semester).replace('SEM_', '');

      if (cleanYear) usersQuery = usersQuery.where('year', '==', cleanYear);
      if (cleanSem) usersQuery = usersQuery.where('semester', '==', cleanSem);
    }

    const usersSnap = await usersQuery.get();
    const tokens = [];

    usersSnap.forEach(doc => {
      const user = doc.data();
      if (!user.fcmToken) return;

      // Filter by dynamic unit code if student registration list is active
      if (unit_code && type !== 'General') {
        const registered = user.registered_units || [];
        if (!registered.some(u => String(u.code).toUpperCase() === String(unit_code).toUpperCase())) return;
      }
      tokens.push(user.fcmToken);
    });

    if (!tokens.length) return null;

    const titleMap = {
      'General': '📢 General Announcement',
      'Notes': '📚 New Notes Uploaded',
      'Past Paper': '📄 Past Paper Available',
      'Assignment': '📝 New Assignment Notice',
      'CAT': '⚠️ Upcoming CAT Reminder',
      'Class Confirmation': '🎓 Class Confirmation Status',
    };

    const finalTitle = titleMap[type] || '📢 Academic Bulletin Notice';
    const finalBody = unit_code ? `[${unit_code}] ${title}` : title;

    // Unified multicast transport payload blueprint
    const message = {
      tokens,
      notification: { title: finalTitle, body: finalBody.substring(0, 100) },
      data: {
        id: noticeId,
        type: String(type).toLowerCase().replace(' ', ''),
        title: finalTitle,
        body: description,
        unitCode: unit_code || '',
      },
      android: {
        notification: { channelId: 'high_importance_channel', priority: 'high' }
      }
    };

    return admin.messaging().sendEachForMulticast(message);
  }
);