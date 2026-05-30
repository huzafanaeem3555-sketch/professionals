require('dotenv').config();
const axios = require('axios');
const UserModel = require('../models/userModel');
const jwt = require('jsonwebtoken');
const { auth } = require('../config/firebase');

const JWT_SECRET = process.env.JWT_SECRET || 'service-connect-secret-change-in-production';
const SESSION_EXPIRES = process.env.SESSION_EXPIRES || '7d';
const PHONE_EMAIL_DOMAIN = process.env.PHONE_EMAIL_DOMAIN || 'serviceconnect.pk';

const createSessionToken = (uid, email) =>
  jwt.sign({ uid, email }, JWT_SECRET, { expiresIn: SESSION_EXPIRES });

const safeCreateCustomToken = async (uid) => {
  try {
    return await auth.createCustomToken(uid);
  } catch (error) {
    console.warn(`createCustomToken skipped for ${uid}: ${error.message}`);
    return null;
  }
};

const createProfileDisplayName = (emailOrPhone) => {
  if (!emailOrPhone) return 'Service Connect User';
  const local = String(emailOrPhone).split('@')[0];
  return local || 'User';
};

const buildUserPayload = (user) => {
  const lat = user.lat ?? user.location?.lat ?? 0;
  const lng = user.lng ?? user.location?.lng ?? 0;
  return {
    uid: user.uid,
    email: user.email || '',
    displayName: user.displayName || '',
    photoURL: user.photoURL || '',
    role: user.role || null,
    profileCompleted: Boolean(user.profileCompleted),
    phoneNumber: user.phoneNumber || '',
    rating: user.rating || 0,
    totalRatings: user.totalRatings || 0,
    vehicleDetails: user.vehicleDetails || null,
    address: user.address || '',
    location: user.location || (lat || lng ? { lat, lng } : null),
    lat,
    lng,
  };
};

/** 03001234567 → 03001234567@serviceconnect.pk */
const normalizePhone = (phone) => String(phone || '').replace(/[\s|-]/g, '').trim();

const phoneToAuthEmail = (phone) => {
  const digits = normalizePhone(phone).replace(/\D/g, '');
  if (!digits) {
    throw new Error('Enter a valid phone number.');
  }
  return `${digits}@${PHONE_EMAIL_DOMAIN}`;
};

/**
 * Accept { phone, password } OR { email, password } from Flutter.
 */
const resolveEmailPassword = (body) => {
  const { email, password, phone, phoneNumber } = body || {};
  const rawPhone = phone || phoneNumber;

  if (email && password) {
    return {
      email: String(email).trim().toLowerCase(),
      password: String(password),
      phoneNumber: rawPhone ? normalizePhone(rawPhone) : '',
    };
  }

  if (rawPhone && password) {
    const authEmail = phoneToAuthEmail(rawPhone);
    return {
      email: authEmail,
      password: String(password),
      phoneNumber: normalizePhone(rawPhone),
    };
  }

  return null;
};

const signInWithEmailPasswordRest = async (email, password) => {
  const apiKey = process.env.FIREBASE_API_KEY;
  console.log('FIREBASE_API_KEY exists:', !!apiKey);
  if (!apiKey || apiKey.includes('your_firebase')) {
    throw new Error(
      'FIREBASE_API_KEY missing in backend/.env — copy current_key from android/app/google-services.json',
    );
  }

  const url = `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`;
  console.log('[signInWithEmailPasswordRest] URL:', url);

  try {
    const response = await axios.post(
      url,
      { email, password, returnSecureToken: true },
      { timeout: 20000 },
    );
    return response.data;
  } catch (error) {
    console.error('Firebase signInWithPassword error:', {
      message: error.message,
      status: error.response?.status,
      responseData: error.response?.data,
      code: error.code,
      stack: error.stack,
    });
    throw error;
  }
};

const firebaseAuthErrorMessage = (error) => {
  const code = error?.code || '';
  const map = {
    'auth/email-already-exists': 'Phone already registered. Use Sign In.',
    'auth/user-not-found': 'Wrong phone number or password.',
    'auth/invalid-password': 'Wrong phone number or password.',
    'auth/invalid-email': 'Invalid phone/email format.',
    'auth/weak-password': 'Password must be at least 6 characters.',
  };
  return map[code] || error?.message || 'Authentication failed.';
};

