const ProfessionalModel = require('../models/professionalModel');
const ServiceAnalyticsModel = require('../models/serviceAnalyticsModel');
const { resolveViewerContext, canViewFemaleProfessional } = require('../utils/accountPolicy');

// Initialize Groq client ONLY if API key exists (Prevents Railway crash)
let Groq;
let groq;

if (process.env.GROQ_API_KEY && process.env.GROQ_API_KEY !== 'your_groq_api_key_here') {
  try {
    Groq = require('groq-sdk');
    groq = new Groq({
      apiKey: process.env.GROQ_API_KEY
    });
    console.log('✅ Groq AI initialized successfully');
  } catch (err) {
    console.log('⚠️ Failed to initialize Groq:', err.message);
    groq = null;
  }
} else {
  console.log('⚠️ GROQ_API_KEY not set - AI search disabled, using keyword search only');
  groq = null;
}

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
    ...(Array.isArray(pro.customServices) ? pro.customServices : []),
  ].filter(Boolean);
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
  'carpent': 'carpenter',
  'wood': 'carpenter',
  'furniture': 'carpenter',
  'ac': 'ac mechanic',
  'cool': 'ac mechanic',
  'air condition': 'ac mechanic',
  'paint': 'painter',
  'wall': 'painter',
  'clean': 'cleaner',
  'house clean': 'cleaner',
  'tutor': 'tutor',
  'teach': 'tutor',
  'study': 'tutor',
  'drive': 'driver',
  'car': 'driver',
  'chef': 'chef',
  'cook': 'chef',
  'food': 'chef',
  'beauty': 'beautician',
  'makeup': 'beautician',
  'hair': 'beautician',
  'it': 'it technician',
  'computer': 'it technician',
  'laptop': 'it technician',
  'software': 'it technician',
  'security': 'security guard',
  'guard': 'security guard'
};

const SearchController = {
  /**
   * GET /api/search?q=
   * Search professionals using Groq AI
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
      
      // Step 1: Try Groq AI for smart search (only if groq is available)
      let matchedServices = [];
      let aiUsed = false;
      
      if (groq) {
        try {
          const aiResult = await this._aiSearch(query);
          if (aiResult && aiResult.services && aiResult.services.length > 0) {
            matchedServices = aiResult.services;
            aiUsed = true;
          }
        } catch (aiError) {
          console.error('Groq AI error:', aiError.message);
          // Fallback to keyword matching
        }
      }
      
      // Step 2: Fallback to keyword matching if AI fails or returns nothing
      if (matchedServices.length === 0) {
        matchedServices = this._keywordSearch(query);
      }
      await ServiceAnalyticsModel.recordSearch(query, matchedServices);
      
      // Step 3: Get professionals matching the services
      const viewer = await resolveViewerContext(req);
      const allProfessionals = filterVisibleProfessionals(
        viewer,
        await ProfessionalModel.getAll()
      );
      
      // Filter professionals by matched services
      let filtered = allProfessionals.filter(pro => {
        if (!pro.isAvailable) return false;
        
        const proServices = allServicesFor(pro);
        return matchedServices.some(service => 
          proServices.some(s => s.toLowerCase().includes(service) || service.includes(s.toLowerCase()))
        ) || proServices.some(s => {
          const normalized = s.toLowerCase().replace(/_/g, ' ');
          return normalized.includes(query) || query.includes(normalized);
        });
      });
      
      // If no matches by service, try name matching
      if (filtered.length === 0) {
        filtered = allProfessionals.filter(pro => {
          if (!pro.isAvailable) return false;
          const name = (pro.name || '').toLowerCase();
          return name.includes(query) || query.includes(name);
        });
      }
      
      // Add relevance score and sort
      const results = filtered.map(pro => ({
        uid: pro.uid,
        phone: pro.phone,
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
   * AI-based search using Groq
   */
  async _aiSearch(query) {
    // Check if groq is available
    if (!groq) {
      return { services: [], confidence: 'low', explanation: 'Groq not configured' };
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
      
      const completion = await groq.chat.completions.create({
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
        model: 'llama3-8b-8192',
        temperature: 0.3,
        max_tokens: 500
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
      console.error('Groq AI error:', error);
      return { services: [], confidence: 'low', explanation: '' };
    }
  },
  
  /**
   * Keyword-based search (fallback)
   */
  _keywordSearch(query) {
    const matchedServices = new Set();
    
    // Check direct service type matches
    for (const service of SERVICE_TYPES) {
      if (service.includes(query) || query.includes(service)) {
        matchedServices.add(service);
      }
    }
    
    // Check keyword mapping
    for (const [keyword, service] of Object.entries(keywordToService)) {
      if (query.includes(keyword)) {
        matchedServices.add(service);
      }
    }
    
    // If still no matches, add common services based on query length
    if (matchedServices.size === 0 && query.length > 2) {
      // Try partial matches
      for (const service of SERVICE_TYPES) {
        if (service.split(' ').some(word => query.includes(word) || word.includes(query))) {
          matchedServices.add(service);
        }
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
    const proServices = allServicesFor(professional).map(s => s.toLowerCase());
    for (const service of matchedServices) {
      if (proServices.some(s => s.includes(service) || service.includes(s))) {
        score += 10;
      }
    }
    
    // Name match
    const name = (professional.name || '').toLowerCase();
    if (name.includes(query)) {
      score += 5;
    }
    
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
      
      const query = q.trim().toLowerCase();
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
