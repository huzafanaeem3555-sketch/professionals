const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middleware/auth');
const UtilityController = require('../controllers/utilityController');

/**
 * POST /api/utils/validate-profile
 * Validate professional profile completeness.
 * Returns: { isComplete, missingFields }
 */
router.post('/validate-profile', verifyToken, UtilityController.validateProfessionalProfile);

/**
 * POST /api/utils/reset-test-data
 * Reset user data for testing (delete bookings, chats, reset wallet to 5000).
 * Dev/test only — disabled in production.
 */
router.post('/reset-test-data', verifyToken, UtilityController.resetTestData);

module.exports = router;
