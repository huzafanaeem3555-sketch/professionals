/**
 * Phone number reveal logic.
 * Phones are revealed when there is a confirmed (or later) booking between parties.
 */

async function canRevealPhone(requesterId, targetId, db) {
  try {
    const snap1 = await db.collection('bookings')
      .where('customerId', '==', requesterId)
      .where('professionalId', '==', targetId)
      .where('status', 'in', ['confirmed', 'in_progress', 'completed'])
      .limit(1)
      .get();

    if (!snap1.empty) return true;

    const snap2 = await db.collection('bookings')
      .where('professionalId', '==', requesterId)
      .where('customerId', '==', targetId)
      .where('status', 'in', ['confirmed', 'in_progress', 'completed'])
      .limit(1)
      .get();

    return !snap2.empty;
  } catch (error) {
    console.error('canRevealPhone error:', error);
    return false;
  }
}

function stripPhone(userObj) {
  const sanitized = { ...userObj };
  delete sanitized.phoneNumber;
  delete sanitized.fcmToken;
  return sanitized;
}

module.exports = { canRevealPhone, stripPhone };
