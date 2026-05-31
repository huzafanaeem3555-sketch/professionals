const express = require('express');
const router = express.Router();
const MarketplaceController = require('../controllers/marketplaceController');
const { verifyToken, optionalAuth } = require('../middleware/auth');

router.post('/complaints', verifyToken, MarketplaceController.createComplaint);
router.get('/favorites', verifyToken, MarketplaceController.listFavorites);
router.post('/favorites/:professionalId', verifyToken, MarketplaceController.toggleFavorite);
router.delete('/favorites/:professionalId', verifyToken, (req, res) => {
  req.body = { favorite: false };
  return MarketplaceController.toggleFavorite(req, res);
});
router.post('/referrals', verifyToken, MarketplaceController.createReferral);
router.get('/referrals', verifyToken, MarketplaceController.listMyReferrals);
router.post('/referrals/apply', verifyToken, MarketplaceController.applyReferral);
router.post('/jobs', verifyToken, MarketplaceController.createJobPost);
router.get('/jobs', optionalAuth, MarketplaceController.listJobPosts);
router.post('/jobs/:postId/offers', verifyToken, MarketplaceController.createJobOffer);
router.get('/jobs/:postId/offers', verifyToken, MarketplaceController.listJobOffers);
router.post('/featured/request', verifyToken, MarketplaceController.requestFeatured);
router.post('/certificates', verifyToken, MarketplaceController.uploadCertificate);
router.get('/certificates/:professionalId?', optionalAuth, MarketplaceController.listCertificates);

module.exports = router;
