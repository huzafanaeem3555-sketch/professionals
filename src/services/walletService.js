const { db } = require('../config/firebase');

const COMMISSION_RATE = 0.10;

function toMoney(value) {
  return Math.round(Number(value || 0) * 100) / 100;
}

async function deductCommission({ professionalId, bookingId, amount }) {
  if (!professionalId || !bookingId || amount === undefined) {
    return {
      success: false,
      statusCode: 400,
      message: 'professionalId, bookingId, and amount are required.',
    };
  }

  const gross = Number(amount);
  if (!Number.isFinite(gross) || gross <= 0) {
    return {
      success: false,
      statusCode: 400,
      message: 'amount must be a valid positive number.',
    };
  }

  const bookingRef = db.ref(`bookings/${bookingId}`);
  const bookingSnap = await bookingRef.once('value');
  if (!bookingSnap.exists()) {
    return {
      success: false,
      statusCode: 404,
      message: 'Booking not found.',
    };
  }
  const booking = bookingSnap.val() || {};
  if (booking.status !== 'completed') {
    return {
      success: false,
      statusCode: 409,
      message: 'Commission can be deducted only after booking is completed.',
    };
  }
  if (booking.commissionDeducted === true) {
    return {
      success: true,
      statusCode: 200,
      data: {
        professionalId,
        bookingId,
        grossAmount: gross,
        commission: Number(booking.commissionAmount || 0),
        walletBalance: Number((await db.ref(`professionals/${professionalId}`).once('value')).val()?.wallet ?? 0),
      },
    };
  }

  const commission = toMoney(gross * COMMISSION_RATE);
  const proRef = db.ref(`professionals/${professionalId}`);
  const proSnap = await proRef.once('value');
  if (!proSnap.exists()) {
    return {
      success: false,
      statusCode: 404,
      message: 'Professional not found.',
    };
  }

  const pro = proSnap.val() || {};
  const currentWallet = Number(pro.wallet ?? pro.walletBalance ?? 5000);
  const newWallet = toMoney(Math.max(0, currentWallet - commission));

  await proRef.update({
    wallet: newWallet,
    walletBalance: newWallet,
    updatedAt: Date.now(),
  });

  const txRef = db.ref('transactions').push();
  await txRef.set({
    id: txRef.key,
    professionalId,
    bookingId,
    type: 'commission_deduction',
    amount: commission,
    grossAmount: gross,
    status: 'completed',
    timestamp: Date.now(),
  });

  await bookingRef.update({
    commissionAmount: commission,
    professionalEarnings: toMoney(gross - commission),
    commissionDeducted: true,
    paymentStatus: 'commission_deducted',
    updatedAt: Date.now(),
  });

  return {
    success: true,
    statusCode: 200,
    data: {
      professionalId,
      bookingId,
      grossAmount: gross,
      commission,
      walletBalance: newWallet,
    },
  };
}

module.exports = {
  COMMISSION_RATE,
  deductCommission,
};
