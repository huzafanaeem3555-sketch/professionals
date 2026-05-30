const ProfessionalModel = require('../models/professionalModel');
const UserModel = require('../models/userModel');
const TransactionModel = require('../models/transactionModel');
const BookingModel = require('../models/bookingModel');
const { uploadMultipleToImgBB } = require('../utils/imgbb');

// Helper: Calculate distance between two coordinates (Haversine formula)
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Earth's radius in km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
            Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
            Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
}

function normalizeServiceList(value) {
  if (!Array.isArray(value)) return [];
  const seen = new Set();
  const result = [];
  for (const item of value) {
    const service = String(item || '').trim();
    if (!service) continue;
    const key = service.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(service);
  }
  return result;
}

async function formatProfessional(pro, { includePhone = false, phoneRevealed = false, includeReviews = false } = {}) {
  const reviews = includeReviews ? await ProfessionalModel.getReviews(pro.uid) : [];
  return {
    uid: pro.uid,
    name: pro.name,
    services: normalizeServiceList(pro.services),
    customServices: normalizeServiceList(pro.customServices),
    location: pro.location || { lat: 0, lng: 0 },
    rating: Number(pro.rating || 0),
    totalRatings: Number(pro.totalRatings || 0),
    completedJobs: Number(pro.completedJobs || 0),
    experienceYears: Number(pro.experienceYears || 0),
    isAvailable: pro.isAvailable !== false,
    photoURL: pro.photoURL || '',
    hourlyRate: pro.hourlyRate || 500,
    phoneNumber: includePhone && phoneRevealed ? (pro.phoneNumber || pro.phone || '') : 'Hidden until agreement',
    description: pro.description || '',
    brochureImages: Array.isArray(pro.brochureImages) ? pro.brochureImages : [],
    portfolio: Array.isArray(pro.portfolio) ? pro.portfolio : [],
    reviews,
  };
}

