const express = require('express');
const router = express.Router();
const { verifyToken, optionalAuth } = require('../middleware/auth');
const GeolocationController = require('../controllers/geolocationController');

/**
 * GET /api/geolocation/nearby
 * Query params: lat, lng, radiusKm (default 10), serviceType, minRating, maxPrice
 * Returns: list of nearby professionals with location
 */
router.get('/nearby', optionalAuth, GeolocationController.getNearbyProfessionals);

/**
 * POST /api/geolocation/professional-location
 * Body: { bookingId } or { professionalId }
 * Returns: professional location + phone ONLY if booking is confirmed
 * Auth required: customer
 */
router.post('/professional-location', verifyToken, GeolocationController.getProfessionalLocationForBooking);

/**
 * POST /api/geolocation/update-location
 * Body: { lat, lng, address (optional) }
 * Returns: updated location
 * Auth required: professional
 */
router.post('/update-location', verifyToken, GeolocationController.updateProfessionalLocation);

module.exports = router;
