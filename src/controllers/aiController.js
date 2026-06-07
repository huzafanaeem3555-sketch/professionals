const { getServiceRecommendation, getAIAssistantReply } = require('../config/groq');
const ProfessionalModel = require('../models/professionalModel');
const ServiceAnalyticsModel = require('../models/serviceAnalyticsModel');
const { resolveViewerContext, canViewFemaleProfessional } = require('../utils/accountPolicy');

const SERVICE_KEYWORDS = {
  plumber: ['plumber', 'pipe', 'leak', 'tap', 'sink', 'drain', 'sewerage', 'water', 'pani', 'nal', 'flush'],
  electrician: ['electric', 'bijli', 'wire', 'wiring', 'fan', 'light', 'switch', 'socket', 'breaker', 'ups'],
  carpenter: ['carpenter', 'wood', 'furniture', 'door', 'darwaza', 'almari', 'cabinet', 'bed'],
  'ac mechanic': ['ac', 'air condition', 'cooling', 'fridge', 'freezer', 'gas', 'hvac'],
  painter: ['paint', 'rang', 'wall', 'ceiling', 'safedi'],
  cleaner: ['clean', 'safai', 'deep cleaning', 'bathroom', 'sofa'],
  tutor: ['tutor', 'teacher', 'tuition', 'parhai', 'math', 'english', 'study'],
  driver: ['driver', 'drive', 'pick and drop', 'car driver'],
  chef: ['chef', 'cook', 'khana', 'cooking'],
  beautician: ['beauty', 'beautician', 'makeup', 'mehndi', 'salon', 'hair'],
  'it technician': ['computer', 'laptop', 'mobile', 'wifi', 'internet', 'software', 'cctv', 'printer'],
  'security guard': ['security', 'guard', 'watchman', 'chowkidar'],
  gardener: ['garden', 'lawn', 'plants'],
  mechanic: ['mechanic', 'car repair', 'bike repair', 'engine'],
  welder: ['welding', 'welder', 'gate'],
  mason: ['mason', 'mistri', 'tiles', 'brick'],
};

function cleanEnglishText(value) {
  return String(value || '')
    .replace(/[\u3400-\u9FFF\uF900-\uFAFF]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function allServicesFor(pro) {
  return [
    ...(Array.isArray(pro.services) ? pro.services : []),
    ...(Array.isArray(pro.customServices) ? pro.customServices : []),
  ]
    .map(cleanEnglishText)
    .filter(Boolean);
}

function normalizeService(value) {
  return cleanEnglishText(value).toLowerCase().replace(/_/g, ' ').trim();
}

function fallbackServiceFromText(text) {
  const query = normalizeService(text);
  for (const [service, keywords] of Object.entries(SERVICE_KEYWORDS)) {
    if (keywords.some(keyword => query.includes(keyword))) return service;
  }
  return '';
}

function distanceKm(a, b) {
  const lat1 = Number(a?.lat || 0);
  const lon1 = Number(a?.lng || 0);
  const lat2 = Number(b?.lat || 0);
  const lon2 = Number(b?.lng || 0);
  if (!lat1 || !lon1 || !lat2 || !lon2) return null;
  const radius = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const x =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) ** 2;
  return Number((radius * 2 * Math.atan2(Math.sqrt(x), Math.sqrt(1 - x))).toFixed(2));
}

function professionalScore(pro, matchedService, customerLocation) {
  const services = allServicesFor(pro).map(normalizeService);
  const service = normalizeService(matchedService);
  let score = 0;
  if (service && services.some(s => s.includes(service) || service.includes(s))) score += 80;
  score += Number(pro.isFeatured === true ? 30 : 0);
  score += Number(pro.rating || 0) * 8;
  score += Math.min(Number(pro.totalRatings || 0), 50) * 0.4;
  score += Math.min(Number(pro.completedJobs || 0), 80) * 0.3;
  const distance = distanceKm(customerLocation, pro.location);
  if (distance !== null) score += Math.max(0, 30 - distance);
  return { score, distance };
}

async function findMatchingProfessionals(req, message, serviceType) {
  const viewer = await resolveViewerContext(req);
  const customerLocation = req.body?.location || req.body?.customerLocation || null;
  const all = await ProfessionalModel.getAll();
  const matched = [];

  for (const pro of all) {
    if (pro.isAvailable === false || pro.isActive === false) continue;
    if (!canViewFemaleProfessional(viewer, pro)) continue;

    const services = allServicesFor(pro);
    const normalizedServices = services.map(normalizeService);
    const normalizedServiceType = normalizeService(serviceType);
    const normalizedMessage = normalizeService(message);
    const serviceMatch = normalizedServiceType &&
      normalizedServices.some(s => s.includes(normalizedServiceType) || normalizedServiceType.includes(s));
    const keywordMatch = normalizedServices.some(s => normalizedMessage.includes(s) || s.includes(normalizedMessage));
    if (normalizedServiceType) {
      if (!serviceMatch && !keywordMatch) continue;
    } else if (!keywordMatch) {
      continue;
    }

    const ranked = professionalScore(pro, serviceType, customerLocation);
    matched.push({
      uid: pro.uid,
      name: cleanEnglishText(pro.name) || 'Professional',
      phone: pro.phoneNumber || pro.phone || '',
      services,
      location: pro.location || {},
      rating: Number(pro.rating || 0),
      totalRatings: Number(pro.totalRatings || 0),
      completedJobs: Number(pro.completedJobs || 0),
      hourlyRate: Number(pro.hourlyRate || 0),
      reliabilityScore: Number(pro.reliabilityScore || 0),
      photoURL: pro.photoURL || '',
      isFeatured: pro.isFeatured === true,
      distance: ranked.distance,
      score: ranked.score,
    });
  }

  matched.sort((a, b) => b.score - a.score);
  return matched.slice(0, 5).map(({ score, ...pro }) => pro);
}

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

      const recommendation = await getServiceRecommendation(message.trim());
      const matchedService =
        normalizeService(recommendation?.serviceType) || fallbackServiceFromText(message.trim());
      if (matchedService) {
        await ServiceAnalyticsModel.recordSearch(message.trim(), [matchedService]).catch(() => null);
      }
      const professionals = await findMatchingProfessionals(req, message.trim(), matchedService);
      const reply = await getAIAssistantReply(message.trim(), history, {
        serviceType: matchedService,
        professionals,
      });
      return res.json({
        success: true,
        data: {
          reply,
          matchedService,
          professionals,
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
