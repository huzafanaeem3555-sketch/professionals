const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middleware/auth');
const AuthController = require('../controllers/authController');

router.post('/google', AuthController.google);
router.post('/signup', AuthController.signUp);
router.post('/signin', AuthController.signIn);
router.post('/refresh', AuthController.refreshToken);
router.post('/check-role', AuthController.checkRole);
router.get('/me', verifyToken, AuthController.getMe);
router.post('/set-role', verifyToken, AuthController.setRole);
router.post('/complete-profile', verifyToken, AuthController.completeProfile);
router.post('/update-location', verifyToken, AuthController.updateLocation);
router.post('/update-phone', verifyToken, AuthController.updatePhone);
router.post('/logout', verifyToken, AuthController.logout);
router.delete('/delete-account', verifyToken, AuthController.deleteAccount);

module.exports = router;
