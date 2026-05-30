const test = require('node:test');
const assert = require('node:assert/strict');

const BookingController = require('../src/controllers/bookingController');
const ProfessionalController = require('../src/controllers/professionalController');
const GeolocationController = require('../src/controllers/geolocationController');
const ProfessionalModel = require('../src/models/professionalModel');

function createRes() {
  return {
    statusCode: 200,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(payload) {
      this.body = payload;
      return this;
    },
  };
}

test('BookingController.createBooking validates required fields', async () => {
  const req = {
    user: { uid: 'customer_1', displayName: 'Customer' },
    body: { professionalId: '', serviceType: '', proposedPrice: undefined },
  };
  const res = createRes();

  await BookingController.createBooking(req, res);

  assert.equal(res.statusCode, 400);
  assert.equal(res.body.success, false);
});

test('ProfessionalController.upsertProfile rejects invalid Pakistani phone', async () => {
  const req = {
    user: { uid: 'pro_1' },
    body: {
      name: 'Ali Pro',
      phoneNumber: '12345',
      services: ['electrician'],
      location: { lat: 24.86, lng: 67.00 },
    },
  };
  const res = createRes();

  await ProfessionalController.upsertProfile(req, res);

  assert.equal(res.statusCode, 400);
  assert.match(res.body.message, /valid Pakistani mobile number/i);
});

test('ProfessionalController.getNearby validates coordinates', async () => {
  const req = { query: {} };
  const res = createRes();

  await ProfessionalController.getNearby(req, res);

  assert.equal(res.statusCode, 400);
  assert.equal(res.body.success, false);
});

test('ProfessionalController.getNearby returns formatted professionals', async () => {
  const original = ProfessionalModel.getNearby;
  ProfessionalModel.getNearby = async () => [
    {
      uid: 'pro_2',
      name: 'Electric Pro',
      services: ['electrician'],
      location: { lat: 24.9, lng: 67.0, address: 'Karachi' },
      rating: 4.7,
      isAvailable: true,
      photoURL: '',
      hourlyRate: 1800,
      description: 'Fast service',
    },
  ];

  const req = { query: { lat: '24.86', lng: '67.00' } };
  const res = createRes();

  try {
    await ProfessionalController.getNearby(req, res);
  } finally {
    ProfessionalModel.getNearby = original;
  }

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.success, true);
  assert.equal(res.body.data.length, 1);
  assert.match(res.body.data[0].phoneNumber, /Hidden until agreement/i);
});

test('GeolocationController.getNearbyProfessionals rejects invalid coordinates', async () => {
  const req = { query: { lat: 'abc', lng: '67.00' } };
  const res = createRes();

  await GeolocationController.getNearbyProfessionals(req, res);

  assert.equal(res.statusCode, 400);
  assert.equal(res.body.success, false);
});
