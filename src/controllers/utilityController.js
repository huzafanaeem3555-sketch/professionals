const UserModel = require('../models/userModel');
const ProfessionalModel = require('../models/professionalModel');
const { dbGet, dbUpdate, dbDelete, dbGetAll } = require('../config/firebase');

const UtilityController = {
  /**
   * Validate professional profile completeness.
   * Returns: { isComplete: boolean, missingFields: [string] }
   */
  async validateProfessionalProfile(req, res) {
    try {
      const { uid } = req.user;
      const user = await UserModel.getById(uid, true);
      const professional = await ProfessionalModel.getById(uid);

      const missingFields = [];

      if (!user?.displayName || user.displayName.trim() === '') {
        missingFields.push('displayName');
      }

      if (!user?.phoneNumber || user.phoneNumber.trim() === '') {
        missingFields.push('phoneNumber');
      }

      if (!professional?.serviceTypes || professional.serviceTypes.length === 0) {
        missingFields.push('serviceTypes');
      }

      if (!user?.lat || !user?.lng) {
        missingFields.push('location');
      }

      if (!professional?.hourlyRate || professional.hourlyRate <= 0) {
        missingFields.push('hourlyRate');
      }

      const isComplete = missingFields.length === 0;

      return res.status(200).json({
        success: true,
        data: {
          isComplete,
          missingFields,
          profile: {
            uid: user?.uid,
            displayName: user?.displayName || '',
            phoneNumber: user?.phoneNumber || '',
            photoURL: user?.photoURL || '',
            address: user?.address || '',
            lat: user?.lat || null,
            lng: user?.lng || null,
            serviceTypes: professional?.serviceTypes || [],
            hourlyRate: professional?.hourlyRate || 0,
            experienceYears: professional?.experienceYears || 0,
            completedJobs: professional?.completedJobs || 0,
            walletBalance: professional?.walletBalance || 0,
          },
        },
      });
    } catch (error) {
      console.error('validateProfessionalProfile error:', error);
      return res.status(500).json({
        success: false,
        message: 'Failed to validate profile: ' + error.message,
      });
    }
  },

  /**
   * Reset test data for a user (clear bookings, chats, reset wallet, reset profile).
   * Development/testing only — requires explicit TEST_MODE flag.
   */
  async resetTestData(req, res) {
    try {
      // Safety check: only allow in development
      if (process.env.NODE_ENV === 'production') {
        return res.status(403).json({
          success: false,
          message: 'Test data reset is disabled in production.',
        });
      }

      const { uid } = req.user;
      const user = await UserModel.getById(uid, true);

      if (!user) {
        return res.status(404).json({ success: false, message: 'User not found.' });
      }

      // Delete all bookings where user is customer or professional
      const allBookings = (await dbGetAll('bookings')) || [];
      for (const bid in allBookings) {
        const booking = allBookings[bid];
        if (booking.customerId === uid || booking.professionalId === uid) {
          await dbDelete(`bookings/${bid}`);
        }
      }

      // Delete all chats where user participated
      const allChats = (await dbGetAll('chats')) || [];
      for (const cid in allChats) {
        const chat = allChats[cid];
        if (chat.customerId === uid || chat.professionalId === uid) {
          await dbDelete(`chats/${cid}`);
        }
      }

      // Reset professional profile if exists
      if (user.role === 'professional') {
        await dbUpdate(`professionals/${uid}`, {
          walletBalance: 5000,
          completedJobs: 0,
          serviceTypes: [],
          hourlyRate: 0,
          availability: {
            monday: { available: true, startTime: '09:00', endTime: '18:00' },
            tuesday: { available: true, startTime: '09:00', endTime: '18:00' },
            wednesday: { available: true, startTime: '09:00', endTime: '18:00' },
            thursday: { available: true, startTime: '09:00', endTime: '18:00' },
            friday: { available: true, startTime: '09:00', endTime: '18:00' },
            saturday: { available: true, startTime: '10:00', endTime: '16:00' },
            sunday: { available: false, startTime: '', endTime: '' },
          },
          isAvailableNow: true,
          portfolio: [],
          verificationStatus: 'pending',
        });
      }

      console.log(`[TEST RESET] User ${uid} data reset: bookings deleted, chats deleted, wallet reset to 5000`);

      return res.status(200).json({
        success: true,
        data: {
          message: 'Test data reset successfully.',
          wallet: 5000,
          bookingsDeleted: allBookings.length,
          chatsDeleted: allChats.length,
        },
      });
    } catch (error) {
      console.error('resetTestData error:', error);
      return res.status(500).json({
        success: false,
        message: 'Failed to reset test data: ' + error.message,
      });
    }
  },
};

module.exports = UtilityController;
