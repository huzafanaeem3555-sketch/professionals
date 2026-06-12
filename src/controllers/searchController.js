const ProfessionalModel = require('../models/professionalModel');
const ServiceAnalyticsModel = require('../models/serviceAnalyticsModel');
const { resolveViewerContext, canViewFemaleProfessional } = require('../utils/accountPolicy');
const { AI_MODEL, AI_PROVIDER, aiChatCompletion } = require('../config/groq');

// Service type mappings for fuzzy matching
const SERVICE_TYPES = [
  'plumber', 'electrician', 'carpenter', 'ac mechanic', 'ac technician',
  'painter', 'cleaner', 'house cleaner', 'tutor', 'teacher', 'driver',
  'chef', 'cook', 'beautician', 'makeup artist', 'hairdresser',
  'it technician', 'computer repair', 'security guard', 'gardener',
  'mechanic', 'car mechanic', 'welder', 'mason',
  'hvac', 'refrigerator repair', 'washing machine repair', 'mobile repair'
];

function allServicesFor(pro) {
  return [
    ...(Array.isArray(pro.services) ? pro.services : []),
    ...(Array.isArray(pro.serviceTypes) ? pro.serviceTypes : []),
    ...(Array.isArray(pro.customServices) ? pro.customServices : []),
  ].filter(Boolean);
}

function normalizeText(value) {
  return String(value || '')
    .toLowerCase()
    .replace(/_/g, ' ')
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function searchTokens(value) {
  return normalizeText(value)
    .split(' ')
    .filter(token => token.length >= 2);
}

function editDistance(a, b) {
  if (a === b) return 0;
  if (!a) return b.length;
  if (!b) return a.length;
  const dp = Array.from({ length: a.length + 1 }, () =>
    Array(b.length + 1).fill(0)
  );
  for (let i = 0; i <= a.length; i += 1) dp[i][0] = i;
  for (let j = 0; j <= b.length; j += 1) dp[0][j] = j;
  for (let i = 1; i <= a.length; i += 1) {
    for (let j = 1; j <= b.length; j += 1) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      dp[i][j] = Math.min(
        dp[i - 1][j] + 1,
        dp[i][j - 1] + 1,
        dp[i - 1][j - 1] + cost
      );
    }
  }
  return dp[a.length][b.length];
}

function tokenMatches(sourceToken, queryToken) {
  if (!sourceToken || !queryToken) return false;
  if (sourceToken === queryToken) return true;

  const minLength = Math.min(sourceToken.length, queryToken.length);
  if (minLength < 4) return false;

  if (sourceToken.startsWith(queryToken) || queryToken.startsWith(sourceToken)) {
    return true;
  }

  if (
    sourceToken[0] !== queryToken[0] ||
    Math.abs(sourceToken.length - queryToken.length) > 2
  ) {
    return false;
  }

  const maxDistance = minLength >= 5 ? 2 : 1;
  return editDistance(sourceToken, queryToken) <= maxDistance;
}

function serviceMatches(a, b) {
  const left = normalizeText(a);
  const right = normalizeText(b);
  if (!left || !right) return false;
  if (left === right) return true;
  if (left.length >= 4 && right.length >= 4 && (left.includes(right) || right.includes(left))) {
    return true;
  }

  const leftTokens = searchTokens(left);
  const rightTokens = searchTokens(right);
  if (rightTokens.length === 0) return false;
  return rightTokens.every(queryToken =>
    leftTokens.some(sourceToken => tokenMatches(sourceToken, queryToken))
  );
}

function profileMatchesQuery(pro, query) {
  const queryText = normalizeText(query);
  const queryTokens = searchTokens(queryText).filter(token => token.length >= 3);
  if (queryTokens.length === 0) return false;

  const profileText = normalizeText([
    pro.name,
    pro.displayName,
    pro.description,
    pro.location?.address,
    ...allServicesFor(pro),
  ].join(' '));
  if (!profileText) return false;
  if (queryText.length >= 4 && profileText.includes(queryText)) return true;

  const profileTokens = searchTokens(profileText);
  return queryTokens.every(queryToken =>
    profileTokens.some(profileToken => tokenMatches(profileToken, queryToken))
  );
}

function isVisibleToViewer(viewer, professional) {
  return canViewFemaleProfessional(viewer, professional);
}

function filterVisibleProfessionals(viewer, professionals) {
  return professionals.filter(pro => isVisibleToViewer(viewer, pro));
}

