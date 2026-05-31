const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

// Initialize Firebase RTDB first
require('./config/firebase');

const authRoutes = require('./routes/auth');
const professionalRoutes = require('./routes/professionals');
const customerRoutes = require('./routes/customers');
const bookingRoutes = require('./routes/bookings');
const userRoutes = require('./routes/users');
const walletRoutes = require('./routes/wallet');
// Payment routes disabled — direct phone reveal on booking
// const paymentRoutes = require('./routes/payments');
const chatRoutes = require('./routes/chat');
const adminRoutes = require('./routes/admin');
const aiRoutes = require('./routes/ai');
const geolocationRoutes = require('./routes/geolocation');
const utilityRoutes = require('./routes/utils');
const searchRoutes = require('./routes/search');  // ✅ ADDED
const notificationRoutes = require('./routes/notifications');

const app = express();
app.set('trust proxy', 1);
app.disable('x-powered-by');

// ————————————————— Security & Middleware —————————————————————
app.use(helmet({ crossOriginResourcePolicy: false }));

// Allow ALL origins including mobile app on LAN (192.168.1.x)
app.use(
  cors({
    origin: (origin, callback) => callback(null, true),
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: false,
  }),
);

app.use(express.json({ limit: '15mb' })); // Large limit for base64 images
app.use(express.urlencoded({ extended: true, limit: '15mb' }));
app.use(morgan('dev'));

// ✅ ROOT ROUTE - Already Here
app.get('/', (req, res) => {
  res.json({
    success: true,
    message: 'Service Connect backend is running',
    apiBase: '/api',
    health: '/health',
  });
});

// ————————————————— Health Check ————————————————————————
app.get('/health', (req, res) => {
  const host = req.app.locals.host || process.env.HOST || '0.0.0.0';
  const port = req.app.locals.port || process.env.PORT || 3000;
  const displayHost = host === '0.0.0.0' ? 'All Interfaces (0.0.0.0)' : host;
  res.json({
    status: 'OK',
    message: 'Service Connect API running',
    listeningOn: `http://${displayHost}:${port}`,
    accessibleAt: [
      `http://localhost:${port}`,
      `http://127.0.0.1:${port}`,
      `http://192.168.1.10:${port}`,
    ],
    database: 'Firebase Realtime Database',
    imageStorage: 'ImgBB (free)',
    ai: 'Groq llama3-8b-8192',
    timestamp: new Date().toISOString(),
  });
});

// ————————————————— API Routes ————————————————————————
app.use('/api/auth', authRoutes);
app.use('/api/professionals', professionalRoutes);
app.use('/api/customers', customerRoutes);
app.use('/api/bookings', bookingRoutes);
app.use('/api/users', userRoutes);
app.use('/api/wallet', walletRoutes);
// Payment routes kept for admin legacy; app uses direct phone contact on booking
// app.use('/api/payments', paymentRoutes);

app.use('/api/chat', chatRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/ai', aiRoutes);
app.use('/api/geolocation', geolocationRoutes);
app.use('/api/utils', utilityRoutes);
app.use('/api/search', searchRoutes);  // ✅ ADDED
app.use('/api/notifications', notificationRoutes);

// ————————————————— 404 ————————————————————————
app.use((req, res) => {
  res.status(404).json({ success: false, message: `Route ${req.method} ${req.originalUrl} not found` });
});

// ————————————————— Error Handler ————————————————————————
app.use((err, req, res, next) => {
  console.error('Error:', err.message);
  res.status(err.statusCode || 500).json({
    success: false,
    message: err.message || 'Internal Server Error',
  });
});

module.exports = app;

process.noDeprecation = process.env.NODE_NO_DEPRECATION !== 'false';
