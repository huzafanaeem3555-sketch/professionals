const fs = require('node:fs');
const path = require('node:path');
const admin = require('firebase-admin');

let db;
let firebaseReady = false;
let firebaseInitError = null;

const DB_TIMEOUT_MS = Number(process.env.DB_TIMEOUT_MS || 8000);

function withTimeout(promise, label, timeoutMs = DB_TIMEOUT_MS) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(
      () => reject(new Error(`${label} timed out after ${timeoutMs}ms`)),
      timeoutMs,
    );
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

function parseServiceAccountJson(raw) {
  if (!raw) return null;
  try {
    const parsed = typeof raw === 'string' ? JSON.parse(raw) : raw;
    if (!parsed || typeof parsed !== 'object') return null;
    return parsed;
  } catch (error) {
    throw new Error(`Invalid Firebase service account JSON: ${error.message}`);
  }
}

function readServiceAccountFromPath(candidatePath) {
  if (!candidatePath) return null;
  const resolved = path.isAbsolute(candidatePath)
    ? candidatePath
    : path.resolve(process.cwd(), candidatePath);
  if (!fs.existsSync(resolved)) return null;
  const raw = fs.readFileSync(resolved, 'utf8');
  return parseServiceAccountJson(raw);
}

function loadServiceAccount() {
  const inlineJson =
    process.env.FIREBASE_SERVICE_ACCOUNT_JSON ||
    process.env.FIREBASE_SERVICE_ACCOUNT_JSON_STR ||
    '';
  const inlineBase64 =
    process.env.FIREBASE_SERVICE_ACCOUNT_JSON_B64 ||
    process.env.FIREBASE_SERVICE_ACCOUNT_BASE64 ||
    '';
  const serviceAccountPath =
    process.env.FIREBASE_SERVICE_ACCOUNT_PATH ||
    path.resolve(__dirname, 'serviceAccountKey.json');

  if (inlineJson.trim()) {
    return parseServiceAccountJson(inlineJson);
  }

  if (inlineBase64.trim()) {
    const decoded = Buffer.from(inlineBase64, 'base64').toString('utf8');
    return parseServiceAccountJson(decoded);
  }

  return readServiceAccountFromPath(serviceAccountPath);
}

function initializeFirebase() {
  if (admin.apps.length) {
    firebaseReady = true;
    return true;
  }

  try {
    const databaseURL =
      process.env.FIREBASE_DATABASE_URL ||
      'https://serviceconnect-dea35-default-rtdb.firebaseio.com/';
    const serviceAccount = loadServiceAccount();
    const appConfig = { databaseURL };

    if (serviceAccount) {
      appConfig.credential = admin.credential.cert(serviceAccount);
    } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      appConfig.credential = admin.credential.applicationDefault();
    } else {
      throw new Error(
        'Missing Firebase credentials. Set FIREBASE_SERVICE_ACCOUNT_JSON, FIREBASE_SERVICE_ACCOUNT_JSON_B64, or FIREBASE_SERVICE_ACCOUNT_PATH.',
      );
    }

    admin.initializeApp(appConfig);
    db = admin.database();
    firebaseReady = true;
    console.log('✅ Firebase initialized successfully');
    return true;
  } catch (error) {
    firebaseInitError = error;
    firebaseReady = false;
    console.error('❌ Firebase init failed:', error.message);
    db = {
      ref: () => ({
        once: async () => ({ exists: () => false, val: () => null }),
        set: async () => {},
        update: async () => {},
        remove: async () => {},
        push: () => ({ key: 'fallback', set: async () => {} }),
      }),
    };
    return false;
  }
}

initializeFirebase();

const auth = firebaseReady ? admin.auth() : null;
const messaging = firebaseReady ? admin.messaging() : null;

async function dbGet(pathName) {
  if (!firebaseReady) return null;
  try {
    const snap = await withTimeout(db.ref(pathName).once('value'), `dbGet ${pathName}`);
    return snap.exists() ? snap.val() : null;
  } catch (error) {
    console.error(`dbGet error:`, error.message);
    return null;
  }
}

async function dbSet(pathName, data) {
  if (!firebaseReady) return false;
  try {
    await withTimeout(db.ref(pathName).set(data), `dbSet ${pathName}`);
    return true;
  } catch (error) {
    console.error(`dbSet error:`, error.message);
    return false;
  }
}

async function dbUpdate(pathName, data) {
  if (!firebaseReady) return false;
  try {
    await withTimeout(db.ref(pathName).update(data), `dbUpdate ${pathName}`);
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
    await withTimeout(ref.set(data), `dbPush ${pathName}`);
    return ref.key;
  } catch (error) {
    console.error(`dbPush error:`, error.message);
    return null;
  }
}

async function dbDelete(pathName) {
  if (!firebaseReady) return false;
  try {
    await withTimeout(db.ref(pathName).remove(), `dbDelete ${pathName}`);
    return true;
  } catch (error) {
    console.error(`dbDelete error:`, error.message);
    return false;
  }
}

async function dbQuery(pathName, orderBy, equalTo, limitToLast = null) {
  if (!firebaseReady) return [];
  try {
    let ref = db.ref(pathName).orderByChild(orderBy).equalTo(equalTo);
    if (limitToLast) ref = ref.limitToLast(limitToLast);
    const snap = await withTimeout(ref.once('value'), `dbQuery ${pathName}`);
    if (!snap.exists()) return [];
    const results = [];
    snap.forEach((child) => results.push({ _key: child.key, ...child.val() }));
    return results;
  } catch (error) {
    console.error(`dbQuery error:`, error.message);
    return [];
  }
}

async function dbGetAll(pathName) {
  if (!firebaseReady) return [];
  try {
    const snap = await withTimeout(db.ref(pathName).once('value'), `dbGetAll ${pathName}`);
    if (!snap.exists()) return [];
    const results = [];
    snap.forEach((child) => results.push({ _key: child.key, ...child.val() }));
    return results;
  } catch (error) {
    console.error(`dbGetAll error:`, error.message);
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
  auth,
  messaging,
  firebaseReady,
  firebaseInitError,
  dbGet,
  dbSet,
  dbUpdate,
  dbPush,
  dbDelete,
  dbQuery,
  dbGetAll,
  dbListen,
};
