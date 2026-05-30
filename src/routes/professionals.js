const express = require('express');
const router = express.Router();
const ProfessionalController = require('../controllers/professionalController');
const { verifyToken, optionalAuth } = require('../middleware/auth');

// ==================== PUBLIC ROUTES ====================

// GET /api/professionals/all - Get all professionals
router.get('/all', ProfessionalController.getAll);

// GET /api/professionals/nearby - Get professionals sorted by distance
router.get('/nearby', ProfessionalController.getNearby);

// ==================== AUTHORIZED ROUTES ====================

// POST /api/professionals/profile - Create/update profile
router.post('/profile', verifyToken, ProfessionalController.upsertProfile);

// GET /api/professionals/profile - Get own profile
router.get('/profile', verifyToken, ProfessionalController.getOwnProfile);

// POST /api/professionals/availability - Toggle availability (online/offline)
router.post('/availability', verifyToken, ProfessionalController.updateAvailability);
router.patch('/availability', verifyToken, ProfessionalController.updateAvailability);

// GET /api/professionals/wallet - Get wallet balance
router.get('/wallet', verifyToken, ProfessionalController.getWallet);

// GET /api/professionals/transactions - Get transaction history
router.get('/transactions', verifyToken, ProfessionalController.getTransactions);

// POST /api/professionals/upload-photo - Upload profile/portfolio image
router.post('/upload-photo', verifyToken, ProfessionalController.uploadPhoto);
router.post('/upload-portfolio', verifyToken, ProfessionalController.uploadPortfolio);

// GET /api/professionals/earnings - Get own earnings stats
router.get('/earnings', verifyToken, ProfessionalController.getEarnings);

// Legacy routing support
router.get('/', ProfessionalController.getAll);
router.get('/profile/own', verifyToken, ProfessionalController.getOwnProfile);

// GET /api/professionals/:uid - Get professional public profile by UID (optionalAuth)
router.get('/:uid', optionalAuth, ProfessionalController.getByUid);

module.exports = router;
