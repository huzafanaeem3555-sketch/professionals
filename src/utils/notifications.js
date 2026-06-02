const { messaging } = require('../config/firebase');
const { dbGet, dbUpdate, dbPush } = require('../config/firebase');
const axios = require('axios');

function normalizeData(data = {}) {
  return Object.entries(data || {}).reduce((acc, [key, value]) => {
    if (value === undefined || value === null) return acc;
    acc[key] = typeof value === 'string' ? value : String(value);
    return acc;
  }, {});
}

async function saveNotificationInboxItem(userId, title, body, data = {}) {
  if (!userId) return null;
  return await dbPush(`userNotifications/${userId}`, {
    title: title || 'HirePro',
    body: body || '',
    data: normalizeData(data),
    type: data?.type || 'general',
    bookingId: data?.bookingId || '',
    leadId: data?.leadId || '',
    read: false,
    createdAt: Date.now(),
  });
}

async function sendRawNotification(token, title, body, data = {}) {
  if (!token) return { success: false, error: 'No token found' };
  if (!messaging) {
    const serverKey = process.env.FCM_SERVER_KEY || process.env.FIREBASE_SERVER_KEY;
    if (!serverKey) {
      return { success: true, inboxOnly: true, error: 'Firebase messaging is not initialized' };
    }
    const response = await axios.post(
      'https://fcm.googleapis.com/fcm/send',
      {
        to: token,
        priority: 'high',
        notification: { title: title || 'HirePro', body: body || '' },
        data: normalizeData(data),
        android: { notification: { channel_id: 'HirePro_channel' } },
      },
      {
        timeout: 12000,
        headers: {
          Authorization: `key=${serverKey}`,
          'Content-Type': 'application/json',
        },
      },
    );
    return { success: true, response: response.data, provider: 'fcm_http' };
  }

  const message = {
    notification: {
      title: title || 'HirePro',
      body: body || '',
    },
    data: normalizeData(data),
    token,
    android: {
      priority: 'high',
      notification: {
        sound: 'default',
        channelId: 'HirePro_channel',
        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
      },
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
        },
      },
    },
  };

  const response = await messaging.send(message);
  return { success: true, response };
}

async function sendNotificationToUser(userId, title, body, data = {}) {
  const normalizedData = normalizeData(data);
  const inboxId = await saveNotificationInboxItem(userId, title, body, normalizedData);

  try {
    const userData = await dbGet(`users/${userId}`);
    const token = userData?.fcmToken;

    if (!token) {
      console.log(`No FCM token found for user ${userId}. Inbox notification saved.`);
      return { success: true, inboxOnly: true, inboxId, error: 'No token found' };
    }

    const result = await sendRawNotification(token, title, body, normalizedData);
    console.log(`Notification sent to ${userId}: ${title}`);
    return { ...result, inboxId };
  } catch (error) {
    console.log(`Failed to send notification to ${userId}:`, error.message);

    if (
      error.code === 'messaging/invalid-registration-token' ||
      error.code === 'messaging/registration-token-not-registered'
    ) {
      await dbUpdate(`users/${userId}`, { fcmToken: null });
    }

    return { success: false, inboxId, error: error.message };
  }
}

async function sendNotificationToMultipleUsers(userIds, title, body, data = {}) {
  try {
    const normalizedData = normalizeData(data);
    const tokens = [];

    for (const userId of userIds || []) {
      await saveNotificationInboxItem(userId, title, body, normalizedData);
      const userData = await dbGet(`users/${userId}`);
      const token = userData?.fcmToken;
      if (token) tokens.push(token);
    }

    if (tokens.length === 0) {
      console.log('No FCM tokens found. Inbox notifications saved.');
      return { success: true, inboxOnly: true, count: 0 };
    }

    if (!messaging) {
      const results = await Promise.allSettled(
        tokens.map(token => sendRawNotification(token, title, body, normalizedData)),
      );
      return {
        success: true,
        provider: 'fcm_http',
        count: results.filter(item => item.status === 'fulfilled').length,
      };
    }

    const response = await messaging.sendEachForMulticast({
      notification: {
        title: title || 'HirePro',
        body: body || '',
      },
      data: normalizedData,
      tokens,
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'HirePro_channel',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
    });

    console.log(`Notifications sent to ${response.successCount} devices, failed: ${response.failureCount}`);
    return {
      success: true,
      successCount: response.successCount,
      failureCount: response.failureCount,
    };
  } catch (error) {
    console.log('Multicast send failed:', error.message);
    return { success: false, error: error.message };
  }
}

async function saveFcmToken(userId, token) {
  try {
    if (!userId || !token) {
      return { success: false, error: 'userId and token required' };
    }

    await dbUpdate(`users/${userId}`, {
      fcmToken: token,
      fcmTokenUpdatedAt: Date.now(),
    });

    console.log(`FCM token saved for user: ${userId}`);
    return { success: true };
  } catch (error) {
    console.log('Failed to save FCM token:', error.message);
    return { success: false, error: error.message };
  }
}

async function sendNewBookingNotification(professionalId, customerName, bookingId) {
  return await sendNotificationToUser(
    professionalId,
    'New Booking Request',
    `${customerName} has requested your service. Tap to view details.`,
    {
      type: 'new_booking',
      bookingId,
      screen: 'notifications',
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
      timestamp: Date.now().toString(),
    },
  );
}

async function sendPriceOfferNotification(customerId, professionalName, price, bookingId) {
  return await sendNotificationToUser(
    customerId,
    'Price Offer Received',
    `${professionalName} offered Rs. ${price} for your service request.`,
    { type: 'price_offer', bookingId, price: price.toString() },
  );
}

async function sendBookingAcceptedNotification(customerId, professionalName, bookingId) {
  return await sendNotificationToUser(
    customerId,
    'Booking Accepted',
    `${professionalName} has accepted your booking. Contact details are now available.`,
    { type: 'booking_accepted', bookingId },
  );
}

async function sendJobCompletedByCustomerNotification(professionalId, customerName, bookingId) {
  return await sendNotificationToUser(
    professionalId,
    'Customer Confirmed Completion',
    `${customerName} has confirmed that the job is complete. Tap to mark as done.`,
    { type: 'customer_completed', bookingId },
  );
}

async function sendNewServicePostNotification(professionalIds, customerName, description, postId) {
  const shortDesc = description.length > 50 ? `${description.substring(0, 50)}...` : description;
  const title = 'New Service Request Near You';
  const body = `${customerName} needs: ${shortDesc}`;
  const data = { type: 'new_service_post', postId };

  if (professionalIds.length === 1) {
    return await sendNotificationToUser(professionalIds[0], title, body, data);
  }

  return await sendNotificationToMultipleUsers(professionalIds, title, body, data);
}

module.exports = {
  sendNotificationToUser,
  sendNotificationToMultipleUsers,
  sendNotification: sendRawNotification,
  saveNotificationInboxItem,
  saveFcmToken,
  sendNewBookingNotification,
  sendPriceOfferNotification,
  sendBookingAcceptedNotification,
  sendJobCompletedByCustomerNotification,
  sendNewServicePostNotification,
};