// Keywords to service type mapping (simple fallback)
const keywordToService = {
  'plumb': 'plumber',
  'pipe': 'plumber',
  'leak': 'plumber',
  'tap': 'plumber',
  'sink': 'plumber',
  'electric': 'electrician',
  'wire': 'electrician',
  'fan': 'electrician',
  'light': 'electrician',
  'carpenter': 'carpenter',
  'wood': 'carpenter',
  'furniture': 'carpenter',
  'ac': 'ac mechanic',
  'cool': 'ac mechanic',
  'air condition': 'ac mechanic',
  'paint': 'painter',
  'wall': 'painter',
  'clean': 'cleaner',
  'house clean': 'cleaner',
  'carpet': 'cleaner',
  'carpet clean': 'cleaner',
  'carpet cleaner': 'cleaner',
  'carpet cleaning': 'cleaner',
  'carpet wash': 'cleaner',
  'rug clean': 'cleaner',
  'rug cleaning': 'cleaner',
  'sofa clean': 'cleaner',
  'sofa cleaning': 'cleaner',
  'tutor': 'tutor',
  'tuition': 'tutor',
  'home tutor': 'tutor',
  'quran teacher': 'tutor',
  'math tutor': 'tutor',
  'english tutor': 'tutor',
  'academy': 'tutor',
  'teach': 'tutor',
  'study': 'tutor',
  'drive': 'driver',
  'driver': 'driver',
  'car driver': 'driver',
  'taxi': 'driver',
  'chef': 'chef',
  'cook': 'chef',
  'food': 'chef',
  'beauty': 'beautician',
  'makeup': 'beautician',
  'hair': 'beautician',
  'computer': 'it technician',
  'laptop': 'it technician',
  'software': 'it technician',
  'network': 'it technician',
  'networking': 'it technician',
  'wifi': 'it technician',
  'router': 'it technician',
  'internet': 'it technician',
  'security': 'security guard',
  'guard': 'security guard',
  'pani leak': 'plumber',
  'nal kharab': 'plumber',
  'pipe masla': 'plumber',
  'pipe issue': 'plumber',
  'water leakage': 'plumber',
  'tank overflow': 'plumber',
  'flush problem': 'plumber',
  'sewerage': 'plumber',
  'drain block': 'plumber',
  'motor pump': 'plumber',
  'bijli ka masla': 'electrician',
  'light nahi': 'electrician',
  'fan slow': 'electrician',
  'switch board': 'electrician',
  'socket': 'electrician',
  'breaker trip': 'electrician',
  'ups wiring': 'electrician',
  'geyser': 'electrician',
  'ac thanda nahi': 'ac mechanic',
  'ac cooling': 'ac mechanic',
  'ac gas': 'ac mechanic',
  'split ac': 'ac mechanic',
  'fridge cooling': 'ac mechanic',
  'deep freezer': 'ac mechanic',
  'darwaza': 'carpenter',
  'almari': 'carpenter',
  'bed repair': 'carpenter',
  'furniture repair': 'carpenter',
  'kitchen cabinet': 'carpenter',
  'rang': 'painter',
  'wall paint': 'painter',
  'safedi': 'painter',
  'ceiling paint': 'painter',
  'safai': 'cleaner',
  'deep cleaning': 'cleaner',
  'bathroom cleaning': 'cleaner',
  'sofa cleaning': 'cleaner',
  'parhai': 'tutor',
  'math teacher': 'tutor',
  'english teacher': 'tutor',
  'home tuition': 'tutor',
  'driver chahiye': 'driver',
  'car driver': 'driver',
  'pick and drop': 'driver',
  'khana pakana': 'chef',
  'cook chahiye': 'chef',
  'cooking': 'chef',
  'mehndi': 'beautician',
  'bridal': 'beautician',
  'salon': 'beautician',
  'laptop repair': 'it technician',
  'mobile repair': 'it technician',
  'wifi issue': 'it technician',
  'internet problem': 'it technician',
  'cctv': 'it technician',
  'chowkidar': 'security guard',
  'watchman': 'security guard',
  'garden': 'gardener',
  'lawn': 'gardener',
  'plants': 'gardener',
  'car repair': 'mechanic',
  'bike repair': 'mechanic',
  'engine': 'mechanic',
  'welding': 'welder',
  'gate welding': 'welder',
  'mistri': 'mason',
  'tiles': 'mason',
  'brick work': 'mason'
};

