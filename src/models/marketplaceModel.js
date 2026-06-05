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
    const owner = await profileFor(ownerId);
    const referral = {
      code,
      ownerId,
      ownerName: owner.name || 'Customer',
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
    const owner = referral.ownerName
      ? { name: referral.ownerName }
      : await profileFor(referral.ownerId);
    await dbUpdate(`users/${customerId}`, {
      activeReferralCode: normalized,
      referredProfessionalId: referral.professionalId,
      referralDiscountPercent: toNumber(referral.discountPercent, 0),
      referralOwnerId: referral.ownerId || '',
      referralOwnerName: owner.name || 'Customer',
      _updatedAt: Date.now(),
    });
    return {
      code: normalized,
      ...referral,
      ownerName: owner.name || referral.ownerName || 'Customer',
    };
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
    const radiusKm = Math.max(1, Math.min(100, toNumber(payload.radiusKm, 20)));
    const isUrgent = payload.isUrgent === true || clean(payload.priority).toLowerCase() === 'urgent';
    const post = {
      postId,
      title: clean(payload.title, clean(payload.serviceType, 'Service job')).slice(0, 120),
      customerId,
      customerName: clean(customer.displayName || customer.name, 'Customer'),
      customerPhone: clean(customer.phoneNumber || customer.phone),
      customerPhotoURL: clean(customer.photoURL),
      serviceType,
      description: clean(payload.description || payload.customerProblem, 'Service needed'),
      budget: toNumber(payload.budget),
      radiusKm,
      isUrgent,
      priority: isUrgent ? 'urgent' : 'normal',
      location,
      status: 'open',
      offerCount: 0,
      createdAt: now,
      updatedAt: now,
    };
    await dbSet(`jobPosts/${postId}`, post);
    const professionals = (await ProfessionalModel.getAll()).filter(pro => {
      if (pro.isActive === false || pro.isAvailable === false) return false;
      const services = [
        ...(Array.isArray(pro.services) ? pro.services : []),
        ...(Array.isArray(pro.customServices) ? pro.customServices : []),
      ].map(normalizeService);
      const serviceMatches = services.length === 0 || services.includes(serviceType);
      const distance = distanceKm(pro.location, post.location);
      const insideRadius = distance === null || distance <= radiusKm;
      return serviceMatches && insideRadius;
    });
    await Promise.all(professionals.map(pro =>
      sendNotificationToUser(
        pro.uid,
        isUrgent ? 'Need Now: urgent job near you' : 'New job post',
        isUrgent
          ? `${post.customerName} needs urgent ${post.title}. Respond quickly.`
          : `${post.customerName} needs ${post.title}.`,
        { type: 'job_post', postId, serviceType, priority: post.priority },
      ).catch(() => null),
    ));
    await sendNotificationToUser(
      customerId,
      isUrgent ? 'Urgent job posted' : 'Job posted',
      isUrgent
        ? `Your urgent job "${post.title}" is now live for nearby professionals.`
        : `Your job "${post.title}" is now live for professionals.`,
      { type: 'job_status_changed', postId, status: 'open', priority: post.priority },
    ).catch(() => null);
    return post;
  },

  async listJobPosts(viewer) {
    const posts = await dbGetAll('jobPosts') || [];
    const uid = clean(viewer?.uid);
    const user = uid ? await UserModel.getById(uid, true).catch(() => null) : null;
    const role = clean(viewer?.role || user?.role).toLowerCase();
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
        if (clean(post.status, 'open') !== 'open') return false;
        return true;
      })
      .map(post => {
        if (!pro) return post;
        const distance = distanceKm(pro.location, post.location);
        return {
          ...post,
          serviceMatched: proServices.includes(normalizeService(post.serviceType)),
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
      professionalPhotoURL: clean(pro.photoURL),
      serviceType: post.serviceType || (Array.isArray(pro.services) ? pro.services[0] : ''),
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

  async counterJobOffer(customerId, postId, offerId, payload) {
    const post = await dbGet(`jobPosts/${postId}`);
    if (!post) throw new Error('Job post not found.');
    if (post.customerId !== customerId) throw new Error('Only the job owner can counter an offer.');
    const offer = await dbGet(`jobPostOffers/${postId}/${offerId}`);
    if (!offer) throw new Error('Offer not found.');
    const counterPrice = toNumber(payload.counterPrice ?? payload.price, 0);
    if (counterPrice <= 0) throw new Error('counterPrice is required.');
    const updates = {
      counterPrice,
      customerMessage: clean(payload.message, 'Please confirm this counter price.'),
      status: 'countered',
      updatedAt: Date.now(),
    };
    await dbUpdate(`jobPostOffers/${postId}/${offerId}`, updates);
    await sendNotificationToUser(
      offer.professionalId,
      'Counter price received',
      `${post.customerName || 'Customer'} countered your offer at PKR ${counterPrice}.`,
      { type: 'job_offer_countered', postId, offerId, counterPrice },
    ).catch(() => null);
    return { postId, offerId, ...updates };
  },

  async selectJobOffer(customerId, postId, offerId) {
    const post = await dbGet(`jobPosts/${postId}`);
    if (!post) throw new Error('Job post not found.');
    if (post.customerId !== customerId) throw new Error('Only the job owner can select an offer.');
    const offer = await dbGet(`jobPostOffers/${postId}/${offerId}`);
    if (!offer) throw new Error('Offer not found.');
    const now = Date.now();
    await dbUpdate(`jobPostOffers/${postId}/${offerId}`, {
      status: 'selected',
      updatedAt: now,
    });
    const allOffers = await dbGet(`jobPostOffers/${postId}`) || {};
    await Promise.all(Object.entries(allOffers).map(([id]) => {
      if (id === offerId) return Promise.resolve();
      return dbUpdate(`jobPostOffers/${postId}/${id}`, {
        status: 'not_selected',
        updatedAt: now,
      }).catch(() => null);
    }));
    const updates = {
      status: 'assigned',
      selectedOfferId: offerId,
      selectedProfessionalId: offer.professionalId,
      selectedProfessionalName: offer.professionalName,
      selectedPrice: toNumber(offer.price),
      updatedAt: now,
    };
    await dbUpdate(`jobPosts/${postId}`, updates);
    await Promise.all([
      sendNotificationToUser(
        offer.professionalId,
        'Your offer was selected',
        `${post.customerName || 'Customer'} selected you for "${post.title || post.serviceType}".`,
        { type: 'job_offer_selected', postId, offerId, status: 'assigned' },
      ).catch(() => null),
      sendNotificationToUser(
        customerId,
        'Professional selected',
        `${offer.professionalName} has been selected for your job.`,
        { type: 'job_status_changed', postId, offerId, status: 'assigned' },
      ).catch(() => null),
    ]);
    return { postId, offerId, ...updates };
  },

  async updateJobStatus(userId, postId, status) {
    const allowed = ['open', 'assigned', 'in_progress', 'completed', 'cancelled', 'closed'];
    const safeStatus = allowed.includes(clean(status).toLowerCase())
      ? clean(status).toLowerCase()
      : 'open';
    const post = await dbGet(`jobPosts/${postId}`);
    if (!post) throw new Error('Job post not found.');
    if (post.customerId !== userId && post.selectedProfessionalId !== userId) {
      throw new Error('You cannot update this job.');
    }
    const updates = { status: safeStatus, updatedAt: Date.now() };
    if (safeStatus === 'open') {
      updates.selectedOfferId = '';
      updates.selectedProfessionalId = '';
      updates.selectedProfessionalName = '';
      updates.selectedPrice = 0;
      const allOffers = await dbGet(`jobPostOffers/${postId}`) || {};
      await Promise.all(Object.entries(allOffers).map(([offerId, offer]) => {
        if (!offer || offer.status !== 'selected') return Promise.resolve();
        return dbUpdate(`jobPostOffers/${postId}/${offerId}`, {
          status: 'pending',
          updatedAt: Date.now(),
        });
      }));
    }
    await dbUpdate(`jobPosts/${postId}`, updates);
    const notifyIds = [post.customerId, post.selectedProfessionalId].filter(Boolean);
    await Promise.all([...new Set(notifyIds)].map(uid =>
      sendNotificationToUser(
        uid,
        'Job status updated',
        `Job "${post.title || post.serviceType}" is now ${safeStatus.replace(/_/g, ' ')}.`,
        { type: 'job_status_changed', postId, status: safeStatus },
      ).catch(() => null),
    ));
    return { postId, ...updates };
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
