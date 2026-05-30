const jwt = require('jsonwebtoken');
const ADMIN_TOKEN_SECRET = process.env.ADMIN_JWT_SECRET || process.env.JWT_SECRET || 'service-connect-secret-change-in-production';

const verifyAdminToken = (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ success: false, message: 'No admin authentication token provided.' });
    }

    const token = authHeader.split('Bearer ')[1];
    if (!token) {
      return res.status(401).json({ success: false, message: 'Invalid admin token format.' });
    }

    const decoded = jwt.verify(token, ADMIN_TOKEN_SECRET);
    if (decoded.role !== 'admin') {
      return res.status(403).json({ success: false, message: 'Admin access required.' });
    }

    req.admin = decoded;
    next();
  } catch (error) {
    return res.status(401).json({ success: false, message: 'Invalid or expired admin token.' });
  }
};

module.exports = { verifyAdminToken };
