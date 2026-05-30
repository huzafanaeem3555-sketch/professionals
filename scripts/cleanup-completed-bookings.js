require('dotenv').config();
const { dbGetAll, dbDelete } = require('../src/config/firebase');

async function cleanup() {
  const now = Date.now();
  const bookings = await dbGetAll('bookings');
  const completedBookings = bookings.filter((booking) => booking.status === 'completed' && booking.shouldDeleteAt && booking.shouldDeleteAt < now);

  for (const booking of completedBookings) {
    const bookingId = booking.bookingId || booking.id || booking._key;
    if (!bookingId) continue;
    console.log(`Deleting completed booking ${bookingId}`);
    await dbDelete(`bookings/${bookingId}`);
    const payments = await dbGetAll('payments');
    const transactions = await dbGetAll('transactions');
    for (const payment of payments.filter((paymentItem) => paymentItem.bookingId === bookingId)) {
      await dbDelete(`payments/${payment.paymentId}`);
    }
    for (const transaction of transactions.filter((tx) => tx.bookingId === bookingId)) {
      await dbDelete(`transactions/${transaction._key || transaction.transactionId}`);
    }
  }

  console.log(`Cleanup finished. Removed ${completedBookings.length} booking(s).`);
}

cleanup().catch((error) => {
  console.error('cleanup error:', error);
  process.exit(1);
});
