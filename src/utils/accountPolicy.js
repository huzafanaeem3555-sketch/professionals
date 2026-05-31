const UserModel = require('../models/userModel');

const CONTACT_LEAD_TTL_MS = 5 * 60 * 60 * 1000;

function normalizeGender(value) {
  return String(value || '').trim().toLowerCase() === 'female' ? 'female' : 'male';
}

function normalizeRole(value) {
  return String(value || '').trim().toLowerCase();
}

async function resolveViewerContext(req) {
  const uid = req?.user?.uid || '';
  if (!uid) return null;

  const user = await UserModel.getById(uid, true);
  if (!user) {
    return {
      uid,
      role: normalizeRole(req?.user?.role),
      gender: normalizeGender(req?.user?.gender),
      verificationStatus: normalizeRole(req?.user?.verificationStatus),
      isActive: true,
    };
  }

  return {
    uid,
    role: normalizeRole(user.role || req?.user?.role),
    gender: normalizeGender(user.gender || req?.user?.gender),
    verificationStatus: normalizeRole(user.verificationStatus || req?.user?.verificationStatus),
    isActive: user.isActive !== false,
  };
}

function isAdminViewer(viewer) {
  return normalizeRole(viewer?.role) === 'admin';
}

function canViewFemaleProfessional(viewer, professional) {
  if (!professional) return false;
  if (normalizeGender(professional.gender) !== 'female') return true;

  if (!viewer) return false;
  if (isAdminViewer(viewer)) return true;
  if (String(viewer.uid || '') === String(professional.uid || '')) return true;

  return (
    normalizeRole(viewer.role) === 'customer' &&
    normalizeGender(viewer.gender) === 'female' &&
    normalizeRole(viewer.verificationStatus) === 'verified' &&
    viewer.isActive !== false
  );
}

function shouldHideLeadPhone(customerGender) {
  return normalizeGender(customerGender) === 'female';
}

module.exports = {
  CONTACT_LEAD_TTL_MS,
  normalizeGender,
  normalizeRole,
  resolveViewerContext,
  isAdminViewer,
  canViewFemaleProfessional,
  shouldHideLeadPhone,
};