const restAuthErrorMessage = (error) => {
  const msg = error?.response?.data?.error?.message;
  if (msg === 'EMAIL_NOT_FOUND' || msg === 'INVALID_PASSWORD' || msg === 'INVALID_LOGIN_CREDENTIALS') {
    return 'Wrong phone number or password.';
  }
  if (msg === 'EMAIL_EXISTS') {
    return 'Phone already registered. Use Sign In.';
  }
  return msg || error?.message || 'Authentication failed.';
};

/** Get or create Firebase Auth user via Admin SDK (signup — no reCAPTCHA). */
const getOrCreateFirebaseUser = async ({ email, password, displayName, phoneNumber }) => {
  try {
    const existing = await auth.getUserByEmail(email);
    return { firebaseUser: existing, created: false };
  } catch (err) {
    if (err.code !== 'auth/user-not-found') {
      throw err;
    }
  }

  const firebaseUser = await auth.createUser({
    email,
    password,
    displayName: displayName || createProfileDisplayName(phoneNumber || email),
  });
  return { firebaseUser, created: true };
};

const buildAuthSuccessResponse = async ({
  uid,
  email,
  phoneNumber,
  displayName,
  photoURL,
  fcmToken,
  isNewFirebaseUser,
}) => {
  const user = await UserModel.upsert(uid, {
    email,
    displayName: displayName || createProfileDisplayName(phoneNumber || email),
    photoURL: photoURL || '',
    fcmToken: fcmToken || '',
    phoneNumber: phoneNumber || '',
    role: null,
    profileCompleted: false,
  });

  const customToken = await safeCreateCustomToken(uid);

  return {
    user: buildUserPayload({ ...user, uid }),
    token: createSessionToken(uid, email),
    customToken,
    expiresIn: SESSION_EXPIRES,
    isNewUser: Boolean(isNewFirebaseUser || user.isNew),
  };
};

const verifyAuthToken = async (idToken) => {
  try {
    const payload = await auth.verifyIdToken(idToken);
    return { provider: 'firebase', payload };
  } catch (fbErr) {
    const resp = await axios.get(
      `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`,
      { timeout: 15000 },
    );
    const payload = resp.data;
    const googleClientIds = (process.env.GOOGLE_CLIENT_IDS || process.env.GOOGLE_CLIENT_ID || '')
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
    if (googleClientIds.length > 0 && !googleClientIds.includes(payload.aud)) {
      throw new Error('Google OAuth client ID (aud) not recognized.');
    }
    if (!payload.email || payload.email_verified === 'false' || payload.email_verified === false) {
      throw new Error('Google token does not contain a verified email.');
    }
    return { provider: 'google', payload };
  }
};

