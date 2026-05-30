/**
 * Migration Script: Add wallet system to professionals
 * - Add walletBalance field (default 5000) to all professionals
 * - Check for existing walletBalance and skip if present
 * 
 * Run with: node migrate-wallets.js
 */

const { initializeApp, cert } = require('firebase-admin/app');
const { getDatabase } = require('firebase-admin/database');
const serviceAccount = require('./serviceAccountKey.json');

const INITIAL_WALLET_BALANCE = 5000;
const PROFESSIONALS_PATH = 'professionals';

// Initialize Firebase
initializeApp({
  credential: cert(serviceAccount),
  databaseURL: 'https://serviceconnect-dea35-default-rtdb.firebaseio.com/',
});

const db = getDatabase();

async function migrateWallets() {
  try {
    console.log('🔄 Starting professional wallet migration...\n');

    const professionalsRef = db.ref(PROFESSIONALS_PATH);
    const snapshot = await professionalsRef.get();

    if (!snapshot.exists()) {
      console.log('❌ No professionals found in database.');
      return;
    }

    const professionals = snapshot.val();
    const professionalIds = Object.keys(professionals);
    console.log(`👥 Found ${professionalIds.length} professionals to check...\n`);

    let updated = 0;
    let skipped = 0;

    for (const uid of professionalIds) {
      const professional = professionals[uid];

      if (professional.walletBalance === undefined || professional.walletBalance === null) {
        console.log(
          `  💰 Professional ${uid}: Added wallet balance (Rs. ${INITIAL_WALLET_BALANCE})`
        );
        await db.ref(`${PROFESSIONALS_PATH}/${uid}/walletBalance`).set(INITIAL_WALLET_BALANCE);
        updated++;
      } else {
        console.log(`  ✓ Professional ${uid}: Already has wallet (Rs. ${professional.walletBalance})`);
        skipped++;
      }
    }

    console.log(`\n✅ Migration complete!`);
    console.log(`   Updated: ${updated} professionals`);
    console.log(`   Skipped: ${skipped} professionals (already have wallets)`);
    process.exit(0);
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  }
}

migrateWallets();
