const express = require('express');
const router = express.Router();
const ChatController = require('../controllers/chatController');
const { verifyToken } = require('../middleware/auth');

router.use(verifyToken);

// GET /api/chat/:otherUserId - Get messages between current user and otherUserId
router.get('/:otherUserId', ChatController.getMessages);

// POST /api/chat/send - Send message
router.post('/send', ChatController.sendMessage);

// GET /api/chat/conversations - Get conversations for current user
router.get('/conversations', ChatController.getConversations);

module.exports = router;