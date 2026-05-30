const { dbGetAll } = require('../config/firebase');

const TRANSACTIONS_PATH = 'transactions';

const TransactionModel = {
  async getByProfessionalId(professionalId) {
    const all = await dbGetAll(TRANSACTIONS_PATH);
    return all
      .filter((tx) => tx.professionalId === professionalId)
      .sort((a, b) => (b.createdAt || 0) - (a.createdAt || 0));
  },

  async getByBookingId(bookingId) {
    const all = await dbGetAll(TRANSACTIONS_PATH);
    return all.filter((tx) => tx.bookingId === bookingId);
  },
};

module.exports = TransactionModel;
