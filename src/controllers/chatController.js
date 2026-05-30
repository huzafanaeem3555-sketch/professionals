const ChatModel = require('../models/chatModel');
const UserModel = require('../models/userModel');

const ChatController = {
  /**
   * GET /api/chat/:otherUserId
   * Get chat messages between current user and otherUserId.
   * Only allowed if a confirmed booking exists between them.
   */
  async getMessages(req, res) {
    try {
      const uid = req.user.uid;
      const { otherUserId } = req.params;
      
      const chatId = ChatModel.getChatId(uid, otherUserId);
      
      // Check if confirmed booking exists between them
      const isAllowed = await ChatModel.hasActiveBooking(uid, otherUserId);
      if (!isAllowed) {
        return res.status(403).json({ 
          success: false, 
          message: 'Chat is only available after booking is confirmed (payment verified).' 
        });
      }
      
      // Get or create chat
      await ChatModel.getOrCreate(uid, otherUserId);
      
      // Get messages
      const messages = await ChatModel.getMessages(chatId);
      
      return res.status(200).json({
        success: true,
        data: {
          chatId,
          messages,
        },
      });
    } catch (error) {
      console.error('getMessages error:', error);
      return res.status(500).json({ 
        success: false, 
        message: 'Failed to fetch messages.' 
      });
    }
  },

  /**
   * POST /api/chat/send
   * Send a message to professional or customer.
   */
  async sendMessage(req, res) {
    try {
      const uid = req.user.uid;
      const { receiverId, text } = req.body;
      
      if (!receiverId || !text || text.trim().length === 0) {
        return res.status(400).json({ 
          success: false, 
          message: 'receiverId and text are required.' 
        });
      }
      
      if (text.length > 1000) {
        return res.status(400).json({ 
          success: false, 
          message: 'Message too long. Maximum 1000 characters.' 
        });
      }
      
      // Check if confirmed booking exists between them
      const isAllowed = await ChatModel.hasActiveBooking(uid, receiverId);
      if (!isAllowed) {
        return res.status(403).json({ 
          success: false, 
          message: 'Chat is only available after booking is confirmed (payment verified).' 
        });
      }
      
      const chatId = ChatModel.getChatId(uid, receiverId);
      await ChatModel.getOrCreate(uid, receiverId);
      
      const message = await ChatModel.sendMessage(chatId, uid, text.trim());
      
      return res.status(201).json({
        success: true,
        data: {
          messageId: message.id,
          timestamp: message.timestamp,
        },
      });
    } catch (error) {
      console.error('sendMessage error:', error);
      return res.status(500).json({ 
        success: false, 
        message: 'Failed to send message.' 
      });
    }
  },

  /**
   * GET /api/chat/conversations
   * Get all conversations for current user.
   */
  async getConversations(req, res) {
    try {
      const uid = req.user.uid;
      
      const chats = await ChatModel.getConversationsForUser(uid);
      
      const conversations = await Promise.all(
        chats.map(async (chat) => {
          const participants = chat.participants || [];
          const otherUserId = participants.find(p => p !== uid);
          
          const otherUser = await UserModel.getById(otherUserId, true);
          
          return {
            chatId: chat.chatId,
            otherUserId: otherUserId || '',
            otherUserName: otherUser?.displayName || 'User',
            otherUserPhoto: otherUser?.photoURL || '',
            lastMessage: chat.lastMessage || '',
            lastUpdated: chat.lastUpdated || 0,
          };
        })
      );
      
      return res.status(200).json({ 
        success: true, 
        data: conversations 
      });
    } catch (error) {
      console.error('getConversations error:', error);
      return res.status(500).json({ 
        success: false, 
        message: 'Failed to fetch conversations.' 
      });
    }
  }
};

module.exports = ChatController;