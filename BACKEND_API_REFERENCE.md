# 🔌 BACKEND API REFERENCE & VERIFICATION

## ✅ BACKEND STATUS

```
Endpoint: http://localhost:5000
Status: Ready for testing
Security: Firebase token verification required
Response Format: { success: boolean, data: object, message: string }
```

---

## 🔐 AUTHENTICATION ENDPOINTS

### 1. Health Check (No Auth Required)
```bash
GET /health

Response:
{ "status": "OK", "message": "Server is running" }

Test:
curl http://localhost:5000/health
```

### 2. Google Sign-In
```bash
POST /api/auth/google
Authorization: None required
Body: {
  "idToken": "firebase_id_token...",
  "fcmToken": "optional_fcm_token"
}

Response:
{
  "success": true,
  "data": {
    "user": {
      "uid": "user_uid",
      "email": "user@example.com",
      "displayName": "User Name",
      "role": "none" or "customer" or "professional"
    },
    "token": "jwt_token_for_future_requests"
  },
  "message": "SignIn successful"
}

Error:
{
  "success": false,
  "message": "Invalid token"
}
```

### 3. Email Sign-Up
```bash
POST /api/auth/signup
Authorization: None required
Body: {
  "email": "user@example.com",
  "password": "password123",
  "name": "User Name"
}

Response:
{
  "success": true,
  "data": {
    "user": { ...user object },
    "token": "jwt_token"
  }
}

Errors:
- Email in use: "Email already registered"
- Invalid email: "Invalid email format"
- Weak password: "Password must be 6+ characters"
```

### 4. Email Sign-In
```bash
POST /api/auth/signin
Authorization: None required
Body: {
  "email": "user@example.com",
  "password": "password123"
}

Response:
{
  "success": true,
  "data": {
    "user": { ...user object with role },
    "token": "jwt_token"
  }
}

Error:
{
  "success": false,
  "message": "Invalid credentials"
}
```

### 5. Check User Role
```bash
POST /api/auth/check-role
Authorization: None required
Body: {
  "email": "user@example.com"
}

Response:
{
  "success": true,
  "data": {
    "hasRole": true,
    "existingRole": "customer" or "professional"
  }
}

Usage: Frontend checks before signup to prevent duplicate roles
```

### 6. Get Current User (ME)
```bash
GET /api/auth/me
Authorization: Bearer {token} REQUIRED

Response:
{
  "success": true,
  "data": {
    "uid": "user_uid",
    "email": "user@example.com",
    "displayName": "User Name",
    "role": "customer" or "professional",
    "phoneNumber": "03001234567",
    "rating": 4.5,
    "totalBookings": 10
  }
}

Error (401):
{
  "success": false,
  "message": "Invalid authentication token"
}
```

### 7. Set Role
```bash
POST /api/auth/set-role
Authorization: Bearer {token} REQUIRED
Body: {
  "role": "customer" or "professional"
}

Response:
{
  "success": true,
  "data": { ...updated user object },
  "message": "Role updated"
}
```

### 8. Update Phone
```bash
POST /api/auth/update-phone
Authorization: Bearer {token} REQUIRED
Body: {
  "phone": "03001234567"
}

Response:
{
  "success": true,
  "data": { ...updated user object }
}
```

---

## 📋 BOOKING ENDPOINTS

### 1. Create Booking
```bash
POST /api/bookings
Authorization: Bearer {token} REQUIRED
Body: {
  "professionalId": "professional_uid",
  "serviceType": "plumbing",
  "proposedPrice": 5000,
  "scheduledTime": "2026-05-20 10:00",
  "address": "123 Main St",
  "description": "Fix leaking pipe"
}

Response:
{
  "success": true,
  "data": {
    "id": "booking_id",
    "customerId": "current_user",
    "professionalId": "professional_uid",
    "status": "pending_acceptance",
    "proposedPrice": 5000,
    "createdAt": "2026-05-18T10:00:00Z"
  }
}
```

### 2. Get My Bookings
```bash
GET /api/bookings/my-bookings
Authorization: Bearer {token} REQUIRED

Response:
{
  "success": true,
  "data": {
    "bookings": [
      {
        "id": "booking_id",
        "status": "pending_acceptance",
        "proposedPrice": 5000,
        "customerId": "...",
        "professionalId": "...",
        "createdAt": "2026-05-18T10:00:00Z"
      }
    ]
  }
}
```

### 3. Accept Booking (Professional)
```bash
POST /api/bookings/{bookingId}/accept
Authorization: Bearer {token} REQUIRED

Response:
{
  "success": true,
  "data": {
    "id": "booking_id",
    "status": "pending_payment"
  }
}
```

