# Admin Panel - Complete Implementation Guide

## Frontend Implementation Status ✅

### Admin Features Implemented:
1. **Admin Login Screen** - Beautiful dark-themed login with admin username "Huzaifa"
2. **Admin Dashboard** - Full-featured admin console with 5 major tabs:
   - **Stats Tab**: Real-time marketplace performance metrics
   - **Professionals Tab**: List of all professionals with delete functionality
   - **Customers Tab**: List of all customers with delete functionality
   - **Bookings Tab**: All bookings with status tracking and delete functionality
   - **Transactions Tab**: All financial transactions with commission breakdown

### Key Frontend Features:
✅ Admin login with username validation (e.g., "Huzaifa")
✅ Token-based authentication (JWT)
✅ Real-time data fetching
✅ Full CRUD operations (Delete professionals, customers, bookings)
✅ Commission tracking (10% auto-deduction)
✅ Dark theme UI with modern design
✅ Responsive layout
✅ Error handling & loading states
✅ Logout functionality

---

## Backend Requirements 🔧

The frontend will make HTTP requests to the following endpoints. **You must implement these on the backend:**

### 1. **Admin Login Endpoint**
```
POST /admin/login
Request: { "username": "Huzaifa" }
Response: { 
  "success": true, 
  "data": { "token": "JWT_TOKEN_HERE" },
  "message": "Login successful"
}
```
**Requirements:**
- Validate username against hardcoded admin credentials
- Generate JWT token valid for extended period
- Return token in response

---

### 2. **Admin Stats Endpoint**
```
GET /admin/stats
Headers: Authorization: Bearer JWT_TOKEN
Response: {
  "success": true,
  "data": {
    "totalProfessionals": 45,
    "totalCustomers": 127,
    "totalCompletedJobs": 892,
    "totalCommission": 89200,
    "totalRevenue": 892000
  }
}
```
**Requirements:**
- Count all professionals in database
- Count all customers in database
- Count completed bookings
- Sum all commission amounts (10% of completed transactions)
- Requires authentication

---

### 3. **Get All Professionals Endpoint**
```
GET /admin/professionals
Headers: Authorization: Bearer JWT_TOKEN
Response: {
  "success": true,
  "data": [
    {
      "uid": "prof_123",
      "displayName": "Ahmed Khan",
      "email": "ahmed@example.com",
      "phoneNumber": "03001234567",
      "serviceTypes": ["electrician", "plumber"],
      "rating": 4.8,
      "totalJobs": 156,
      "wallet": 45000,
      "status": "active"
    }
  ]
}
```
**Requirements:**
- Return all professionals
- Include serviceTypes as array
- Include rating and totalJobs count
- Requires authentication

---

### 4. **Get All Customers Endpoint**
```
GET /admin/customers
Headers: Authorization: Bearer JWT_TOKEN
Response: {
  "success": true,
  "data": [
    {
      "uid": "cust_456",
      "displayName": "Fatima Ali",
      "email": "fatima@example.com",
      "phoneNumber": "03005678901",
      "totalBookings": 12,
      "totalSpent": 125000,
      "status": "active"
    }
  ]
}
```
**Requirements:**
- Return all customers
- Include totalBookings count
- Include totalSpent amount
- Requires authentication

---

### 5. **Get All Bookings Endpoint**
```
GET /admin/bookings
Headers: Authorization: Bearer JWT_TOKEN
Response: {
  "success": true,
  "data": [
    {
      "bookingId": "book_789",
      "id": "book_789",
      "customerName": "Fatima Ali",
      "professionalName": "Ahmed Khan",
      "serviceType": "electrical",
      "status": "completed",
      "agreedPrice": 2500,
      "proposedPrice": 2000,
      "createdAt": 1705276800000,
      "updatedAt": 1705363200000
    }
  ]
}
```
**Requirements:**
- Return all bookings
- Include customer and professional names
- Include timestamps in milliseconds
- Include status field
- Requires authentication

---

### 6. **Get All Transactions Endpoint**
```
GET /admin/transactions
Headers: Authorization: Bearer JWT_TOKEN
Response: {
  "success": true,
  "data": [
    {
      "transactionId": "tx_123",
      "bookingId": "book_789",
      "professionalName": "Ahmed Khan",
      "amount": 2500,
      "commission": 250,
      "type": "payment",
      "status": "completed",
      "createdAt": 1705363200000
    }
  ]
}
```
**Requirements:**
- Return all transactions
- Include commission amount (10% of transaction)
- Include timestamps in milliseconds
- Requires authentication

---

### 7. **Delete User Endpoint**
```
DELETE /admin/users/{uid}
Headers: Authorization: Bearer JWT_TOKEN
Response: {
  "success": true,
  "message": "User deleted successfully",
  "data": {
    "uid": "prof_123",
    "name": "Ahmed Khan"
  }
}
```
**Requirements:**
- Delete user by UID
- Also delete associated bookings, transactions, and data
- Return 200 on success
- Requires authentication

---

