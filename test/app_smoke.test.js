const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');

const app = require('../src/app');

function listen(server) {
  return new Promise((resolve) => {
    server.listen(0, '127.0.0.1', () => {
      resolve(server.address());
    });
  });
}

test('health route responds with OK payload', async () => {
  const server = http.createServer(app);
  const address = await listen(server);

  try {
    const response = await fetch(`http://127.0.0.1:${address.port}/health`);
    const json = await response.json();

    assert.equal(response.status, 200);
    assert.equal(json.status, 'OK');
  } finally {
    server.close();
  }
});

test('unknown route returns JSON 404', async () => {
  const server = http.createServer(app);
  const address = await listen(server);

  try {
    const response = await fetch(
      `http://127.0.0.1:${address.port}/missing-route`,
    );
    const json = await response.json();

    assert.equal(response.status, 404);
    assert.equal(json.success, false);
  } finally {
    server.close();
  }
});
