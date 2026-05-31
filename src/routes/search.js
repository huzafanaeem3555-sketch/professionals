const express = require('express');
const router = express.Router();
const SearchController = require('../controllers/searchController');
const { optionalAuth } = require('../middleware/auth');

router.get('/', optionalAuth, SearchController.search);
router.get('/suggest', optionalAuth, SearchController.getSuggestions);

module.exports = router;
