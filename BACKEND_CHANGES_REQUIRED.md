# 🔧 BACKEND CHANGES REQUIRED - BID SYSTEM IMPLEMENTATION

## ✅ FRONTEND STATUS: FIXED
The frontend bidding system has been updated with correct status names and flow.

---

## 📋 INFORMATION FOR YOUR BACKEND DEVELOPER

### **STATUS VALUES** (Critical - Must Match Frontend)
Your backend MUST handle these exact status values in this order:

| Status | Meaning | When | Who Sets |
|--------|---------|------|----------|
| `pending_acceptance` | Customer sent bid, waiting for professional response | After customer sends bid | Front-end → Firebase |
| `pending_payment` | Professional accepted, waiting for customer EasyPaisa payment | After professional accepts | Backend accepting endpoint |
| `confirmed` | Payment verified, both parties confirmed | After payment verified | Backend payment endpoint |
| `in_progress` | Professional started work | When professional clicks "Start Job" | Professional clicks button |
| `completed` | Work finished, ready for rating | When professional completes | Professional marks complete |
| `cancelled` | Either party cancelled | On cancellation | Either party cancels |

---

## 🎯 API ENDPOINTS NEEDING UPDATES

### 1. **POST /api/bookings/{bookingId}/accept** (Professional accepts bid)
**Current Issue:** Backend might be setting wrong status

**What it should do:**
```javascript
// When professional accepts a booking
{
  // 1. Validate booking exists and status is "pending_acceptance"
  if (booking.status !== "pending_acceptance") {
    return { success: false, message: "Booking not in pending state" };
  }

  // 2. Deduct 10% commission from professional's wallet
  const commission = booking.agreedPrice * 0.10;
  professional.walletBalance -= commission;

  // 3. Update booking status to "pending_payment" (NOT "confirmed")
  booking.status = "pending_payment";
  booking.acceptedAt = new Date();
  booking.acceptedBy = professionalId;

  // 4. Record transaction
  createTransaction({
    type: "commission_deduction",
    amount: commission,
    professionalId: professionalId,
    bookingId: bookingId
  });

  // 5. Send notification to customer
  notifyCustomer(booking.customerId, {
    type: "bid_accepted",
    message: `Professional accepted your bid. Please make payment.`,
    bookingId: bookingId
  });

  return {
    success: true,
    data: {
      id: bookingId,
      status: "pending_payment",  // ← THIS IS KEY
      professionalEarnings: 0.9 * booking.agreedPrice
    }
  };
}
```

### 2. **POST /api/bookings/{bookingId}/confirm-payment** (Customer pays)
**Current Issue:** Backend might not handle the flow correctly

**What it should do:**
```javascript
// When customer confirms payment
{
  // 1. Validate booking is in "pending_payment" state
  if (booking.status !== "pending_payment") {
    return { success: false, message: "Booking not waiting for payment" };
  }

  // 2. Verify transaction ID format and possibly screenshot
  // (Your OCR/manual verification logic)

  // 3. Update customer's transaction
  booking.paymentStatus = "confirmed";
  booking.status = "confirmed";  // ← NOW it moves to confirmed
  booking.paidAt = new Date();
  booking.transactionId = transactionId;

  // 4. Create chat room
  createChatRoom({
    user1: booking.customerId,
    user2: booking.professionalId,
    bookingId: bookingId
  });

  // 5. Unlock phone number
  // (Make professional's phone visible to customer and vice versa)
  
  return {
    success: true,
    data: {
      id: bookingId,
      status: "confirmed",
      paymentConfirmed: true,
      phoneNumberRevealed: true,
      chatRoomCreated: true
    }
  };
}
```

### 3. **GET /api/bookings/my-bookings** (Multiple statuses)
**What it should return:**
```javascript
{
  success: true,
  data: {
    bookings: [
      {
        id: "booking_123",
        status: "pending_acceptance",  // Still waiting for professional
        customerId: "customer_uid",
        professionalId: "prof_uid",
        agreedPrice: 5000,
        proposedPrice: 5000,  // Can be same
        createdAt: "2026-05-18T10:00:00Z"
      },
      {
        id: "booking_124",
        status: "pending_payment",    // Professional accepted, waiting for customer to pay
        customerId: "customer_uid",
        professionalId: "prof_uid",
        agreedPrice: 5000,
        acceptedAt: "2026-05-18T10:30:00Z"
      },
      {
        id: "booking_125",
        status: "confirmed",          // Payment done, Work ready to start
        customerId: "customer_uid",
        professionalId: "prof_uid",
        agreedPrice: 5000,
        paidAt: "2026-05-18T11:00:00Z",
        transactionId: "EasyPaisa_123"
      }
    ]
  }
}
```

---

## 🔄 COMPLETE BID FLOW (Backend Perspective)