const SearchController = {
  /**
   * GET /api/search?q=
   * Search professionals using the configured AI provider.
   */
  async search(req, res) {
    try {
      const { q } = req.query;
      
      if (!q || q.trim().length === 0) {
        return res.status(400).json({ 
          success: false, 
          message: 'Search query is required.' 
        });
      }
      
      const query = q.trim().toLowerCase();
      
      // Step 1: Prefer deterministic service matching. AI can suggest only when
      // the local synonym map cannot classify the query.
      let matchedServices = [];
      let aiUsed = false;
      const deterministicServices = this._keywordSearch(query);
      
      if (deterministicServices.length > 0) {
        matchedServices = deterministicServices;
      } else if (AI_PROVIDER !== 'fallback') {
        try {
          const aiResult = await this._aiSearch(query);
          if (aiResult && aiResult.services && aiResult.services.length > 0) {
            matchedServices = aiResult.services.filter(service =>
              SERVICE_TYPES.some(type => serviceMatches(type, service))
            );
            aiUsed = true;
          }
        } catch (aiError) {
          console.error('AI search error:', aiError.message);
        }
      }
      
      await ServiceAnalyticsModel.recordSearch(query, matchedServices);
      
      // Step 3: Get professionals matching the services
      const viewer = await resolveViewerContext(req);
      const allProfessionals = filterVisibleProfessionals(
        viewer,
        await ProfessionalModel.getAll()
      );
      
      let filtered = allProfessionals.filter(pro => {
        if (!pro.isAvailable) return false;
        
        const proServices = allServicesFor(pro);
        if (matchedServices.length > 0) {
          return matchedServices.some(service =>
            proServices.some(s => serviceMatches(s, service))
          );
        }

        return profileMatchesQuery(pro, query);
      });
      
      // Add relevance score and sort
      const results = filtered.map(pro => ({
        uid: pro.uid,
        phone: pro.phoneNumber || pro.phone || '',
        name: pro.name,
        services: pro.services || [],
        customServices: pro.customServices || [],
        location: pro.location,
        rating: pro.rating || 0,
        totalRatings: pro.totalRatings || 0,
        isAvailable: pro.isAvailable,
        photoURL: pro.photoURL || '',
        relevance: this._calculateRelevance(pro, query, matchedServices)
      }));
      
      // Sort by relevance (highest first)
      results.sort((a, b) => {
        const relevanceDiff = b.relevance - a.relevance;
        if (relevanceDiff !== 0) return relevanceDiff;
        const ratingDiff = Number(b.rating || 0) - Number(a.rating || 0);
        if (ratingDiff !== 0) return ratingDiff;
        return Number(b.totalRatings || 0) - Number(a.totalRatings || 0);
      });
      
      return res.status(200).json({
        success: true,
        message: results.length
          ? 'Professionals found.'
          : 'No available professionals found for this search.',
        data: {
          query,
          aiUsed,
          matchedServices,
          results,
          count: results.length
        }
      });
    } catch (error) {
      console.error('Search error:', error);
      return res.status(500).json({ 
        success: false, 
        message: 'Search failed. Please try again.' 
      });
    }
  },
  
  /**
   * AI-based service search using the configured AI provider.
   */
  async _aiSearch(query) {
    if (AI_PROVIDER === 'fallback') {
      return { services: [], confidence: 'low', explanation: 'AI provider not configured' };
    }
    
    try {
      const prompt = `You are a service matching assistant. Analyze the user query and return ONLY the matching service types from this list: ${SERVICE_TYPES.join(', ')}.
      
User query: "${query}"

Return a JSON object with this exact format:
{
  "services": ["service1", "service2"],
  "confidence": "high/medium/low",
  "explanation": "brief reason"
}

If no service matches, return empty array for services.`;
      
      const completion = await aiChatCompletion({
        messages: [
          {
            role: 'system',
            content: 'You are a service matching assistant. Return only valid JSON.'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        temperature: 0.3,
        maxTokens: 500
      });
      
      const response = completion.choices[0]?.message?.content || '';
      
      // Extract JSON from response
      const jsonMatch = response.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        const result = JSON.parse(jsonMatch[0]);
        return {
          services: result.services || [],
          confidence: result.confidence || 'low',
          explanation: result.explanation || ''
        };
      }
      
      return { services: [], confidence: 'low', explanation: '' };
    } catch (error) {
      console.error(`${AI_PROVIDER} AI search error (${AI_MODEL}):`, error.message || error);
      return { services: [], confidence: 'low', explanation: '' };
    }
  },
  
  /**
   * Keyword-based search (fallback)
   */
  _keywordSearch(query) {
    const matchedServices = new Set();
    const normalizedQuery = normalizeText(query);
    const queryTokens = searchTokens(normalizedQuery);
    
    // Check direct service type matches
    for (const service of SERVICE_TYPES) {
      if (serviceMatches(service, normalizedQuery)) {
        matchedServices.add(service);
      }
    }
    
    // Check keyword mapping
    for (const [keyword, service] of Object.entries(keywordToService)) {
      const normalizedKeyword = normalizeText(keyword);
      if (
        serviceMatches(normalizedKeyword, normalizedQuery) ||
        queryTokens.some(token => tokenMatches(normalizedKeyword, token))
      ) {
        matchedServices.add(service);
      }
    }

    return Array.from(matchedServices);
  },
  
  /**
   * Calculate relevance score for sorting
   */
  _calculateRelevance(professional, query, matchedServices) {
    let score = 0;
    
    // Service match (higher weight)
    const proServices = allServicesFor(professional).map(normalizeText);
    for (const service of matchedServices) {
      if (proServices.some(s => serviceMatches(s, service))) {
        score += 80;
      }
    }
    for (const service of proServices) {
      if (service === query) score += 140;
      if (service.startsWith(query)) score += 110;
      if (service.includes(query)) score += 85;
    }
    
    // Name match
    const name = normalizeText(professional.name || professional.displayName);
    if (name === query) score += 130;
    if (name.startsWith(query)) score += 100;
    if (name.includes(query)) score += 70;
    const description = normalizeText(professional.description);
    if (description.includes(query)) score += 35;
    const address = normalizeText(professional.location?.address);
    if (address.includes(query)) score += 20;
    
    // Rating boost
    score += (professional.rating || 0) * 3;
    score += Math.min(Number(professional.totalRatings || 0), 50) / 5;
    
    return score;
  },

  async getPopularServices(req, res) {
    try {
      const limit = Math.min(Math.max(Number(req.query.limit || 50), 1), 100);
      const services = await ServiceAnalyticsModel.getPopularServices(limit);
      return res.status(200).json({
        success: true,
        data: services,
      });
    } catch (error) {
      console.error('popular services error:', error);
      return res.status(500).json({
        success: false,
        message: 'Failed to fetch popular services.',
      });
    }
  },

  async trackService(req, res) {
    try {
      const { query, serviceType } = req.body || {};
      await ServiceAnalyticsModel.recordSearch(query || serviceType, serviceType ? [serviceType] : []);
      return res.status(200).json({ success: true });
    } catch (error) {
      return res.status(500).json({
        success: false,
        message: 'Failed to track service search.',
      });
    }
  },
  
  /**
   * GET /api/search/suggest?q=
   * Get search suggestions (auto-complete)
   */
  async getSuggestions(req, res) {
    try {
      const { q } = req.query;
      
      if (!q || q.trim().length < 1) {
        return res.status(200).json({ 
          success: true, 
          data: { suggestions: [] } 
        });
      }
      
      const query = normalizeText(q.trim());
      const suggestions = new Set();
      const viewer = await resolveViewerContext(req);
      const popularServices = await ServiceAnalyticsModel.getPopularServices(100);
      const popularScore = new Map(
        popularServices.map(item => [
          ServiceAnalyticsModel.normalizeServiceKey(item.serviceKey || item.label),
          Number(item.score || item.totalUsage || 0),
        ])
      );
      
      // Add matching service types
      for (const service of SERVICE_TYPES) {
        if (service.includes(query) || query.includes(service)) {
          suggestions.add(service);
        }
      }
      
      // Add suggestions from professional names
      const allProfessionals = filterVisibleProfessionals(
        viewer,
        await ProfessionalModel.getAll()
      );
      for (const pro of allProfessionals) {
        const name = (pro.name || '').toLowerCase();
        if (name.includes(query)) {
          suggestions.add(pro.name);
        }
        for (const service of allServicesFor(pro)) {
          const normalized = service.toLowerCase();
          if (normalized.includes(query) || query.includes(normalized)) {
            suggestions.add(service);
          }
        }
      }
      
      return res.status(200).json({
        success: true,
        data: {
          suggestions: Array.from(suggestions)
            .sort((a, b) => {
              const scoreDiff =
                (popularScore.get(ServiceAnalyticsModel.normalizeServiceKey(b)) || 0) -
                (popularScore.get(ServiceAnalyticsModel.normalizeServiceKey(a)) || 0);
              if (scoreDiff !== 0) return scoreDiff;
              return String(a).localeCompare(String(b));
            })
            .slice(0, 10)
        }
      });
    } catch (error) {
      console.error('Suggestions error:', error);
      return res.status(500).json({ 
        success: false, 
        message: 'Failed to get suggestions.' 
      });
    }
  }
};

module.exports = SearchController;
