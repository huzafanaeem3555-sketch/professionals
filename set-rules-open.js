const admin = require('firebase-admin');

const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://serviceconnect-dea35-default-rtdb.firebaseio.com/',
});

const db = admin.database();

const openRules = {
  rules: {
    users: {
      ".read": "true",
      ".write": "true"
    },
    professionals: {
      ".read": "true",
      ".write": "true"
    },
    bookings: {
      ".read": "true",
      ".write": "true",
      ".indexOn": ["customerId", "professionalId", "_createdAt"]
    },
    chats: {
      ".read": "true",
      ".write": "true"
    }
  }
};

async function run() {
  try {
    console.log('Setting open database rules...');
    await db.setRules(JSON.stringify(openRules, null, 2));
    console.log('✅ Rules updated to OPEN successfully!');
    
    console.log('Retrieving new rules to verify...');
    const rules = await db.getRules();
    console.log('NEW RULES:');
    console.log(rules);
    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

run();
