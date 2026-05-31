const express = require('express');
const router = express.Router();
const { verifyAdminToken } = require('../middleware/adminAuth');
const AdminController = require('../controllers/adminController');

router.post('/login', AdminController.login);
router.get('/stats', verifyAdminToken, AdminController.getStats);
router.get('/professionals', verifyAdminToken, AdminController.getProfessionals);
router.patch('/professionals/:uid', verifyAdminToken, AdminController.updateProfessional);
router.get('/professionals/:uid/reviews', verifyAdminToken, AdminController.getProfessionalReviews);
router.delete('/professionals/:uid/reviews/:reviewId', verifyAdminToken, AdminController.deleteProfessionalReview);
router.get('/customers', verifyAdminToken, AdminController.getCustomers);
router.post('/users', verifyAdminToken, AdminController.createUser);
router.get('/bookings', verifyAdminToken, AdminController.getBookings);
router.get('/transactions', verifyAdminToken, AdminController.getTransactions);
router.get('/complaints', verifyAdminToken, AdminController.getComplaints);
router.patch('/complaints/:id', verifyAdminToken, AdminController.updateComplaint);
router.delete('/complaints/:id', verifyAdminToken, AdminController.deleteComplaint);
router.get('/marketplace', verifyAdminToken, AdminController.getMarketplace);
router.patch('/settings/contact-cleanup', verifyAdminToken, AdminController.updateCleanupSettings);
router.delete('/users/clear-all', verifyAdminToken, AdminController.clearAllData);
router.patch('/users/:uid/verify', verifyAdminToken, AdminController.verifyUser);
router.delete('/users/:uid', verifyAdminToken, AdminController.deleteUser);
router.delete('/bookings/:id', verifyAdminToken, AdminController.deleteBooking);

module.exports = router;