```
1. CUSTOMER CREATES BID
   POST /api/bookings
   └─→ Backend creates booking with status: "pending_acceptance"
   └─→ Firebase gets same document
   └─→ Professional sees it in "My Bookings"

2. PROFESSIONAL RESPONDS
   POST /api/bookings/{id}/accept
   └─→ Backend deducts 10% commission from wallet
   └─→ Status changes: "pending_acceptance" → "pending_payment"
   └─→ Notification sent to customer
   └─→ Frontend shows "Awaiting Payment"

3. CUSTOMER PAYS
   POST /api/bookings/{id}/confirm-payment
   └─→ Backend verifies transaction ID / screenshot
   └─→ Customer's payment recorded in DB
   └─→ Status changes: "pending_payment" → "confirmed"
   └─→ Chat room created
   └─→ Phone numbers revealed
   └─→ Frontend unlocks chat + payment button changes to "Start Job"

4. PROFESSIONAL STARTS WORK
   POST /api/bookings/{id}/start  (or manual update)
   └─→ Status: "confirmed" → "in_progress"
   └─→ Timer/clock can start

5. PROFESSIONAL COMPLETES
   POST /api/bookings/{id}/complete
   └─→ Status: "in_progress" → "completed"
   └─→ Customer can now rate/review

6. CUSTOMER RATES
   POST /api/bookings/{id}/rate
   └─→ Updates professional's average rating
   └─→ Reviews stored
```

---

## 💳 PAYMENT/COMMISSION LOGIC

### When Professional **ACCEPTS** Bid:
```
Customer Bid Amount:        Rs. 5,000
Platform Commission (10%):  Rs. 500   ← Deducted from professional's wallet
Professional Receives:      Rs. 4,500 ← What professional will get after customer pays
```

### When Customer **PAYS**:
```
Professional already paid:  Rs. 500 (commission deducted during acceptance)
Now system owes professional: Rs. 4,500 (calculated on payment confirmation)
Total transaction chain should show both movements
```

---

## 🧪 TESTING YOUR BACKEND

### Step 1: Accept Booking Response
```bash
curl -X POST http://localhost:5000/api/bookings/booking_123/accept \
  -H "Authorization: Bearer your_token" \
  -H "Content-Type: application/json"

# Expected Response:
{
  "success": true,
  "data": {
    "id": "booking_123",
    "status": "pending_payment",  # ← Key: Must be this, not "confirmed"
    "professionalEarnings": 4500
  }
}
```

### Step 2: Confirm Payment
```bash
curl -X POST http://localhost:5000/api/bookings/booking_123/confirm-payment \
  -H "Authorization: Bearer your_token" \
  -H "Content-Type: application/json" \
  -d '{
    "transactionId": "easypisa_xyz123",
    "screenshotUrl": "https://s3.../screenshot.jpg"
  }'

# Expected Response:
{
  "success": true,
  "data": {
    "id": "booking_123",
    "status": "confirmed",  # ← Key: Only now confirmed
    "paymentConfirmed": true,
    "phoneNumberRevealed": true
  }
}
```

---

## ⚠️ CRITICAL: DO NOT DO THIS

❌ **WRONG:**
```javascript
// When professional accepts
booking.status = "confirmed";  // ❌ Wrong!
```

✅ **RIGHT:**
```javascript
// When professional accepts
booking.status = "pending_payment";  // ✅ Correct!

// Only after customer confirms payment:
booking.status = "confirmed";  // ✅ Now correct!
```

---

## 📝 CHECKLIST FOR YOUR BACKEND DEV

- [ ] Update `/api/bookings/{id}/accept` to set status to `pending_payment` (not `confirmed`)
- [ ] Update `/api/bookings/{id}/confirm-payment` to set status to `confirmed`
- [ ] Add wallet deduction logic in accept endpoint
- [ ] Add transaction recording for commission deducted
- [ ] Ensure all status values match exactly (case-sensitive)
- [ ] Test the complete flow: accept → pending_payment → confirm payment → confirmed
- [ ] Add notifications/emails at each stage
- [ ] Test that customers can't pay if booking not in "pending_payment" status
- [ ] Test that professionals can't accept if booking not in "pending_acceptance" status

---

## 🔗 RELATIONSHIP TO FRONTEND

**Frontend expects these status changes:**

When Frontend sees status... | Frontend shows...
--------------------------- | ----------------
`pending_acceptance` | "Awaiting Professional Response" (for customer) OR pending bid (for professional)
`pending_payment` | "Waiting for Your Payment" (for customer) OR "Waiting for Customer Payment" (professional)
`confirmed` | "Ready to Start" / "In Queue"
`in_progress` | "Job in Progress"
`completed` | "Completed - Rate Professional"
`cancelled` | "Bid Cancelled"

---

## ✅ SUMMARY

**Key Point:** The booking status flow MUST be:
```
pending_acceptance → pending_payment → confirmed → in_progress → completed
       ↓                    ↓
   Professional    Customer pays
   accepts         EasyPaisa
```

**Your backend MUST implement this exact flow for the frontend to work correctly.**

Any deviation will cause:
- Professional bids not showing
- Payment screens not appearing
- Status mismatches
- Chat not unlocking after payment

---

*Last Updated: May 19, 2026*
*Frontend Status: ✅ READY*
*Waiting on: Backend updates to confirm status flow*

