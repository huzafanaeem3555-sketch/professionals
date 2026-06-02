const Groq = require('groq-sdk');

const GROQ_API_KEY = process.env.GROQ_API_KEY;
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

const GROQ_MODEL = 'llama-3.3-70b-versatile'; // Updated — llama3-8b-8192 was decommissioned

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
The user text can be English, Urdu script, or Roman Urdu from voice transcription. Translate the user's intent and choose exactly one serviceType only from:
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
async function getAIAssistantReply(userMessage, conversationHistory = []) {
  const systemPrompt = `You are a friendly customer support assistant for Service Connect Pakistan.
You help users with: booking services, finding professionals, understanding payment steps, and general support.
EasyPaisa number: 03455876761. Commission is 10% of agreed price.
Keep replies concise (under 100 words). Be helpful and professional. Always respond in English only.`;

  const messages = [
    ...conversationHistory.slice(-6), // Last 6 messages for context
    { role: 'user', content: userMessage },
  ];

  try {
    return await groqChat(messages, systemPrompt);
  } catch (err) {
    console.error('Groq assistant error:', err.message);
    return 'Sorry, the AI assistant is currently unavailable. Please try again later.';
  }
}

module.exports = { groq, groqChat, getServiceRecommendation, getAIAssistantReply };