### 4. Reject Booking (Professional)
```bash
POST /api/bookings/{bookingId}/reject
Authorization: Bearer {token} REQUIRED

Response:
{
  "success": true,
  "data": { "status": "cancelled" }
}
```

### 5. Cancel Booking (Customer)
```bash
DELETE /api/bookings/{bookingId}
Authorization: Bearer {token} REQUIRED

Response:
{
  "success": true,
  "data": { "status": "cancelled" }
}
```

### 6. Confirm Payment
```bash
POST /api/bookings/{bookingId}/confirm-payment
Authorization: Bearer {token} REQUIRED
Body: {
  "transactionId": "123456",
  "screenshotUrl": "optional_s3_url"
}

Response:
{
  "success": true,
  "data": {
    "id": "booking_id",
    "status": "confirmed",
    "paymentConfirmed": true,
    "phoneNumberRevealed": true
  }
}

Side Effects:
- Phone number becomes visible
- Chat unlocks
- Booking status: pending_payment → confirmed
```

---

## 💬 CHAT ENDPOINTS

### 1. Send Message
```bash
POST /api/chat/send
Authorization: Bearer {token} REQUIRED
Body: {
  "receiverId": "other_user_id",
  "text": "Hello, can you fix my tap?"
}

Response:
{
  "success": true,
  "data": {
    "id": "message_id",
    "senderId": "current_user",
    "receiverId": "other_user_id",
    "text": "Hello...",
    "timestamp": "2026-05-18T10:00:00Z"
  }
}

Note: Also written to Firebase RTDB at /chats/{chatId}/messages/{messageId}
```

### 2. Get Messages
```bash
GET /api/chat/messages/{otherUserId}
Authorization: Bearer {token} REQUIRED

Response:
{
  "success": true,
  "data": {
    "messages": [
      {
        "id": "message_id",
        "senderId": "...",
        "text": "...",
        "timestamp": "..."
      }
    ]
  }
}
```

### 3. Get Conversations
```bash
GET /api/chat/conversations
Authorization: Bearer {token} REQUIRED

Response:
{
  "success": true,
  "data": {
    "conversations": [
      {
        "userId": "other_user_id",
        "name": "Professional Name",
        "lastMessage": "Will be there in 10 mins",
        "timestamp": "2026-05-18T10:00:00Z"
      }
    ]
  }
}
```

### Real-time Chat (Firebase RTDB)
```
Frontend listens on:
/chats/{chatId}/messages
When new message written, Firebase triggers onChildAdded event
Frontend updates UI immediately
```

---

## 👨‍💼 PROFESSIONAL ENDPOINTS

### 1. Get Nearby Professionals
```bash
GET /api/professionals/nearby
Query Params:
  lat: 31.5204 (latitude)
  lng: 74.3587 (longitude)
  radius: 10 (km, optional, default 10)
  serviceType: plumbing (optional filter)

Response:
{
  "success": true,
  "data": {
    "professionals": [
      {
        "uid": "professional_uid",
        "displayName": "Ahmed",
        "rating": 4.8,
        "totalBookings": 45,
        "distance": 2.3,
        "services": ["plumbing", "electrical"],
        "hourlyRate": 500,
        "photoURL": "https://...",
        "location": { "lat": 31.5, "lng": 74.3 }
      }
    ]
  }
}
```

### 2. Get Professional Profile
```bash
GET /api/professionals/{uid}
Authorization: None required (public profile)

Response:
{
  "success": true,
  "data": {
    "uid": "professional_uid",
    "displayName": "Ahmed",
    "email": "ahmed@example.com",
    "bio": "Expert plumber with 10 years experience",
    "rating": 4.8,
    "totalBookings": 45,
    "services": [
      {
        "name": "Pipe Repair",
        "basePrice": 500,
        "description": "Fix or replace damaged pipes"
      }
    ],
    "portfolio": ["image_url1", "image_url2"],
    "hourlyRate": 500,
    "isAvailable": true,
    "location": { "lat": 31.5, "lng": 74.3 }
  }
}
```

### 3. Update Professional Profile
```bash
POST /api/professionals/update-profile
Authorization: Bearer {token} REQUIRED
Body: {
  "bio": "Expert with 10 years experience",
  "hourlyRate": 500,
  "phoneNumber": "03001234567"
}

Response:
{
  "success": true,
  "data": { ...updated profile }
}
```

### 4. Toggle Availability
```bash
POST /api/professionals/toggle-availability
Authorization: Bearer {token} REQUIRED
Body: {
  "isAvailable": true or false
}

Response:
{
  "success": true,
  "data": { "isAvailable": true }
}

Note: When false, won't appear in nearby professionals search
```