const ProfessionalController = {
  // GET /api/professionals/all - Get all professionals (public, hides phone)
  async getAll(req, res) {
    try {
      const professionals = await ProfessionalModel.getAll();
      
      const formatted = await Promise.all(professionals.map(pro => formatProfessional(pro)));
      
      return res.json({ success: true, data: formatted, count: formatted.length });
    } catch (error) {
      console.error('getAll error:', error);
      return res.status(500).json({ success: false, message: 'Failed to fetch professionals.' });
    }
  },

  // GET /api/professionals/nearby - Get professionals sorted by distance
  async getNearby(req, res) {
    try {
      const { lat, lng, radius = 20, serviceType } = req.query;
      
      if (!lat || !lng) {
        return res.status(400).json({ success: false, message: 'lat and lng are required.' });
      }
      
      const customerLat = parseFloat(lat);
      const customerLng = parseFloat(lng);
      const radiusKm = parseFloat(radius);
      
      const professionals = await ProfessionalModel.getNearby({
        lat: customerLat,
        lng: customerLng,
        radiusKm,
        serviceType
      });
      
      // Map and hide phone numbers
      const formatted = professionals.map(pro => ({
        ...pro,
        services: normalizeServiceList(pro.services),
        customServices: normalizeServiceList(pro.customServices),
        phoneNumber: 'Hidden until agreement'
      }));
      
      return res.json({ success: true, data: formatted, count: formatted.length });
    } catch (error) {
      console.error('getNearby error:', error);
      return res.status(500).json({ success: false, message: 'Failed to fetch nearby professionals.' });
    }
  },

  // GET /api/professionals/:uid - Get single professional by UID (hides phone unless booking confirmed)
  async getByUid(req, res) {
    try {
      const { uid } = req.params;
      const professional = await ProfessionalModel.getById(uid);
      
      if (!professional) {
        return res.status(404).json({ success: false, message: 'Professional not found.' });
      }
      
      // By default hide phone number unless requested by customer who has a confirmed booking
      let phoneRevealed = false;
      if (req.user) {
        const bookings = await BookingModel.getByUserId(req.user.uid);
        phoneRevealed = bookings.some(b => 
          b.professionalId === uid && 
          ['confirmed', 'in_progress', 'completed'].includes(b.status)
        );
      }
      
      const data = await formatProfessional(professional, {
        includePhone: true,
        phoneRevealed,
        includeReviews: true,
      });

      return res.json({
        success: true,
        data
      });
    } catch (error) {
      console.error('getByUid error:', error);
      return res.status(500).json({ success: false, message: 'Failed to fetch professional.' });
    }
  },

  // POST /api/professionals/profile - Create/update professional profile
  async upsertProfile(req, res) {
    try {
      const uid = req.user.uid;
      const { name, services, customServices, phoneNumber, location, photoURL, description, hourlyRate, experienceYears, brochureImages } = req.body;
      const normalizedServices = normalizeServiceList(services);
      const normalizedCustomServices = normalizeServiceList(customServices);
      
      if (!name) {
        return res.status(400).json({ success: false, message: 'Name is required.' });
      }
      if (!phoneNumber) {
        return res.status(400).json({ success: false, message: 'Phone number is required.' });
      }
      const pkPhone = /^(03\d{9}|3\d{9})$/;
      if (!pkPhone.test(phoneNumber.replace(/\s|-/g, ''))) {
        return res.status(400).json({
          success: false,
          message: 'Please enter a valid Pakistani mobile number (e.g., 03001234567).',
        });
      }
      if (normalizedServices.length === 0 && normalizedCustomServices.length === 0) {
        return res.status(400).json({ success: false, message: 'At least one service is required.' });
      }
      if (!location || location.lat === undefined || location.lng === undefined) {
        return res.status(400).json({ success: false, message: 'Location (lat, lng) is required.' });
      }
      
      const existing = await ProfessionalModel.getById(uid);
      
      const profileData = {
        name,
        services: normalizedServices,
        customServices: normalizedCustomServices,
        phoneNumber,
        location: {
          lat: parseFloat(location.lat),
          lng: parseFloat(location.lng),
          address: location.address || '',
        },
        description: description || existing?.description || '',
        photoURL: photoURL || existing?.photoURL || '',
        brochureImages: Array.isArray(brochureImages) ? brochureImages.map(String).filter(Boolean) : (existing?.brochureImages || []),
        hourlyRate: hourlyRate ? parseFloat(hourlyRate) : (existing?.hourlyRate || 500),
        experienceYears: experienceYears !== undefined ? Number(experienceYears) : (existing?.experienceYears || 0),
        walletBalance: existing ? existing.walletBalance : 5000,
        totalEarnings: existing ? existing.totalEarnings : 0,
        completedJobs: existing ? existing.completedJobs : 0,
        rating: existing ? existing.rating : 0,
        totalRatings: existing ? existing.totalRatings : 0,
      };
      
      const saved = await ProfessionalModel.upsert(uid, profileData);
      
      // Update professional details in UserModel as well
      await UserModel.upsert(uid, {
        displayName: name,
        phoneNumber,
        photoURL: photoURL || '',
        profileCompleted: true,
        location: profileData.location
      });
      
      return res.status(201).json({
        success: true,
        message: existing ? 'Profile updated successfully.' : 'Professional profile created successfully.',
        data: saved
      });
    } catch (error) {
      console.error('upsertProfile error:', error);
      return res.status(500).json({ success: false, message: error.message || 'Failed to save profile.' });
    }
  },

  // POST /api/professionals/availability - Toggle professional availability
  async updateAvailability(req, res) {
    try {
      const uid = req.user.uid;
      const { isAvailable } = req.body;
      
      const isAvailableNow = isAvailable === true || isAvailable === 'true';
      
      await ProfessionalModel.updateAvailability(uid, isAvailableNow);
      
      return res.json({
        success: true,
        data: { isAvailable: isAvailableNow },
        message: isAvailableNow ? 'You are now online (visible to customers).' : 'You are now offline (hidden from customers).'
      });
    } catch (error) {
      console.error('updateAvailability error:', error);
      return res.status(500).json({ success: false, message: 'Failed to update availability.' });
    }
  },

  // GET /api/professionals/profile - Get own profile (requires auth)
  async getOwnProfile(req, res) {
    try {
      const uid = req.user.uid;
      const professional = await ProfessionalModel.getById(uid);
      
      if (!professional) {
        return res.json({ success: true, data: { exists: false } });
      }
      
      return res.json({
        success: true,
        data: {
          exists: true,
          profile: professional
        }
      });
    } catch (error) {
      console.error('getOwnProfile error:', error);
      return res.status(500).json({ success: false, message: 'Failed to fetch profile.' });
    }
  },

  // GET /api/professionals/wallet - Get wallet balance
  async getWallet(req, res) {
    try {
      const uid = req.user.uid;
      const professional = await ProfessionalModel.getById(uid);
      if (!professional) {
        return res.status(404).json({ success: false, message: 'Professional not found.' });
      }
      return res.json({ 
        success: true, 
        data: { 
          walletBalance: professional.walletBalance || 0, 
          currency: 'PKR' 
        } 
      });
    } catch (error) {
      return res.status(500).json({ success: false, message: 'Failed to fetch wallet balance.' });
    }
  },

  // GET /api/professionals/transactions - Get transaction history
  async getTransactions(req, res) {
    try {
      const uid = req.user.uid;
      const transactions = await TransactionModel.getByProfessionalId(uid);
      return res.json({ success: true, data: { transactions } });
    } catch (error) {
      return res.status(500).json({ success: false, message: 'Failed to fetch transaction history.' });
    }
  },

  // POST /api/professionals/upload-photo - Upload base64 image to ImgBB and update photoURL
  async uploadPhoto(req, res) {
    try {
      const uid = req.user.uid;
      const { image } = req.body;
      if (!image) {
        return res.status(400).json({ success: false, message: 'Image base64 string is required.' });
      }
      
      const { uploadToImgBB } = require('../utils/imgbb');
      const upload = await uploadToImgBB(image, `profile_${uid}_${Date.now()}`);
      const url = upload.url || upload.displayUrl;
      
      // Update professional and user models
      await ProfessionalModel.updateById(uid, { photoURL: url });
      await UserModel.upsert(uid, { photoURL: url });
      
      return res.json({ success: true, data: { photoURL: url }, message: 'Image uploaded successfully.' });
    } catch (error) {
      console.error('uploadPhoto error:', error);
      return res.status(500).json({ success: false, message: 'Failed to upload photo.' });
    }
  },

  // GET /api/professionals/earnings - Get earnings stats
  async getEarnings(req, res) {
    try {
      const uid = req.user.uid;
      const professional = await ProfessionalModel.getById(uid);
      if (!professional) {
        return res.status(404).json({ success: false, message: 'Professional not found.' });
      }
      
      const allBookings = await BookingModel.getByUserId(uid);
      const completed = allBookings.filter(b => b.status === 'completed');
      const active = allBookings.filter(b => ['confirmed', 'in_progress'].includes(b.status));
      const transactions = await TransactionModel.getByProfessionalId(uid);

      return res.json({
        success: true,
        data: {
          walletBalance: professional.walletBalance || 0,
          totalEarnings: professional.totalEarnings || 0,
          completedJobs: professional.completedJobs || 0,
          activeBookings: active.length,
          transactions,
          recentBookings: completed.slice(0, 10)
        }
      });
    } catch (error) {
      console.error('getEarnings error:', error);
      return res.status(500).json({ success: false, message: 'Failed to fetch earnings stats.' });
    }
  },

  // POST /api/professionals/upload-portfolio - Legacy endpoint for portfolio base64 uploads
  async uploadPortfolio(req, res) {
    try {
      const uid = req.user.uid;
      const { images } = req.body;
      if (!images || !Array.isArray(images) || images.length === 0) {
        return res.status(400).json({ success: false, message: 'Array of base64 images is required.' });
      }
      
      const urls = await uploadMultipleToImgBB(images);
      const portfolio = await ProfessionalModel.addPortfolioImages(uid, urls);
      
      return res.json({ success: true, data: { portfolio }, message: 'Portfolio uploaded successfully.' });
    } catch (error) {
      console.error('uploadPortfolio error:', error);
      return res.status(500).json({ success: false, message: 'Failed to upload portfolio.' });
    }
  },

  // Legacy route maps
  async getByPhone(req, res) {
    // For compatibility with previous route parameter name
    req.params.uid = req.params.phone;
    return ProfessionalController.getByUid(req, res);
  }
};

module.exports = ProfessionalController;
