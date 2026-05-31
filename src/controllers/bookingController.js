const BookingModel = require('../models/bookingModel');
const ProfessionalModel = require('../models/professionalModel');
const UserModel = require('../models/userModel');
const {
  sendNotificationToUser,
  sendNewBookingNotification,
  sendPriceOfferNotification,
  sendBookingAcceptedNotification,
  sendJobCompletedByCustomerNotification,
} = require('../utils/notifications');
const { deductCommission } = require('../services/walletService');
const ServiceAnalyticsModel = require('../models/serviceAnalyticsModel');

const BookingController = {
  // POST /api/bookings - Customer creates booking
  async createBooking(req, res) {
    try {
      const customerId = req.user.uid;
      const {
        professionalId,
        serviceType,
        proposedPrice,
        customerProblem,
        customerLocation,
        customerAddress,
        description,
        address,
        scheduledTime,
        contactMethod,
      } = req.body;

      if (!professionalId || !serviceType) {
        return res.status(400).json({
          success: false,
          message: 'professionalId and serviceType are required.',
        });
      }

      let proUid = professionalId;
      let professional = await ProfessionalModel.getById(professionalId);
      if (!professional) {
        professional = await ProfessionalModel.getByPhone(professionalId);
        if (professional?.uid) proUid = professional.uid;
      }
      if (!professional) {
        return res.status(404).json({
          success: false,
          message: 'Professional not found.',
        });
      }

      const customerUser = await UserModel.getById(customerId, true);
      const proUser = await UserModel.getById(proUid, true);

      const proAddress = customerAddress || address || proUser?.address || professional.location?.address || '';

      const booking = await BookingModel.create({
        customerId,
        professionalId: proUid,
        serviceType,
        proposedPrice: parseFloat(proposedPrice || 0),
        customerProblem: customerProblem || description || '',
        customerLocation: customerLocation || { lat: 0, lng: 0 },
        customerAddress: proAddress,
        address: proAddress,
        description: description || customerProblem || '',
        scheduledTime: scheduledTime || null,
        customerPhone: customerUser?.phoneNumber || '',
        customerName: customerUser?.displayName || req.user.displayName || 'Customer',
        professionalPhone: professional.phoneNumber || professional.phone || '',
        professionalLocation: professional.location || null,
        contactMethod: req.body?.contactMethod || 'direct_contact',
      });
      await ServiceAnalyticsModel.incrementService(serviceType, 'bookingCount').catch(() => null);

      // Send phone notification to professional. Android shows this even when
      // the Flutter app is closed because the payload includes notification.
      const customerName = customerUser?.displayName || req.user.displayName || 'A customer';
      const contactLabel =
        contactMethod === 'whatsapp'
          ? 'WhatsApp Now'
          : contactMethod === 'call'
            ? 'Call Now'
            : 'booking request';
      await sendNotificationToUser(
        proUid,
        'New Booking Request',
        `${customerName} sent a ${contactLabel} for ${String(serviceType).replace(/_/g, ' ')}.`,
        {
          type: 'new_booking',
          bookingId: booking.bookingId,
          contactMethod: contactMethod || '',
          serviceType: serviceType || '',
          customerName,
          customerPhone: customerUser?.phoneNumber || '',
          customerId,
          screen: 'notifications',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          timestamp: Date.now().toString(),
        }
      );

      return res.status(201).json({
        success: true,
        message: 'Service request sent successfully.',
        data: {
          ...booking,
          status: 'pending_acceptance',
          contactInfo: {
            phone: professional.phoneNumber || professional.phone || '',
            location: professional.location || null,
            name: professional.name || proUser?.displayName || 'Professional',
          },
          phoneRevealed: true,
        },
      });
    } catch (error) {
      console.error('createBooking error:', error);
      return res.status(500).json({
        success: false,
        message: 'Failed to create booking.',
      });
    }
  },

  // GET /api/bookings/my - Get user's bookings
  async getMyBookings(req, res) {
    try {
      const uid = req.user.uid;

      const bookings = await BookingModel.getByUserId(uid);

      const enrichedBookings = await Promise.all(bookings.map(async (booking) => {
        const isCustomer = booking.customerId === uid;
        const otherUserId = isCustomer ? booking.professionalId : booking.customerId;
        const otherUser = await UserModel.getById(otherUserId, true);

        const showPhone = true;

        return {
          ...booking,
          otherUserName: otherUser?.displayName || 'User',
          otherUserPhoto: otherUser?.photoURL || '',
          otherUserPhone: showPhone ? (otherUser?.phoneNumber || 'Not provided') : 'Hidden until agreement',
          isCustomer
        };
      }));

      return res.status(200).json({
        success: true,
        data: enrichedBookings,
        count: enrichedBookings.length
      });
    } catch (error) {
      console.error('getMyBookings error:', error);
      return res.status(500).json({
        success: false,
        message: 'Failed to fetch bookings.'
      });
    }
  },

  // GET /api/bookings/:bookingId - Get single booking details
  async getBooking(req, res) {
    try {
      const { bookingId } = req.params;
      const uid = req.user.uid;

      const booking = await BookingModel.getById(bookingId);
      if (!booking) {
        return res.status(404).json({
          success: false,
          message: 'Booking not found.'
        });
      }

      if (booking.customerId !== uid && booking.professionalId !== uid) {
        return res.status(403).json({
          success: false,
          message: 'Access denied.'
        });
      }

      const isCustomer = booking.customerId === uid;
      const otherUserId = isCustomer ? booking.professionalId : booking.customerId;

      const [otherUser, professionalProfile] = await Promise.all([
        UserModel.getById(otherUserId, true),
        isCustomer ? ProfessionalModel.getById(booking.professionalId) : Promise.resolve(null)
      ]);

      const showPhone = true;

      return res.status(200).json({
        success: true,
        data: {
          ...booking,
          otherUserName: otherUser?.displayName || 'User',
          otherUserPhoto: otherUser?.photoURL || '',
          otherUserPhone: showPhone ? (otherUser?.phoneNumber || 'Not provided') : 'Hidden until agreement',
          professionalLocation: professionalProfile?.location || null,
          isCustomer
        }
      });
    } catch (error) {
      console.error('getBooking error:', error);
      return res.status(500).json({
        success: false,
        message: 'Failed to fetch booking.'
      });
    }
  },

  // POST /api/bookings/:id/propose-price - Professional proposes price
  async proposePrice(req, res) {
    try {
      const { bookingId } = req.params;
      const { price } = req.body;
      const professionalId = req.user.uid;

      if (!price) {
        return res.status(400).json({ success: false, message: 'Price is required.' });
      }

      const booking = await BookingModel.getById(bookingId);
      if (!booking) {
        return res.status(404).json({ success: false, message: 'Booking not found.' });
      }

      if (booking.professionalId !== professionalId) {
        return res.status(403).json({ success: false, message: 'Only the assigned professional can propose a price.' });
      }

      const updatedBooking = await BookingModel.proposePrice(bookingId, parseFloat(price));

      // Send notification to customer
      const professionalUser = await UserModel.getById(professionalId, true);
      const professionalName = professionalUser?.displayName || 'Professional';
      await sendPriceOfferNotification(booking.customerId, professionalName, parseFloat(price), bookingId);

      return res.status(200).json({
        success: true,
        message: 'Price proposal sent successfully.',
        data: updatedBooking
      });
    } catch (error) {
      console.error('proposePrice error:', error);
      return res.status(500).json({ success: false, message: 'Failed to send price proposal.' });
    }
  },

  // POST /api/bookings/:id/counter-price - Customer counters price
  async counterPrice(req, res) {
    try {
      const { bookingId } = req.params;
      const { counterPrice } = req.body;
      const customerId = req.user.uid;

      if (!counterPrice) {
        return res.status(400).json({ success: false, message: 'Counter price is required.' });
      }

      const booking = await BookingModel.getById(bookingId);
      if (!booking) {
        return res.status(404).json({ success: false, message: 'Booking not found.' });
      }

      if (booking.customerId !== customerId) {
        return res.status(403).json({ success: false, message: 'Only the customer can counter the price.' });
      }

      const updatedBooking = await BookingModel.counterPrice(bookingId, parseFloat(counterPrice));

      // Send notification to professional
      const customerUser = await UserModel.getById(customerId, true);
      const customerName = customerUser?.displayName || 'Customer';
      await sendNotificationToUser(
        booking.professionalId,
        '💸 Counter Bid Received',
        `${customerName} proposed a counter price of Rs. ${counterPrice}.`,
        { bookingId, type: 'price_update', counterPrice: counterPrice.toString() }
      );

      return res.status(200).json({
        success: true,
        message: 'Counter offer proposed successfully.',
        data: updatedBooking
      });
    } catch (error) {
      console.error('counterPrice error:', error);
      return res.status(500).json({ success: false, message: 'Failed to propose counter offer.' });
    }
  },

  // POST /api/bookings/:id/accept-price - Accepts price
  async acceptPrice(req, res) {
    try {
      const { bookingId } = req.params;
      const { price } = req.body;
      const uid = req.user.uid;

      if (!price) {
        return res.status(400).json({ success: false, message: 'Price is required to accept.' });
      }

      const booking = await BookingModel.getById(bookingId);
      if (!booking) {
        return res.status(404).json({ success: false, message: 'Booking not found.' });
      }

      if (booking.customerId !== uid && booking.professionalId !== uid) {
        return res.status(403).json({ success: false, message: 'Access denied.' });
      }

      const updatedBooking = await BookingModel.acceptPrice(bookingId, parseFloat(price));

      // Notify other user
      const isCustomer = booking.customerId === uid;
      const otherUserId = isCustomer ? booking.professionalId : booking.customerId;
      const otherUser = await UserModel.getById(otherUserId, true);
      const otherName = otherUser?.displayName || (isCustomer ? 'Professional' : 'Customer');

      await sendNotificationToUser(
        otherUserId,
        '🤝 Deal Confirmed!',
        `${otherName} has accepted the price of Rs. ${price}. Contact details are now available.`,
        { bookingId, type: 'bid_agreed', price: price.toString() }
      );

      return res.status(200).json({
        success: true,
        message: 'Price accepted. Deal confirmed and contact details revealed.',
        data: updatedBooking
      });
    } catch (error) {
      console.error('acceptPrice error:', error);
      return res.status(500).json({ success: false, message: 'Failed to accept price.' });
    }
  },

  // POST /api/bookings/:id/accept - Legacy accept booking
  async acceptBooking(req, res) {
    try {
      const { bookingId } = req.params;
      const uid = req.user.uid;

      const booking = await BookingModel.getById(bookingId);
      if (!booking) {
        return res.status(404).json({ success: false, message: 'Booking not found.' });
      }

      if (booking.customerId !== uid && booking.professionalId !== uid) {
        return res.status(403).json({ success: false, message: 'Access denied.' });
      }

      const price = Number(
        req.body?.price ||
        booking.proposedPrice ||
        booking.counterPrice ||
        booking.agreedPrice ||
        0
      );
      if (!price || price <= 0) {
        return res.status(400).json({ success: false, message: 'No valid offer price found.' });
      }

      const updatedBooking = await BookingModel.acceptPrice(bookingId, price);

      // Send notification
      const isCustomer = booking.customerId === uid;
      const otherUserId = isCustomer ? booking.professionalId : booking.customerId;
      await sendBookingAcceptedNotification(otherUserId, price, bookingId);

      return res.status(200).json({
        success: true,
        message: 'Booking confirmed. Contact details revealed.',
        data: updatedBooking,
      });
    } catch (error) {
      console.error('acceptBooking error:', error);
      return res.status(500).json({ success: false, message: 'Failed to accept booking.' });
    }
  },

  // POST /api/bookings/:id/reject - Rejects booking
  async rejectBooking(req, res) {
    try {
      const { bookingId } = req.params;
      const uid = req.user.uid;

      const booking = await BookingModel.getById(bookingId);
      if (!booking) {
        return res.status(404).json({ success: false, message: 'Booking not found.' });
      }

      if (booking.customerId !== uid && booking.professionalId !== uid) {
        return res.status(403).json({ success: false, message: 'Access denied.' });
      }

      await BookingModel.rejectBooking(bookingId);

      // Notify other user
      const isCustomer = booking.customerId === uid;
      const otherUserId = isCustomer ? booking.professionalId : booking.customerId;
      const otherUser = await UserModel.getById(otherUserId, true);

      if (otherUser?.fcmToken) {
        await sendNotificationToUser(
          otherUserId,
          '❌ Service Request Cancelled',
          `The ${isCustomer ? 'customer' : 'professional'} has cancelled the request.`,
          { bookingId, type: 'booking_cancelled' }
        );
      }

      return res.status(200).json({
        success: true,
        message: 'Booking rejected.',
        data: { bookingId, status: 'rejected' }
      });
    } catch (error) {
      console.error('rejectBooking error:', error);
      return res.status(500).json({ success: false, message: 'Failed to reject booking.' });
    }
  },

  // POST /api/bookings/:id/start - Professional starts job
  async startJob(req, res) {
    try {
      const { bookingId } = req.params;
      const professionalId = req.user.uid;

      const booking = await BookingModel.getById(bookingId);
      if (!booking) {
        return res.status(404).json({ success: false, message: 'Booking not found.' });
      }

      if (booking.professionalId !== professionalId) {
        return res.status(403).json({ success: false, message: 'Only the assigned professional can start the job.' });
      }

      if (booking.status !== 'confirmed') {
        return res.status(400).json({ success: false, message: `Cannot start job. Current status: ${booking.status}` });
      }

      const updated = await BookingModel.startJob(bookingId);

      // Notify customer
      await sendNotificationToUser(
        booking.customerId,
        '🛠️ Job Started',
        'The professional has started working on your request.',
        { bookingId, type: 'job_started' }
      );

      return res.status(200).json({
        success: true,
        message: 'Job started successfully.',
        data: updated
      });
    } catch (error) {
      console.error('startJob error:', error);
      return res.status(500).json({ success: false, message: 'Failed to start job.' });
    }
  },

  // POST /api/bookings/:id/complete - Professional completes job
  async completeBooking(req, res) {
    try {
      const { bookingId } = req.params;
      const professionalId = req.user.uid;

      const booking = await BookingModel.getById(bookingId);
      if (!booking) {
        return res.status(404).json({ success: false, message: 'Booking not found.' });
      }

      if (booking.professionalId !== professionalId) {
        return res.status(403).json({ success: false, message: 'Only the assigned professional can complete the job.' });
      }

      if (booking.status !== 'customer_confirmed') {
        return res.status(400).json({ success: false, message: `Cannot complete job. Current status: ${booking.status}` });
      }

      const updated = await BookingModel.professionalConfirmCompletion(bookingId);
      const finalAmount = Number(
        booking.agreedPrice || booking.proposedPrice || booking.counterPrice || 0,
      );

      // Deduct 10% commission
      const walletRes = await deductCommission({
        professionalId: professionalId,
        bookingId,
        amount: finalAmount,
      });

      if (!walletRes.success) {
        return res.status(walletRes.statusCode || 500).json({
          success: false,
          message: walletRes.message || 'Failed to deduct commission after completion.',
        });
      }

      // Notify customer
      await sendNotificationToUser(
        booking.customerId,
        '🎉 Job Completed',
        'The professional has marked the job as completed. Thank you for using Service Connect!',
        { bookingId, type: 'job_completed' }
      );

      return res.status(200).json({
        success: true,
        message: 'Job completed successfully and commission deducted.',
        data: {
          ...updated,
          wallet: walletRes.data,
        }
      });
    } catch (error) {
      console.error('completeBooking error:', error);
      return res.status(500).json({ success: false, message: 'Failed to complete booking.' });
    }
  },

  // POST /api/bookings/:id/customer-complete - Customer confirms completion
  async customerComplete(req, res) {
    try {
      const { bookingId } = req.params;
      const customerId = req.user.uid;

      const booking = await BookingModel.getById(bookingId);
      if (!booking) {
        return res.status(404).json({ success: false, message: 'Booking not found.' });
      }

      if (booking.customerId !== customerId) {
        return res.status(403).json({ success: false, message: 'Only customer can confirm completion.' });
      }

      if (booking.status !== 'in_progress') {
        return res.status(400).json({ success: false, message: `Cannot confirm completion. Current status: ${booking.status}` });
      }

      const updated = await BookingModel.customerConfirmCompletion(bookingId);

      // Send notification to professional
      await sendJobCompletedByCustomerNotification(booking.professionalId, booking.customerName || 'Customer', bookingId);

      return res.status(200).json({
        success: true,
        message: 'Customer completion confirmed. Waiting for professional confirmation.',
        data: updated,
      });
    } catch (error) {
      console.error('customerComplete error:', error);
      return res.status(500).json({ success: false, message: 'Failed to confirm completion.' });
    }
  },

  // DELETE /api/bookings/:bookingId - Cancel booking
  async cancelBooking(req, res) {
    try {
      const { bookingId } = req.params;
      const uid = req.user.uid;

      const booking = await BookingModel.getById(bookingId);
      if (!booking) {
        return res.status(404).json({ success: false, message: 'Booking not found.' });
      }

      if (booking.customerId !== uid) {
        return res.status(403).json({ success: false, message: 'Only the customer can cancel the booking request.' });
      }

      await BookingModel.cancel(bookingId);

      // Notify professional
      await sendNotificationToUser(
        booking.professionalId,
        '❌ Request Cancelled',
        'The customer has cancelled their service request.',
        { bookingId, type: 'booking_cancelled' }
      );

      return res.status(200).json({
        success: true,
        message: 'Booking request cancelled.',
        data: { bookingId, status: 'cancelled' }
      });
    } catch (error) {
      console.error('cancelBooking error:', error);
      return res.status(500).json({ success: false, message: 'Failed to cancel booking.' });
    }
  },

  // POST /api/bookings/:bookingId/rate - Customer rates professional
  async rateBooking(req, res) {
    try {
      const { bookingId } = req.params;
      const { rating, review } = req.body;
      const customerId = req.user.uid;

      const booking = await BookingModel.getById(bookingId);
      if (!booking) {
        return res.status(404).json({ success: false, message: 'Booking not found.' });
      }

      if (booking.customerId !== customerId) {
        return res.status(403).json({ success: false, message: 'Only the customer can rate this booking.' });
      }

      if (booking.status !== 'completed') {
        return res.status(400).json({ success: false, message: 'Booking must be completed before rating.' });
      }

      if (Number(booking.customerRating || 0) > 0) {
        return res.status(409).json({ success: false, message: 'This booking has already been rated.' });
      }

      if (!rating || rating < 1 || rating > 5) {
        return res.status(400).json({ success: false, message: 'Rating must be between 1 and 5.' });
      }

      await BookingModel.addRating(bookingId, rating, review || '');
      await ProfessionalModel.updateRating(booking.professionalId, rating);
      await sendNotificationToUser(
        booking.professionalId,
        'New rating received',
        `Customer rated your work ${rating}/5.`,
        { bookingId, type: 'rating_received', rating: String(rating) }
      ).catch(() => null);

      return res.status(200).json({
        success: true,
        message: 'Rating submitted successfully.',
        data: { bookingId, rating, review: review || '' }
      });
    } catch (error) {
      console.error('rateBooking error:', error);
      return res.status(500).json({ success: false, message: 'Failed to submit rating.' });
    }
  },

  // Legacy support
  async getCustomerBookings(req, res) {
    return BookingController.getMyBookings(req, res);
  },
  async getProfessionalBookings(req, res) {
    return BookingController.getMyBookings(req, res);
  },

  // GET /api/bookings/professional/:id
  async getProfessionalBookingsById(req, res) {
    try {
      const { id } = req.params;
      const uid = req.user.uid;

      if (uid !== id) {
        return res.status(403).json({
          success: false,
          message: 'Access denied.',
        });
      }

      const bookings = await BookingModel.getByProfessionalId(id);
      return res.status(200).json({
        success: true,
        data: bookings,
        count: bookings.length,
      });
    } catch (error) {
      console.error('getProfessionalBookingsById error:', error);
      return res.status(500).json({
        success: false,
        message: 'Failed to fetch professional bookings.',
      });
    }
  }
};

module.exports = BookingController;