### 5. Upload Portfolio
```bash
POST /api/professionals/upload-portfolio
Authorization: Bearer {token} REQUIRED
Content-Type: multipart/form-data
Body: {
  "files": [binary_image1, binary_image2]
}

Response:
{
  "success": true,
  "data": {
    "portfolio": ["s3_url1", "s3_url2"]
  }
}
```

---

## 💰 EARNINGS ENDPOINTS

### Get Earnings
```bash
GET /api/professionals/earnings
Authorization: Bearer {token} REQUIRED

Response:
{
  "success": true,
  "data": {
    "totalEarnings": 45000,
    "thisMonth": 8500,
    "thisWeek": 1200,
    "pendingPayment": 2000,
    "confirmed": 46000,
    "transactions": [
      {
        "id": "tx_id",
        "bookingId": "booking_id",
        "amount": 500,
        "commission": 50,
        "netEarnings": 450,
        "status": "confirmed",
        "date": "2026-05-18"
      }
    ]
  }
}
```

---

## 🔒 AUTHENTICATION HEADER FORMAT

All protected endpoints require:
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

If missing or invalid:
```json
{
  "success": false,
  "message": "Invalid authentication token",
  "statusCode": 401
}
```

---

## 🧪 TESTING BACKEND WITH CURL

### Test Health (No Auth)
```bash
curl http://localhost:5000/health
```

### Test Google Sign-In
```bash
# First get a Firebase ID token
# Then:
curl -X POST http://localhost:5000/api/auth/google \
  -H "Content-Type: application/json" \
  -d '{
    "idToken": "your_firebase_token_here"
  }'
```

### Test Protected Route (with token)
```bash
curl http://localhost:5000/api/auth/me \
  -H "Authorization: Bearer your_token_here"
```

### Test Booking Creation
```bash
curl -X POST http://localhost:5000/api/bookings \
  -H "Authorization: Bearer your_token_here" \
  -H "Content-Type: application/json" \
  -d '{
    "professionalId": "prof_uid",
    "serviceType": "plumbing",
    "proposedPrice": 5000
  }'
```

---

## ✅ VERIFICATION CHECKLIST

Before going to production, verify:

- [ ] Health check responds (GET /health)
- [ ] Google Sign-In works (POST /api/auth/google)
- [ ] Email Sign-Up works (POST /api/auth/signup)
- [ ] Email Sign-In works (POST /api/auth/signin)
- [ ] Token auth works (GET /api/auth/me)
- [ ] Create Booking works (POST /api/bookings)
- [ ] Accept Booking works (POST /api/bookings/{id}/accept)
- [ ] Payment confirmation works (POST /api/bookings/{id}/confirm-payment)
- [ ] Chat endpoints work (POST /api/chat/send)
- [ ] Professional endpoints work (GET /api/professionals/nearby)
- [ ] All error responses have proper format
- [ ] 401 Unauthorized returns on invalid token
- [ ] 500 Server errors are handled gracefully
- [ ] Timeouts don't exceed 20 seconds
- [ ] Database transactions are atomic
- [ ] Payment processing is idempotent (same ID can't double-charge)

---

## 🔔 REAL-TIME FEATURES

### Firebase Realtime Database Paths

```
/users/{uid}
  - displayName
  - email
  - role
  - phoneNumber
  - photoURL

/chats/{chatId}/messages/{messageId}
  - senderId
  - text
  - timestamp
  - read: false

/bookings/{bookingId}
  - status (pending_acceptance, pending_payment, confirmed, etc.)
  - customerId
  - professionalId
  - proposedPrice

/notifications/{uid}/{notificationId}
  - type (booking_bid, payment_confirmed, message, etc.)
  - data
  - timestamp
```

---

## 📊 RESPONSE TIME EXPECTATIONS

| Endpoint | Time | Notes |
|----------|------|-------|
| Health Check | <100ms | Should always be fast |
| Google Auth | 1-2s | Includes Firebase verification |
| Email Auth | 500ms-1s | Database lookup + token generation |
| Get Bookings | 300-500ms | List query |
| Create Booking | 500-800ms | Save + notification |
| Payment Confirm | 1-2s | Update + chat unlock |
| Chat Send | 300-500ms | Save + RTDB sync |

---

## 🚨 ERROR CODES & MESSAGES

| Code | Message | Fix |
|------|---------|-----|
| 401 | Invalid authentication token | Logout & login again |
| 403 | Not authorized for this action | Check user role |
| 404 | Resource not found | Verify IDs are correct |
| 500 | Server error | Check backend logs |
| TIMEOUT | Request timed out | Check internet, retry |
| NETWORK_ERROR | Connection refused | Backend not running |

---

*Last Updated: May 18, 2026*
*Backend Status: READY FOR TESTING*

