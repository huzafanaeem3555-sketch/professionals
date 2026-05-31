const { dbGetAll, dbDelete } = require('../config/firebase');
const { CONTACT_LEAD_TTL_MS } = require('../utils/accountPolicy');

const CLEANUP_INTERVAL_MS = Number(process.env.CONTACT_LEAD_CLEANUP_INTERVAL_MS || 30 * 60 * 1000);

function toNumber(value) {
  if (typeof value === 'number') return value;
  if (typeof value === 'string') {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}

async function cleanupExpiredContactLeads() {
  const now = Date.now();
  const leadGroups = await dbGetAll('professionalContactLeads');
  let removed = 0;

  for (const group of leadGroups) {
    const professionalId = String(group?._key || group?.id || '').trim();
    if (!professionalId) continue;

    const entries = Object.entries(group).filter(([key]) => !key.startsWith('_'));
    for (const [leadId, lead] of entries) {
      if (!lead || typeof lead !== 'object') continue;
      const expiresAt = toNumber(lead.expiresAt || lead._expiresAt);
      const createdAt = toNumber(lead.createdAt || lead._createdAt);
      const ttlExpiresAt = createdAt ? createdAt + CONTACT_LEAD_TTL_MS : 0;
      const shouldRemove = (expiresAt > 0 && expiresAt <= now) || (ttlExpiresAt > 0 && ttlExpiresAt <= now);
      if (!shouldRemove) continue;

      await dbDelete(`professionalContactLeads/${professionalId}/${leadId}`);
      removed += 1;
    }

    const refreshed = await dbGetAll(`professionalContactLeads/${professionalId}`);
    if (!refreshed || refreshed.length === 0) {
      await dbDelete(`professionalContactLeads/${professionalId}`);
    }
  }

  return { removed };
}

function startContactLeadCleanupJob() {
  const run = async () => {
    try {
      await cleanupExpiredContactLeads();
    } catch (error) {
      console.error('[contactLeadCleanup] failed:', error.message || error);
    }
  };

  void run();
  const timer = setInterval(run, CLEANUP_INTERVAL_MS);
  timer.unref?.();
  return timer;
}

module.exports = {
  cleanupExpiredContactLeads,
  startContactLeadCleanupJob,
};
