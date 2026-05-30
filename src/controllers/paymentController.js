const axios = require('axios');
const FormData = require('form-data');
const PaymentModel = require('../models/paymentModel');
const BookingModel = require('../models/bookingModel');
const UserModel = require('../models/userModel');
const { uploadToImgBB } = require('../utils/imgbb');
const { sendNotificationToUser } = require('../utils/notifications');

const extractTransactionId = (text) => {
  if (!text) return '';
  const normalized = text.replace(/\s+/g, ' ');
  const patterns = [
    /transaction\s*id[:\s]*([A-Za-z0-9-]+)/i,
    /txn\s*id[:\s]*([A-Za-z0-9-]+)/i,
    /ref(?:erence)?\s*(?:no\.?|number)?[:\s]*([A-Za-z0-9-]+)/i,
    /([A-Z0-9]{6,})/,
  ];
  for (const pattern of patterns) {
    const match = normalized.match(pattern);
    if (match && match[1]) return match[1].trim();
  }
  return '';
};

const extractAmount = (text) => {
  if (!text) return null;
  const normalized = text.replace(/\s+/g, ' ');
  const amountPattern = /(?:rs\.?|pkr|amount)[:\s]*([0-9,]+(?:\.[0-9]{1,2})?)/i;
  const match = normalized.match(amountPattern);
  if (match && match[1]) {
    return parseFloat(match[1].replace(/,/g, '')) || null;
  }
  return null;
};

const extractTextFromImageBuffer = async (buffer) => {
  const form = new FormData();
  form.append('apikey', process.env.OCR_SPACE_API_KEY || 'helloworld');
  form.append('language', 'eng');
  form.append('isOverlayRequired', 'false');
  form.append('base64image', `data:image/png;base64,${buffer.toString('base64')}`);

  const response = await axios.post('https://api.ocr.space/parse/image', form, {
    headers: form.getHeaders(),
    timeout: 60000,
  });

  const data = response.data;
  if (!data || data.IsErroredOnProcessing) {
    throw new Error(data?.ErrorMessage?.[0] || 'OCR extraction failed.');
  }

  return data.ParsedResults?.[0]?.ParsedText || '';
};

