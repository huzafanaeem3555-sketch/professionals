/**
 * Migration Script: Fix old booking data
 * - Convert status 'pending_approval' → 'pending_acceptance'
 * - Add missing commission fields (commissionAmount, professionalEarnings)
 * - Add phone reveal flags
 * 
 * Run with: node migrate-bookings.js
 */

const { initializeApp, cert } = require('firebase-admin/app');
const { getDatabase } = require('firebase-admin/database');
const serviceAccount = require('./serviceAccountKey.json');

const COMMISSION_RATE = 0.10;
const BOOKINGS_PATH = 'bookings';

// Initialize Firebase
initializeApp({
  credential: cert(serviceAccount),
  databaseURL: 'https://serviceconnect-dea35-default-rtdb.firebaseio.com/',
});

const db = getDatabase();

async function migrateBookings() {
  try {
    console.log('🔄 Starting booking migration...\n');

    const bookingsRef = db.ref(BOOKINGS_PATH);
    const snapshot = await bookingsRef.get();

    if (!snapshot.exists()) {
      console.log('❌ No bookings found in database.');
      return;
    }

    const bookings = snapshot.val();
    const bookingIds = Object.keys(bookings);
    console.log(`📊 Found ${bookingIds.length} bookings to check...\n`);

    let updated = 0;
    let skipped = 0;

    for (const bookingId of bookingIds) {
      const booking = bookings[bookingId];
      let needsUpdate = false;
      const updates = {};

      // Check 1: Convert pending_approval → pending_acceptance
      if (booking.status === 'pending_approval') {
        console.log(`  ⚠️  Booking ${bookingId}: pending_approval → pending_acceptance`);
        updates.status = 'pending_acceptance';
        needsUpdate = true;
      }

      // Check 2: Add missing commission fields
      if (!booking.commissionAmount || !booking.professionalEarnings) {
        const price = booking.proposedPrice || booking.agreedPrice || 0;
        const commission = price * COMMISSION_RATE;
        const earnings = price * (1 - COMMISSION_RATE);

        console.log(
          `  💰 Booking ${bookingId}: Added commission (Rs. ${commission.toFixed(2)}) and earnings (Rs. ${earnings.toFixed(2)})`
        );
        updates.commissionAmount = parseFloat(commission.toFixed(2));
        updates.professionalEarnings = parseFloat(earnings.toFixed(2));
        needsUpdate = true;
      }

      // Check 3: Add phone reveal flags
      if (booking.customerPhoneRevealed === undefined || booking.professionalPhoneRevealed === undefined) {
        const phoneRevealed = booking.paymentStatus === 'completed' || booking.status === 'confirmed';
        console.log(
          `  📱 Booking ${bookingId}: Added phone reveal flags (${phoneRevealed})`
        );
        updates.customerPhoneRevealed = phoneRevealed;
        updates.professionalPhoneRevealed = phoneRevealed;
        needsUpdate = true;
      }

      // Check 4: Add id field if missing (for backwards compatibility)
      if (!booking.id) {
        console.log(`  🔑 Booking ${bookingId}: Added id field`);
        updates.id = bookingId;
        needsUpdate = true;
      }

      if (needsUpdate) {
        await db.ref(`${BOOKINGS_PATH}/${bookingId}`).update(updates);
        updated++;
      } else {
        skipped++;
      }
    }

    console.log(`\n✅ Migration complete!`);
    console.log(`   Updated: ${updated} bookings`);
    console.log(`   Skipped: ${skipped} bookings (no changes needed)`);
    process.exit(0);
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  }
}

migrateBookings();
