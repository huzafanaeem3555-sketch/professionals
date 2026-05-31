const { db, dbGet, dbGetAll } = require('../config/firebase');

const ANALYTICS_PATH = 'serviceAnalytics';

function normalizeServiceKey(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .replace(/_/g, ' ')
    .replace(/[^a-z0-9 ]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/\s/g, '_')
    .slice(0, 60);
}

function humanizeService(key, label) {
  const text = String(label || key || '').trim();
  if (!text) return 'General';
  return text
    .replace(/_/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

function serviceListFrom(value) {
  if (Array.isArray(value)) return value;
  if (value && typeof value === 'object') return Object.values(value);
  return String(value || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

function bump(map, service, field, amount = 1) {
  const key = normalizeServiceKey(service);
  if (!key) return;
  const existing = map.get(key) || {
    serviceKey: key,
    label: humanizeService(key, service),
    searchCount: 0,
    bookingCount: 0,
    contactCount: 0,
    professionalCount: 0,
    lastUsedAt: 0,
  };
  existing[field] = Number(existing[field] || 0) + amount;
  if (!existing.label || existing.label === humanizeService(key, key)) {
    existing.label = humanizeService(key, service);
  }
  map.set(key, existing);
}

const ServiceAnalyticsModel = {
  normalizeServiceKey,

  async incrementService(service, field = 'searchCount', amount = 1) {
    const key = normalizeServiceKey(service);
    if (!key) return null;
    const safeField = ['searchCount', 'bookingCount', 'contactCount'].includes(field)
      ? field
      : 'searchCount';
    const ref = db.ref(`${ANALYTICS_PATH}/${key}`);
    const existing = (await ref.once('value')).val() || {};
    const updates = {
      serviceKey: key,
      label: existing.label || humanizeService(key, service),
      [safeField]: Number(existing[safeField] || 0) + Number(amount || 1),
      lastUsedAt: Date.now(),
      updatedAt: Date.now(),
    };
    await ref.update(updates);
    return { ...existing, ...updates };
  },

  async recordSearch(query, services = []) {
    const unique = new Set(
      serviceListFrom(services)
        .map(normalizeServiceKey)
        .filter(Boolean),
    );
    if (unique.size === 0) {
      const inferred = normalizeServiceKey(query);
      if (inferred && inferred.length >= 3) unique.add(inferred);
    }
    await Promise.all(
      Array.from(unique).map((service) =>
        this.incrementService(service, 'searchCount').catch(() => null),
      ),
    );
  },

  async getPopularServices(limit = 50) {
    const [analyticsRaw, bookings, professionals, leadGroups] = await Promise.all([
      dbGet(ANALYTICS_PATH),
      dbGetAll('bookings'),
      dbGetAll('professionals'),
      dbGetAll('professionalContactLeads'),
    ]);

    const map = new Map();
    const analytics = analyticsRaw && typeof analyticsRaw === 'object' ? analyticsRaw : {};
    for (const [key, value] of Object.entries(analytics)) {
      const cleanKey = normalizeServiceKey(value?.serviceKey || key);
      if (!cleanKey) continue;
      map.set(cleanKey, {
        serviceKey: cleanKey,
        label: humanizeService(cleanKey, value?.label),
        searchCount: Number(value?.searchCount || 0),
        bookingCount: Number(value?.bookingCount || 0),
        contactCount: Number(value?.contactCount || 0),
        professionalCount: Number(value?.professionalCount || 0),
        lastUsedAt: Number(value?.lastUsedAt || value?.updatedAt || 0),
      });
    }

    for (const booking of bookings || []) {
      bump(map, booking.serviceType, 'bookingCount');
    }

    for (const pro of professionals || []) {
      for (const service of [
        ...serviceListFrom(pro.services || pro.serviceTypes),
        ...serviceListFrom(pro.customServices),
      ]) {
        bump(map, service, 'professionalCount');
      }
    }

    for (const group of leadGroups || []) {
      for (const [leadId, lead] of Object.entries(group)) {
        if (leadId.startsWith('_') || !lead || typeof lead !== 'object') continue;
        bump(map, lead.serviceType, 'contactCount');
      }
    }

    return Array.from(map.values())
      .map((item) => {
        const totalUsage =
          Number(item.searchCount || 0) +
          Number(item.bookingCount || 0) +
          Number(item.contactCount || 0);
        const score =
          Number(item.searchCount || 0) * 3 +
          Number(item.contactCount || 0) * 5 +
          Number(item.bookingCount || 0) * 8 +
          Number(item.professionalCount || 0);
        return { ...item, totalUsage, score };
      })
      .filter((item) => item.serviceKey)
      .sort((a, b) => {
        const scoreDiff = Number(b.score || 0) - Number(a.score || 0);
        if (scoreDiff !== 0) return scoreDiff;
        const usageDiff = Number(b.totalUsage || 0) - Number(a.totalUsage || 0);
        if (usageDiff !== 0) return usageDiff;
        return String(a.label).localeCompare(String(b.label));
      })
      .slice(0, limit);
  },
};

module.exports = ServiceAnalyticsModel;
