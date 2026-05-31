const { v4: uuidv4 } = require('uuid');
const { dbGet, dbGetAll, dbSet, dbUpdate, dbDelete, dbPush } = require('../config/firebase');
const ProfessionalModel = require('./professionalModel');
const UserModel = require('./userModel');
const { sendNotificationToUser } = require('../utils/notifications');

const ADMIN_WHATSAPP = '03195682936';

function clean(value, fallback = '') {
  const text = value === undefined || value === null ? '' : String(value).trim();
  return text || fallback;
}

function itemId(item) {
  return clean(item?.uid || item?.id || item?._key || item?.bookingId || item?.complaintId || item?.postId);
}

function toNumber(value, fallback = 0) {
  const num = Number(value);
  return Number.isFinite(num) ? num : fallback;
}

function normalizeService(value) {
  return clean(value, 'general').toLowerCase().replace(/\s+/g, '_');
}

function distanceKm(a, b) {
  const lat1 = toNumber(a?.lat);
  const lon1 = toNumber(a?.lng);
  const lat2 = toNumber(b?.lat);
  const lon2 = toNumber(b?.lng);
  if (!lat1 || !lon1 || !lat2 || !lon2) return null;
  const r = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const x =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) ** 2;
  return r * 2 * Math.atan2(Math.sqrt(x), Math.sqrt(1 - x));
}

async function profileFor(uid) {
  if (!uid) return {};
  const [user, pro] = await Promise.all([
    UserModel.getById(uid, true).catch(() => null),
    ProfessionalModel.getById(uid).catch(() => null),
  ]);
  return { ...(user || {}), ...(pro || {}), uid };
}

