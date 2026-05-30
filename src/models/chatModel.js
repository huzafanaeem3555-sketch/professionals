const { dbGet, dbSet, dbUpdate, dbGetAll, dbPush } = require('../config/firebase');

const CHATS_PATH = 'chats';
const BOOKINGS_PATH = 'bookings';

const ChatModel = {
  getChatId(uid1, uid2) {
    return [uid1, uid2].sort().join('_');
  },

  async getOrCreate(uid1, uid2) {
    const chatId = this.getChatId(uid1, uid2);
    const existing = await dbGet(`${CHATS_PATH}/${chatId}`);
    if (existing) return existing;

    const sorted = [uid1, uid2].sort();
    const chat = {
      chatId,
      participant1: sorted[0],
      participant2: sorted[1],
      participants: sorted,
      lastMessage: '',
      lastUpdated: Date.now(),
      _createdAt: Date.now(),
    };
    await dbSet(`${CHATS_PATH}/${chatId}`, chat);
    return chat;
  },

  /**
   * Get messages (latest N messages from RTDB).
   */
  async getMessages(chatId, limit = 50) {
    const { db } = require('../config/firebase');
    const snap = await db.ref(`${CHATS_PATH}/${chatId}/messages`)
      .orderByChild('timestamp')
      .limitToLast(limit)
      .once('value');

    if (!snap.exists()) return [];
    const messages = [];
    snap.forEach(child => {
      const value = child.val();
      messages.push({
        id: child.key,
        senderId: value.senderId || '',
        text: value.text || '',
        timestamp: value.timestamp || 0,
      });
    });
    return messages.sort((a, b) => a.timestamp - b.timestamp);
  },

  /**
   * Send a message.
   */
  async sendMessage(chatId, senderId, text) {
    const { db } = require('../config/firebase');
    const msgRef = db.ref(`${CHATS_PATH}/${chatId}/messages`).push();
    const message = {
      id: msgRef.key,
      senderId,
      text,
      timestamp: Date.now(),
    };
    await msgRef.set(message);

    // Update chat metadata for shared conversation
    await dbUpdate(`${CHATS_PATH}/${chatId}`, {
      lastMessage: text.length > 60 ? text.substring(0, 60) + '...' : text,
      lastUpdated: Date.now(),
    });

    return message;
  },

  /**
   * Check if two users have an active confirmed booking (access control for chat).
   */
  async hasActiveBooking(uid1, uid2) {
    const allBookings = await dbGetAll(BOOKINGS_PATH);
    return allBookings.some(b =>
      ['confirmed', 'in_progress', 'completed'].includes(b.status) &&
      ((b.customerId === uid1 && b.professionalId === uid2) ||
       (b.customerId === uid2 && b.professionalId === uid1))
    );
  },

  /**
   * Get all conversations for a user.
   */
  async getConversationsForUser(uid) {
    const all = await dbGetAll(CHATS_PATH);
    return all.filter(chat => {
      const participants = Array.isArray(chat.participants) ? chat.participants : Object.values(chat.participants || {});
      return participants.includes(uid);
    }).sort((a, b) => (b.lastUpdated || 0) - (a.lastUpdated || 0));
  },
};

module.exports = ChatModel;
