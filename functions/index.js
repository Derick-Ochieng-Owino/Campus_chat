/**
 * Firebase Cloud Functions
 * Triggers FCM notifications for chat messages and announcements.
 * Sensitive data (like default app ID) should go in environment variables.
 *
 * Example setup:
 *   firebase functions:config:set app.default_app_id="campus-chat-c8499"
 */

const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

admin.initializeApp();

// --- USE ENVIRONMENT VARIABLE INSTEAD OF functions.config() ---
const DEFAULT_APP_ID = process.env.FIREBASE_APP_DEFAULT_APP_ID || 'default_app_id';
const USERS_COLLECTION = 'users';

// Utility: Send FCM notification
async function sendNotification(notificationType, payloadData, payloadNotification) {
  try {
    const appId = payloadData.appId || DEFAULT_APP_ID;

    const tokensSnapshot = await admin.firestore()
      .collection(`apps/${appId}/${USERS_COLLECTION}`)
      .get();

    const registrationTokens = [];
    tokensSnapshot.forEach(doc => {
      const userData = doc.data();
      if (userData.fcmToken) registrationTokens.push(userData.fcmToken);
    });

    if (!registrationTokens.length) {
      console.log(`No tokens found for App ID ${appId}. Skipping notification.`);
      return null;
    }

    // Ensure all data values are strings
    const stringifiedData = {};
    for (const key in payloadData) {
      stringifiedData[key] = String(payloadData[key]);
    }

    const message = {
      tokens: registrationTokens,
      data: { ...stringifiedData, type: notificationType },
      notification: payloadNotification,
    };

    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`Sent ${response.successCount} messages, failed: ${response.failureCount}`);

    return response;
  } catch (error) {
    console.error('Error sending notification:', error);
    return null;
  }
}

// ----------------- CHAT MESSAGE TRIGGER -----------------
exports.sendChatNotification = onDocumentCreated(
  'apps/{appId}/chats/{chatId}/messages/{messageId}',
  async (event) => {
    const snap = event.data;
    const context = event.params;

    const message = snap || {};
    const { chatId, appId } = context;

    if (message.senderId === message.recipientId) return null;

    const isGroup = chatId.startsWith('group_');

    const senderSnap = await admin.firestore()
      .doc(`apps/${appId}/${USERS_COLLECTION}/${message.senderId}`)
      .get();
    const senderName = senderSnap.exists ? senderSnap.data().name || 'Unknown User' : 'Unknown User';

    const text = message.text || '';
    const title = isGroup
      ? `💬 New Group Message in ${message.groupName || 'Chat'}`
      : `👤 New Message from ${senderName}`;
    const body = `${senderName}: ${text.substring(0, 50)}${text.length > 50 ? '...' : ''}`;

    const payloadNotification = { title, body };
    const payloadData = {
      appId,
      chatId,
      isGroup: isGroup.toString(),
      screen: isGroup ? 'group_chat_screen' : 'individual_chat_screen',
    };

    return sendNotification('chat', payloadData, payloadNotification);
  }
);

// ----------------- ANNOUNCEMENT TRIGGER -----------------
exports.sendAnnouncementNotification = onDocumentCreated(
  'announcements/{announcementId}',
  async (event) => {
    const snap = event.data;
    const announcement = snap.data();
    const announcementId = event.params.announcementId;

    const categoryKey = (announcement.category || announcement.type || 'general').toLowerCase();

    const categories = {
      general: '📢 General Announcement',
      assignment: '📝 New Assignment Posted',
      assignments: '📝 New Assignment Posted',
      class_confirmation: '🗓️ Class Confirmed/Cancelled',
      cats: '⚠️ CAT/Exam Alert',
      notes: '📄 New Class Notes Released',
    };

    const titlePrefix = categories[categoryKey] || categories.general;

    const content = announcement.description || announcement.content || '';
    const body =
      content.length > 80 ? content.substring(0, 80) + '... Tap to view.' : content;

    // Notification content
    const payloadNotification = {
      title: `${titlePrefix}`,
      body,
    };

    // Data sent with the notification
    const payloadData = {
      screen: 'announcements_detail',
      announcementId,
      category: categoryKey,
    };

    return sendNotification('announcement', payloadData, payloadNotification);
  }
);
