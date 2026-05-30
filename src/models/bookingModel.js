const { db } = require('../config/firebase');
const { v4: uuidv4 } = require('uuid');
const ProfessionalModel = require('./professionalModel');

const BOOKINGS_PATH = 'bookings';
const USER_BOOKINGS_PATH = 'userBookings'; // Index path to query quickly: userBookings/{uid}/{bookingId} = true
const COMMISSION_RATE = 0.10;

function toMoney(value) {
  return Math.round(Number(value || 0) * 100) / 100;
}

function addHistoryEntry(history, entry) {
  const existing = history && typeof history === 'object' ? history : {};
  const normalized = Array.isArray(existing) ? { ...existing } : { ...existing };
  normalized[`offer_${Date.now()}_${Math.floor(Math.random() * 1000)}`] = entry;
  return normalized;
}

const BookingModel = {
  // Create new booking (customer requested booking)
  async create(data) {
    const bookingId = uuidv4();
    const createdAt = Date.now();
    const price = toMoney(data.proposedPrice || 0);

    const booking = {
      bookingId,
      customerId: data.customerId,
      professionalId: data.professionalId,
      customerProblem: data.customerProblem || data.description || '',
      customerLocation: data.customerLocation || { lat: 0, lng: 0 },
      customerAddress: data.customerAddress || data.address || '',
      scheduledTime: data.scheduledTime || null,
      serviceType: data.serviceType || 'general',
      proposedPrice: price,
      counterPrice: 0,
      agreedPrice: 0,
      status: 'pending_acceptance',
      negotiationHistory: {
        initial: {
          from: 'customer',
          price,
          timestamp: createdAt,
        },
      },
      paymentStatus: 'pending_quote',
      commissionDeducted: false,
      transactionId: '',
      screenshotUrl: '',
      commissionAmount: toMoney(price * COMMISSION_RATE),
      professionalEarnings: toMoney(price * (1 - COMMISSION_RATE)),
      professionalPhone: data.professionalPhone || '',
      professionalLocation: data.professionalLocation || null,
      customerPhone: data.customerPhone || '',
      customerName: data.customerName || '',
      contactMethod: data.contactMethod || 'direct_contact',
      createdAt,
      updatedAt: createdAt,
    };

    await db.ref(`${BOOKINGS_PATH}/${bookingId}`).set(booking);

    await db.ref(`${USER_BOOKINGS_PATH}/${data.customerId}/${bookingId}`).set(true);
    await db.ref(`${USER_BOOKINGS_PATH}/${data.professionalId}/${bookingId}`).set(true);

    return booking;
  },

  // Get booking by ID
  async getById(bookingId) {
    const snapshot = await db.ref(`${BOOKINGS_PATH}/${bookingId}`).once('value');
    const data = snapshot.val();
    if (!data) return null;
    
    return {
      bookingId,
      ...data
    };
  },

  // Get all bookings for a user (customer or professional)
  async getByUserId(uid) {
    const snapshot = await db.ref(`${USER_BOOKINGS_PATH}/${uid}`).once('value');
    const bookingRefs = snapshot.val();
    if (!bookingRefs) return [];
    
    const bookings = [];
    for (const bookingId of Object.keys(bookingRefs)) {
      const booking = await this.getById(bookingId);
      if (booking) {
        bookings.push(booking);
      }
    }
    
    return bookings.sort((a, b) => (b.createdAt || 0) - (a.createdAt || 0));
  },

  async getByCustomerId(customerId) {
    return this.getByUserId(customerId);
  },

  async getByProfessionalPhone(professionalPhone) {
    // Legacy support: finding bookings by professional identifier
    return this.getByUserId(professionalPhone);
  },

  async getByProfessionalId(professionalId) {
    return this.getByUserId(professionalId);
  },

  // Update status directly
  async updateStatus(bookingId, status) {
    await db.ref(`${BOOKINGS_PATH}/${bookingId}/status`).set(status);
    await db.ref(`${BOOKINGS_PATH}/${bookingId}/updatedAt`).set(Date.now());
    return { bookingId, status };
  },

  // Propose price (professional counters)
  async proposePrice(bookingId, price) {
    const booking = await this.getById(bookingId);
    if (!booking) throw new Error('Booking not found');

    const history = addHistoryEntry(booking.negotiationHistory, {
      from: 'professional',
      price: Number(price),
      timestamp: Date.now()
    });

    await db.ref(`${BOOKINGS_PATH}/${bookingId}`).update({
      proposedPrice: Number(price),
      status: 'pending_customer_response',
      negotiationHistory: history,
      updatedAt: Date.now()
    });

    return this.getById(bookingId);
  },

  // Counter price (customer counters)
  async counterPrice(bookingId, price) {
    const booking = await this.getById(bookingId);
    if (!booking) throw new Error('Booking not found');

    const history = addHistoryEntry(booking.negotiationHistory, {
      from: 'customer',
      price: Number(price),
      timestamp: Date.now()
    });

    await db.ref(`${BOOKINGS_PATH}/${bookingId}`).update({
      counterPrice: Number(price),
      status: 'pending_professional_response',
      negotiationHistory: history,
      updatedAt: Date.now()
    });

    return this.getById(bookingId);
  },

  // Accept Price (either customer or professional accepts)
  async acceptPrice(bookingId, acceptedPrice) {
    const booking = await this.getById(bookingId);
    if (!booking) throw new Error('Booking not found');

    const finalPrice = toMoney(acceptedPrice);
    const commission = toMoney(finalPrice * COMMISSION_RATE);
    const earnings = toMoney(finalPrice - commission);
    const professional = await ProfessionalModel.getById(booking.professionalId);
    const proPhone = professional?.phoneNumber || professional?.phone || booking.professionalPhone || '';
    const proLocation = professional?.location || null;

    const history = addHistoryEntry(booking.negotiationHistory, {
      from: 'accepted',
      price: finalPrice,
      action: 'accepted',
      timestamp: Date.now(),
    });

    await db.ref(`${BOOKINGS_PATH}/${bookingId}`).update({
      agreedPrice: finalPrice,
      commissionAmount: commission,
      professionalEarnings: earnings,
      professionalPhone: proPhone,
      professionalLocation: proLocation,
      status: 'confirmed',
      paymentStatus: 'pending_commission',
      commissionDeducted: false,
      confirmedAt: Date.now(),
      negotiationHistory: history,
      updatedAt: Date.now()
    });

    return this.getById(bookingId);
  },

  // Reject Booking
  async rejectBooking(bookingId) {
    const booking = await this.getById(bookingId);
    if (!booking) throw new Error('Booking not found');

    if (
      booking.commissionDeducted === true &&
      Number(booking.commissionAmount || 0) > 0 &&
      booking.professionalId
    ) {
      const proRef = db.ref(`professionals/${booking.professionalId}`);
      const proSnap = await proRef.once('value');
      const pro = proSnap.val() || {};
      const currentWallet = Number(pro.wallet ?? pro.walletBalance ?? 5000);
      const refund = Number(booking.commissionAmount || 0);
      const refundedWallet = toMoney(currentWallet + refund);

      await proRef.update({
        wallet: refundedWallet,
        walletBalance: refundedWallet,
        updatedAt: Date.now(),
      });

      const txId = uuidv4();
      await db.ref(`transactions/${txId}`).set({
        id: txId,
        professionalId: booking.professionalId,
        bookingId,
        amount: refund,
        type: 'commission_refund',
        status: 'completed',
        timestamp: Date.now(),
      });
    }

    return this.updateStatus(bookingId, 'rejected');
  },

  // Cancel Booking
  async cancel(bookingId) {
    return this.updateStatus(bookingId, 'cancelled');
  },

  // Start Job (professional starts)
  async startJob(bookingId) {
    return this.updateStatus(bookingId, 'in_progress');
  },

  // Complete Booking (professional marks completed)
  async completeBooking(bookingId) {
    const booking = await this.getById(bookingId);
    if (!booking) throw new Error('Booking not found');

    await db.ref(`${BOOKINGS_PATH}/${bookingId}`).update({
      status: 'completed',
      completedAt: Date.now(),
      updatedAt: Date.now()
    });

    // Increment completed jobs count on professional profile
    await ProfessionalModel.incrementCompletedJobs(booking.professionalId);

    return this.getById(bookingId);
  },

  async customerConfirmCompletion(bookingId) {
    const booking = await this.getById(bookingId);
    if (!booking) throw new Error('Booking not found');
    await db.ref(`${BOOKINGS_PATH}/${bookingId}`).update({
      status: 'customer_confirmed',
      customerConfirmedAt: Date.now(),
      updatedAt: Date.now(),
    });
    return this.getById(bookingId);
  },

  async professionalConfirmCompletion(bookingId) {
    const booking = await this.getById(bookingId);
    if (!booking) throw new Error('Booking not found');
    await db.ref(`${BOOKINGS_PATH}/${bookingId}`).update({
      status: 'completed',
      completedAt: Date.now(),
      professionalConfirmedAt: Date.now(),
      updatedAt: Date.now(),
    });
    await ProfessionalModel.incrementCompletedJobs(booking.professionalId);
    return this.getById(bookingId);
  },

  // Confirm Payment (verified screenshot/txn ID)
  async confirmPayment(bookingId, transactionId, screenshotUrl) {
    const booking = await this.getById(bookingId);
    if (!booking) throw new Error('Booking not found');

    const commission = booking.commissionAmount || 0;
    const earnings = booking.professionalEarnings || 0;
    const proId = booking.professionalId;

    // Deduct 10% commission from professional's wallet in RTDB
    const walletRef = db.ref(`professionals/${proId}/walletBalance`);
    const transactionResult = await walletRef.transaction((current) => {
      const currVal = typeof current === 'number' ? current : (current ? Number(current) : 0);
      if (isNaN(currVal)) return 0;
      if (currVal - commission < 0) {
        // Return undefined to abort transaction if balance is insufficient
        return;
      }
      return currVal - commission;
    }, { applyLocally: false });

    if (!transactionResult.committed) {
      throw new Error('Insufficient professional wallet balance for commission deduction. Professional must recharge wallet.');
    }

    const newBalance = transactionResult.snapshot.val();

    // Add 90% earnings to professional's totalEarnings in RTDB
    const earningsRef = db.ref(`professionals/${proId}/totalEarnings`);
    await earningsRef.transaction((current) => {
      const currVal = typeof current === 'number' ? current : (current ? Number(current) : 0);
      return currVal + earnings;
    });

    // Create a transaction record in transactions
    const txId = uuidv4();
    const txData = {
      professionalId: proId,
      bookingId,
      amount: commission,
      type: 'commission_deduction',
      timestamp: Date.now()
    };
    await db.ref(`transactions/${txId}`).set(txData);

    // Update booking values
    await db.ref(`${BOOKINGS_PATH}/${bookingId}`).update({
      status: 'confirmed',
      paymentStatus: 'completed',
      transactionId,
      screenshotUrl,
      updatedAt: Date.now()
    });

    return {
      newBalance,
      commission,
      professionalEarnings: earnings
    };
  },

  // Add rating after job completion
  async addRating(bookingId, rating, review) {
    await db.ref(`${BOOKINGS_PATH}/${bookingId}/customerRating`).set(rating);
    if (review) {
      await db.ref(`${BOOKINGS_PATH}/${bookingId}/customerReview`).set(review);
    }
    await db.ref(`${BOOKINGS_PATH}/${bookingId}/updatedAt`).set(Date.now());
  },

  async getActiveBookingsForUser(uid) {
    const all = await this.getByUserId(uid);
    const activeStatuses = ['pending_acceptance', 'pending_customer_response', 'pending_professional_response', 'pending_payment', 'confirmed', 'in_progress', 'customer_confirmed'];
    
    return all
      .filter(b => activeStatuses.includes(b.status))
      .sort((a, b) => (b.createdAt || 0) - (a.createdAt || 0));
  }
};

module.exports = BookingModel;
