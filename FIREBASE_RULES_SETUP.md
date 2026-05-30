# Firebase RTDB Rules Setup

## Critical: Add These Rules to Firebase Console

Go to Firebase Console → Your Project → Realtime Database → Rules and add `.indexOn` for bookings queries:

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

## Why These Rules Are Important:

1. **Bookings Index**: Allows efficient querying by `customerId` and `professionalId`
2. **Date Index**: Allows sorting by creation time
3. **Read/Write Permissions**: Protects user data while allowing valid queries

## Steps to Apply:

1. Open [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to Realtime Database
4. Click "Rules" tab
5. Replace existing rules with the above JSON
6. Click Publish
7. Restart the app