const AuthController = {
  /** POST /api/auth/google — Google OAuth idToken from google_sign_in (no signInWithCredential) */
  async google(req, res) {
    try {
      const { idToken, fcmToken } = req.body;
      if (!idToken) {
        return res.status(400).json({ success: false, message: 'idToken is required.' });
      }

      const verification = await verifyAuthToken(idToken);
      const provider = verification.provider;
      const decoded = verification.payload;

      const uid = provider === 'firebase' ? decoded.uid : `google:${decoded.sub}`;
      const email = decoded.email;
      const displayName =
        decoded.name || decoded.displayName || createProfileDisplayName(email);
      const photoURL = decoded.picture || decoded.photoURL || '';

      let user = await UserModel.getById(uid, true);
      let isNewUser = false;
      if (!user) {
        user = await UserModel.upsert(uid, {
          email,
          displayName,
          photoURL,
          fcmToken: fcmToken || '',
          phoneNumber: '',
          role: null,
          profileCompleted: false,
        });
        isNewUser = true;
      } else {
        if (fcmToken) {
          await UserModel.updateFcmToken(uid, fcmToken);
          user.fcmToken = fcmToken;
        }
      }

      const customToken = await safeCreateCustomToken(uid);

      return res.status(200).json({
        success: true,
        message: 'Signed in with Google.',
        data: {
          user: buildUserPayload(user),
          token: createSessionToken(uid, email),
          customToken,
          expiresIn: SESSION_EXPIRES,
          isNewUser,
          ...(provider === 'google' ? { googleToken: idToken } : { firebaseToken: idToken }),
        },
      });
    } catch (error) {
      console.error('Google auth error:', error?.response?.data || error.message || error);
      const msg = error.message || 'token verification failed';
      let hint = '';
      if (msg.includes('aud') || msg.includes('client')) {
        hint = ' Set GOOGLE_CLIENT_IDS in backend/.env to your Web client ID from google-services.json.';
      }
      return res.status(401).json({
        success: false,
        message: 'Google authentication failed: ' + msg + hint,
      });
    }
  },

  /** POST /api/auth/signup — phone+password OR email+password */
  async signUp(req, res) {
    const started = Date.now();
    try {
      const creds = resolveEmailPassword(req.body);
      if (!creds) {
        return res.status(400).json({
          success: false,
          message: 'phone+password or email+password is required.',
        });
      }

      if (creds.password.length < 6) {
        return res.status(400).json({
          success: false,
          message: 'Password must be at least 6 characters.',
        });
      }

      const { email, password, phoneNumber } = creds;
      const { displayName, fcmToken } = req.body;

      console.log(`[signup] ${email} (phone=${phoneNumber || 'n/a'})`);

      const { firebaseUser, created } = await getOrCreateFirebaseUser({
        email,
        password,
        displayName,
        phoneNumber,
      });

      const data = await buildAuthSuccessResponse({
        uid: firebaseUser.uid,
        email,
        phoneNumber,
        displayName: firebaseUser.displayName || displayName,
        photoURL: firebaseUser.photoURL || '',
        fcmToken,
        isNewFirebaseUser: created,
      });

      console.log(`[signup] OK uid=${firebaseUser.uid} in ${Date.now() - started}ms`);

      return res.status(created ? 201 : 200).json({
        success: true,
        message: created
          ? 'Account created successfully.'
          : 'Account already exists — signed in.',
        data,
      });
    } catch (error) {
      console.error('signup error:', error?.response?.data || error.code || error.message || error);
      const status = error.code === 'auth/email-already-exists' ? 400 : 401;
      return res.status(status).json({
        success: false,
        message: firebaseAuthErrorMessage(error) || restAuthErrorMessage(error),
      });
    }
  },

  /** POST /api/auth/signin — phone+password OR email+password */
  async signIn(req, res) {
    const started = Date.now();
    try {
      const creds = resolveEmailPassword(req.body);
      if (!creds) {
        return res.status(400).json({
          success: false,
          message: 'phone+password or email+password is required.',
        });
      }

      const { email, password, phoneNumber } = creds;
      const { fcmToken } = req.body;

      console.log(`[signin] ${email}`);

      const signInResult = await signInWithEmailPasswordRest(email, password);
      const decoded = await auth.verifyIdToken(signInResult.idToken);
      const uid = decoded.uid;

      let user = await UserModel.getById(uid, true);
      if (!user) {
        const firebaseUser = await auth.getUser(uid);
        await UserModel.upsert(uid, {
          email,
          displayName: firebaseUser.displayName || createProfileDisplayName(phoneNumber || email),
          photoURL: firebaseUser.photoURL || '',
          fcmToken: fcmToken || '',
          phoneNumber: phoneNumber || '',
          role: null,
          profileCompleted: false,
        });
      } else {
        if (fcmToken) await UserModel.updateFcmToken(uid, fcmToken);
        if (phoneNumber && phoneNumber !== user.phoneNumber) {
          await UserModel.updatePhoneNumber(uid, phoneNumber);
        }
      }

      const freshUser = await UserModel.getById(uid, true);
      const customToken = await safeCreateCustomToken(uid);

      console.log(`[signin] OK uid=${uid} in ${Date.now() - started}ms`);

      return res.status(200).json({
        success: true,
        data: {
          user: buildUserPayload(freshUser),
          token: createSessionToken(uid, email),
          customToken,
          expiresIn: SESSION_EXPIRES,
          firebaseToken: signInResult.idToken,
        },
      });
    } catch (error) {
      console.error('signin error:', {
        message: error.message,
        status: error.response?.status,
        responseData: error.response?.data,
        code: error.code,
        stack: error.stack,
      });

      if (error.message?.includes('FIREBASE_API_KEY')) {
        return res.status(500).json({ success: false, message: error.message });
      }

      return res.status(401).json({
        success: false,
        message: restAuthErrorMessage(error) || firebaseAuthErrorMessage(error),
      });
    }
  },

  /** POST /api/auth/signin with idToken (Google / legacy) */
  async signInWithToken(req, res) {
    try {
      const { idToken, fcmToken, phoneNumber } = req.body;
      if (!idToken) {
        return res.status(400).json({ success: false, message: 'idToken is required.' });
      }

      const verification = await verifyAuthToken(idToken);
      const provider = verification.provider;
      const decoded = verification.payload;

      const uid = provider === 'firebase' ? decoded.uid : `google:${decoded.sub}`;
      const emailAddress = decoded.email;
      const displayName = decoded.name || decoded.displayName;
      const photoURL = decoded.picture || decoded.photoURL;
      const phone = phoneNumber || decoded.phone_number || '';

      let user = await UserModel.getById(uid, true);
      let isNewUser = false;
      if (!user) {
        user = await UserModel.upsert(uid, {
          email: emailAddress,
          displayName: displayName || createProfileDisplayName(emailAddress),
          photoURL: photoURL || '',
          fcmToken: fcmToken || '',
          phoneNumber: phone || '',
          role: null,
          profileCompleted: false,
        });
        isNewUser = true;
      } else {
        if (fcmToken) {
          await UserModel.updateFcmToken(uid, fcmToken);
          user.fcmToken = fcmToken;
        }
        if (phone && phone !== user.phoneNumber) {
          await UserModel.updatePhoneNumber(uid, phone);
          user.phoneNumber = phone;
        }
      }

      const customToken = await safeCreateCustomToken(uid);

      const responseData = {
        user: buildUserPayload(user),
        token: createSessionToken(uid, emailAddress),
        customToken,
        expiresIn: SESSION_EXPIRES,
        isNewUser,
      };
      if (provider === 'firebase') responseData.firebaseToken = idToken;
      else responseData.googleToken = idToken;

      return res.status(200).json({ success: true, data: responseData });
    } catch (error) {
      console.error('signin token error:', error);
      return res.status(401).json({
        success: false,
        message: error.message || 'Signin token verification failed.',
      });
    }
  },

  async setRole(req, res) {
    try {
      const { uid } = req.user;
      const { role } = req.body;

      if (!role || !['customer', 'professional'].includes(role)) {
        return res.status(400).json({
          success: false,
          message: 'Invalid role. Must be "customer" or "professional".',
        });
      }

      const user = await UserModel.getById(uid, true);
      if (!user) {
        return res.status(404).json({ success: false, message: 'User not found.' });
      }

      await UserModel.updateRole(uid, role);

      if (role === 'professional') {
        const ProfessionalModel = require('../models/professionalModel');
        const pro = await ProfessionalModel.getById(uid);
        if (!pro) {
          await ProfessionalModel.upsert(uid, {
            walletBalance: 5000,
            profileCreated: false,
            profileCompleted: false,
          });
        }
      }

      const updatedUser = await UserModel.getById(uid, true);

      return res.status(200).json({
        success: true,
        data: { user: buildUserPayload(updatedUser) },
      });
    } catch (error) {
      console.error('setRole error:', error);
      return res.status(500).json({ success: false, message: error.message || 'Failed to set role.' });
    }
  },

  async checkRole(req, res) {
    try {
      const { email, phone, phoneNumber } = req.body;
      let lookupEmail = email;
      if (!lookupEmail && (phone || phoneNumber)) {
        lookupEmail = phoneToAuthEmail(phone || phoneNumber);
      }
      if (!lookupEmail) {
        return res.status(400).json({ success: false, message: 'email or phone is required.' });
      }

      const user = await UserModel.getByEmail(lookupEmail);
      return res.status(200).json({
        success: true,
        data: {
          hasRole: Boolean(user?.role),
          existingRole: user?.role || null,
        },
      });
    } catch (error) {
      console.error('checkRole error:', error);
      return res.status(500).json({ success: false, message: 'Role check failed.' });
    }
  },

  async refreshToken(req, res) {
    try {
      const { token } = req.body;
      if (!token) {
        return res.status(400).json({ success: false, message: 'token is required.' });
      }
      const decoded = jwt.verify(token, JWT_SECRET);
      const sessionToken = createSessionToken(decoded.uid, decoded.email);
      return res.status(200).json({
        success: true,
        data: { token: sessionToken, expiresIn: SESSION_EXPIRES },
      });
    } catch (error) {
      console.error('refreshToken error:', error);
      return res.status(401).json({ success: false, message: 'Invalid or expired session token.' });
    }
  },

  async getMe(req, res) {
    try {
      const { uid } = req.user;
      const user = await UserModel.getById(uid, true);

      if (!user) {
        return res.status(404).json({ success: false, message: 'User not found' });
      }

      return res.status(200).json({
        success: true,
        data: { user: buildUserPayload(user) },
      });
    } catch (error) {
      console.error('getMe error:', error);
      return res.status(500).json({ success: false, message: 'Failed to fetch user profile.' });
    }
  },

  async updateLocation(req, res) {
    try {
      const { uid } = req.user;
      const { lat, lng, address } = req.body;

      if (!lat || !lng) {
        return res.status(400).json({ success: false, message: 'lat and lng are required.' });
      }

      await UserModel.updateLocation(uid, lat, lng, address);
      return res.status(200).json({ success: true, data: { message: 'Location updated successfully.' } });
    } catch (error) {
      console.error('updateLocation error:', error);
      return res.status(500).json({ success: false, message: 'Failed to update location.' });
    }
  },

  async updatePhone(req, res) {
    try {
      const { uid } = req.user;
      const { phoneNumber } = req.body;

      if (!phoneNumber) {
        return res.status(400).json({ success: false, message: 'Phone number is required.' });
      }

      const pkPhone = /^(03\d{9}|3\d{9})$/;
      if (!pkPhone.test(phoneNumber.replace(/\s|-/g, ''))) {
        return res.status(400).json({
          success: false,
          message: 'Please enter a valid Pakistani mobile number (e.g., 03001234567).',
        });
      }

      await UserModel.updatePhoneNumber(uid, phoneNumber);
      return res.status(200).json({ success: true, data: { message: 'Phone number updated successfully.' } });
    } catch (error) {
      console.error('updatePhone error:', error);
      return res.status(500).json({ success: false, message: 'Failed to update phone number.' });
    }
  },

  async logout(req, res) {
    return res.status(200).json({ success: true, data: { message: 'Logged out successfully.' } });
  },

  async deleteAccount(req, res) {
    try {
      const { uid } = req.user;
      const { db } = require('../config/firebase');
      await db.ref(`users/${uid}`).remove();
      await db.ref(`professionals/${uid}`).remove();

      return res.status(200).json({ success: true, data: { message: 'Account and data deleted successfully.' } });
    } catch (error) {
      console.error('deleteAccount error:', error);
      return res.status(500).json({ success: false, message: 'Failed to delete account data.' });
    }
  },

  async completeProfile(req, res) {
    try {
      const { uid } = req.user;
      const { displayName, name, phoneNumber, phone, location, vehicleDetails } = req.body;
      const finalName = displayName || name;
      const finalPhone = phoneNumber || phone;

      if (!finalName) {
        return res.status(400).json({ success: false, message: 'Name is required.' });
      }
      if (!finalPhone) {
        return res.status(400).json({ success: false, message: 'Phone number is required.' });
      }
      if (!location || location.lat === undefined || location.lng === undefined) {
        return res.status(400).json({ success: false, message: 'Location (lat, lng) is required.' });
      }

      const user = await UserModel.getById(uid, true);
      if (!user) {
        return res.status(404).json({ success: false, message: 'User not found.' });
      }

      const lat = parseFloat(location.lat);
      const lng = parseFloat(location.lng);

      const userUpdates = {
        displayName: finalName,
        name: finalName,
        phoneNumber: finalPhone,
        lat,
        lng,
        location: {
          lat,
          lng,
        },
        address: location.address || '',
        profileCompleted: true,
        _updatedAt: Date.now(),
      };

      if (vehicleDetails) {
        userUpdates.vehicleDetails = {
          make: vehicleDetails.make || '',
          model: vehicleDetails.model || '',
          year: vehicleDetails.year || '',
          color: vehicleDetails.color || '',
          plateNumber: vehicleDetails.plateNumber || '',
        };
      }

      const { db } = require('../config/firebase');
      await db.ref(`users/${uid}`).update(userUpdates);

      if (user.role === 'professional') {
        const proUpdates = {
          profileCompleted: true,
          profileCreated: true,
          displayName: finalName,
          phoneNumber: finalPhone,
          lat,
          lng,
          address: location.address || '',
          isAvailableNow: true,
        };
        if (vehicleDetails) {
          proUpdates.vehicleDetails = {
            make: vehicleDetails.make || '',
            model: vehicleDetails.model || '',
            year: vehicleDetails.year || '',
            color: vehicleDetails.color || '',
            plateNumber: vehicleDetails.plateNumber || '',
          };
        }
        await db.ref(`professionals/${uid}`).update(proUpdates);
      }

      const updatedUser = await UserModel.getById(uid, true);

      return res.status(200).json({
        success: true,
        data: { user: buildUserPayload(updatedUser) },
      });
    } catch (error) {
      console.error('completeProfile error:', error);
      return res.status(500).json({ success: false, message: error.message || 'Failed to complete profile.' });
    }
  },
};

/**
 * signIn route: email/password OR idToken (Google).
 * Original signIn mixed both; keep one entry point.
 */
const originalSignIn = AuthController.signIn.bind(AuthController);
AuthController.signIn = async (req, res) => {
  if (req.body?.idToken && !req.body?.password) {
    return AuthController.signInWithToken(req, res);
  }
  return originalSignIn(req, res);
};

module.exports = AuthController;
