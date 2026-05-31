const express = require('express');
const router = express.Router();
const SearchController = require('../controllers/searchController');
const { optionalAuth } = require('../middleware/auth');

router.get('/popular', optionalAuth, SearchController.getPopularServices);
router.post('/track', optionalAuth, SearchController.trackService);
router.get('/', optionalAuth, SearchController.search);
router.get('/suggest', optionalAuth, SearchController.getSuggestions);

module.exports = router;
