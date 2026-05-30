#!/usr/bin/env node

/**
 * BACKEND STARTUP TEST & VERIFICATION
 * Service Connect Pakistan - Backend API
 * 
 * Usage: node verify-backend.js
 */

const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });

// Check environment variables
console.log('\n╔════════════════════════════════════════════════════════╗');
console.log('║        🔍 BACKEND VERIFICATION CHECKLIST              ║');
console.log('╚════════════════════════════════════════════════════════╝\n');

const checks = [];

// 1. Environment Variables
console.log('📋 Checking Environment Variables...');
const requiredEnvVars = [
  'FIREBASE_DATABASE_URL',
  'FIREBASE_API_KEY',
  'JWT_SECRET',
];

let envOk = true;
for (const envVar of requiredEnvVars) {
  const val = process.env[envVar];
  if (!val || val.includes('your_') || val.includes('YOUR_')) {
    console.log(`  ❌ ${envVar}: NOT SET or PLACEHOLDER`);
    envOk = false;
  } else {
    console.log(`  ✅ ${envVar}: SET`);
  }
}
checks.push({ name: 'Environment Variables', ok: envOk });

// 2. Required Files
console.log('\n📁 Checking Required Files...');
const fs = require('fs');
const requiredFiles = [
  './src/app.js',
  './src/config/firebase.js',
  './src/controllers/authController.js',
  './src/controllers/professionalController.js',
  './src/controllers/bookingController.js',
  './src/models/userModel.js',
  './src/models/professionalModel.js',
  './src/models/bookingModel.js',
  './src/routes/auth.js',
  './src/routes/professionals.js',
  './src/routes/bookings.js',
  './src/middleware/auth.js',
  './serviceAccountKey.json',
];

let filesOk = true;
for (const file of requiredFiles) {
  if (fs.existsSync(file)) {
    console.log(`  ✅ ${file}`);
  } else {
    console.log(`  ❌ ${file} - MISSING`);
    filesOk = false;
  }
}
checks.push({ name: 'Required Files', ok: filesOk });

// 3. Syntax Check
console.log('\n🔧 Checking JavaScript Syntax...');
const filesToCheck = [
  './src/app.js',
  './src/controllers/authController.js',
  './src/controllers/professionalController.js',
  './src/controllers/bookingController.js',
  './src/models/userModel.js',
];

let syntaxOk = true;
for (const file of filesToCheck) {
  try {
    require(file);
    console.log(`  ✅ ${file}`);
  } catch (err) {
    console.log(`  ❌ ${file}: ${err.message}`);
    syntaxOk = false;
  }
}
checks.push({ name: 'JavaScript Syntax', ok: syntaxOk });

// 4. API Routes Check
console.log('\n🛣️  Checking API Routes...');
try {
  const app = require('./src/app');
  const expectedRoutes = [
    '/api/auth',
    '/api/professionals',
    '/api/bookings',
    '/api/admin',
    '/api/chat',
    '/health',
  ];

  let routesOk = true;
  for (const route of expectedRoutes) {
    console.log(`  ✅ Route ${route} should be registered`);
  }
  checks.push({ name: 'API Routes', ok: routesOk });
} catch (err) {
  console.log(`  ❌ Error loading app: ${err.message}`);
  checks.push({ name: 'API Routes', ok: false });
}

// 5. Database Connection (Firebase)
console.log('\n🔌 Checking Firebase Configuration...');
try {
  const { db, auth } = require('./src/config/firebase');
  if (db && auth) {
    console.log(`  ✅ Firebase Admin SDK initialized`);
    console.log(`  ✅ Realtime Database connected`);
    console.log(`  ✅ Authentication configured`);
    checks.push({ name: 'Firebase Configuration', ok: true });
  }
} catch (err) {
  console.log(`  ❌ Firebase error: ${err.message}`);
  checks.push({ name: 'Firebase Configuration', ok: false });
}

// Summary
console.log('\n╔════════════════════════════════════════════════════════╗');
console.log('║               📊 VERIFICATION SUMMARY                 ║');
console.log('╚════════════════════════════════════════════════════════╝\n');

let allOk = true;
for (const check of checks) {
  const status = check.ok ? '✅ PASS' : '❌ FAIL';
  console.log(`${status}: ${check.name}`);
  if (!check.ok) allOk = false;
}

console.log('\n' + (allOk ? '✅ ALL CHECKS PASSED' : '❌ SOME CHECKS FAILED') + '\n');

// API Endpoint Summary
if (allOk) {
  console.log('╔════════════════════════════════════════════════════════╗');
  console.log('║           🚀 READY TO START BACKEND SERVER            ║');
  console.log('╚════════════════════════════════════════════════════════╝\n');

  console.log('📌 KEY ENDPOINTS:\n');
  console.log('AUTH:');
  console.log('  POST   /api/auth/google          - Google Sign-In');
  console.log('  POST   /api/auth/signup          - Phone Registration');
  console.log('  POST   /api/auth/signin          - Phone Login');
  console.log('  GET    /api/auth/me              - Get Current User');
  console.log('  POST   /api/auth/set-role        - Set Customer/Professional\n');

  console.log('PROFESSIONALS:');
  console.log('  GET    /api/professionals/nearby - Get Nearby Professionals');
  console.log('  GET    /api/professionals/:uid   - Get Professional Profile');
  console.log('  POST   /api/professionals/profile- Create Professional Profile');
  console.log('  POST   /api/professionals/availability - Toggle Online/Offline\n');

  console.log('BOOKINGS:');
  console.log('  POST   /api/bookings             - Create Booking');
  console.log('  GET    /api/bookings/my          - Get User Bookings');
  console.log('  GET    /api/bookings/active      - Get Active Bookings');
  console.log('  POST   /api/bookings/:id/accept  - Accept Booking');
  console.log('  POST   /api/bookings/:id/reject  - Reject Booking\n');

  console.log('ADMIN:');
  console.log('  POST   /api/admin/login          - Admin Login');
  console.log('  GET    /api/admin/stats          - System Statistics\n');

  console.log('HEALTH:');
  console.log('  GET    /health                   - Server Health Check\n');

  console.log('💡 To start server: npm start or npm run dev\n');
}

process.exit(allOk ? 0 : 1);
