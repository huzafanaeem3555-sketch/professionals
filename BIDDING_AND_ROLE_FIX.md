# ✅ BIDDING SYSTEM & ROLE SWITCHING FIX - COMPLETE GUIDE

## 🔴 CRITICAL: Firebase RTDB Rules Configuration

Your app error shows: `Index not defined, add ".indexOn": "professionalId"...`

### ��� STEP 1: Update Firebase RTDB Rules (DO THIS FIRST!)

1. Open [Firebase Console](https://console.firebase.google.com)
2. Select your project: **serviceconnect-dea35**
3. Go to **Realtime Database** → **Rules** tab
4. Replace ALL existing rules with this:

```json
{
  "rules": {
    "users": {
      "$uid": {
        ".read": "auth.uid == $uid || auth.uid != null",
        ".write": "auth.uid == $uid"
      }
    },
    "bookings": {
      ".indexOn": ["customerId", "professionalId", "_createdAt"],
      "$bookingId": {
        ".read": "root.child('users').child(auth.uid).exists()",
        ".write": "data.child('customerId').val() == auth.uid || data.child('professionalId').val() == auth.uid"
      }
    },
    "professionals": {
      "$uid": {
        ".read": "auth.uid != null",
        ".write": "auth.uid == $uid"
      }
    },
    "chat": {
      ".read": "auth.uid != null",
      ".write": "auth.uid != null"
    }
  }
}
```

5. Click **PUBLISH**
6. Wait for deployment (30 seconds)

---

## 🎯 What This Does

| Rule | Purpose |
|------|---------|
| `.indexOn: ["customerId", "professionalId", "_createdAt"]` | ✅ Fixes the error! Allows efficient queries by field |
| `customerId` | Customers see their own bids |
| `professionalId` | Professionals see bids sent TO them |
| `_createdAt` | Sort bids by time (newest first) |

---

## 🔄 BIDDING FLOW (Now Fixed)

### Customer Side:
1. ✅ Sees professionals list
2. ✅ Sends bid/booking request to professional
3. ✅ Sees "Pending Approval" status
4. ✅ When professional accepts → "Pending Payment"
5. ✅ Uploads payment screenshot
6. ✅ Payment confirmed → Chat unlock + Phone reveal

### Professional Side:
1. ✅ Receives bid notification (pending_approval status)
2. ✅ Sees bid with deduction details:
   - Total Bid: Rs. 5,000
   - Platform Commission: Rs. 500 (10%)
   - You Earn: Rs. 4,500 (90%)
3. ✅ Accept/Reject bid
4. ✅ Wait for customer payment
5. ✅ Start job when payment confirmed

---

## ♻️ ROLE SWITCHING (Now Enabled)

### Before:
❌ User locked into one role after selection

### After:
✅ Users can switch roles anytime:
- From Profile Screen → "Switch Role" button
- Or just select different role in role selection screen
- Both customer and professional data persists

---

## 📝 CODE CHANGES MADE

### 1. **AuthProvider** - Added `switchRole()` method
```dart
Future<bool> switchRole(String newRole) async {
  // Updates both Firebase RTDB and in-memory state
  // Allows user to become customer or professional anytime
}
```

### 2. **BookingProvider** - Added bid management methods
```dart
// Get all bids sent TO a professional
await bookingProvider.getPendingBidsForProfessional(professionalId);

// Get all bids sent BY a customer  
await bookingProvider.getBidsForCustomer(customerId);

// Calculate price breakdown with commission
final breakdown = BookingProvider.getPriceBreakdown(agreedPrice);
// Returns: {totalPrice, commission, professionalEarnings}
```

### 3. **Role Selection Screen** - Updated messaging
Changed from: "You can only select one role. Choose carefully."
To: "You can switch roles anytime from your profile."

---

## 🧪 TESTING CHECKLIST

After applying Firebase rules, test these scenarios:

### Scenario 1: Customer Sends Bid
- [ ] Log in as Customer (Role A)
- [ ] Find professional
- [ ] Send booking/bid
- [ ] Check "My Bookings" shows it
- [ ] Status should be "pending_approval"

### Scenario 2: Professional Receives Bid
- [ ] (Optional) Sign in as different account
- [ ] Set role to Professional (Role B)  
- [ ] Go to "My Bookings" / Pending Bids
- [ ] Should see YOUR bids (not others')
- [ ] Can see commission breakdown:
  ```
  Bid Price: 5000
  Platform Fee: 500 (10%)
  Your Earnings: 4500 (90%)
  ```

### Scenario 3: Role Switching
- [ ] Profile → Switch Role (Customer → Professional)
- [ ] Confirm both roles' data loads correctly
- [ ] Switch back (Professional → Customer)
- [ ] Previous data persists

### Scenario 4: Accept/Reject/Payment Flow
- [ ] Professional accepts bid
- [ ] Customer gets "Pending Payment" status
- [ ] Customer uploads EasyPaisa screenshot
- [ ] Payment confirmed
- [ ] Phone revealed + Chat enabled

---

## 🆘 Troubleshooting

| Issue | Solution |
|-------|----------|
| "Index not defined" error | ✅ You probably missed step 1 - update Firebase rules and wait 30 seconds |
| Professional not seeing bids | ✅ Rules not published yet, or cache refresh needed. Go to app → Pull to refresh |
| Role switch doesn't work | ✅ Ensure user is not guest. Must be logged in with Google Sign-In |
| Both sides not seeing correct data | ✅ Check that `customerId` and `professionalId` fields match in bookings |

---

## 💡 Architecture Overview

```
Customer                Firebase RTDB               Professional
  │                         │                            │
  ├─→ Send Bid ───────→ bookings/{id}  ←────────── Check Pending
  │   (customerId)         │                   (professionalId)
  │                   STATUS: pending_approval
  │                        │
  │←───── Accept Bid ─←─ professionalId confirmed
  │                   STATUS: pending_payment
  │
  ├─→ Upload Screenshot ──→ payments/{id}
  │                        │
  │                        ├─→ Verify OCR/Manual
  │                        │
  ├─→ Confirm Payment ───→ STATUS: confirmed
  │                        │
  │←── Chat Unlocked ──←── Chat room created
  │←── Phone Revealed ──←────── /users/{id}/phoneNumber
  │
  ├─→ Start Job ─────→ STATUS: in_progress
  │
  ├─→ Rate Job ─────→ Professional Rating++
  └─→ Complete ────→ STATUS: completed
```

---

## 📱 Next Steps

1. ✅ Update Firebase Rules (CRITICAL)
2. ✅ Restart the app (clear cache if needed)
3. ✅ Test with the checklist above
4. ✅ Monitor app logs for any errors
5. Report any issues

---

**After Firebase rules are set, the error should disappear and bidding/role switching will work properly! 🚀**

