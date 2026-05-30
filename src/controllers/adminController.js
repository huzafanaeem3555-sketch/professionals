const AdminModel = require('../models/adminModel');
const { dbGetAll, dbSet } = require('../config/firebase');

const AdminController = {
  async login(req, res) {
    try {
      const { username } = req.body;
      if (!username) {
        return res.status(400).json({ success: false, message: 'username is required.' });
      }

      if (String(username).toLowerCase() !== 'huzaifa') {
        return res.status(401).json({ success: false, message: 'Invalid admin username.' });
      }

      // Check if user exists in the 'users' node with role "admin"
      const users = await dbGetAll('users') || [];
      let adminUser = users.find(
        (u) => u.role === 'admin' && String(u.displayName).toLowerCase() === 'huzaifa'
      );

      if (!adminUser) {
        // Create admin user in 'users' node
        const adminPayload = {
          uid: 'admin_huzaifa',
          email: 'admin@serviceconnect.pk',
          displayName: 'Huzaifa',
          photoURL: '',
          phoneNumber: '+923000000000',
          role: 'admin',
          profileCompleted: true,
          createdAt: Date.now(),
          _createdAt: Date.now(),
          _updatedAt: Date.now(),
        };
        await dbSet(`users/admin_huzaifa`, adminPayload);
        adminUser = adminPayload;
      }

      const token = AdminModel.createToken(adminUser.displayName);
      return res.status(200).json({ 
        success: true, 
        data: { 
          token, 
          user: adminUser,
          expiresIn: '8h' 
        } 
      });
    } catch (error) {
      console.error('admin login error:', error);
      return res.status(500).json({ success: false, message: 'Admin login failed.' });
    }
  },

  async getStats(req, res) {
    try {
      const stats = await AdminModel.getStats();
      return res.status(200).json({ success: true, data: stats });
    } catch (error) {
      console.error('admin stats error:', error);
      return res.status(500).json({ success: false, message: 'Failed to fetch admin stats.' });
    }
  },

  async getProfessionals(req, res) {
    try {
      const professionals = await AdminModel.listProfessionals();
      return res.status(200).json({ success: true, data: professionals });
    } catch (error) {
      console.error('admin professionals error:', error);
      return res.status(500).json({ success: false, message: 'Failed to fetch professionals.' });
    }
  },

  async getCustomers(req, res) {
    try {
      const customers = await AdminModel.listCustomers();
      return res.status(200).json({ success: true, data: customers });
    } catch (error) {
      console.error('admin customers error:', error);
      return res.status(500).json({ success: false, message: 'Failed to fetch customers.' });
    }
  },

  async createUser(req, res) {
    try {
      const data = await AdminModel.createUser(req.body || {});
      return res.status(201).json({ success: true, data });
    } catch (error) {
      console.error('admin createUser error:', error);
      return res.status(400).json({
        success: false,
        message: error.message || 'Failed to create user.',
      });
    }
  },

  async getBookings(req, res) {
    try {
      const bookings = await AdminModel.listBookings();
      return res.status(200).json({ success: true, data: bookings });
    } catch (error) {
      console.error('admin bookings error:', error);
      return res.status(500).json({ success: false, message: 'Failed to fetch bookings.' });
    }
  },

  async getTransactions(req, res) {
    try {
      const transactions = await AdminModel.listTransactions();
      return res.status(200).json({ success: true, data: transactions });
    } catch (error) {
      console.error('admin transactions error:', error);
      return res.status(500).json({ success: false, message: 'Failed to fetch transactions.' });
    }
  },

  async deleteUser(req, res) {
    try {
      const { uid } = req.params;
      if (!uid) {
        return res.status(400).json({ success: false, message: 'uid parameter is required.' });
      }
      await AdminModel.deleteUser(uid);
      return res.status(200).json({ success: true, data: { message: 'User deleted successfully.' } });
    } catch (error) {
      console.error('admin deleteUser error:', error);
      return res.status(500).json({ success: false, message: 'Failed to delete user.' });
    }
  },

  async updateProfessional(req, res) {
    try {
      const { uid } = req.params;
      if (!uid) {
        return res.status(400).json({ success: false, message: 'uid parameter is required.' });
      }
      const data = await AdminModel.updateProfessional(uid, req.body || {});
      return res.status(200).json({ success: true, data });
    } catch (error) {
      console.error('admin updateProfessional error:', error);
      return res.status(500).json({ success: false, message: 'Failed to update professional.' });
    }
  },

  async getProfessionalReviews(req, res) {
    try {
      const { uid } = req.params;
      if (!uid) {
        return res.status(400).json({ success: false, message: 'uid parameter is required.' });
      }
      const reviews = await AdminModel.listProfessionalReviews(uid);
      return res.status(200).json({ success: true, data: reviews });
    } catch (error) {
      console.error('admin getProfessionalReviews error:', error);
      return res.status(500).json({ success: false, message: 'Failed to fetch reviews.' });
    }
  },

  async deleteProfessionalReview(req, res) {
    try {
      const { uid, reviewId } = req.params;
      if (!uid || !reviewId) {
        return res.status(400).json({ success: false, message: 'uid and reviewId are required.' });
      }
      const data = await AdminModel.deleteProfessionalReview(uid, reviewId);
      return res.status(200).json({ success: true, data });
    } catch (error) {
      console.error('admin deleteProfessionalReview error:', error);
      return res.status(500).json({ success: false, message: 'Failed to delete review.' });
    }
  },

  async deleteBooking(req, res) {
    try {
      const { id } = req.params;
      if (!id) {
        return res.status(400).json({ success: false, message: 'Booking id is required.' });
      }
      await AdminModel.deleteBooking(id);
      return res.status(200).json({ success: true, data: { message: 'Booking deleted successfully.' } });
    } catch (error) {
      console.error('admin deleteBooking error:', error);
      return res.status(500).json({ success: false, message: 'Failed to delete booking.' });
    }
  },

  async clearAllData(req, res) {
    try {
      await AdminModel.clearAllData();
      return res.status(200).json({
        success: true,
        data: { message: 'All non-admin app data cleared successfully.' },
      });
    } catch (error) {
      console.error('admin clearAllData error:', error);
      return res.status(500).json({
        success: false,
        message: 'Failed to clear app data.',
      });
    }
  },
};

module.exports = AdminController;
