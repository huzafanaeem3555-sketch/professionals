const jwt = require('jsonwebtoken');
const { dbGet, dbGetAll, dbSet, dbUpdate, dbDelete } = require('../config/firebase');

const ADMIN_TOKEN_SECRET = process.env.ADMIN_JWT_SECRET || process.env.JWT_SECRET || 'service-connect-secret-change-in-production';
const ADMIN_TOKEN_EXPIRES = process.env.ADMIN_TOKEN_EXPIRES || '8h';

const AdminModel = {
  createToken(username) {
    return jwt.sign({ username, role: 'admin' }, ADMIN_TOKEN_SECRET, { expiresIn: ADMIN_TOKEN_EXPIRES });
  },

  verifyToken(token) {
    return jwt.verify(token, ADMIN_TOKEN_SECRET);
  },

  async getStats() {
    const professionals = await dbGetAll('professionals');
    const users = await dbGetAll('users') || [];
    const bookings = await dbGetAll('bookings') || [];
    const completed = bookings.filter((b) => b.status === 'completed');

    // Calculate commission as 10% of agreed/proposed price of completed bookings
    const commissionFromBookings = completed.reduce((sum, b) => {
      const price = b.agreedPrice || b.proposedPrice || 0;
      return sum + (price * 0.10);
    }, 0);

    return {
      totalProfessionals: professionals.length,
      totalCustomers: users.filter((u) => u.role === 'customer').length,
      totalBookings: bookings.length,
      totalCompletedJobs: completed.length,
      totalPendingJobs: bookings.filter((b) => ['pending_acceptance', 'pending_payment', 'confirmed', 'in_progress', 'pending_customer_response', 'pending_professional_response'].includes(b.status)).length,
      totalCommission: parseFloat(commissionFromBookings.toFixed(2)),
    };
  },

  async listProfessionals() {
    const professionals = await dbGetAll('professionals') || [];
    const users = await dbGetAll('users') || [];
    return professionals.map((pro) => {
      const user = users.find((u) => u.uid === pro.uid) || {};
      return {
        ...pro,
        displayName: user.displayName || 'Professional',
        email: user.email || '',
        phoneNumber: user.phoneNumber || '',
        rating: user.rating || pro.rating || 0,
        totalJobs: pro.completedJobs || 0,
      };
    });
  },

  async listCustomers() {
    const users = await dbGetAll('users') || [];
    const bookings = await dbGetAll('bookings') || [];
    const customers = users.filter((user) => user.role === 'customer');
    return customers.map((c) => {
      const count = bookings.filter((b) => b.customerId === c.uid).length;
      return {
        ...c,
        totalBookings: count,
      };
    });
  },

  async listBookings() {
    const bookings = await dbGetAll('bookings') || [];
    const users = await dbGetAll('users') || [];
    return bookings.map((b) => {
      const customer = users.find((u) => u.uid === b.customerId) || {};
      const professional = users.find((u) => u.uid === b.professionalId) || {};
      return {
        ...b,
        customerName: customer.displayName || 'Customer',
        professionalName: professional.displayName || 'Professional',
      };
    });
  },

  async listTransactions() {
    const transactions = await dbGetAll('transactions') || [];
    const users = await dbGetAll('users') || [];
    return transactions.map((tx) => {
      const pro = users.find((u) => u.uid === tx.professionalId) || {};
      return {
        ...tx,
        professionalName: pro.displayName || 'Professional',
      };
    });
  },

  async deleteUser(uid) {
    const bookings = await dbGetAll('bookings') || [];
    const payments = await dbGetAll('payments') || [];
    const transactions = await dbGetAll('transactions') || [];
    const bookingIds = bookings.filter((b) => b.customerId === uid || b.professionalId === uid).map((b) => b.bookingId);

    for (const bookingId of bookingIds) {
      await dbDelete(`bookings/${bookingId}`);
    }

    for (const payment of payments.filter((p) => p.customerId === uid || p.professionalId === uid)) {
      await dbDelete(`payments/${payment.paymentId}`);
    }

    for (const transaction of transactions.filter((t) => t.customerId === uid || t.professionalId === uid)) {
      await dbDelete(`transactions/${transaction._key || transaction.transactionId}`);
    }

    await dbDelete(`professionalContactLeads/${uid}`);
    const allLeads = await dbGetAll('professionalContactLeads') || [];
    for (const leadGroup of allLeads) {
      const professionalId = leadGroup._key || leadGroup.id;
      for (const [leadId, lead] of Object.entries(leadGroup)) {
        if (leadId.startsWith('_') || !lead || typeof lead !== 'object') continue;
        if (lead.customerId === uid) {
          await dbDelete(`professionalContactLeads/${professionalId}/${leadId}`);
        }
      }
    }

    await dbDelete(`users/${uid}`);
    await dbDelete(`professionals/${uid}`);
    await dbDelete(`professionalReviews/${uid}`);
  },

  async updateProfessional(uid, payload) {
    const proUpdates = {};
    const userUpdates = {};

    if (payload.displayName !== undefined) userUpdates.displayName = String(payload.displayName).trim();
    if (payload.phoneNumber !== undefined) userUpdates.phoneNumber = String(payload.phoneNumber).trim();
    if (payload.rating !== undefined) {
      proUpdates.rating = Number(payload.rating) || 0;
      userUpdates.rating = proUpdates.rating;
    }
    if (payload.totalRatings !== undefined) proUpdates.totalRatings = Math.max(0, Number(payload.totalRatings) || 0);
    if (payload.experienceYears !== undefined) proUpdates.experienceYears = Math.max(0, Number(payload.experienceYears) || 0);
    if (payload.isAvailableNow !== undefined) proUpdates.isAvailableNow = Boolean(payload.isAvailableNow);
    if (payload.serviceTypes !== undefined) {
      proUpdates.serviceTypes = Array.isArray(payload.serviceTypes)
        ? payload.serviceTypes.map(String).filter(Boolean)
        : String(payload.serviceTypes).split(',').map(s => s.trim()).filter(Boolean);
    }
    if (payload.customServices !== undefined) {
      proUpdates.customServices = Array.isArray(payload.customServices)
        ? payload.customServices.map(String).filter(Boolean)
        : String(payload.customServices).split(',').map(s => s.trim()).filter(Boolean);
    }

    if (Object.keys(userUpdates).length) await dbUpdate(`users/${uid}`, userUpdates);
    if (Object.keys(proUpdates).length) await dbUpdate(`professionals/${uid}`, proUpdates);
    return { uid, ...userUpdates, ...proUpdates };
  },

  async listProfessionalReviews(uid) {
    const reviews = await dbGet(`professionalReviews/${uid}`) || {};
    return Object.entries(reviews)
      .map(([reviewId, review]) => ({ reviewId, ...review }))
      .sort((a, b) => Number(b.updatedAt || b.createdAt || 0) - Number(a.updatedAt || a.createdAt || 0));
  },

  async deleteProfessionalReview(uid, reviewId) {
    await dbDelete(`professionalReviews/${uid}/${reviewId}`);
    const reviews = await this.listProfessionalReviews(uid);
    const ratings = reviews.map(r => Number(r.rating || 0)).filter(r => r > 0);
    const totalRatings = ratings.length;
    const rating = totalRatings
      ? Number((ratings.reduce((sum, r) => sum + r, 0) / totalRatings).toFixed(2))
      : 0;
    await dbUpdate(`professionals/${uid}`, { rating, totalRatings });
    return { rating, totalRatings };
  },

  async deleteBooking(bookingId) {
    const payments = await dbGetAll('payments') || [];
    const transactions = await dbGetAll('transactions') || [];

    await dbDelete(`bookings/${bookingId}`);
    for (const payment of payments.filter((p) => p.bookingId === bookingId)) {
      await dbDelete(`payments/${payment.paymentId}`);
    }
    for (const transaction of transactions.filter((t) => t.bookingId === bookingId)) {
      await dbDelete(`transactions/${transaction._key || transaction.transactionId}`);
    }
  },

  async clearAllData() {
    const users = await dbGetAll('users') || [];
    const keepAdminIds = new Set(
      users
        .filter((u) => u.role === 'admin' || String(u.displayName || '').toLowerCase() === 'huzaifa')
        .map((u) => u.uid),
    );

    const keysToClear = [
      'bookings',
      'payments',
      'transactions',
      'professionals',
      'chats',
      'userBookings',
      'locationTracking',
      'professionalContactLeads',
    ];
    for (const key of keysToClear) {
      await dbDelete(key);
    }

    for (const user of users) {
      if (!user?.uid) continue;
      if (keepAdminIds.has(user.uid)) continue;
      await dbDelete(`users/${user.uid}`);
    }
  },
};

module.exports = AdminModel;
