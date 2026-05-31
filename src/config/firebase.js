// SIMPLE FIREBASE - NO SERVICE ACCOUNT, NO CREDENTIALS, ONLY DATABASE URL
const admin = require('firebase-admin');

// Initialize Firebase with ONLY database URL
let db;
let firebaseReady = false;

try {
  if (!admin.apps.length) {
    admin.initializeApp({
      databaseURL: process.env.FIREBASE_DATABASE_URL || 'https://serviceconnect-dea35-default-rtdb.firebaseio.com/'
    });
    console.log('✅ Firebase connected successfully');
    firebaseReady = true;
  }
  db = admin.database();
} catch (error) {
  console.error('❌ Firebase connection failed:', error.message);
  firebaseReady = false;
  // Create fallback dummy database
  db = {
    ref: () => ({
      once: async () => ({ exists: () => false, val: () => null }),
      set: async () => {},
      update: async () => {},
      remove: async () => {},
      push: () => ({ key: 'fallback', set: async () => {} })
    })
  };
}

// ============================================
// DATABASE HELPER FUNCTIONS
// ============================================

// Get data from a path
async function dbGet(pathName) {
  if (!firebaseReady) return null;
  try {
    const snapshot = await db.ref(pathName).once('value');
    return snapshot.exists() ? snapshot.val() : null;
  } catch (error) {
    console.error(`dbGet error at ${pathName}:`, error.message);
    return null;
  }
}

// Set data at a path
async function dbSet(pathName, data) {
  if (!firebaseReady) return false;
  try {
    await db.ref(pathName).set(data);
    return true;
  } catch (error) {
    console.error(`dbSet error at ${pathName}:`, error.message);
    return false;
  }
}

// Update data at a path
async function dbUpdate(pathName, data) {
  if (!firebaseReady) return false;
  try {
    await db.ref(pathName).update(data);
    return true;
  } catch (error) {
    console.error(`dbUpdate error at ${pathName}:`, error.message);
    return false;
  }
}

// Push data (generate unique key)
async function dbPush(pathName, data) {
  if (!firebaseReady) return null;
  try {
    const newRef = db.ref(pathName).push();
    await newRef.set(data);
    return newRef.key;
  } catch (error) {
    console.error(`dbPush error at ${pathName}:`, error.message);
    return null;
  }
}

// Delete data at a path
async function dbDelete(pathName) {
  if (!firebaseReady) return false;
  try {
    await db.ref(pathName).remove();
    return true;
  } catch (error) {
    console.error(`dbDelete error at ${pathName}:`, error.message);
    return false;
  }
}

// Query data with order and filter
async function dbQuery(pathName, orderBy, equalTo, limitToLast = null) {
  if (!firebaseReady) return [];
  try {
    let query = db.ref(pathName).orderByChild(orderBy).equalTo(equalTo);
    if (limitToLast) {
      query = query.limitToLast(limitToLast);
    }
    const snapshot = await query.once('value');
    if (!snapshot.exists()) return [];
    const results = [];
    snapshot.forEach((child) => {
      results.push({ _key: child.key, ...child.val() });
    });
    return results;
  } catch (error) {
    console.error(`dbQuery error at ${pathName}:`, error.message);
    return [];
  }
}

// Get all data from a path
async function dbGetAll(pathName) {
  if (!firebaseReady) return [];
  try {
    const snapshot = await db.ref(pathName).once('value');
    if (!snapshot.exists()) return [];
    const results = [];
    snapshot.forEach((child) => {
      results.push({ _key: child.key, ...child.val() });
    });
    return results;
  } catch (error) {
    console.error(`dbGetAll error at ${pathName}:`, error.message);
    return [];
  }
}

// Listen for real-time updates
function dbListen(pathName, callback) {
  if (!firebaseReady) return () => {};
  const ref = db.ref(pathName);
  const handler = (snapshot) => {
    callback(snapshot.exists() ? snapshot.val() : null);
  };
  ref.on('value', handler);
  return () => ref.off('value', handler);
}

// ============================================
// AUTH (optional - only if available)
// ============================================
const auth = firebaseReady ? admin.auth() : null;
const messaging = firebaseReady ? admin.messaging() : null;

// ============================================
// EXPORTS
// ============================================
module.exports = {
  admin,
  db,
  auth,
  messaging,
  firebaseReady,
  dbGet,
  dbSet,
  dbUpdate,
  dbPush,
  dbDelete,
  dbQuery,
  dbGetAll,
  dbListen,
};