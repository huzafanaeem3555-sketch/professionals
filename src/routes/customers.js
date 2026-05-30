const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middleware/auth');
const BookingModel = require('../models/bookingModel');
const PaymentModel = require('../models/paymentModel');
const UserModel = require('../models/userModel');
const ProfessionalModel = require('../models/professionalModel');
const { sendNotificationToUser } = require('../utils/notifications');
const { dbGet } = require('../config/firebase');

// POST /api/customers/request-booking
router.post('/request-booking', verifyToken, async (req, res) => {
  try {
    const { professionalId, serviceType, agreedPrice, scheduledTime, location, address, description } = req.body;

    if (!professionalId || !serviceType || !agreedPrice) {
      return res.status(400).json({
        success: false,
        message: 'professionalId, serviceType, and agreedPrice are required.',
      });
    }

    if (agreedPrice < 100) {
      return res.status(400).json({ success: false, message: 'Minimum price is Rs. 100.' });
    }

    // Verify professional exists
    const pro = await ProfessionalModel.getById(professionalId);
    if (!pro) {
      return res.status(404).json({ success: false, message: 'Professional not found.' });
    }

    const booking = await BookingModel.create({
      customerId: req.user.uid,
      professionalId,
      serviceType,
      agreedPrice: parseFloat(agreedPrice),
      scheduledTime: scheduledTime || null,
      location,
      address,
      description,
    });

    // Get customer and professional details for contact info
    const customerUser = await UserModel.getById(req.user.uid, true);
    const proUser = await UserModel.getById(professionalId, true);

    // Notify professional (don't wait)
    if (professionalId) {
      sendNotificationToUser(
        professionalId,
        '🔔 New Booking Request!',
        `${req.user.displayName || 'A customer'} wants to hire you for ${serviceType.toUpperCase()}`,
        { bookingId: booking.bookingId, type: 'new_booking' }
      );
    }

    return res.status(201).json({
      success: true,
      message: 'Booking confirmed. Contact details are available.',
      data: {
        bookingId: booking.bookingId,
        status: booking.status,
        contactInfo: {
          name: proUser?.displayName,
          phone: proUser?.phoneNumber || 'Not provided',
          photoURL: proUser?.photoURL,
        },
        customerContact: {
          name: customerUser?.displayName,
          phone: customerUser?.phoneNumber || 'Not provided',
          address: booking.address || customerUser?.address || '',
        },
        phoneRevealed: true,
      },
    });
  } catch (error) {
    console.error('request-booking error:', error);
    return res.status(500).json({ success: false, message: 'Failed to create booking.' });
  }
});

// GET /api/customers/my-bookings
router.get('/my-bookings', verifyToken, async (req, res) => {
  try {
    const bookings = await BookingModel.getByCustomerId(req.user.uid);
    return res.json({ success: true, count: bookings.length, data: bookings });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Failed to fetch bookings.' });
  }
});

// POST /api/customers/rate-professional
router.post('/rate-professional', verifyToken, async (req, res) => {
  try {
    const { bookingId, rating, review } = req.body;
    if (!bookingId || !rating || rating < 1 || rating > 5) {
      return res.status(400).json({ success: false, message: 'bookingId and rating (1-5) are required.' });
    }

    const booking = await BookingModel.getById(bookingId);
    if (!booking) return res.status(404).json({ success: false, message: 'Booking not found.' });
    if (booking.customerId !== req.user.uid) {
      return res.status(403).json({ success: false, message: 'Not authorized.' });
    }
    if (booking.status !== 'completed') {
      return res.status(400).json({ success: false, message: 'Can only rate completed bookings.' });
    }
    if (booking.customerRating > 0) {
      return res.status(400).json({ success: false, message: 'Already rated.' });
    }

    await BookingModel.addRating(bookingId, rating, review);
    await UserModel.updateRating(booking.professionalId, rating);

    return res.json({ success: true, message: '⭐ Rating submitted! Thank you.' });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Failed to submit rating.' });
  }
});

module.exports = router;
