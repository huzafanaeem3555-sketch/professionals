const admin = require('firebase-admin');

// ULTRA SIMPLE - NO SERVICE ACCOUNT, NO CREDENTIALS
let db;
let firebaseReady = false;

try {
  // Initialize with ONLY database URL
  if (!admin.apps.length) {
    admin.initializeApp({
      databaseURL: process.env.FIREBASE_DATABASE_URL || 'https://serviceconnect-dea35-default-rtdb.firebaseio.com/'
    });
    console.log('✅ Firebase initialized (simple mode)');
  }
  db = admin.database();
  firebaseReady = true;
} catch (error) {
  console.error('❌ Firebase init failed:', error.message);
  firebaseReady = false;
  // Fallback dummy database
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

// Helper functions
async function dbGet(pathName) {
  if (!firebaseReady) return null;
  try {
    const snap = await db.ref(pathName).once('value');
    return snap.exists() ? snap.val() : null;
  } catch (error) {
    console.error(`dbGet error:`, error.message);
    return null;
  }
}

async function dbSet(pathName, data) {
  if (!firebaseReady) return false;
  try {
    await db.ref(pathName).set(data);
    return true;
  } catch (error) {
    console.error(`dbSet error:`, error.message);
    return false;
  }
}

async function dbUpdate(pathName, data) {
  if (!firebaseReady) return false;
  try {
    await db.ref(pathName).update(data);
    return true;
  } catch (error) {
    console.error(`dbUpdate error:`, error.message);
    return false;
  }
}

async function dbPush(pathName, data) {
  if (!firebaseReady) return null;
  try {
    const ref = db.ref(pathName).push();
    await ref.set(data);
    return ref.key;
  } catch (error) {
    console.error(`dbPush error:`, error.message);
    return null;
  }
}

async function dbDelete(pathName) {
  if (!firebaseReady) return false;
  try {
    await db.ref(pathName).remove();
    return true;
  } catch (error) {
    console.error(`dbDelete error:`, error.message);
    return false;
  }
}

async function dbGetAll(pathName) {
  if (!firebaseReady) return [];
  try {
    const snap = await db.ref(pathName).once('value');
    if (!snap.exists()) return [];
    const results = [];
    snap.forEach((child) => results.push({ _key: child.key, ...child.val() }));
    return results;
  } catch (error) {
    console.error(`dbGetAll error:`, error.message);
    return [];
  }
}

async function dbQuery(pathName, orderBy, equalTo, limitToLast = null) {
  if (!firebaseReady) return [];
  try {
    let ref = db.ref(pathName).orderByChild(orderBy).equalTo(equalTo);
    if (limitToLast) ref = ref.limitToLast(limitToLast);
    const snap = await ref.once('value');
    if (!snap.exists()) return [];
    const results = [];
    snap.forEach((child) => results.push({ _key: child.key, ...child.val() }));
    return results;
  } catch (error) {
    console.error(`dbQuery error:`, error.message);
    return [];
  }
}

function dbListen(pathName, callback) {
  if (!firebaseReady) return () => {};
  const ref = db.ref(pathName);
  ref.on('value', (snapshot) => {
    callback(snapshot.exists() ? snapshot.val() : null);
  });
  return () => ref.off();
}

module.exports = {
  admin,
  db,
  auth: null,
  messaging: null,
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