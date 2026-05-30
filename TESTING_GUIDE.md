# Service Connect - Full Testing Guide (Crash Prevention)

## 1) Quick Automated Checks
Run these on every change:

```bash
cd backend
npm test
```

```bash
cd frontend
flutter analyze
flutter test
```

Expected: all pass, no analyze errors.

## 2) Realtime Backend E2E (with real tokens)
Use current flow script:

```bash
cd backend
BASE_URL=http://YOUR_PC_IP:3000 \
CUSTOMER_TOKEN=... \
PROF_TOKEN=... \
PROF_UID=... \
node scripts/e2e_test.js
```

Expected:
1. Create request -> success
2. Propose price -> success
3. Accept price -> success
4. Start job -> success
5. Customer complete -> success
6. Professional complete -> success

## 3) Manual Real Device Test Cases

### A. Login + Session Persistence
1. Open app, Google Sign-In, select role.
2. Kill app completely.
3. Reopen app.
Expected: app should not ask login again until signout.

### B. Customer Request Flow
1. Customer sees professional list.
2. Open one professional.
3. Send request with only:
   - description
   - address
   - optional day/time
Expected: request saved with `pending_acceptance`.

### C. No Early Contact Reveal
1. Immediately after request, check booking details.
Expected: professional phone must NOT be shown before deal confirmation.

### D. Negotiation
1. Professional opens pending request and offers price.
2. Customer accepts or counters.
Expected:
- counter/offer status transitions are correct
- on final accept: status `confirmed`

### E. Job Completion + Commission
1. Professional starts job (`in_progress`).
2. Customer confirms completion (`customer_confirmed`).
3. Professional confirms completion (`completed`).
Expected:
- only at step 3 commission is deducted
- transaction entry exists in `transactions`

### F. Chat Access Rules
1. Try chat before confirmed booking.
Expected: blocked.
2. Try chat after confirmed booking.
Expected: allowed and realtime send/receive works.

### G. Admin Controls
Login username: `Huzaifa`

Checks:
1. View professionals/customers/bookings/transactions.
2. Delete one professional.
3. Delete one customer.
4. Clear all non-admin data.
Expected: all operations succeed and UI refreshes.

## 4) API Endpoint Validation Checklist

Auth:
- `POST /api/auth/google`
- `POST /api/users/set-role`

Professionals:
- `GET /api/professionals/nearby`
- `GET /api/professionals/:uid`

Bookings:
- `POST /api/bookings`
- `POST /api/bookings/:bookingId/propose-price`
- `POST /api/bookings/:bookingId/accept-price`
- `POST /api/bookings/:bookingId/start`
- `POST /api/bookings/:bookingId/customer-complete`
- `POST /api/bookings/:bookingId/complete`
- `GET /api/bookings/my`

Wallet/Admin:
- `POST /api/wallet/deduct` (guarded, completed only)
- `POST /api/admin/login`
- `DELETE /api/admin/users/clear-all`

## 5) Anti-Stuck / Crash Checks
1. Toggle airplane mode during booking API call.
Expected: error dialog/snackbar, no infinite loader.

2. Slow network simulation (2G/3G).
Expected: timeout in <= 10s with retry once.

3. Reopen app during active booking stream updates.
Expected: no crash, bookings reload correctly.

4. Invalid/expired FCM token on one device.
Expected: flow continues; only notification skipped log.

## 6) Release Gate (Do Not Ship If Fails)
- Any `flutter analyze` errors
- Any failing `npm test` or `flutter test`
- Early phone reveal before confirmed deal
- Commission deduct before `completed`
- App stuck loader > 10s without user feedback
