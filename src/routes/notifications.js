const express = require('express');
const router = express.Router();
const { saveFcmToken, sendNotificationToUser } = require('../utils/notifications');
const { verifyToken } = require('../middleware/auth');
const UserModel = require('../models/userModel');
const ProfessionalModel = require('../models/professionalModel');
const ServiceAnalyticsModel = require('../models/serviceAnalyticsModel');
const { dbPush } = require('../config/firebase');

function normalizeGender(value) {
  return String(value || '').trim().toLowerCase() === 'female' ? 'female' : 'male';
}

async function assertSameGenderContact(targetUserId, customerGender) {
  const professional = await ProfessionalModel.getById(targetUserId);
  if (!professional) {
    const error = new Error('Professional not found.');
    error.statusCode = 404;
    throw error;
  }
  if (normalizeGender(professional.gender) !== normalizeGender(customerGender)) {
    const error = new Error('This professional is not available for your account.');
    error.statusCode = 403;
    throw error;
  }
}

async function saveProfessionalLead({
  targetUserId,
  customerId,
  customerName,
  customerPhotoURL,
  customerPhone,
  customerGender,
  customerAddress,
  customerLocation,
  serviceType,
  contactMethod,
  type,
  title,
  body,
  referralCode,
  referralDiscountPercent,
  referralOwnerId,
  referralOwnerName,
  hasReferralDiscount,
}) {
  const now = Date.now();
  const isFemaleCustomer = String(customerGender || '').toLowerCase() === 'female';
  const visiblePhone = isFemaleCustomer ? 'Hidden' : (customerPhone || '');
  const leadType = type || (
    contactMethod === 'profile_view'
      ? 'profile_view'
      : contactMethod === 'whatsapp'
        ? 'direct_whatsapp'
        : 'direct_call'
  );
  const leadTitle = title || (
    leadType === 'profile_view'
      ? 'Customer viewed your profile'
      : 'Customer contacted you'
  );
  const leadBody = body || (
    leadType === 'profile_view'
      ? `${customerName || 'A customer'} viewed your HirePro profile.`
      : `${customerName || 'A customer'} contacted you. Phone: ${visiblePhone}`
  );
  return await dbPush(`professionalContactLeads/${targetUserId}`, {
    customerId: customerId || '',
    customerName: customerName || 'Customer',
    customerPhotoURL: customerPhotoURL || '',
    customerPhone: visiblePhone,
    customerGender: isFemaleCustomer ? 'female' : 'male',
    customerAddress: customerAddress || '',
    customerLocation: customerLocation || null,
    serviceType: serviceType || '',
    contactMethod: contactMethod || '',
    type: leadType,
    title: leadTitle,
    body: leadBody,
    referralCode: referralCode || '',
    referralDiscountPercent: Number(referralDiscountPercent || 0),
    referralOwnerId: referralOwnerId || '',
    referralOwnerName: referralOwnerName || '',
    hasReferralDiscount: hasReferralDiscount === true || Boolean(referralCode),
    createdAt: now,
    expiresAt: now + 5 * 60 * 60 * 1000,
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
      customerPhotoURL,
      customerGender,
      customerAddress,
      customerLocation,
      leadAlreadySaved,
      referralCode,
      referralDiscountPercent,
      referralOwnerId,
      referralOwnerName,
      hasReferralDiscount,
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
    const finalCustomerGender = customerGender || sender?.gender || 'male';
    await assertSameGenderContact(targetUserId, finalCustomerGender);
    let leadId = '';
    if (!leadAlreadySaved) {
      leadId = await saveProfessionalLead({
        targetUserId,
        customerId: senderId,
        customerName: sender?.displayName || sender?.name || req.user.displayName || 'Customer',
        customerPhotoURL: customerPhotoURL || sender?.photoURL || req.user.photoURL || '',
        customerPhone: customerPhone || sender?.phoneNumber || '',
        customerGender: finalCustomerGender,
        customerAddress: customerAddress || sender?.address || '',
        customerLocation: customerLocation || sender?.location || null,
        serviceType: serviceType || '',
        contactMethod: contactMethod || '',
        type,
        title,
        body,
        referralCode,
        referralDiscountPercent,
        referralOwnerId,
        referralOwnerName,
        hasReferralDiscount,
      }) || '';
    }
    await ServiceAnalyticsModel.incrementService(serviceType, 'contactCount').catch(() => null);

    const result = await sendNotificationToUser(targetUserId, title, body, {
      type,
      bookingId: bookingId ? String(bookingId) : '',
      leadId: leadId || '',
      contactMethod: contactMethod ? String(contactMethod) : '',
      serviceType: serviceType ? String(serviceType) : '',
      customerPhone: customerPhone ? String(customerPhone) : '',
      customerPhotoURL: customerPhotoURL || sender?.photoURL || req.user.photoURL || '',
      customerAddress: customerAddress ? String(customerAddress) : '',
      customerLocation: customerLocation ? JSON.stringify(customerLocation) : '',
      referralCode: referralCode || '',
      referralDiscountPercent: referralDiscountPercent ? String(referralDiscountPercent) : '',
      referralOwnerId: referralOwnerId || '',
      referralOwnerName: referralOwnerName || '',
      hasReferralDiscount: hasReferralDiscount ? 'true' : '',
      senderId,
      senderName: sender?.displayName || req.user.displayName || 'User',
      timestamp: Date.now().toString(),
    });

    return res.json({
      success: result.success,
      data: { ...result, leadId },
    });
  } catch (error) {
    return res.status(error.statusCode || 500).json({ success: false, message: error.message });
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
      customerPhotoURL,
      customerGender,
      customerAddress,
      customerLocation,
      serviceType,
      contactMethod,
      type,
      title,
      body,
      leadAlreadySaved,
      referralCode,
      referralDiscountPercent,
      referralOwnerId,
      referralOwnerName,
      hasReferralDiscount,
    } = req.body;

    if (!targetUserId || !customerPhone || !customerAddress) {
      return res.status(400).json({
        success: false,
        message: 'targetUserId, customerPhone, and customerAddress are required',
      });
    }

    await assertSameGenderContact(targetUserId, customerGender);

    const leadId = leadAlreadySaved ? '' : await saveProfessionalLead({
        targetUserId,
        customerId,
        customerName,
        customerPhotoURL,
        customerPhone,
        customerGender,
        customerAddress,
        customerLocation,
        serviceType,
        contactMethod,
        type,
        title,
        body,
        referralCode,
        referralDiscountPercent,
        referralOwnerId,
        referralOwnerName,
        hasReferralDiscount,
      });
    await ServiceAnalyticsModel.incrementService(serviceType, 'contactCount').catch(() => null);

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
        customerPhotoURL: customerPhotoURL || '',
        customerAddress: customerAddress || '',
        customerLocation: customerLocation ? JSON.stringify(customerLocation) : '',
        referralCode: referralCode || '',
        referralDiscountPercent: referralDiscountPercent ? String(referralDiscountPercent) : '',
        referralOwnerId: referralOwnerId || '',
        referralOwnerName: referralOwnerName || '',
        hasReferralDiscount: hasReferralDiscount ? 'true' : '',
        senderId: customerId || '',
        senderName: customerName || 'Customer',
        timestamp: Date.now().toString(),
      },
    );

    return res.json({ success: true, data: { leadId, notification: notifyResult } });
  } catch (error) {
    return res.status(error.statusCode || 500).json({ success: false, message: error.message });
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
      body || 'This is a test notification from HirePro'
    );
    
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
