const ProfessionalModel = require('../models/professionalModel');
const UserModel = require('../models/userModel');
const BookingModel = require('../models/bookingModel');
const { dbGet } = require('../config/firebase');
const { resolveViewerContext, canViewFemaleProfessional } = require('../utils/accountPolicy');

const GeolocationController = {
  /**
   * Get nearby professionals based on customer location and filters.
   * Requires: lat, lng in query/body
   * Optional: radiusKm (default 20), serviceType, minRating, maxPrice
  */
  async getNearbyProfessionals(req, res) {
    try {
      const { lat, lng, radiusKm = 20, serviceType, minRating, maxPrice } = req.query || req.body;

      if (!lat || !lng) {
        return res.status(400).json({
          success: false,
          message: 'lat and lng are required.',
        });
      }

      const latNum = parseFloat(lat);
      const lngNum = parseFloat(lng);

      if (isNaN(latNum) || isNaN(lngNum)) {
        return res.status(400).json({
          success: false,
          message: 'lat and lng must be valid numbers.',
        });
      }

      const radiusNum = radiusKm ? parseFloat(radiusKm) : 20;

      const filters = {
        lat: latNum,
        lng: lngNum,
        radiusKm: radiusNum,
      };

      if (serviceType) filters.serviceType = serviceType;
      if (minRating) filters.minRating = parseFloat(minRating);
      if (maxPrice) filters.maxPrice = parseFloat(maxPrice);

      const viewer = await resolveViewerContext(req);
      const nearby = (await ProfessionalModel.getNearby(filters)).filter((pro) => {
        if (pro.isActive === false) return false;
        return canViewFemaleProfessional(viewer, pro);
      });

      return res.status(200).json({
        success: true,
        data: {
          professionals: nearby,
          count: nearby.length,
        },
      });
    } catch (error) {
      console.error('getNearbyProfessionals error:', error);
      return res.status(500).json({
        success: false,
        message: 'Failed to fetch nearby professionals: ' + error.message,
      });
    }
  },

  /**
   * Get professional location and phone ONLY if booking is confirmed (payment done).
   * Requires: bookingId (or booking can have professionalId + customerId)
   * Returns: professional location, phone (only if booking is confirmed)
   */
  async getProfessionalLocationForBooking(req, res) {
    try {
      const { uid: customerId } = req.user;
      const { bookingId, professionalId } = req.body;

      if (!bookingId && !professionalId) {
        return res.status(400).json({
          success: false,
          message: 'bookingId or professionalId is required.',
        });
      }

      let booking = null;
      let profId = professionalId;

      if (bookingId) {
        // Fetch booking to verify customer and check payment
        booking = await BookingModel.getById(bookingId);
        if (!booking) {
          return res.status(404).json({ success: false, message: 'Booking not found.' });
        }

        // Verify customer owns this booking
        if (booking.customerId !== customerId) {
          return res.status(403).json({
            success: false,
            message: 'You are not authorized to view this booking.',
          });
        }

        // Check if booking is confirmed (payment done)
        if (!['confirmed', 'in_progress', 'completed'].includes(booking.status)) {
          return res.status(403).json({
            success: false,
            message: `Professional location is only available after booking is confirmed. Current status: ${booking.status}`,
          });
        }

        profId = booking.professionalId;
      } else {
        // If professionalId is provided directly, try to find a confirmed booking between them
        const bookingPath = `bookings`;
        const allBookings = await dbGet(bookingPath);
        if (allBookings && typeof allBookings === 'object') {
          for (const bid in allBookings) {
            const b = allBookings[bid];
            if (b.customerId === customerId && b.professionalId === profId && ['confirmed', 'in_progress', 'completed'].includes(b.status)) {
              booking = { ...b, id: bid };
              break;
            }
          }
        }
        if (!booking) {
          return res.status(403).json({
            success: false,
            message: 'No confirmed booking found with this professional.',
          });
        }
      }

      // Fetch professional and user info
      const professional = await ProfessionalModel.getById(profId);
      const user = await UserModel.getById(profId, true);

      if (!professional || !user) {
        return res.status(404).json({
          success: false,
          message: 'Professional not found.',
        });
      }

      return res.status(200).json({
        success: true,
        data: {
          professional: {
            uid: professional.uid,
            displayName: user.displayName || '',
            photoURL: user.photoURL || '',
            phoneNumber: user.phoneNumber || 'Not provided', // Revealed only after confirmed booking
            lat: user.location?.lat || null,
            lng: user.location?.lng || null,
            address: user.address || '',
            rating: user.rating || 0,
            totalRatings: user.totalRatings || 0,
          },
          booking: {
            id: booking.id || bookingId,
            status: booking.status,
            price: booking.price,
            serviceType: booking.serviceType,
          },
        },
      });
    } catch (error) {
      console.error('getProfessionalLocationForBooking error:', error);
      return res.status(500).json({
        success: false,
        message: 'Failed to fetch professional location: ' + error.message,
      });
    }
  },

  /**
   * Update professional location (for real-time tracking during active booking).
   * Called by professional periodically during job (in_progress status).
   */
  async updateProfessionalLocation(req, res) {
    try {
      const { uid: professionalId } = req.user;
      const { lat, lng, address } = req.body;

      if (!lat || !lng) {
        return res.status(400).json({
          success: false,
          message: 'lat and lng are required.',
        });
      }

      // Update user location
      await UserModel.updateLocation(professionalId, lat, lng, address || '');

      return res.status(200).json({
        success: true,
        data: {
          message: 'Location updated successfully.',
          location: { lat, lng, address: address || '' },
        },
      });
    } catch (error) {
      console.error('updateProfessionalLocation error:', error);
      return res.status(500).json({
        success: false,
        message: 'Failed to update location: ' + error.message,
      });
    }
  },
};

module.exports = GeolocationController;