const PaymentController = {
  async verifyTransaction(req, res) {
    try {
      const { transactionId } = req.body;
      if (!transactionId) {
        return res.status(400).json({ success: false, message: 'transactionId is required.' });
      }

      const result = await PaymentModel.verifyEasypaisa(transactionId.trim());
      if (!result.verified) {
        return res.status(400).json({ success: false, message: result.message || 'Transaction could not be verified.' });
      }

      return res.status(200).json({ success: true, data: result });
    } catch (error) {
      console.error('verifyTransaction error:', error);
      return res.status(500).json({ success: false, message: 'Verification failed.' });
    }
  },

  async verifyScreenshot(req, res) {
    try {
      const file = req.file;
      if (!file) {
        return res.status(400).json({ success: false, message: 'Screenshot image is required.' });
      }

      const screenshotUrl = await uploadToImgBB(file.buffer.toString('base64'), `payment_receipt_${Date.now()}`);
      const extractedText = await extractTextFromImageBuffer(file.buffer);
      const extractedTransactionId = extractTransactionId(extractedText);
      const amount = extractAmount(extractedText);

      return res.status(200).json({
        success: true,
        data: {
          extractedTransactionId,
          amount,
          screenshotUrl,
          extractedText,
        },
      });
    } catch (error) {
      console.error('verifyScreenshot error:', error);
      return res.status(500).json({ success: false, message: 'Screenshot verification failed.' });
    }
  },

  async confirmPayment(req, res) {
    try {
      const { uid } = req.user;
      const { bookingId } = req.params;
      const { transactionId, screenshotUrl } = req.body;

      if (!transactionId || !transactionId.trim()) {
        return res.status(400).json({ success: false, message: 'transactionId is required.' });
      }

      if (!screenshotUrl) {
        return res.status(400).json({ success: false, message: 'screenshotUrl is required.' });
      }

      const booking = await BookingModel.getById(bookingId);
      if (!booking) {
        return res.status(404).json({ success: false, message: 'Booking not found.' });
      }

      if (booking.customerId !== uid) {
        return res.status(403).json({ success: false, message: 'Only the customer can confirm payment.' });
      }

      if (booking.paymentStatus === 'completed') {
        return res.status(400).json({ success: false, message: 'Payment already confirmed.' });
      }

      const verification = await PaymentModel.verifyEasypaisa(transactionId.trim());
      if (!verification.verified) {
        return res.status(400).json({ success: false, message: verification.message || 'Payment verification failed.' });
      }

      const payment = await PaymentModel.create({
        bookingId,
        customerId: uid,
        professionalId: booking.professionalId,
        amount: booking.agreedPrice || booking.proposedPrice || 0,
        commission: booking.commissionAmount || 0,
      });

      let confirmResult;
      try {
        confirmResult = await BookingModel.confirmPayment(bookingId, transactionId.trim(), screenshotUrl);
      } catch (err) {
        // If wallet transaction failed due to insufficient funds or other reason
        console.error('BookingModel.confirmPayment failed:', err.message || err);
        return res.status(400).json({ success: false, message: err.message || 'Failed to confirm payment.' });
      }

      // Mark payment record as confirmed
      await PaymentModel.confirm(payment.paymentId, transactionId.trim());

      console.log('[PAYMENT] Confirmed', bookingId, 'tx:', transactionId.trim(), 'commission:', confirmResult.commission);

      const [customerUser, professionalUser] = await Promise.all([
        UserModel.getById(uid, true),
        UserModel.getById(booking.professionalId, true),
      ]);

      return res.status(200).json({
        success: true,
        data: {
          customerPhone: customerUser?.phoneNumber || 'Not available',
          professionalPhone: professionalUser?.phoneNumber || 'Not available',
          professionalLocation: professionalUser?.location || null,
          professionalAddress: professionalUser?.address || '',
          professionalName: professionalUser?.displayName || 'Professional',
          professionalPhoto: professionalUser?.photoURL || '',
          status: 'confirmed',
          commissionDeducted: confirmResult.commission || booking.commissionAmount || 0,
          professionalEarnings: confirmResult.professionalEarnings || booking.professionalEarnings || 0,
          professionalNewBalance: confirmResult.newBalance,
        },
      });
    } catch (error) {
      console.error('confirmPayment error:', error);
      return res.status(500).json({ success: false, message: 'Payment confirmation failed.' });
    }
  },

  async processPayment(req, res) {
    try {
      const { uid } = req.user;
      const { bookingId, paymentMethod } = req.body;

      if (!bookingId) {
        return res.status(400).json({ success: false, message: 'bookingId is required.' });
      }

      const booking = await BookingModel.getById(bookingId);
      if (!booking) {
        return res.status(404).json({ success: false, message: 'Booking not found.' });
      }

      if (booking.customerId !== uid) {
        return res.status(403).json({ success: false, message: 'Only the customer can process payment.' });
      }

      if (booking.paymentStatus === 'completed') {
        return res.status(200).json({
          success: true,
          message: 'Payment already completed.',
          data: {
            transactionId: booking.transactionId,
            bookingId,
            amount: booking.agreedPrice,
            status: booking.status,
          }
        });
      }

      const agreedPrice = booking.agreedPrice || booking.proposedPrice || 0;
      const commission = parseFloat((agreedPrice * 0.10).toFixed(2));
      const professionalEarnings = parseFloat((agreedPrice * 0.90).toFixed(2));

      // Simulate a random transaction ID
      const transactionId = 'TXN-' + Math.random().toString(36).substr(2, 9).toUpperCase();

      // Deduct 10% commission from professional's wallet
      const { db } = require('../config/firebase');
      const walletRef = db.ref(`professionals/${booking.professionalId}/walletBalance`);
      const transactionResult = await walletRef.transaction((current) => {
        const currVal = typeof current === 'number' ? current : (current ? Number(current) : 0);
        if (isNaN(currVal)) return;
        if (currVal - commission < 0) {
          return;
        }
        return currVal - commission;
      }, { applyLocally: false });

      if (!transactionResult.committed) {
        return res.status(400).json({
          success: false,
          message: 'Insufficient professional wallet balance for commission deduction. Professional must recharge wallet.'
        });
      }

      const newBalance = transactionResult.snapshot.val();

      // Log transaction entry
      const txData = {
        bookingId,
        professionalId: booking.professionalId,
        customerId: uid,
        amount: agreedPrice,
        commission,
        transactionId,
        createdAt: Date.now(),
      };
      const { dbPush } = require('../config/firebase');
      const txId = await dbPush('transactions', txData);

      // Update booking in DB
      const { dbUpdate } = require('../config/firebase');
      await dbUpdate(`bookings/${bookingId}`, {
        status: 'confirmed',
        paymentStatus: 'completed',
        transactionId,
        agreedPrice,
        customerPhoneRevealed: true,
        professionalPhoneRevealed: true,
        paymentConfirmedAt: Date.now(),
        _updatedAt: Date.now(),
      });

      const [customerUser, professionalUser] = await Promise.all([
        UserModel.getById(uid, true),
        UserModel.getById(booking.professionalId, true),
      ]);

      // Notify professional
      if (booking.professionalId) {
        await sendNotificationToUser(
          booking.professionalId,
          '💳 Payment Confirmed',
          `Payment for ${booking.serviceType} has been completed. Job is now confirmed.`,
          { bookingId, type: 'payment_confirmed' }
        );
      }

      return res.status(200).json({
        success: true,
        message: 'Payment processed successfully.',
        data: {
          transactionId,
          bookingId,
          amount: agreedPrice,
          commissionDeducted: commission,
          professionalEarnings,
          professionalNewBalance: newBalance,
          status: 'confirmed',
          customerPhone: customerUser?.phoneNumber || 'Not available',
          professionalPhone: professionalUser?.phoneNumber || 'Not available',
          professionalName: professionalUser?.displayName || 'Professional',
        },
      });
    } catch (error) {
      console.error('processPayment error:', error);
      return res.status(500).json({ success: false, message: 'Failed to process payment.' });
    }
  },
};

module.exports = PaymentController;
