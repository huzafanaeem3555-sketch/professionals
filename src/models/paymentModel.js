const { dbGet, dbSet, dbUpdate, dbGetAll } = require('../config/firebase');
const { v4: uuidv4 } = require('uuid');

const PAYMENTS_PATH = 'payments';
const EASYPAISA_NUMBER = process.env.EASYPAISA_ACCOUNT_NUMBER || '03455876761';

const PaymentModel = {
  async create({ bookingId, customerId, professionalId, amount, commission }) {
    const paymentId = uuidv4();
    const payment = {
      paymentId,
      bookingId,
      customerId,
      professionalId,
      amount,
      commission: commission || 0,
      easypaisaNumber: EASYPAISA_NUMBER,
      transactionId: '',
      status: 'initiated',
      _createdAt: Date.now(),
      confirmedAt: 0,
    };
    await dbSet(`${PAYMENTS_PATH}/${paymentId}`, payment);
    return payment;
  },

  /**
   * Simulate EasyPaisa verification.
   * Replace with real EasyPaisa Checkout API in production.
   */
  async verifyEasypaisa(transactionId) {
    if (!transactionId || transactionId.trim().length < 3) {
      return { verified: false, message: 'Please enter a valid transaction ID (minimum 3 characters).' };
    }
    // Simulate processing delay
    await new Promise(resolve => setTimeout(resolve, 1500));
    return {
      verified: true,
      message: '✅ Payment verified successfully!',
      transactionId: transactionId.trim(),
    };
  },

  async confirm(paymentId, transactionId) {
    await dbUpdate(`${PAYMENTS_PATH}/${paymentId}`, {
      transactionId,
      status: 'completed',
      confirmedAt: Date.now(),
    });
  },

  async getByBookingId(bookingId) {
    const all = await dbGetAll(PAYMENTS_PATH);
    const matches = all.filter(p => p.bookingId === bookingId);
    if (!matches.length) return null;
    return matches.sort((a, b) => (b._createdAt || 0) - (a._createdAt || 0))[0];
  },

  async markFailed(paymentId) {
    await dbUpdate(`${PAYMENTS_PATH}/${paymentId}`, {
      status: 'failed',
      failedAt: Date.now(),
    });
  },
};

module.exports = PaymentModel;
