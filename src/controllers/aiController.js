const { getServiceRecommendation, getAIAssistantReply } = require('../config/groq');

const AIController = {
  /**
   * POST /api/ai/recommend-service
   * User describes problem → AI suggests service type + price range.
   */
  async recommendService(req, res) {
    try {
      const { description } = req.body;
      if (!description || description.trim().length < 5) {
        return res.status(400).json({
          success: false,
          message: 'Please describe your problem in at least 5 characters.',
        });
      }

      const recommendation = await getServiceRecommendation(description.trim());
      return res.json({
        success: true,
        data: recommendation,
      });
    } catch (error) {
      console.error('recommendService error:', error);
      return res.status(500).json({
        success: false,
        message: 'AI recommendation failed. Please select service manually.',
      });
    }
  },

  /**
   * POST /api/ai/chat
   * In-app AI support assistant (powered by Groq llama3).
   */
  async aiChat(req, res) {
    try {
      const { message, history = [] } = req.body;
      if (!message || message.trim().length === 0) {
        return res.status(400).json({ success: false, message: 'Message is required.' });
      }

      const reply = await getAIAssistantReply(message.trim(), history);
      return res.json({
        success: true,
        data: {
          reply,
          model: 'llama-3.3-70b-versatile',
        },
      });
    } catch (error) {
      console.error('aiChat error:', error);
      return res.status(500).json({
        success: false,
        message: 'AI assistant is temporarily unavailable.',
      });
    }
  },
};

module.exports = AIController;
