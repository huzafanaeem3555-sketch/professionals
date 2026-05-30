const jwt = require('jsonwebtoken');
const { auth } = require('../config/firebase');
const JWT_SECRET = process.env.JWT_SECRET || 'service-connect-secret-change-in-production';

const verifyToken = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        message: 'No authentication token. Please login first.',
      });
    }

    const authToken = authHeader.split('Bearer ')[1];
    if (!authToken) {
      return res.status(401).json({ success: false, message: 'Invalid token format.' });
    }

    let decoded;
    try {
      decoded = jwt.verify(authToken, JWT_SECRET);
      req.user = {
        uid: decoded.uid,
        email: decoded.email,
        displayName: decoded.displayName || '',
      };
      return next();
    } catch (jwtError) {
      // Not a backend session token, try Firebase ID token
    }

    const firebaseDecoded = await auth.verifyIdToken(authToken);
    req.user = {
      uid: firebaseDecoded.uid,
      email: firebaseDecoded.email,
      displayName: firebaseDecoded.name,
      photoURL: firebaseDecoded.picture,
    };
    next();
  } catch (error) {
    if (error.code === 'auth/id-token-expired') {
      return res.status(401).json({ success: false, message: 'Session expired. Please login again.' });
    }
    return res.status(401).json({ success: false, message: 'Invalid authentication token.' });
  }
};

const optionalAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (authHeader?.startsWith('Bearer ')) {
      const authToken = authHeader.split('Bearer ')[1];
      try {
        const decoded = jwt.verify(authToken, JWT_SECRET);
        req.user = { uid: decoded.uid, email: decoded.email, displayName: decoded.displayName || '' };
      } catch (jwtError) {
        const decoded = await auth.verifyIdToken(authToken);
        req.user = { uid: decoded.uid, email: decoded.email, displayName: decoded.name };
      }
    }
  } catch (_) {}
  next();
};

module.exports = { verifyToken, optionalAuth };
