const { db } = require('../config/firebase');

const PROF_PATH = 'professionals';
const DB_TIMEOUT_MS = Number(process.env.DB_TIMEOUT_MS || 8000);

async function onceValueWithTimeout(refPath, timeoutMs = DB_TIMEOUT_MS) {
  try {
    const ref = db.ref(refPath);
    return await Promise.race([
      ref.once('value'),
      new Promise((_, reject) =>
        setTimeout(
          () => reject(new Error(`Realtime DB timeout at "${refPath}" after ${timeoutMs}ms`)),
          timeoutMs,
        ),
      ),
    ]);
  } catch (error) {
    console.error(`onceValueWithTimeout error at ${refPath}:`, error.message);
    throw error;
  }
}

// Haversine distance in km
function getDistanceKm(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
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

const ProfessionalModel = {
  // Get all professionals
  async getAll() {
    try {
      const snapshot = await onceValueWithTimeout(PROF_PATH);
      const data = snapshot.val();
      if (!data) return [];
      return Object.entries(data).map(([uid, value]) => ({
        uid,
        ...value,
      }));
    } catch (_) {
      return [];
    }
  },

  // Get professional by UID
  async getById(uid) {
    try {
      const snapshot = await onceValueWithTimeout(`${PROF_PATH}/${uid}`);
      const data = snapshot.val();
      if (!data) return null;
      return {
        uid,
        ...data,
      };
    } catch (_) {
      return null;
    }
  },

  // Get professional by phone number
  async getByPhone(phone) {
    const all = await this.getAll();
    return all.find(p => p.phoneNumber === phone) || null;
  },

  // Create new professional profile
  async create(uid, profileData) {
    const { name, services, customServices, description, phoneNumber, photoURL, location, rating, isAvailable, hourlyRate, experienceYears, brochureImages } = profileData;
    
    const professional = {
      name: name || '',
      services: normalizeServiceList(services),
      customServices: normalizeServiceList(customServices),
      description: description || '',
      phoneNumber: phoneNumber || '',
      photoURL: photoURL || '',
      brochureImages: Array.isArray(brochureImages) ? brochureImages.map(String).filter(Boolean) : [],
      location: location || { lat: 0, lng: 0, address: '' },
      walletBalance: profileData.walletBalance !== undefined ? Number(profileData.walletBalance) : 5000,
      totalEarnings: profileData.totalEarnings !== undefined ? Number(profileData.totalEarnings) : 0,
      completedJobs: profileData.completedJobs !== undefined ? Number(profileData.completedJobs) : 0,
      experienceYears: experienceYears !== undefined ? Number(experienceYears) : 0,
      rating: Number(rating || 0),
      totalRatings: Number(profileData.totalRatings || 0),
      isAvailable: isAvailable !== false,
      hourlyRate: hourlyRate || 500,
      profileCompleted: true,
      createdAt: Date.now(),
      updatedAt: Date.now()
    };
    
    await db.ref(`${PROF_PATH}/${uid}`).set(professional);
    
    return {
      uid,
      ...professional
    };
  },

  // Update professional by UID
  async updateById(uid, updates) {
    const existing = await this.getById(uid);
    if (!existing) return null;
    
    const updated = {
      ...existing,
      ...updates,
      updatedAt: Date.now()
    };
    
    await db.ref(`${PROF_PATH}/${uid}`).update({
      ...updates,
      updatedAt: Date.now()
    });
    
    return updated;
  },

  // Update availability
  async updateAvailability(uid, isAvailable) {
    await db.ref(`${PROF_PATH}/${uid}/isAvailable`).set(isAvailable);
    return { uid, isAvailable };
  },

  // Get nearby professionals sorted by distance
  async getNearby({ lat, lng, radiusKm = 20, serviceType }) {
    const allPros = await this.getAll();
    if (!allPros || allPros.length === 0) return [];

    const results = [];

    for (const pro of allPros) {
      // Filter by availability
      if (pro.isAvailable === false) continue;

      // Filter by service type
      if (serviceType) {
        const services = normalizeServiceList([
          ...(Array.isArray(pro.services) ? pro.services : []),
          ...(Array.isArray(pro.customServices) ? pro.customServices : []),
        ]);
        const requested = String(serviceType).toLowerCase();
        const matched = services.some(service => service.toLowerCase() === requested);
        if (!matched) continue;
      }

      const proLat = pro.location?.lat || 0;
      const proLng = pro.location?.lng || 0;
      if (!proLat || !proLng) continue;

      // Calculate distance
      const distance = getDistanceKm(lat, lng, proLat, proLng);
      if (distance > radiusKm) continue;

      results.push({
        uid: pro.uid,
        name: pro.name,
        services: normalizeServiceList(pro.services),
        customServices: normalizeServiceList(pro.customServices),
        location: pro.location,
        rating: pro.rating || 0,
        totalRatings: pro.totalRatings || 0,
        distance: parseFloat(distance.toFixed(2)),
        isAvailable: true,
        photoURL: pro.photoURL || '',
        brochureImages: Array.isArray(pro.brochureImages) ? pro.brochureImages : [],
        hourlyRate: pro.hourlyRate || 500,
        description: pro.description || ''
      });
    }

    // Sort by distance (nearest first)
    results.sort((a, b) => a.distance - b.distance);
    return results;
  },

  async upsert(uid, data) {
    const existing = await this.getById(uid);
    
    if (!existing) {
      return this.create(uid, {
        name: data.displayName || data.name || '',
        services: data.services || [],
        customServices: data.customServices || [],
        description: data.description || '',
        phoneNumber: data.phoneNumber || '',
        location: data.location,
        isAvailable: true,
        photoURL: data.photoURL || '',
        brochureImages: data.brochureImages || [],
        hourlyRate: data.hourlyRate || 500,
        walletBalance: 5000,
        totalEarnings: 0,
        completedJobs: 0,
        experienceYears: data.experienceYears || 0,
      });
    }
    
    return this.updateById(uid, {
      name: data.name || data.displayName || existing.name,
      services: data.services || existing.services,
      customServices: data.customServices || existing.customServices,
      description: data.description || existing.description,
      phoneNumber: data.phoneNumber || existing.phoneNumber,
      location: data.location || existing.location,
      isAvailable: data.isAvailable !== undefined ? data.isAvailable : existing.isAvailable,
      photoURL: data.photoURL || existing.photoURL,
      brochureImages: Array.isArray(data.brochureImages) ? data.brochureImages : (existing.brochureImages || []),
      hourlyRate: data.hourlyRate || existing.hourlyRate,
      experienceYears: data.experienceYears !== undefined ? Number(data.experienceYears) : (existing.experienceYears || 0),
    });
  },

  async createProfile(uid, data) {
    return this.upsert(uid, data);
  },

  async updateAvailabilityById(uid, isAvailableNow) {
    return this.updateAvailability(uid, isAvailableNow);
  },

  async addPortfolioImages(uid, urls) {
    const existing = await this.getById(uid);
    const portfolio = existing?.portfolio || [];
    const newPortfolio = [...portfolio, ...urls];
    await db.ref(`${PROF_PATH}/${uid}/portfolio`).set(newPortfolio);
    return newPortfolio;
  },

  async incrementCompletedJobs(uid) {
    const pro = await this.getById(uid);
    const count = (pro?.completedJobs || 0) + 1;
    await db.ref(`${PROF_PATH}/${uid}/completedJobs`).set(count);
  },

  async updateRating(uid, newRating) {
    const pro = await this.getById(uid);
    if (!pro) return;

    const rating = Number(newRating);
    const previousTotal = Number(pro.totalRatings || 0);
    const previousAverage = Number(pro.rating || 0);
    const totalRatings = previousTotal + 1;
    const avgRating = ((previousAverage * previousTotal) + rating) / totalRatings;

    await db.ref(`${PROF_PATH}/${uid}`).update({
      rating: Number(avgRating.toFixed(2)),
      totalRatings,
      updatedAt: Date.now(),
    });
  },

  async getReviews(uid, limit = 20) {
    const [bookingSnapshot, reviewSnapshot] = await Promise.all([
      onceValueWithTimeout('bookings'),
      onceValueWithTimeout(`professionalReviews/${uid}`),
    ]);

    const bookingData = bookingSnapshot.val() || {};
    const directReviewData = reviewSnapshot.val() || {};

    const bookingReviews = Object.entries(bookingData)
      .map(([bookingId, booking]) => ({ bookingId, ...booking }))
      .filter(
        booking =>
          booking.professionalId === uid &&
          Number(booking.customerRating || 0) > 0,
      )
      .map(booking => ({
        bookingId: booking.bookingId,
        customerName: booking.customerName || 'Customer',
        rating: Number(booking.customerRating || 0),
        review: booking.customerReview || '',
        createdAt: Number(booking.ratedAt || booking.updatedAt || 0),
      }));

    const directReviews = Object.entries(directReviewData)
      .map(([customerId, review]) => ({
        bookingId: customerId,
        customerName: review.customerName || 'Customer',
        rating: Number(review.rating || 0),
        review: review.review || '',
        createdAt: Number(review.updatedAt || review.createdAt || 0),
      }))
      .filter(review => review.rating > 0);

    return [...directReviews, ...bookingReviews]
      .sort((a, b) => Number(b.createdAt || 0) - Number(a.createdAt || 0))
      .slice(0, limit);
  }
};

module.exports = ProfessionalModel;