const MarketplaceModel = {
  async createComplaint(customerId, payload) {
    const now = Date.now();
    const professionalId = clean(payload.professionalId);
    const reason = clean(payload.reason || payload.message || payload.description);
    if (!professionalId || !reason) {
      throw new Error('professionalId and reason are required.');
    }
    const [customer, professional] = await Promise.all([
      profileFor(customerId),
      profileFor(professionalId),
    ]);
    const complaintId = uuidv4();
    const complaint = {
      complaintId,
      customerId,
      customerName: clean(customer.displayName || customer.name, 'Customer'),
      customerPhone: clean(customer.phoneNumber || customer.phone),
      professionalId,
      professionalName: clean(professional.name || professional.displayName, 'Professional'),
      professionalPhone: clean(professional.phoneNumber || professional.phone),
      bookingId: clean(payload.bookingId),
      reason,
      status: 'open',
      priority: clean(payload.priority, 'normal'),
      adminNotes: '',
      createdAt: now,
      updatedAt: now,
    };
    await dbSet(`complaints/${complaintId}`, complaint);
    return complaint;
  },

  async listComplaints() {
    return (await dbGetAll('complaints') || [])
      .map(item => ({ ...item, complaintId: item.complaintId || item._key }))
      .sort((a, b) => toNumber(b.createdAt) - toNumber(a.createdAt));
  },

  async updateComplaint(id, payload) {
    const updates = {
      updatedAt: Date.now(),
      ...(payload.status !== undefined ? { status: clean(payload.status, 'open') } : {}),
      ...(payload.adminNotes !== undefined ? { adminNotes: clean(payload.adminNotes) } : {}),
      ...(payload.priority !== undefined ? { priority: clean(payload.priority, 'normal') } : {}),
    };
    await dbUpdate(`complaints/${id}`, updates);
    return { complaintId: id, ...updates };
  },

  async deleteComplaint(id) {
    await dbDelete(`complaints/${id}`);
  },

  async toggleFavorite(customerId, professionalId, favorite = true) {
    if (!professionalId) throw new Error('professionalId is required.');
    if (!favorite) {
      await dbDelete(`favorites/${customerId}/${professionalId}`);
      return { professionalId, favorite: false };
    }
    const pro = await profileFor(professionalId);
    const data = {
      professionalId,
      professionalName: clean(pro.name || pro.displayName, 'Professional'),
      serviceTypes: pro.services || pro.serviceTypes || [],
      photoURL: clean(pro.photoURL),
      rating: toNumber(pro.rating),
      createdAt: Date.now(),
    };
    await dbSet(`favorites/${customerId}/${professionalId}`, data);
    return { ...data, favorite: true };
  },

  async listFavorites(customerId) {
    const raw = await dbGet(`favorites/${customerId}`) || {};
    const favorites = await Promise.all(
      Object.entries(raw).map(async ([professionalId, value]) => {
        const pro = await ProfessionalModel.getById(professionalId).catch(() => null);
        return {
          professionalId,
          ...(value || {}),
          professional: pro,
        };
      }),
    );
    return favorites.sort((a, b) => toNumber(b.createdAt) - toNumber(a.createdAt));
  },

  async createReferral(ownerId, payload) {
    const professionalId = clean(payload.professionalId);
    if (!professionalId) throw new Error('professionalId is required.');
    const discountPercent = Math.max(0, Math.min(80, toNumber(payload.discountPercent, 10)));
    const code = clean(payload.code, `HP${ownerId.slice(0, 4)}${professionalId.slice(0, 4)}${Math.floor(Math.random() * 900 + 100)}`).toUpperCase();
    const referral = {
      code,
      ownerId,
      professionalId,
      discountPercent,
      usedCount: 0,
      isActive: true,
      createdAt: Date.now(),
      updatedAt: Date.now(),
    };
    await dbSet(`referrals/${code}`, referral);
    return referral;
  },

  async applyReferral(customerId, code) {
    const normalized = clean(code).toUpperCase();
    const referral = await dbGet(`referrals/${normalized}`);
    if (!referral || referral.isActive === false) throw new Error('Invalid referral code.');
    await dbUpdate(`users/${customerId}`, {
      activeReferralCode: normalized,
      referredProfessionalId: referral.professionalId,
      referralDiscountPercent: toNumber(referral.discountPercent, 0),
      _updatedAt: Date.now(),
    });
    return { code: normalized, ...referral };
  },

  async listMyReferrals(uid) {
    const all = await dbGetAll('referrals') || [];
    return all
      .filter(item => item.ownerId === uid || item.professionalId === uid)
      .sort((a, b) => toNumber(b.createdAt) - toNumber(a.createdAt));
  },

  async createJobPost(customerId, payload) {
    const serviceType = normalizeService(payload.serviceType);
    const now = Date.now();
    const postId = uuidv4();
    const customer = await profileFor(customerId);
    const location = payload.location && typeof payload.location === 'object'
      ? payload.location
      : { lat: toNumber(payload.lat), lng: toNumber(payload.lng), address: clean(payload.address) };
    const radiusKm = Math.max(1, Math.min(100, toNumber(payload.radiusKm, 10)));
    const post = {
      postId,
      customerId,
      customerName: clean(customer.displayName || customer.name, 'Customer'),
      serviceType,
      description: clean(payload.description || payload.customerProblem, 'Service needed'),
      budget: toNumber(payload.budget),
      radiusKm,
      location,
      status: 'open',
      offerCount: 0,
      createdAt: now,
      updatedAt: now,
    };
    await dbSet(`jobPosts/${postId}`, post);
    const professionals = (await ProfessionalModel.getAll()).filter(pro => {
      const services = [...(pro.services || []), ...(pro.customServices || [])]
        .map(s => normalizeService(s));
      return pro.isActive !== false && pro.isAvailable !== false && services.includes(serviceType);
    });
    await Promise.all(professionals.slice(0, 25).map(pro =>
      sendNotificationToUser(
        pro.uid,
        'New job post nearby',
        `${post.customerName} needs ${serviceType.replace(/_/g, ' ')} work.`,
        { type: 'job_post', postId, serviceType },
      ).catch(() => null),
    ));
    return post;
  },

  async listJobPosts(viewer) {
    const posts = await dbGetAll('jobPosts') || [];
    const role = clean(viewer?.role).toLowerCase();
    const uid = clean(viewer?.uid);
    const pro = role === 'professional'
      ? await ProfessionalModel.getById(uid).catch(() => null)
      : null;
    const proServices = [
      ...(Array.isArray(pro?.services) ? pro.services : []),
      ...(Array.isArray(pro?.customServices) ? pro.customServices : []),
    ].map(normalizeService);
    return posts
      .filter(post => {
        if (role === 'customer') return post.customerId === uid;
        if (post.status === 'closed') return false;
        if (!pro) return true;
        if (!proServices.includes(normalizeService(post.serviceType))) return false;
        const distance = distanceKm(pro.location, post.location);
        return distance === null || distance <= toNumber(post.radiusKm, 10);
      })
      .map(post => {
        if (!pro) return post;
        const distance = distanceKm(pro.location, post.location);
        return {
          ...post,
          distanceKm: distance === null ? null : Number(distance.toFixed(2)),
        };
      })
      .sort((a, b) => toNumber(b.createdAt) - toNumber(a.createdAt));
  },

  async createJobOffer(professionalId, postId, payload) {
    const post = await dbGet(`jobPosts/${postId}`);
    if (!post) throw new Error('Job post not found.');
    const pro = await profileFor(professionalId);
    const offerId = uuidv4();
    const offer = {
      offerId,
      postId,
      professionalId,
      professionalName: clean(pro.name || pro.displayName, 'Professional'),
      professionalPhone: clean(pro.phoneNumber || pro.phone),
      price: toNumber(payload.price),
      message: clean(payload.message, 'I can do this work.'),
      status: 'pending',
      createdAt: Date.now(),
      updatedAt: Date.now(),
    };
    await dbSet(`jobPostOffers/${postId}/${offerId}`, offer);
    await dbUpdate(`jobPosts/${postId}`, {
      offerCount: toNumber(post.offerCount) + 1,
      updatedAt: Date.now(),
    });
    await sendNotificationToUser(
      post.customerId,
      'New offer received',
      `${offer.professionalName} offered PKR ${offer.price}.`,
      { type: 'job_offer', postId, offerId },
    ).catch(() => null);
    return offer;
  },

  async listJobOffers(postId) {
    const raw = await dbGet(`jobPostOffers/${postId}`) || {};
    return Object.entries(raw)
      .map(([offerId, value]) => ({ offerId, ...(value || {}) }))
      .sort((a, b) => toNumber(a.price) - toNumber(b.price));
  },

  async requestFeatured(professionalId, payload) {
    const pro = await profileFor(professionalId);
    const requestId = uuidv4();
    const data = {
      requestId,
      professionalId,
      professionalName: clean(pro.name || pro.displayName, 'Professional'),
      professionalPhone: clean(pro.phoneNumber || pro.phone),
      message: clean(payload.message, `Please contact ${ADMIN_WHATSAPP} on WhatsApp for paid featured listing.`),
      status: 'pending_payment',
      adminWhatsApp: ADMIN_WHATSAPP,
      createdAt: Date.now(),
      updatedAt: Date.now(),
    };
    await dbSet(`featuredRequests/${requestId}`, data);
    return data;
  },

  async listFeaturedRequests() {
    return (await dbGetAll('featuredRequests') || [])
      .map(item => ({ ...item, requestId: item.requestId || item._key }))
      .sort((a, b) => toNumber(b.createdAt) - toNumber(a.createdAt));
  },

  async uploadCertificate(professionalId, payload) {
    const certificateId = uuidv4();
    const cert = {
      certificateId,
      professionalId,
      title: clean(payload.title, 'Certificate'),
      issuer: clean(payload.issuer),
      fileUrl: clean(payload.fileUrl || payload.url),
      status: 'pending',
      createdAt: Date.now(),
      updatedAt: Date.now(),
    };
    await dbSet(`professionalCertificates/${professionalId}/${certificateId}`, cert);
    return cert;
  },

  async listCertificates(professionalId) {
    const raw = await dbGet(`professionalCertificates/${professionalId}`) || {};
    return Object.entries(raw).map(([certificateId, value]) => ({ certificateId, ...(value || {}) }));
  },

  async getCleanupSettings() {
    return await dbGet('adminSettings/contactLeadCleanup') || {
      hours: 5,
      allowedHours: [4, 5, 24],
      updatedAt: 0,
    };
  },

  async updateCleanupSettings(hours) {
    const safe = [4, 5, 24].includes(Number(hours)) ? Number(hours) : 5;
    const data = { hours: safe, allowedHours: [4, 5, 24], updatedAt: Date.now() };
    await dbSet('adminSettings/contactLeadCleanup', data);
    return data;
  },

  async listAdminBundle() {
    const [complaints, featuredRequests, jobPosts, cleanupSettings] = await Promise.all([
      this.listComplaints(),
      this.listFeaturedRequests(),
      dbGetAll('jobPosts'),
      this.getCleanupSettings(),
    ]);
    return { complaints, featuredRequests, jobPosts, cleanupSettings };
  },
};

module.exports = MarketplaceModel;
