const express = require('express');
const router = express.Router();
const BookingController = require('../controllers/bookingController');
const { verifyToken } = require('../middleware/auth');

// All booking routes require authorization
router.use(verifyToken);

// POST /api/bookings - Create new booking (customer requested booking)
router.post('/', BookingController.createBooking);
router.post('/create', BookingController.createBooking);

// GET /api/bookings/my - Get user's bookings (both customer & professional)
router.get('/my', BookingController.getMyBookings);

router.get('/professional/:id', BookingController.getProfessionalBookingsById);

// Legacy routing support
router.get('/customer/:customerId', BookingController.getMyBookings);
router.get('/professional/:professionalPhone', BookingController.getMyBookings);
router.get('/active', async (req, res) => {
  const BookingModel = require('../models/bookingModel');
  const bookings = await BookingModel.getActiveBookingsForUser(req.user.uid);
  return res.json({ success: true, data: { activeBookings: bookings } });
});

// GET /api/bookings/:bookingId - Get single booking details
router.get('/:bookingId', BookingController.getBooking);

// POST /api/bookings/:bookingId/propose-price - Professional proposes counter price
router.post('/:bookingId/propose-price', BookingController.proposePrice);

// POST /api/bookings/:bookingId/counter-price - Customer counters a price
router.post('/:bookingId/counter-price', BookingController.counterPrice);

// POST /api/bookings/:bookingId/accept-price - Accepts agreed price
router.post('/:bookingId/accept-price', BookingController.acceptPrice);

// PATCH /api/bookings/:bookingId/accept - Accept latest offer (mobile compatibility)
router.patch('/:bookingId/accept', BookingController.acceptBooking);

// POST /api/bookings/:bookingId/reject - Reject booking (either side)
router.post('/:bookingId/reject', BookingController.rejectBooking);
router.patch('/:bookingId/reject', BookingController.rejectBooking);

// POST /api/bookings/:bookingId/start - Professional starts job
router.post('/:bookingId/start', BookingController.startJob);

// POST /api/bookings/:bookingId/complete - Professional completes job
router.post('/:bookingId/complete', BookingController.completeBooking);
router.post('/:bookingId/customer-complete', BookingController.customerComplete);

// DELETE /api/bookings/:bookingId - Cancel booking (customer)
router.delete('/:bookingId', BookingController.cancelBooking);

// POST /api/bookings/:bookingId/rate - Customer rates professional
router.post('/:bookingId/rate', BookingController.rateBooking);

module.exports = router;
