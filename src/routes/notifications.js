const express = require('express');
const router = express.Router();
const { saveFcmToken, sendNotificationToUser } = require('../utils/notifications');
const { verifyToken } = require('../middleware/auth');
const UserModel = require('../models/userModel');
const { dbPush } = require('../config/firebase');

async function saveProfessionalLead({
  targetUserId,
  customerId,
  customerName,
  customerPhone,
  customerAddress,
  customerLocation,
  serviceType,
  contactMethod,
  type,
  title,
  body,
}) {
  const now = Date.now();
  return await dbPush(`professionalContactLeads/${targetUserId}`, {
    customerId: customerId || '',
    customerName: customerName || 'Customer',
    customerPhone: customerPhone || '',
    customerAddress: customerAddress || '',
    customerLocation: customerLocation || null,
    serviceType: serviceType || '',
    contactMethod: contactMethod || '',
    type: type || (contactMethod === 'whatsapp' ? 'direct_whatsapp' : 'direct_call'),
    title: title || 'Customer contacted you',
    body: body || `${customerName || 'A customer'} contacted you. Phone: ${customerPhone || ''}`,
    createdAt: now,
    expiresAt: now + 30 * 24 * 60 * 60 * 1000,
  });
}

// Update FCM token for current user
router.post('/update-token', async (req, res) => {
  try {
    const { userId, token } = req.body;
    
    if (!userId || !token) {
      return res.status(400).json({ error: 'userId and token required' });
    }
    
    const result = await saveFcmToken(userId, token);
    
    if (result.success) {
      res.json({ success: true });
    } else {
      res.status(500).json({ error: result.error });
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Send a contact notification to another user
router.post('/contact', verifyToken, async (req, res) => {
  try {
    const senderId = req.user.uid;
    const {
      targetUserId,
      title,
      body,
      type = 'contact_request',
      bookingId,
      contactMethod,
      serviceType,
      customerPhone,
      customerAddress,
      customerLocation,
      leadAlreadySaved,
    } = req.body;

    if (!targetUserId || !title || !body) {
      return res.status(400).json({
        success: false,
        message: 'targetUserId, title, and body are required',
      });
    }

    if (targetUserId === senderId) {
      return res.status(400).json({
        success: false,
        message: 'Cannot send notification to yourself',
      });
    }

    const sender = await UserModel.getById(senderId, true);
    let leadId = '';
    if (!leadAlreadySaved) {
      leadId = await saveProfessionalLead({
        targetUserId,
        customerId: senderId,
        customerName: sender?.displayName || sender?.name || req.user.displayName || 'Customer',
        customerPhone: customerPhone || sender?.phoneNumber || '',
        customerAddress: customerAddress || sender?.address || '',
        customerLocation: customerLocation || sender?.location || null,
        serviceType: serviceType || '',
        contactMethod: contactMethod || '',
        type,
        title,
        body,
      }) || '';
    }

    const result = await sendNotificationToUser(targetUserId, title, body, {
      type,
      bookingId: bookingId ? String(bookingId) : '',
      leadId: leadId || '',
      contactMethod: contactMethod ? String(contactMethod) : '',
      serviceType: serviceType ? String(serviceType) : '',
      customerPhone: customerPhone ? String(customerPhone) : '',
      customerAddress: customerAddress ? String(customerAddress) : '',
      customerLocation: customerLocation ? JSON.stringify(customerLocation) : '',
      senderId,
      senderName: sender?.displayName || req.user.displayName || 'User',
      timestamp: Date.now().toString(),
    });

    return res.json({
      success: result.success,
      data: { ...result, leadId },
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// Public fallback used by the mobile app when local RTDB write is blocked.
router.post('/contact-public', async (req, res) => {
  try {
    const {
      targetUserId,
      customerId,
      customerName,
      customerPhone,
      customerAddress,
      customerLocation,
      serviceType,
      contactMethod,
      type,
      title,
      body,
      leadAlreadySaved,
    } = req.body;

    if (!targetUserId || !customerPhone || !customerAddress) {
      return res.status(400).json({
        success: false,
        message: 'targetUserId, customerPhone, and customerAddress are required',
      });
    }

    const leadId = leadAlreadySaved ? '' : await saveProfessionalLead({
        targetUserId,
        customerId,
        customerName,
        customerPhone,
        customerAddress,
        customerLocation,
        serviceType,
        contactMethod,
        type,
        title,
        body,
      });

    const notifyResult = await sendNotificationToUser(
      targetUserId,
      title || 'Customer contacted you',
      body || `${customerName || 'A customer'} contacted you. Phone: ${customerPhone}`,
      {
        type: type || 'direct_contact',
        leadId: leadId || '',
        contactMethod: contactMethod || '',
        serviceType: serviceType || '',
        customerPhone: customerPhone || '',
        customerAddress: customerAddress || '',
        customerLocation: customerLocation ? JSON.stringify(customerLocation) : '',
        senderId: customerId || '',
        senderName: customerName || 'Customer',
        timestamp: Date.now().toString(),
      },
    );

    return res.json({ success: true, data: { leadId, notification: notifyResult } });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// Test notification (for debugging)
router.post('/test', async (req, res) => {
  try {
    const { userId, title, body } = req.body;
    
    if (!userId) {
      return res.status(400).json({ error: 'userId required' });
    }
    
    const result = await sendNotificationToUser(
      userId, 
      title || 'Test Notification', 
      body || 'This is a test notification from Service Connect'
    );
    
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
