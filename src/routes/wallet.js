const express = require('express');
const { verifyToken } = require('../middleware/auth');
const WalletController = require('../controllers/walletController');

const router = express.Router();

// Required compatibility endpoint:
// POST /api/wallet/deduct
router.post('/deduct', verifyToken, WalletController.deduct);

module.exports = router;
