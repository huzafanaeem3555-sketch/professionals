const { dbGet, dbSet, dbUpdate, dbGetAll } = require('../config/firebase');

const USERS_PATH = 'users';

/**
 * UserModel schema:
 * {
 *   email: string,
 *   displayName: string,
 *   photoURL: string,
 *   phoneNumber: string,
 *   role: 'customer' | 'professional' | 'admin',
 *   profileCompleted: boolean,
 *   location: { lat: number, lng: number },
 *   createdAt: timestamp
 * }
 */
const UserModel = {
  /**
   * Create or update user in Realtime Database.
   */
  async upsert(uid, data) {
    const existing = await dbGet(`${USERS_PATH}/${uid}`);

    if (!existing) {
      const newUser = {
        uid,
        email: data.email || '',
        displayName: data.displayName || '',
        photoURL: data.photoURL || '',
        phoneNumber: data.phoneNumber || '',
        role: data.role !== undefined ? data.role : null,
        profileCompleted: data.profileCompleted === true,
        isVerified: false,
        rating: 0,
        totalRatings: 0,
        location: data.location || {
          lat: data.lat || 0,
          lng: data.lng || 0,
        },
        address: data.address || '',
        fcmToken: data.fcmToken || '',
        _createdAt: Date.now(),
        _updatedAt: Date.now(),
      };
      await dbSet(`${USERS_PATH}/${uid}`, newUser);
      return { ...newUser, isNew: true };
    }

    // Update existing - merge all provided fields
    const updates = {
      _updatedAt: Date.now(),
      ...(data.email && { email: data.email }),
      ...(data.displayName && { displayName: data.displayName }),
      ...(data.photoURL && { photoURL: data.photoURL }),
      ...(data.phoneNumber && { phoneNumber: data.phoneNumber }),
      ...(data.fcmToken && { fcmToken: data.fcmToken }),
      ...(data.role !== undefined && { role: data.role }),
      ...(data.profileCompleted !== undefined && { profileCompleted: data.profileCompleted }),
      ...(data.address && { address: data.address }),
      ...(data.location && { location: data.location }),
      ...(data.lat !== undefined || data.lng !== undefined) && {
        location: {
          ...(existing.location || {}),
          lat: data.lat !== undefined ? data.lat : existing.location?.lat || 0,
          lng: data.lng !== undefined ? data.lng : existing.location?.lng || 0,
        },
      },
    };
    await dbUpdate(`${USERS_PATH}/${uid}`, updates);
    return { ...existing, ...updates, isNew: false };
  },

  /**
   * Get user by UID — never returns phoneNumber unless includePhone=true.
   */
  async getById(uid, includePhone = false) {
    const user = await dbGet(`${USERS_PATH}/${uid}`);
    if (!user) return null;
    if (!includePhone) {
      const { phoneNumber, fcmToken, ...safeUser } = user;
      return safeUser;
    }
    return user;
  },

  async getByEmail(email) {
    if (!email) return null;
    const users = await dbGetAll(USERS_PATH);
    return users.find((user) => String(user.email).toLowerCase() === String(email).toLowerCase()) || null;
  },

  /**
   * Update role.
   */
  async updateRole(uid, role) {
    if (!['customer', 'professional'].includes(role)) {
      throw new Error('Invalid role');
    }
    await dbUpdate(`${USERS_PATH}/${uid}`, { role });
  },

  /**
   * Update location.
   */
  async updateLocation(uid, lat, lng, address) {
    await dbUpdate(`${USERS_PATH}/${uid}`, {
      location: {
        lat: parseFloat(lat),
        lng: parseFloat(lng),
      },
      address: address || '',
      _updatedAt: Date.now(),
    });
  },

  /**
   * Update FCM token.
   */
  async updateFcmToken(uid, token) {
    await dbUpdate(`${USERS_PATH}/${uid}`, { fcmToken: token });
  },

  /**
   * Update phone number.
   */
  async updatePhoneNumber(uid, phoneNumber) {
    await dbUpdate(`${USERS_PATH}/${uid}`, { phoneNumber });
  },

  /**
   * Update rating average.
   */
  async updateRating(uid, newRating) {
    const user = await dbGet(`${USERS_PATH}/${uid}`);
    if (!user) throw new Error('User not found');

    const totalRatings = (user.totalRatings || 0) + 1;
    const rating = ((user.rating || 0) * (totalRatings - 1) + newRating) / totalRatings;

    await dbUpdate(`${USERS_PATH}/${uid}`, {
      rating: parseFloat(rating.toFixed(1)),
      totalRatings,
    });
  },

  async setProfileCompleted(uid, completed = true) {
    await dbUpdate(`${USERS_PATH}/${uid}`, {
      profileCompleted: Boolean(completed),
      _updatedAt: Date.now(),
    });
  },
};

module.exports = UserModel;
