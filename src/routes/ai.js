const express = require('express');
const router = express.Router();
const AIController = require('../controllers/aiController');
const { verifyToken } = require('../middleware/auth');

// POST /api/ai/recommend-service — describe problem, get service suggestion
router.post('/recommend-service', verifyToken, AIController.recommendService);

// POST /api/ai/chat — AI support assistant
router.post('/chat', verifyToken, AIController.aiChat);

module.exports = router;
