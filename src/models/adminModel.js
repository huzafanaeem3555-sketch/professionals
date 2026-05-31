const jwt = require('jsonwebtoken');
const { dbGet, dbGetAll, dbSet, dbUpdate, dbDelete } = require('../config/firebase');
const { sendNotificationToUser } = require('../utils/notifications');
const { normalizeGender } = require('../utils/accountPolicy');

const ADMIN_TOKEN_SECRET = process.env.ADMIN_JWT_SECRET || process.env.JWT_SECRET || 'service-connect-secret-change-in-production';
const ADMIN_TOKEN_EXPIRES = process.env.ADMIN_TOKEN_EXPIRES || '8h';

function itemId(item) {
  return String(item?.uid || item?.id || item?._key || item?.phone || item?.phoneNumber || '').trim();
}

function cleanText(value, fallback = '') {
  const text = value === undefined || value === null ? '' : String(value).trim();
  return text || fallback;
}

function toList(value) {
  if (Array.isArray(value)) return value.map(String).filter(Boolean);
  if (value && typeof value === 'object') return Object.values(value).map(String).filter(Boolean);
  return String(value || '')
    .split(',')
    .map(s => s.trim())
    .filter(Boolean);
}

const AdminModel = {
  createToken(username) {
    return jwt.sign({ username, role: 'admin' }, ADMIN_TOKEN_SECRET, { expiresIn: ADMIN_TOKEN_EXPIRES });
  },

  verifyToken(token) {
    return jwt.verify(token, ADMIN_TOKEN_SECRET);
  },

  async getStats() {
    const professionals = await dbGetAll('professionals') || [];
    const users = await dbGetAll('users') || [];
    const bookings = await dbGetAll('bookings') || [];
    const leads = await dbGetAll('professionalContactLeads') || [];
    const completed = bookings.filter((b) => b.status === 'completed');
    const customerIds = new Set(
      users
        .filter((u) => String(u.role || '').toLowerCase() === 'customer')
        .map(itemId)
        .filter(Boolean),
    );
    for (const booking of bookings) {
      if (booking.customerId) customerIds.add(String(booking.customerId));
    }
    for (const leadGroup of leads) {
      for (const [leadId, lead] of Object.entries(leadGroup)) {
        if (leadId.startsWith('_') || !lead || typeof lead !== 'object') continue;
        if (lead.customerId) customerIds.add(String(lead.customerId));
      }
    }

    // Calculate commission as 10% of agreed/proposed price of completed bookings
    const commissionFromBookings = completed.reduce((sum, b) => {
      const price = b.agreedPrice || b.proposedPrice || 0;
      return sum + (price * 0.10);
    }, 0);

    return {
      totalProfessionals: professionals.length,
      totalCustomers: customerIds.size,
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
      const uid = itemId(pro);
      const user = users.find((u) => itemId(u) === uid) || {};
      const displayName = cleanText(
        user.displayName || user.name || pro.displayName || pro.name || pro.businessName,
        'Professional',
      );
      const phoneNumber = cleanText(
        user.phoneNumber || user.phone || pro.phoneNumber || pro.phone,
        '',
      );
      const serviceTypes = toList(pro.serviceTypes || pro.services);
      return {
        ...pro,
        uid,
        displayName,
        name: cleanText(pro.name, displayName),
        email: cleanText(user.email || pro.email, ''),
        phoneNumber,
        phone: cleanText(pro.phone || phoneNumber, phoneNumber),
        gender: cleanText(user.gender || pro.gender, 'male'),
        verificationStatus: cleanText(user.verificationStatus || pro.verificationStatus, 'verified'),
        isActive: user.isActive !== undefined ? Boolean(user.isActive) : (pro.isActive !== false),
        serviceTypes,
        services: serviceTypes,
        customServices: toList(pro.customServices),
        rating: user.rating || pro.rating || 0,
        totalJobs: pro.completedJobs || pro.totalJobs || 0,
        experienceYears: Number(pro.experienceYears || 0),
        createdAt: pro.createdAt || user.createdAt || pro._createdAt || user._createdAt || 0,
      };
    }).sort((a, b) => Number(b.createdAt || 0) - Number(a.createdAt || 0));
  },

  async listCustomers() {
    const users = await dbGetAll('users') || [];
    const bookings = await dbGetAll('bookings') || [];
    const leads = await dbGetAll('professionalContactLeads') || [];
    const customerMap = new Map();

    function upsertCustomer(data) {
      const uid = itemId(data) || cleanText(data?.customerId, '');
      if (!uid) return;
      const existing = customerMap.get(uid) || {};
      customerMap.set(uid, {
        ...existing,
        ...data,
        uid,
        displayName: cleanText(
          data.displayName || data.name || data.customerName || existing.displayName,
          'Customer',
        ),
        phoneNumber: cleanText(
          data.phoneNumber || data.phone || data.customerPhone || existing.phoneNumber,
          '',
        ),
        email: cleanText(data.email || existing.email, ''),
        gender: cleanText(data.gender || existing.gender, 'male'),
        verificationStatus: cleanText(data.verificationStatus || existing.verificationStatus, 'verified'),
        isActive: data.isActive !== undefined ? Boolean(data.isActive) : (existing.isActive !== false),
      });
    }

    users
      .filter((user) => String(user.role || '').toLowerCase() === 'customer')
      .forEach(upsertCustomer);

    for (const booking of bookings) {
      upsertCustomer({
        uid: booking.customerId,
        displayName: booking.customerName,
        phoneNumber: booking.customerPhone,
        address: booking.address || booking.customerAddress,
      });
    }

    for (const leadGroup of leads) {
      for (const [leadId, lead] of Object.entries(leadGroup)) {
        if (leadId.startsWith('_') || !lead || typeof lead !== 'object') continue;
        upsertCustomer({
          uid: lead.customerId,
          displayName: lead.customerName,
          phoneNumber: lead.customerPhone,
          address: lead.customerAddress,
        });
      }
    }

    return Array.from(customerMap.values()).map((c) => {
      const count = bookings.filter((b) => String(b.customerId || '') === c.uid).length;
      return { ...c, totalBookings: count };
    }).sort((a, b) => Number(b.createdAt || b._createdAt || 0) - Number(a.createdAt || a._createdAt || 0));
  },

  async createUser(payload) {
    const role = String(payload.role || '').trim().toLowerCase();
    if (!['customer', 'professional'].includes(role)) {
      throw new Error('role must be customer or professional');
    }
    const now = Date.now();
    const uid = String(payload.uid || `admin_${role}_${now}`).trim();
    const displayName = String(payload.displayName || payload.name || role).trim();
    const phoneNumber = String(payload.phoneNumber || payload.phone || '').trim();
    const email = String(payload.email || `${uid}@hirepro.local`).trim();

    const isFemale = normalizeGender(payload.gender) === 'female';
    const user = {
      uid,
      email,
      displayName,
      photoURL: String(payload.photoURL || ''),
        phoneNumber,
        role,
        gender: isFemale ? 'female' : 'male',
        verificationStatus: isFemale ? 'pending' : 'verified',
        isActive: !isFemale,
        profileCompleted: true,
      createdAt: now,
      _createdAt: now,
      _updatedAt: now,
    };
    await dbSet(`users/${uid}`, user);

    if (role === 'professional') {
      const serviceTypes = Array.isArray(payload.serviceTypes)
        ? payload.serviceTypes.map(String).filter(Boolean)
        : String(payload.serviceTypes || payload.services || '')
            .split(',')
            .map(s => s.trim())
            .filter(Boolean);
      const customServices = Array.isArray(payload.customServices)
        ? payload.customServices.map(String).filter(Boolean)
        : String(payload.customServices || '')
            .split(',')
            .map(s => s.trim())
            .filter(Boolean);
      const professional = {
        uid,
        name: displayName,
        phone: phoneNumber,
        phoneNumber,
        services: serviceTypes,
        serviceTypes,
        customServices,
        description: String(payload.description || ''),
        experienceYears: Math.max(0, Number(payload.experienceYears) || 0),
        hourlyRate: Math.max(0, Number(payload.hourlyRate) || 0),
        isAvailable: payload.isAvailable !== false,
        isAvailableNow: payload.isAvailableNow !== false,
        gender: user.gender,
        verificationStatus: user.verificationStatus,
        isActive: user.isActive,
        rating: Math.max(0, Math.min(5, Number(payload.rating) || 0)),
        totalRatings: Math.max(0, Number(payload.totalRatings) || 0),
        completedJobs: Math.max(0, Number(payload.completedJobs) || 0),
        photoURL: String(payload.photoURL || ''),
        location: {
          lat: Number(payload.lat) || 0,
          lng: Number(payload.lng) || 0,
          address: String(payload.address || ''),
        },
        createdAt: now,
        updatedAt: now,
      };
      await dbSet(`professionals/${uid}`, professional);
      return { user, professional };
    }

    return { user };
  },

  async listBookings() {
    const bookings = await dbGetAll('bookings') || [];
    const users = await dbGetAll('users') || [];
    const professionals = await dbGetAll('professionals') || [];
    return bookings.map((b) => {
      const bookingId = cleanText(b.bookingId || b.id || b._key, '');
      const customer = users.find((u) => itemId(u) === String(b.customerId || '')) || {};
      const professionalUser = users.find((u) => itemId(u) === String(b.professionalId || '')) || {};
      const professional = professionals.find((p) => itemId(p) === String(b.professionalId || '')) || {};
      return {
        ...b,
        bookingId,
        id: bookingId,
        customerName: cleanText(b.customerName || customer.displayName || customer.name, 'Customer'),
        customerPhone: cleanText(b.customerPhone || customer.phoneNumber || customer.phone, ''),
        professionalName: cleanText(
          b.professionalName || professionalUser.displayName || professionalUser.name || professional.name,
          'Professional',
        ),
        professionalPhone: cleanText(b.professionalPhone || professional.phoneNumber || professional.phone, ''),
      };
    }).sort((a, b) => Number(b.createdAt || 0) - Number(a.createdAt || 0));
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
    const user = await dbGet(`users/${uid}`);
    const professional = await dbGet(`professionals/${uid}`);
    if (professional || String(user?.role || '').toLowerCase() === 'professional') {
      const deactivatedAt = Date.now();
      await dbUpdate(`users/${uid}`, {
        isActive: false,
        verificationStatus: 'deactivated',
        femaleVerificationRequired: false,
        _updatedAt: deactivatedAt,
      });
      await dbUpdate(`professionals/${uid}`, {
        isActive: false,
        verificationStatus: 'deactivated',
        _updatedAt: deactivatedAt,
      });
      return {
        protectedProfessional: true,
        message: 'Professional preserved and deactivated.',
      };
    }
    const bookings = await dbGetAll('bookings') || [];
    const payments = await dbGetAll('payments') || [];
    const transactions = await dbGetAll('transactions') || [];
    const bookingIds = bookings.filter((b) => b.customerId === uid || b.professionalId === uid).map((b) => b.bookingId);

    for (const bookingId of bookingIds) {
      await dbDelete(`bookings/${bookingId}`);
    }

    await dbDelete(`userBookings/${uid}`);

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
    await dbDelete(`professionalReviews/${uid}`);
    await dbDelete(`professionals/${uid}`);
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
    if (payload.gender !== undefined) {
      const gender = String(payload.gender || 'male').toLowerCase() === 'female' ? 'female' : 'male';
      proUpdates.gender = gender;
      userUpdates.gender = gender;
    }
    if (payload.verificationStatus !== undefined) {
      const status = String(payload.verificationStatus || '').trim() || 'pending';
      proUpdates.verificationStatus = status;
      userUpdates.verificationStatus = status;
      const active = status === 'verified';
      proUpdates.isActive = active;
      userUpdates.isActive = active;
    }
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

  async verifyUser(uid, verified = true) {
    const status = verified ? 'verified' : 'pending';
    const updates = {
      verificationStatus: status,
      isActive: verified,
      femaleVerificationRequired: !verified,
      verifiedAt: verified ? Date.now() : null,
    };
    await dbUpdate(`users/${uid}`, updates);
    const pro = await dbGet(`professionals/${uid}`);
    if (pro) {
      await dbUpdate(`professionals/${uid}`, updates);
    }
    if (verified) {
      const user = await dbGet(`users/${uid}`);
      const displayName = user?.displayName || pro?.displayName || 'User';
      await sendNotificationToUser(
        uid,
        'Account verified',
        `Your ${String(user?.role || pro?.role || 'account')} has been verified by admin. You can now access the app.`,
        {
          type: 'verification',
          status: 'verified',
          uid,
        },
      );
      return { uid, ...updates, displayName };
    }
    return { uid, ...updates };
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
    const keepProfessionalIds = new Set(
      users
        .filter((u) => String(u.role || '').toLowerCase() === 'professional')
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
      if (keepProfessionalIds.has(user.uid) || await dbGet(`professionals/${user.uid}`)) {
        await dbUpdate(`users/${user.uid}`, {
          isActive: true,
          verificationStatus: String(user.verificationStatus || 'verified'),
          _updatedAt: Date.now(),
        });
        continue;
      }
      await dbDelete(`users/${user.uid}`);
    }
  },
};

module.exports = AdminModel;
