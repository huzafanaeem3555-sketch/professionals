const express = require('express');
const multer = require('multer');
const router = express.Router();
const { verifyToken } = require('../middleware/auth');
const PaymentController = require('../controllers/paymentController');

const upload = multer({ storage: multer.memoryStorage() });

router.post('/verify', verifyToken, PaymentController.verifyTransaction);
router.post('/verify-screenshot', verifyToken, upload.single('image'), PaymentController.verifyScreenshot);
router.post('/confirm/:bookingId', verifyToken, PaymentController.confirmPayment);
router.post('/', verifyToken, PaymentController.processPayment);

module.exports = router;
