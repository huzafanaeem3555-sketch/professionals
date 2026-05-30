const BookingModel = require('../models/bookingModel');
const UserModel = require('../models/userModel');
const ProfessionalModel = require('../models/professionalModel');
const { sendNotificationToUser } = require('../utils/notifications');

const CustomerController = {
  /**
   * POST /api/customers/request-booking
   * Create a new booking request (status: pending_payment).
   */
  async requestBooking(req, res) {
    try {
      const { uid: customerId } = req.user;
      const {
        professionalId,
        serviceType,
        scheduledTime,
        location,
        address,
        description,
        agreedPrice,
      } = req.body;

      // Validation
      if (!professionalId || !serviceType || !agreedPrice) {
        return res.status(400).json({
          success: false,
          message: 'professionalId, serviceType, and agreedPrice are required.',
        });
      }

      if (agreedPrice <= 0) {
        return res.status(400).json({
          success: false,
          message: 'agreedPrice must be greater than 0.',
        });
      }

      if (customerId === professionalId) {
        return res.status(400).json({
          success: false,
          message: 'You cannot book your own services.',
        });
      }

      // Verify professional exists
      const [professional, professionalUser] = await Promise.all([
        ProfessionalModel.getById(professionalId),
        UserModel.getById(professionalId, false),
      ]);

      if (!professional || !professionalUser) {
        return res.status(404).json({
          success: false,
          message: 'Professional not found.',
        });
      }

      // Create booking
      const booking = await BookingModel.create({
        customerId,
        professionalId,
        serviceType,
        scheduledTime,
        location,
        address,
        description,
        agreedPrice,
      });

      // Send notification to professional
      if (professionalId) {
        await sendNotificationToUser(
          professionalId,
          '📋 New Booking Request!',
          `You have a new booking request for ${serviceType}. Amount: Rs. ${agreedPrice}`,
          { bookingId: booking.bookingId, type: 'new_booking' }
        );
      }

      return res.status(201).json({
        success: true,
        message: 'Booking request created. Please complete payment to confirm.',
        data: {
          bookingId: booking.bookingId,
          status: booking.status,
          agreedPrice: booking.agreedPrice,
          platformCommission: booking.platformCommission,
          professionalEarnings: booking.professionalEarnings,
          easypaisaNumber: process.env.EASYPAISA_ACCOUNT_NUMBER || '03455876761',
          paymentInstructions: `Please send Rs. ${booking.platformCommission} (10% commission) to EasyPaisa number ${process.env.EASYPAISA_ACCOUNT_NUMBER || '03455876761'} to confirm your booking.`,
        },
      });
    } catch (error) {
      console.error('requestBooking error:', error);
      return res.status(500).json({
        success: false,
        message: 'Failed to create booking. Please try again.',
      });
    }
  },

  /**
   * GET /api/customers/my-bookings
   * List all bookings for the authenticated customer.
   */
  async getMyBookings(req, res) {
    try {
      const { uid: customerId } = req.user;
      const bookings = await BookingModel.getByCustomerId(customerId);

      // Enrich with professional info (no phone)
      const enriched = await Promise.all(
        bookings.map(async (booking) => {
          const [professional, professionalUser] = await Promise.all([
            ProfessionalModel.getById(booking.professionalId),
            UserModel.getById(booking.professionalId, false),
          ]);

          return {
            ...booking,
            professionalInfo: professionalUser
              ? {
                  displayName: professionalUser.displayName,
                  photoURL: professionalUser.photoURL,
                  rating: professionalUser.rating,
                }
              : null,
          };
        })
      );

      return res.status(200).json({
        success: true,
        count: enriched.length,
        data: enriched,
      });
    } catch (error) {
      console.error('getMyBookings error:', error);
      return res.status(500).json({
        success: false,
        message: 'Failed to fetch bookings.',
      });
    }
  },

  /**
   * POST /api/customers/rate-professional
   * Rate and review a professional after job completion.
   */
  async rateProfessional(req, res) {
    try {
      const { uid: customerId } = req.user;
      const { bookingId, rating, review } = req.body;

      if (!bookingId || !rating) {
        return res.status(400).json({
          success: false,
          message: 'bookingId and rating are required.',
        });
      }

      if (rating < 1 || rating > 5) {
        return res.status(400).json({
          success: false,
          message: 'Rating must be between 1 and 5.',
        });
      }

      const booking = await BookingModel.getById(bookingId);

      if (!booking) {
        return res.status(404).json({
          success: false,
          message: 'Booking not found.',
        });
      }

      if (booking.customerId !== customerId) {
        return res.status(403).json({
          success: false,
          message: 'You can only rate your own bookings.',
        });
      }

      if (booking.status !== 'completed') {
        return res.status(400).json({
          success: false,
          message: 'You can only rate after the job is completed.',
        });
      }

      if (booking.customerRating) {
        return res.status(400).json({
          success: false,
          message: 'You have already rated this booking.',
        });
      }

      // Save rating to booking
      await BookingModel.addRating(bookingId, rating, review);

      // Update professional's average rating
      await UserModel.updateRating(booking.professionalId, rating);

      return res.status(200).json({
        success: true,
        message: 'Rating submitted. Thank you for your feedback!',
      });
    } catch (error) {
      console.error('rateProfessional error:', error);
      return res.status(500).json({
        success: false,
        message: 'Failed to submit rating.',
      });
    }
  },
};

module.exports = CustomerController;
