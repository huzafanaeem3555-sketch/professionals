const express = require('express');
const { verifyToken } = require('../middleware/auth');
const AuthController = require('../controllers/authController');

const router = express.Router();

// Required compatibility endpoint:
// POST /api/users/set-role
router.post('/set-role', verifyToken, AuthController.setRole);

module.exports = router;
