const axios = require('axios');
const firebase = require('firebase/compat/app');
require('firebase/compat/database');

const FIREBASE_API_KEY =
  process.env.FIREBASE_API_KEY || 'AIzaSyAix8w3uQwdtBV0jYRSWoTBcQE_KYLPK2M';
const FIREBASE_DATABASE_URL =
  process.env.FIREBASE_DATABASE_URL ||
  'https://serviceconnect-dea35-default-rtdb.firebaseio.com/';

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

function normalizeAuthError(error, fallbackMessage) {
  const code = error?.code || error?.response?.data?.error?.message || '';
  const message = fallbackMessage || error?.message || 'Authentication failed.';
  const mapped = {
    EMAIL_EXISTS: 'auth/email-already-exists',
    EMAIL_NOT_FOUND: 'auth/user-not-found',
    INVALID_PASSWORD: 'auth/invalid-password',
    INVALID_LOGIN_CREDENTIALS: 'auth/invalid-password',
    USER_NOT_FOUND: 'auth/user-not-found',
  };
  const normalizedCode = mapped[code] || code;
  const err = new Error(message);
  if (normalizedCode) err.code = normalizedCode;
  return err;
}

function createFallbackQuery() {
  return {
    once: async () => ({
      exists: () => false,
      val: () => null,
      forEach: () => {},
    }),
    set: async () => {},
    update: async () => {},
    remove: async () => {},
    push: () => ({ key: 'fallback', set: async () => {} }),
    on: () => {},
    off: () => {},
    orderByChild: () => createFallbackQuery(),
    equalTo: () => createFallbackQuery(),
    limitToLast: () => createFallbackQuery(),
  };
}

async function callIdentityToolkit(endpoint, payload) {
  const url = `https://identitytoolkit.googleapis.com/v1/${endpoint}?key=${FIREBASE_API_KEY}`;
  try {
    const response = await axios.post(url, payload, { timeout: 20000 });
    return response.data;
  } catch (error) {
    throw normalizeAuthError(error);
  }
}

function mapAuthUser(user) {
  if (!user) return null;
  return {
    uid: user.localId || user.uid || '',
    email: user.email || '',
    displayName: user.displayName || user.name || '',
    photoURL: user.photoUrl || user.photoURL || '',
    phoneNumber: user.phoneNumber || '',
    emailVerified: user.emailVerified !== false,
    raw: user,
  };
}

async function firebaseLookupByIdToken(idToken) {
  const url = `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${FIREBASE_API_KEY}`;
  try {
    const response = await axios.post(
      url,
      { idToken },
      { timeout: 20000 },
    );
    const user = response.data?.users?.[0];
    if (!user) {
      throw normalizeAuthError({ code: 'USER_NOT_FOUND' }, 'Token user not found.');
    }
    return mapAuthUser(user);
  } catch (error) {
    throw normalizeAuthError(error);
  }
}

async function firebaseLookupByEmail(email) {
  const url = `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${FIREBASE_API_KEY}`;
  try {
    const response = await axios.post(
      url,
      { email: [email] },
      { timeout: 20000 },
    );
    const user = response.data?.users?.[0];
    if (!user) {
      throw normalizeAuthError({ code: 'USER_NOT_FOUND' }, 'User not found.');
    }
    return mapAuthUser(user);
  } catch (error) {
    throw normalizeAuthError(error);
  }
}

async function firebaseCreateUser({ email, password, displayName }) {
  const created = await callIdentityToolkit('accounts:signUp', {
    email,
    password,
    returnSecureToken: true,
  });

  if (displayName) {
    try {
      await callIdentityToolkit('accounts:update', {
        idToken: created.idToken,
        displayName,
        returnSecureToken: true,
      });
    } catch (_) {
      // Profile update is best-effort. The user still exists and can sign in.
    }
  }

  return mapAuthUser({
    localId: created.localId,
    email: created.email,
    displayName: displayName || created.displayName || '',
    photoUrl: created.photoUrl || '',
    emailVerified: created.emailVerified,
  });
}

function createAuthBridge() {
  return {
    async verifyIdToken(idToken) {
      return firebaseLookupByIdToken(idToken);
    },
    async getUserByEmail(email) {
      return firebaseLookupByEmail(email);
    },
    async getUser(uid) {
      const url = `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${FIREBASE_API_KEY}`;
      try {
        const response = await axios.post(
          url,
          { localId: [uid] },
          { timeout: 20000 },
        );
        const user = response.data?.users?.[0];
        if (!user) {
          throw normalizeAuthError({ code: 'USER_NOT_FOUND' }, 'User not found.');
        }
        return mapAuthUser(user);
      } catch (error) {
        throw normalizeAuthError(error);
      }
    },
    async createUser({ email, password, displayName }) {
      return firebaseCreateUser({ email, password, displayName });
    },
    async createCustomToken() {
      throw new Error('Custom token creation requires Firebase Admin credentials.');
    },
  };
}

function initializeFirebase() {
  try {
    const app = firebase.apps.length
      ? firebase.app()
      : firebase.initializeApp({ databaseURL: FIREBASE_DATABASE_URL });

    db = firebase.database(app);
    firebaseReady = true;
    console.log('✅ Firebase connected successfully');
  } catch (error) {
    firebaseInitError = error;
    firebaseReady = false;
    console.error('❌ Firebase connection failed:', error.message);
    db = {
      ref: () => createFallbackQuery(),
    };
  }
}

initializeFirebase();

const auth = createAuthBridge();
const messaging = null;

async function dbGet(pathName) {
  if (!firebaseReady) return null;
  try {
    const snapshot = await withTimeout(db.ref(pathName).once('value'), `dbGet ${pathName}`);
    return snapshot.exists() ? snapshot.val() : null;
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
    const newRef = db.ref(pathName).push();
    await withTimeout(newRef.set(data), `dbPush ${pathName}`);
    return newRef.key;
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

async function dbGetAll(pathName) {
  if (!firebaseReady) return [];
  try {
    const snapshot = await withTimeout(db.ref(pathName).once('value'), `dbGetAll ${pathName}`);
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

async function dbQuery(pathName, orderByField, equalToValue, limitVal = null) {
  if (!firebaseReady) return [];
  try {
    let q = db.ref(pathName).orderByChild(orderByField).equalTo(equalToValue);
    if (limitVal) {
      q = q.limitToLast(limitVal);
    }
    const snapshot = await withTimeout(q.once('value'), `dbQuery ${pathName}`);
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

function dbListen(pathName, callback) {
  if (!firebaseReady) return () => {};
  const ref = db.ref(pathName);
  const handler = (snapshot) => {
    callback(snapshot.exists() ? snapshot.val() : null);
  };
  ref.on('value', handler);
  return () => ref.off('value', handler);
}

module.exports = {
  db,
  auth,
  messaging,
  firebaseReady,
  firebaseInitError,
  firebaseApiKey: FIREBASE_API_KEY,
  dbGet,
  dbSet,
  dbUpdate,
  dbPush,
  dbDelete,
  dbGetAll,
  dbQuery,
  dbListen,
};
