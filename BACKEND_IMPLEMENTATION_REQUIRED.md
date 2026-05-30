# Backend Implementation Guide - Admin Panel & API Endpoints

## 🚨 Critical: Required Backend Endpoints

All these endpoints must be implemented for the admin panel to work.

---

## 1. Admin Authentication

### Endpoint: POST /admin/login
```http
POST http://172.28.31.120:5000/api/admin/login HTTP/1.1
Content-Type: application/json

{
  "username": "Huzaifa"
}
```

**Response (Success - 200):**
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "admin": {
      "id": "admin_1",
      "username": "Huzaifa",
      "email": "admin@serviceconnect.pk",
      "role": "super_admin"
    }
  },
  "message": "Admin login successful"
}
```

**Response (Failure - 401):**
```json
{
  "success": false,
  "message": "Invalid admin credentials",
  "errorCode": 401
}
```

**Backend Requirements:**
- [ ] Store admin credentials in database (username: "Huzaifa")
- [ ] Hash password using bcrypt
- [ ] Validate username and password
- [ ] Generate JWT token with secret key
- [ ] Token should be valid for 24 hours
- [ ] Return token in response

**Backend Code Example (Node.js/Express):**
```javascript
router.post('/admin/login', async (req, res) => {
  const { username } = req.body;
  
  try {
    // Find admin by username
    const admin = await Admin.findOne({ username });
    if (!admin) {
      return res.status(401).json({
        success: false,
        message: 'Invalid admin credentials'
      });
    }
    
    // Generate JWT token
    const token = jwt.sign(
      { id: admin._id, role: 'admin' },
      process.env.JWT_SECRET,
      { expiresIn: '24h' }
    );
    
    res.json({
      success: true,
      data: { token, admin },
      message: 'Admin login successful'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});
```

---

## 2. Admin Stats Endpoint

### Endpoint: GET /admin/stats
```http
GET http://172.28.31.120:5000/api/admin/stats HTTP/1.1
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response (Success - 200):**
```json
{
  "success": true,
  "data": {
    "totalProfessionals": 45,
    "totalCustomers": 127,
    "totalCompletedJobs": 892,
    "totalCommission": 89200,
    "onlineProfessionals": 12,
    "pendingBookings": 23,
    "completedBookingsThisMonth": 156
  }
}
```

**Backend Requirements:**
- [ ] Count all users with role = 'professional'
- [ ] Count all users with role = 'customer'
- [ ] Count all bookings with status = 'completed'
- [ ] Sum all transactions where type = 'commission' (10% of booking amount)
- [ ] Count professionals with availability = true
- [ ] Count bookings with status = 'pending_acceptance'
- [ ] Count completed bookings in current month
- [ ] Requires valid JWT token

**Backend Code Example:**
```javascript
router.get('/admin/stats', authenticateAdmin, async (req, res) => {
  try {
    const stats = {
      totalProfessionals: await User.countDocuments({ role: 'professional' }),
      totalCustomers: await User.countDocuments({ role: 'customer' }),
      totalCompletedJobs: await Booking.countDocuments({ status: 'completed' }),
      totalCommission: await Transaction.aggregate([
        { $match: { type: 'commission' } },
        { $group: { _id: null, total: { $sum: '$amount' } } }
      ]),
      // ... more stats
    };
    
    res.json({ success: true, data: stats });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});
```

---

## 3. Get All Professionals

### Endpoint: GET /admin/professionals
```http
GET http://172.28.31.120:5000/api/admin/professionals HTTP/1.1
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response (Success - 200):**
```json
{
  "success": true,
  "data": [
    {
      "uid": "prof_123abc",
      "displayName": "Ahmed Khan",
      "email": "ahmed@example.com",
      "phoneNumber": "+923001234567",
      "serviceTypes": ["electrician", "plumber"],
      "rating": 4.8,
      "totalJobs": 156,
      "wallet": 45000,
      "status": "active",
      "createdAt": 1705276800000
    },
    {
      "uid": "prof_456def",
      "displayName": "Fatima Ali",
      "email": "fatima@example.com",
      "phoneNumber": "+923005678901",
      "serviceTypes": ["beautician"],
      "rating": 4.9,
      "totalJobs": 89,
      "wallet": 32500,
      "status": "active",
      "createdAt": 1705190400000
    }
  ]
}
```

**Backend Requirements:**
- [ ] Return all users with role = 'professional'
- [ ] Include serviceTypes as array
- [ ] Calculate rating (average of all reviews)
- [ ] Calculate totalJobs (count of completed bookings)
- [ ] Get wallet balance from user profile
- [ ] Include status (active/inactive/suspended)
- [ ] Order by most recent or most completed jobs
- [ ] Requires valid JWT token

---

## 4. Get All Customers

### Endpoint: GET /admin/customers
```http
GET http://172.28.31.120:5000/api/admin/customers HTTP/1.1
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response (Success - 200):**
```json
{
  "success": true,
  "data": [
    {
      "uid": "cust_789xyz",
      "displayName": "Hassan Raza",
      "email": "hassan@example.com",
      "phoneNumber": "+923101234567",
      "totalBookings": 12,
      "totalSpent": 125000,
      "averageRating": 4.5,
      "status": "active",
      "createdAt": 1705363200000
    },
    {
      "uid": "cust_012abc",
      "displayName": "Aisha Khan",
      "email": "aisha@example.com",
      "phoneNumber": "+923109876543",
      "totalBookings": 8,
      "totalSpent": 89500,
      "averageRating": 4.7,
      "status": "active",
      "createdAt": 1705276800000
    }
  ]
}
```

**Backend Requirements:**
- [ ] Return all users with role = 'customer'
- [ ] Calculate totalBookings (count of user's bookings)
- [ ] Calculate totalSpent (sum of all agreed prices)
- [ ] Calculate averageRating (average of ratings they gave)
- [ ] Include status
- [ ] Order by most recent or most spending
- [ ] Requires valid JWT token

---

## 5. Get All Bookings

### Endpoint: GET /admin/bookings
```http
GET http://172.28.31.120:5000/api/admin/bookings HTTP/1.1
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response (Success - 200):**
```json
{
  "success": true,
  "data": [
    {
      "bookingId": "book_001",
      "id": "book_001",
      "customerId": "cust_789xyz",
      "customerName": "Hassan Raza",
      "professionalId": "prof_123abc",
      "professionalName": "Ahmed Khan",
      "serviceType": "electrical",
      "status": "completed",
      "proposedPrice": 2000,
      "agreedPrice": 2500,
      "address": "123 Main Street, Karachi",
      "description": "Install ceiling fan",
      "scheduledTime": "2024-01-15T10:00:00Z",
      "createdAt": 1705276800000,
      "updatedAt": 1705363200000,
      "rating": 5,
      "review": "Excellent work, highly recommended!"
    },
    {
      "bookingId": "book_002",
      "id": "book_002",
      "customerId": "cust_012abc",
      "customerName": "Aisha Khan",
      "professionalId": "prof_456def",
      "professionalName": "Fatima Ali",
      "serviceType": "plumbing",
      "status": "in_progress",
      "proposedPrice": 3000,
      "agreedPrice": 3500,
      "address": "456 Oak Avenue, Lahore",
      "description": "Fix leaking tap",
      "scheduledTime": "2024-01-20T14:00:00Z",
      "createdAt": 1705190400000,
      "updatedAt": 1705276800000
    }
  ]
}
```

**Backend Requirements:**
- [ ] Return all bookings
- [ ] Include customer and professional names/IDs
- [ ] Include all price information (proposed, agreed)
- [ ] Include booking status
- [ ] Include service type
- [ ] Include location/address
- [ ] Include timestamps in milliseconds (JavaScript format)
- [ ] Include rating and review if completed
- [ ] Order by most recent first
- [ ] Requires valid JWT token

---

## 6. Get All Transactions

### Endpoint: GET /admin/transactions
```http
GET http://172.28.31.120:5000/api/admin/transactions HTTP/1.1
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response (Success - 200):**
```json
{
  "success": true,
  "data": [
    {
      "transactionId": "tx_001",
      "bookingId": "book_001",
      "customerId": "cust_789xyz",
      "customerName": "Hassan Raza",
      "professionalId": "prof_123abc",
      "professionalName": "Ahmed Khan",
      "type": "payment",
      "status": "completed",
      "amount": 2500,
      "commission": 250,
      "professionalEarnings": 2250,
      "method": "easypaisa",
      "transactionRef": "EP123456789",
      "createdAt": 1705363200000
    },
    {
      "transactionId": "tx_002",
      "bookingId": "book_002",
      "customerId": "cust_012abc",
      "customerName": "Aisha Khan",
      "professionalId": "prof_456def",
      "professionalName": "Fatima Ali",
      "type": "payment",
      "status": "pending",
      "amount": 3500,
      "commission": 350,
      "professionalEarnings": 3150,
      "method": "easypaisa",
      "transactionRef": "EP987654321",
      "createdAt": 1705276800000
    }
  ]
}
```

**Backend Requirements:**
- [ ] Return all transactions
- [ ] Calculate commission (10% of amount)
- [ ] Calculate professional earnings (90% of amount)
- [ ] Include all names and IDs
- [ ] Include payment method
- [ ] Include transaction reference
- [ ] Include status
- [ ] Timestamps in milliseconds
- [ ] Order by most recent first
- [ ] Requires valid JWT token

---

## 7. Delete User

### Endpoint: DELETE /admin/users/{uid}
```http
DELETE http://172.28.31.120:5000/api/admin/users/prof_123abc HTTP/1.1
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response (Success - 200):**
```json
{
  "success": true,
  "message": "User deleted successfully",
  "data": {
    "uid": "prof_123abc",
    "displayName": "Ahmed Khan",
    "deletedAt": 1705449600000
  }
}
```

**Response (Failure - 404):**
```json
{
  "success": false,
  "message": "User not found"
}
```

**Backend Requirements:**
- [ ] Delete user from database
- [ ] Delete all associated bookings (cascade)
- [ ] Delete all associated transactions (cascade)
- [ ] Delete all associated messages/chats
- [ ] Delete all associated reviews
- [ ] Mark as deleted (soft delete recommended)
- [ ] Return deleted user info
- [ ] Requires valid JWT token
- [ ] Only super_admin can perform this

**Backend Code Example:**
```javascript
router.delete('/admin/users/:uid', authenticateAdmin, async (req, res) => {
  const { uid } = req.params;
  
  try {
    // Start transaction for cascade delete
    const session = await mongoose.startSession();
    session.startTransaction();
    
    // Delete user
    const user = await User.findByIdAndDelete(uid, { session });
    if (!user) {
      await session.abortTransaction();
      return res.status(404).json({ success: false, message: 'User not found' });
    }
    
    // Delete associated data
    await Booking.deleteMany({ $or: [{ customerId: uid }, { professionalId: uid }] }, { session });
    await Transaction.deleteMany({ $or: [{ customerId: uid }, { professionalId: uid }] }, { session });
    await Chat.deleteMany({ $or: [{ user1: uid }, { user2: uid }] }, { session });
    await Review.deleteMany({ professionalId: uid }, { session });
    
    await session.commitTransaction();
    
    res.json({ success: true, message: 'User deleted successfully', data: { uid, displayName: user.displayName } });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});
```

---

## 8. Delete Booking

### Endpoint: DELETE /admin/bookings/{bookingId}
```http
DELETE http://172.28.31.120:5000/api/admin/bookings/book_001 HTTP/1.1
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response (Success - 200):**
```json
{
  "success": true,
  "message": "Booking deleted successfully",
  "data": {
    "bookingId": "book_001",
    "deletedAt": 1705449600000
  }
}
```

**Response (Failure - 404):**
```json
{
  "success": false,
  "message": "Booking not found"
}
```

**Backend Requirements:**
- [ ] Delete booking from database
- [ ] Delete associated transactions (cascade)
- [ ] Refund customer if payment was made
- [ ] Update professional and customer booking counts
- [ ] Mark as deleted (soft delete recommended)
- [ ] Requires valid JWT token
- [ ] Return booking info

---

## 🔐 Authentication Middleware

All admin endpoints must check for valid JWT token:

**Middleware Example (Node.js/Express):**
```javascript
const authenticateAdmin = (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];
  
  if (!token) {
    return res.status(401).json({ success: false, message: 'No token provided' });
  }
  
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    // Verify admin role
    if (decoded.role !== 'admin') {
      return res.status(403).json({ success: false, message: 'Insufficient permissions' });
    }
    
    req.user = decoded;
    next();
  } catch (error) {
    res.status(401).json({ success: false, message: 'Invalid token' });
  }
};
```

---

## 📊 Database Schema Examples

### Admin Collection:
```javascript
{
  _id: ObjectId,
  username: "Huzaifa",
  passwordHash: "bcrypt_hash_...",
  role: "super_admin",
  email: "admin@serviceconnect.pk",
  permissions: ["all"],
  lastLogin: Date,
  createdAt: Date,
  updatedAt: Date
}
```

### Transaction Collection:
```javascript
{
  _id: ObjectId,
  transactionId: "tx_001",
  bookingId: "book_001",
  customerId: "cust_789",
  professionalId: "prof_123",
  type: "payment", // payment, refund, commission_withdrawal
  status: "completed", // pending, completed, failed
  amount: 2500,
  commission: 250,
  professionalEarnings: 2250,
  method: "easypaisa",
  transactionRef: "EP123456",
  metadata: {},
  createdAt: Date,
  updatedAt: Date
}
```

---

## ✅ Implementation Checklist

### Phase 1: Authentication
- [ ] Create Admin model/collection
- [ ] Implement POST /admin/login
- [ ] Generate JWT tokens
- [ ] Store tokens in database (optional)
- [ ] Create authenticateAdmin middleware

### Phase 2: Read Operations
- [ ] Implement GET /admin/stats
- [ ] Implement GET /admin/professionals
- [ ] Implement GET /admin/customers
- [ ] Implement GET /admin/bookings
- [ ] Implement GET /admin/transactions

### Phase 3: Write Operations
- [ ] Implement DELETE /admin/users/{uid}
- [ ] Implement DELETE /admin/bookings/{id}
- [ ] Add cascade delete logic
- [ ] Add transaction rollback support

### Phase 4: Testing
- [ ] Test all endpoints with JWT token
- [ ] Test without token (should fail)
- [ ] Test with invalid token (should fail)
- [ ] Test delete operations
- [ ] Test data accuracy
- [ ] Load test with multiple requests

### Phase 5: Production
- [ ] Set JWT_SECRET in environment variables
- [ ] Enable CORS for frontend domain
- [ ] Add rate limiting
- [ ] Add logging and monitoring
- [ ] Add error tracking (Sentry, etc.)
- [ ] Set up SSL/HTTPS

---

## 🧪 Quick Test Commands

### Using cURL:

**1. Login:**
```bash
curl -X POST http://172.28.31.120:5000/api/admin/login \
  -H "Content-Type: application/json" \
  -d '{"username":"Huzaifa"}'
```

**2. Get Stats (replace TOKEN with actual token):**
```bash
curl -X GET http://172.28.31.120:5000/api/admin/stats \
  -H "Authorization: Bearer TOKEN"
```

**3. Get Professionals:**
```bash
curl -X GET http://172.28.31.120:5000/api/admin/professionals \
  -H "Authorization: Bearer TOKEN"
```

**4. Delete User:**
```bash
curl -X DELETE http://172.28.31.120:5000/api/admin/users/prof_123abc \
  -H "Authorization: Bearer TOKEN"
```

---

## 🚨 Important Notes

1. **Admin Credentials**: Make sure "Huzaifa" is set up as admin username
2. **JWT Secret**: Keep JWT_SECRET secure in environment variables
3. **CORS**: Allow requests from Flutter app (172.28.31.120:3000 or your frontend domain)
4. **Timestamps**: Always return milliseconds (not seconds)
5. **Soft Delete**: Consider soft deletes instead of hard deletes
6. **Transactions**: Use database transactions for cascade deletes
7. **Logging**: Log all admin actions for audit trail
8. **Rate Limiting**: Implement rate limiting on admin endpoints
9. **Monitoring**: Monitor admin endpoints for unusual activity
10. **Backup**: Ensure regular database backups before going live

---

## 📞 Questions?

Refer to ADMIN_PANEL_COMPLETE.md for frontend details
Refer to FIXES_SUMMARY_COMPLETE.md for frontend fixes applied

**All frontend code is ready and waiting for backend implementation!**

