const { deductCommission } = require('../services/walletService');

const WalletController = {
  async deduct(req, res) {
    try {
      const result = await deductCommission(req.body || {});
      if (!result.success) {
        return res.status(result.statusCode || 400).json({
          success: false,
          message: result.message || 'Failed to deduct wallet commission.',
        });
      }
      return res.status(200).json({ success: true, data: result.data });
    } catch (error) {
      console.error('wallet deduct error:', error);
      return res.status(500).json({
        success: false,
        message: 'Failed to deduct wallet commission.',
      });
    }
  },
};

module.exports = WalletController;