### 8. **Delete Booking Endpoint**
```
DELETE /admin/bookings/{bookingId}
Headers: Authorization: Bearer JWT_TOKEN
Response: {
  "success": true,
  "message": "Booking deleted successfully",
  "data": {
    "bookingId": "book_789"
  }
}
```
**Requirements:**
- Delete booking by ID
- Also delete associated transactions/payments
- Return 200 on success
- Requires authentication

---

## Database Schema Recommendations

### Admin Collection/Table:
```
{
  id: "admin_huzaifa",
  username: "Huzaifa",
  passwordHash: "bcrypt_hash_here",
  role: "super_admin",
  email: "admin@serviceconnect.pk",
  createdAt: timestamp,
  permissions: ["all"]
}
```

### Transaction Collection (for commission tracking):
```
{
  transactionId: unique_id,
  bookingId: reference,
  amount: number,
  commission: number (10% of amount),
  type: "payment" | "refund" | "commission_withdrawal",
  status: "pending" | "completed" | "failed",
  metadata: {...},
  createdAt: timestamp,
  updatedAt: timestamp
}
```

---

## Authentication Flow

1. **Admin enters username "Huzaifa"** on login screen
2. **Frontend sends POST /admin/login** with username
3. **Backend validates credentials** and returns JWT token
4. **Frontend stores token** in SharedPreferences (persistent)
5. **All subsequent admin requests** include: `Authorization: Bearer TOKEN`
6. **Backend validates token** on every request
7. **Logout clears token** from storage and local state

---

## Error Handling

Frontend expects these error responses:

```json
{
  "success": false,
  "message": "Invalid admin credentials",
  "errorCode": 401
}
```

Common error codes backend should return:
- `401`: Unauthorized (invalid token or credentials)
- `403`: Forbidden (insufficient permissions)
- `404`: Not found
- `500`: Server error

---

## Testing Checklist

### Backend Tests Required:
- [ ] Admin login works with "Huzaifa"
- [ ] JWT token generated and stored
- [ ] All endpoints require valid token
- [ ] Stats endpoint returns correct counts
- [ ] Professionals list returns all users with role='professional'
- [ ] Customers list returns all users with role='customer'
- [ ] Bookings list returns all bookings with statuses
- [ ] Transactions list calculates 10% commission correctly
- [ ] Delete user removes all related data (cascade)
- [ ] Delete booking removes associated transactions
- [ ] All timestamps are in milliseconds (JavaScript format)

### Frontend Tests (Already Done):
- ✅ Admin login UI
- ✅ Admin dashboard tabs
- ✅ Data display and formatting
- ✅ Delete confirmations
- ✅ Error messages
- ✅ Loading states
- ✅ Logout functionality

---

## API Constants (Frontend Already Configured)

The frontend expects the API to be at: **http://172.28.31.120:5000/api**

Admin endpoints base path: `/admin`

All endpoints support:
- Bearer token authentication
- JSON request/response
- CORS headers

---

## Commission System Details

The admin panel displays a **10% commission structure**:
- **Customer pays**: Full amount (e.g., 2500 PKR)
- **Commission deducted**: 10% (e.g., 250 PKR)
- **Professional receives**: 90% (e.g., 2250 PKR)

This is tracked in the Transactions tab and displayed in the Stats dashboard.

---

## Next Steps for Backend Implementation

1. **Create Admin table** with credentials
2. **Generate JWT secret key** for token signing
3. **Implement /admin/login** endpoint
4. **Implement auth middleware** to validate JWT
5. **Implement all GET endpoints** (stats, professionals, customers, bookings, transactions)
6. **Implement DELETE endpoints** with cascade delete logic
7. **Add error handling** for all endpoints
8. **Test all endpoints** with the frontend
9. **Deploy to production**

---

## Security Recommendations

1. ✅ **Hash admin passwords** using bcrypt (not plain text)
2. ✅ **Use HTTPS** in production
3. ✅ **Set JWT expiration** (e.g., 24 hours)
4. ✅ **Implement rate limiting** on login endpoint
5. ✅ **Log all admin activities** for audit trail
6. ✅ **Validate all inputs** on backend
7. ✅ **Use CORS** to restrict origins
8. ✅ **Add admin IP whitelist** (optional)

---

## Frontend Code Structure

```
lib/
├── screens/
│   ├── admin_login_screen.dart          ← Admin login form
│   └── admin_dashboard.dart             ← Main admin panel
├── providers/
│   └── admin_provider.dart              ← State management
└── services/
    └── api_service.dart                 ← API calls to backend
```

All admin endpoints are already integrated in `ApiService` class.

---

## Additional Notes

- The admin panel is **completely separate** from the regular user authentication
- Admin login uses **username-only** (no password field for simplicity)
- All data is **read-only display + delete capability**
- The panel supports **real-time updates** if backend implements polling/WebSockets
- **Commission tracking is automatic** on transaction creation
- **Soft delete** is recommended (mark as deleted instead of true delete) for data integrity

---

**Status**: ✅ Frontend Complete | ⏳ Awaiting Backend Implementation

For any frontend issues or changes, refer to admin_dashboard.dart and admin_provider.dart files.

