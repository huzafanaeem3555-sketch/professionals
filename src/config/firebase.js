// FIREBASE CLIENT SDK - COMPLETE WORKING SOLUTION FOR RAILWAY
// NO firebase-admin, NO service account, NO credentials needed

const { initializeApp } = require('firebase/app');
const { 
  getDatabase, 
  ref, 
  get, 
  set, 
  update, 
  push, 
  remove, 
  query, 
  orderByChild, 
  equalTo, 
  limitToLast,
  onValue,
  off
} = require('firebase/database');

// Firebase configuration - only database URL needed
const firebaseConfig = {
  databaseURL: process.env.FIREBASE_DATABASE_URL || 'https://serviceconnect-dea35-default-rtdb.firebaseio.com/'
};

// Initialize Firebase
let db;
let firebaseReady = false;

try {
  const app = initializeApp(firebaseConfig);
  db = getDatabase(app);
  firebaseReady = true;
  console.log('✅ Firebase connected successfully');
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
    const snapshot = await get(ref(db, pathName));
    return snapshot.exists() ? snapshot.val() : null;
  } catch (error) {
    console.error(`dbGet error:`, error.message);
    return null;
  }
}

// Set data at a path
async function dbSet(pathName, data) {
  if (!firebaseReady) return false;
  try {
    await set(ref(db, pathName), data);
    return true;
  } catch (error) {
    console.error(`dbSet error:`, error.message);
    return false;
  }
}

// Update data at a path
async function dbUpdate(pathName, data) {
  if (!firebaseReady) return false;
  try {
    await update(ref(db, pathName), data);
    return true;
  } catch (error) {
    console.error(`dbUpdate error:`, error.message);
    return false;
  }
}

// Push data (generate unique key)
async function dbPush(pathName, data) {
  if (!firebaseReady) return null;
  try {
    const newRef = push(ref(db, pathName));
    await set(newRef, data);
    return newRef.key;
  } catch (error) {
    console.error(`dbPush error:`, error.message);
    return null;
  }
}

// Delete data at a path
async function dbDelete(pathName) {
  if (!firebaseReady) return false;
  try {
    await remove(ref(db, pathName));
    return true;
  } catch (error) {
    console.error(`dbDelete error:`, error.message);
    return false;
  }
}

// Get all data from a path
async function dbGetAll(pathName) {
  if (!firebaseReady) return [];
  try {
    const snapshot = await get(ref(db, pathName));
    if (!snapshot.exists()) return [];
    const results = [];
    snapshot.forEach((child) => {
      results.push({ _key: child.key, ...child.val() });
    });
    return results;
  } catch (error) {
    console.error(`dbGetAll error:`, error.message);
    return [];
  }
}

// Query data with order and filter
async function dbQuery(pathName, orderByField, equalToValue, limitVal = null) {
  if (!firebaseReady) return [];
  try {
    let q = query(ref(db, pathName), orderByChild(orderByField), equalTo(equalToValue));
    if (limitVal) {
      q = query(q, limitToLast(limitVal));
    }
    const snapshot = await get(q);
    if (!snapshot.exists()) return [];
    const results = [];
    snapshot.forEach((child) => {
      results.push({ _key: child.key, ...child.val() });
    });
    return results;
  } catch (error) {
    console.error(`dbQuery error:`, error.message);
    return [];
  }
}

// Listen for real-time updates
function dbListen(pathName, callback) {
  if (!firebaseReady) return () => {};
  const dbRef = ref(db, pathName);
  const handler = (snapshot) => {
    callback(snapshot.exists() ? snapshot.val() : null);
  };
  onValue(dbRef, handler);
  return () => off(dbRef, 'value', handler);
}

// ============================================
// AUTH & MESSAGING (not available in client SDK)
// ============================================
const auth = null;
const messaging = null;

// ============================================
// EXPORTS
// ============================================
module.exports = {
  db,
  auth,
  messaging,
  firebaseReady,
  dbGet,
  dbSet,
  dbUpdate,
  dbPush,
  dbDelete,
  dbGetAll,
  dbQuery,
  dbListen,
};