/*
Realtime end-to-end flow validator for current booking lifecycle.
Usage:
  BASE_URL=http://192.168.1.10:3000 \
  CUSTOMER_TOKEN=ey... \
  PROF_TOKEN=ey... \
  PROF_UID=professional_uid \
  node scripts/e2e_test.js

Flow:
  1) Customer creates request (no price required)
  2) Professional proposes price
  3) Customer accepts price (deal confirmed)
  4) Professional starts job (in_progress)
  5) Customer confirms completion (customer_confirmed)
  6) Professional completes (completed + commission deduction)
*/

const BASE = process.env.BASE_URL || 'http://127.0.0.1:3000';
const CUSTOMER_TOKEN = process.env.CUSTOMER_TOKEN;
const PROF_TOKEN = process.env.PROF_TOKEN;
const PROF_UID = process.env.PROF_UID;

if (!CUSTOMER_TOKEN || !PROF_TOKEN || !PROF_UID) {
  console.error('Missing env vars. Set CUSTOMER_TOKEN, PROF_TOKEN, PROF_UID.');
  process.exit(1);
}

const headers = (token) => ({
  'Content-Type': 'application/json',
  'Authorization': `Bearer ${token}`,
});

async function call(path, opts = {}) {
  const url = `${BASE}${path}`;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 10000);
  const res = await fetch(url, { ...opts, signal: controller.signal });
  clearTimeout(timer);
  const text = await res.text();
  let body = text;
  try { body = JSON.parse(text); } catch (e) {}
  return { status: res.status, body };
}

(async () => {
  try {
    console.log('1) Create request as customer...');
    const createPayload = {
      professionalId: PROF_UID,
      serviceType: 'plumber',
      description: 'Kitchen sink leakage test case',
      address: 'Test address from e2e script',
      scheduledTime: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
    };

    const createRes = await call('/api/bookings', {
      method: 'POST',
      headers: headers(CUSTOMER_TOKEN),
      body: JSON.stringify(createPayload),
    });
    console.log('Create status:', createRes.status);
    console.log(JSON.stringify(createRes.body, null, 2));

    if (!createRes.body || !createRes.body.success) {
      console.error('Create booking failed. Aborting.');
      process.exit(2);
    }

    const bookingId = createRes.body.data.bookingId;

    console.log('\n2) Professional fetches bookings...');
    const myRes = await call('/api/bookings/my', { headers: headers(PROF_TOKEN) });
    console.log('GET /api/bookings/my status:', myRes.status);
    console.log(JSON.stringify(myRes.body, null, 2));

    console.log('\n3) Professional proposes price...');
    const proposeRes = await call(`/api/bookings/${bookingId}/propose-price`, {
      method: 'POST',
      headers: headers(PROF_TOKEN),
      body: JSON.stringify({ price: 4500 }),
    });
    console.log('Propose status:', proposeRes.status);
    console.log(JSON.stringify(proposeRes.body, null, 2));

    if (!proposeRes.body || !proposeRes.body.success) {
      console.error('Propose price failed. Aborting.');
      process.exit(3);
    }

    console.log('\n4) Customer accepts price...');
    const acceptRes = await call(`/api/bookings/${bookingId}/accept-price`, {
      method: 'POST',
      headers: headers(CUSTOMER_TOKEN),
      body: JSON.stringify({ price: 4500 }),
    });
    console.log('Accept price status:', acceptRes.status);
    console.log(JSON.stringify(acceptRes.body, null, 2));

    if (!acceptRes.body || !acceptRes.body.success) {
      console.error('Accept price failed.');
      process.exit(4);
    }

    console.log('\n5) Professional starts job...');
    const startRes = await call(`/api/bookings/${bookingId}/start`, {
      method: 'POST',
      headers: headers(PROF_TOKEN),
    });
    console.log('Start status:', startRes.status);
    console.log(JSON.stringify(startRes.body, null, 2));
    if (!startRes.body || !startRes.body.success) {
      console.error('Start job failed.');
      process.exit(5);
    }

    console.log('\n6) Customer confirms completion...');
    const custDoneRes = await call(`/api/bookings/${bookingId}/customer-complete`, {
      method: 'POST',
      headers: headers(CUSTOMER_TOKEN),
    });
    console.log('Customer complete status:', custDoneRes.status);
    console.log(JSON.stringify(custDoneRes.body, null, 2));
    if (!custDoneRes.body || !custDoneRes.body.success) {
      console.error('Customer completion failed.');
      process.exit(6);
    }

    console.log('\n7) Professional completes booking...');
    const doneRes = await call(`/api/bookings/${bookingId}/complete`, {
      method: 'POST',
      headers: headers(PROF_TOKEN),
    });
    console.log('Complete status:', doneRes.status);
    console.log(JSON.stringify(doneRes.body, null, 2));
    if (!doneRes.body || !doneRes.body.success) {
      console.error('Professional completion failed.');
      process.exit(7);
    }

    console.log('\nE2E test completed successfully.');
    process.exit(0);
  } catch (err) {
    console.error('E2E script error:', err);
    process.exit(10);
  }
})();
