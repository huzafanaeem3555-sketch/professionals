const Groq = require('groq-sdk');

const GROQ_API_KEY = String(process.env.GROQ_API_KEY || process.env.GROK_API_KEY || '').trim();
let groq;
if (!GROQ_API_KEY) {
  console.warn('⚠️ GROQ_API_KEY is missing. AI features will be disabled.');
  groq = {
    chat: {
      completions: {
        create: async () => {
          throw new Error('GROQ_API_KEY missing');
        },
      },
    },
  };
} else {
  groq = new Groq({ apiKey: GROQ_API_KEY });
}

const GROQ_MODEL = 'llama-3.1-8b-instant';

/**
 * Send a chat message to Groq AI and get a response.
 * Used for: AI assistant, smart recommendations, professional matching.
 */
async function groqChat(messages, systemPrompt = null) {
  const allMessages = [];

  if (systemPrompt) {
    allMessages.push({ role: 'system', content: systemPrompt });
  }

  allMessages.push(...messages);

  const response = await groq.chat.completions.create({
    model: GROQ_MODEL,
    messages: allMessages,
    max_tokens: 512,
    temperature: 0.7,
  });

  return response.choices[0]?.message?.content || 'Sorry, I could not generate a response.';
}

/**
 * Get AI-powered service recommendation based on user's description.
 */
async function getServiceRecommendation(userDescription) {
  const systemPrompt = `You are HirePro's service-matching assistant for Pakistan.
The user text can be English or a spoken-language transcription. Translate the user's intent and choose exactly one serviceType only from:
plumber, electrician, carpenter, ac_mechanic, painter, cleaner, tutor, driver, chef, beautician, it_technician, security_guard.

Examples:
- "bijli ka masla", "fan kharab", "wiring", "light issue" => electrician
- "pani leak", "pipe toot gaya", "nal kharab" => plumber
- "AC thanda nahi", "fridge cooling", "air condition" => ac_mechanic
- "darwaza", "furniture", "lakri ka kaam" => carpenter
- "rang", "paint wall" => painter
- "safai", "cleaning" => cleaner
- "computer", "laptop", "wifi", "web development", "software" => it_technician

Return strict JSON only: {"serviceType": "...", "priceMin": 500, "priceMax": 2000, "advice": "..."}`;

  try {
    const response = await groqChat(
      [{ role: 'user', content: userDescription }],
      systemPrompt
    );

    // Try to parse JSON from response
    const jsonMatch = response.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      return JSON.parse(jsonMatch[0]);
    }
    return { serviceType: null, advice: response };
  } catch (err) {
    console.error('Groq recommendation error:', err.message);
    return { serviceType: null, advice: 'Please describe your issue and we will help you find the right professional.' };
  }
}

/**
 * AI-powered chat assistant for in-app support.
 */
async function getAIAssistantReply(userMessage, conversationHistory = [], matchContext = null) {
  const matchText = matchContext
    ? `\nMatched service: ${matchContext.serviceType || 'unknown'}.
Available professionals: ${Array.isArray(matchContext.professionals) && matchContext.professionals.length
      ? matchContext.professionals.map((pro, index) => `${index + 1}. ${pro.name} (${pro.uid}) - ${pro.services.join(', ')}`).join('; ')
      : 'none found yet'}.
If professionals are available, mention that matching professionals are shown below the chat response and ask the customer to use WhatsApp for final price and timing.`
    : '';

  const systemPrompt = `You are HirePro's AI service assistant for Pakistan.
Help customers understand their issue, choose the right service, and contact a suitable professional.
Reply in the same language or writing style used by the customer. If the customer writes Roman Urdu, reply in Roman Urdu. If they write English, reply in English.
Keep replies concise, practical, and under 120 words.
Do not invent professional phone numbers or IDs. Use only the matched context if available.
EasyPaisa number: 03455876761. Commission is 10% of agreed price.${matchText}`;

  const messages = [
    ...conversationHistory.slice(-6), // Last 6 messages for context
    { role: 'user', content: userMessage },
  ];

  try {
    return await groqChat(messages, systemPrompt);
  } catch (err) {
    console.error('Groq assistant error:', err.message);
    return fallbackAssistantReply(userMessage, matchContext);
  }
}

function fallbackAssistantReply(userMessage, matchContext = null) {
  const service = String(matchContext?.serviceType || 'service').replace(/_/g, ' ');
  const count = Array.isArray(matchContext?.professionals)
    ? matchContext.professionals.length
    : 0;
  const text = String(userMessage || '').toLowerCase();
  const romanUrdu = [
    'pani', 'bijli', 'masla', 'kharab', 'chahiye', 'nal', 'darwaza',
    'thanda', 'safai', 'kaam', 'kr', 'kar', 'hai', 'ho raha',
  ].some(word => text.includes(word));

  if (romanUrdu) {
    return count > 0
      ? `Aap ka masla ${service} se related lag raha hai. Neechay matching professionals show ho rahe hain. WhatsApp button se un se price aur timing confirm kar lain.`
      : `Aap ka masla ${service} se related lag raha hai. Is waqt exact matching professional nahi mila, search ya post job try kar lain.`;
  }

  return count > 0
    ? `This looks like a ${service} issue. Matching professionals are shown below. Use WhatsApp to confirm price, timing, and availability.`
    : `This looks like a ${service} issue. No exact professional is available right now, so try search or post a job.`;
}

module.exports = { GROQ_MODEL, groq, groqChat, getServiceRecommendation, getAIAssistantReply };
