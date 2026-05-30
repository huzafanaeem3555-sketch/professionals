# 🔄 Authentication Flow Diagram

## Complete Flow Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        FRESH INSTALL / FIRST RUN                            │
└─────────────────────────────────────────────────────────────────────────────┘

                                    [START]
                                      │
                    ┌─────────────────┴─────────────────┐
                    │   App Initialization              │
                    │   - Firebase init                 │
                    │   - AuthProvider created          │
                    └─────────────────┬─────────────────┘
                                      │
                    ┌─────────────────▼─────────────────┐
                    │   AuthProvider._initializeAsync  │
                    │   - Load token from storage       │
                    │   - Restore session (if token)    │
                    │   - Status = unauthenticated      │
                    └─────────────────┬─────────────────┘
                                      │
                    ┌─────────────────▼─────────────────┐
                    │   [SplashScreen] (2.5 sec)       │
                    │   - Animations                    │
                    │   - Wait for auth init            │
                    └─────────────────┬─────────────────┘
                                      │
                    ┌─────────────────▼─────────────────┐
                    │   _navigate()                     │
                    │   Check: auth.status?             │
                    └────┬──────────────────────┬────────┘
                         │                      │
         Status=auth      │                      │      Status=unauthenticated
         ┌────────────────┘                      └────────────────┐
         │                                                         │
         └──────────────────────────────────────────────────────>>│
                                                                  │
                                            ┌─────────────────────▼──────┐
                                            │   [Login Screen]           │
                                            │   - Sign In tab            │
                                            │   - Sign Up tab            │
                                            │   - Google Sign-In button  │
                                            └─────────────────────┬──────┘
                                                                  │
                                    ┌─────────────────────────────┼──────────────┐
                                    │                    │                │
                    ┌───────────────▼──┐    ┌────────────▼───┐  ┌────────▼───┐
                    │ Google Sign-In   │    │ Email Sign-Up  │  │Email Sign-In
                    │ - Open Google    │    │ - Validate     │  │ - Validate
                    │ - Get ID token   │    │ - Backend call │  │ - Backend call
                    └────────┬─────────┘    └────────┬────────┘  └────────┬────┘
                             │                       │                    │
        ┌────────────────────┼───────────────────────┼────────────────────┐
        │    Each signin calls _navigateAfterLoginAsync()                  │
        │    └─ Fetch role from backend (GET /api/auth/me)                │
        │    └─ Check: role exists?                                       │
        └────┬───────────────────────────────────────────────────────┬────┘
             │                                                        │
      Role exists                                              Role not set
             │                                                        │
      ┌──────▼──────────┐                                   ┌────────▼──────┐
      │ Navigate to     │                                   │ [Role         │
      │ /customer-home  │                                   │  Selection]   │
      │ or             │                                   │ - Customer    │
      │ /professional  │                                   │ - Professional│
      │ -home          │                                   └────────┬──────┘
      └─────────────────┘                                           │
                                                     ┌───────────────▼─────┐
                                                     │  selectRole(role)   │
                                                     │  - Backend update   │
                                                     │  - setRole()        │
                                                     └───────────┬─────────┘
                                                                 │
                                                     ┌───────────▼─────────┐
                                                     │ Navigate to         │
                                                     │ /customer-home      │
                                                     │ or                  │
                                                     │ /professional-home  │
                                                     └─────────────────────┘
```

---

## Cold Start (Returning User)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        APP RESTART (RETURNING USER)                          │
└─────────────────────────────────────────────────────────────────────────────┘

                                    [START]
                                      │
                    ┌─────────────────┴─────────────────┐
                    │   App Initialization              │
                    │   - Firebase init                 │
                    │   - AuthProvider created          │
                    └─────────────────┬─────────────────┘
                                      │
                    ┌─────────────────▼─────────────────┐
                    │  AuthProvider._initializeAsync()  │
                    │  (runs in background)             │
                    └─────────────────┬─────────────────┘
                                      │
        ┌─────────────────────────────┼─────────────────────────────┐
        │                             │                             │
   ┌────▼────────────────────┐   ┌────▼────────────────┐    [Splash Screen]
   │ _api.initializeToken()  │   │ restoreSession()    │   (2.5 sec anim)
   │                         │   │                     │
   │ SharedPrefs.getString   │   │ ├─ Get token        │
   │ ('backend_auth_token')  │   │ ├─ GET /api/auth/me │
   │                         │   │ ├─ Parse response   │
   │ _backendToken = token   │   │ ├─ _user = data     │
   │                         │   │ ├─ _status = auth   │
   │ ✅ Token: abc123...     │   │ └─ return true      │
   └────┬────────────────────┘   └────┬────────────────┘
        │                             │
        └─────────────────┬───────────┘
                          │
                    ┌─────▼──────────┐
                    │ Status = auth  │
                    │ User loaded    │
                    │ Role = 'cust'  │
                    └─────┬──────────┘
                          │
                    After 2.5 sec
                          │
                    ┌─────▼──────────────────┐
                    │ _navigate()            │
                    │ Check status? = auth   │
                    └─────┬──────────────────┘
                          │
               ┌──────────┼──────────┐
               │                     │
          Has role?             No role?
               │                     │
          YES ├──▼──────────┐   ┌────▼─────────┐
              │ Check role  │   │     [Role    │
              └──┬──────────┘   │   Selection] │
                 │               └──────────────┘
        ┌────────┘
        │
    ┌───▼───────────┐
    │ Role = cust   │
    │ Role = prof   │
    └───┬────┬──────┘
        │    │
    ┌───▼┐  ┌▼──────────────┐
    │Cust│  │Professional   │
    │Home│  │Home           │
    └────┘  └───────────────┘

Duration: 2.5 seconds (including animation)
Network calls: 1 (GET /api/auth/me - runs in background)
User sees: Beautiful splash screen, then straight to app
Result: Seamless cold start! ✨
```

---

## Token Lifecycle

```
┌─────────────────────────────────────────────────────────────────┐
│                      TOKEN LIFECYCLE                            │
└─────────────────────────────────────────────────────────────────┘

1. LOGIN
   ┌──────────────────────────────┐
   │ POST /api/auth/signin        │
   │ POST /api/auth/signup        │
   │ POST /api/auth/google        │
   └───────────────┬──────────────┘
                   │
   ┌───────────────▼──────────────┐
   │ Response:                    │
   │ {                            │
   │   success: true,             │
   │   data: {                    │
   │     user: {...},             │
   │     token: 'eyJ...'  ◄──────┐│
   │   }                          ││
   │ }                            ││
   └───────────────┬──────────────┘│
                   │               │
                   └───────────────┘
                       │
   ┌───────────────────▼──────────────────┐
   │ setBackendToken(token)               │
   │ ├─ _backendToken = token (memory)    │
   │ └─ SharedPrefs.setString(token)      │
   └───────────────────┬──────────────────┘
                       │
                   ┌───┴────────────────────────────────┐
                   │ Token now stored & in memory       │
                   │ Ready for API calls                │
                   └───┬────────────────────────────────┘
                       │


2. API REQUESTS (All Protected Endpoints)
   ┌────────────────────────────────────┐
   │ _api.someProtectedMethod()         │
   │ (e.g., getMe(), setRole(), etc.)   │
   └───────────────┬────────────────────┘
                   │
   ┌───────────────▼────────────────────┐
   │ _authOptions()                     │
   │ ├─ getCurrentToken()               │
   │ │  ├─ Check _backendToken (mem)    │
   │ │  ├─ Check SharedPrefs storage    │
   │ │  └─ Return token if found        │
   │ └─ Create Options with header:     │
   │    Authorization: Bearer <token>   │
   └───────────────┬────────────────────┘
                   │
   ┌───────────────▼────────────────────┐
   │ Dio.get/post/delete(options)       │
   │ Headers: {                         │
   │   'Authorization': 'Bearer abc...' │
   │   'Content-Type': 'application...  │
   │ }                                  │
   └───────────────┬────────────────────┘
                   │
   ┌───────────────▼────────────────────┐
   │ Backend validates token            │
   │ ├─ Check Firebase ID token         │
   │ ├─ Check user exists               │
   │ └─ Return user data                │
   └────────────────────────────────────┘


3. LOGOUT
   ┌──────────────────────────────┐
   │ logout() / signOut()         │
   └───────────────┬──────────────┘
                   │
   ┌───────────────▼──────────────┐
   │ _authService.signOut()       │
   │ └─ Firebase logout           │
   └───────────────┬──────────────┘
                   │
   ┌───────────────▼──────────────┐
   │ _api.clearToken()            │
   │ ├─ _backendToken = null      │
   │ └─ SharedPrefs.remove(token) │
   └───────────────┬──────────────┘
                   │
   ┌───────────────▼──────────────┐
   │ Token fully removed          │
   │ ├─ Not in memory             │
   │ ├─ Not in storage            │
   │ └─ Not in Firebase           │
   └───────────────┬──────────────┘
                   │
   ┌───────────────▼──────────────┐
   │ User logged out ✓            │
   │ Next request will fail 401   │
   │ User redirected to login     │
   └──────────────────────────────┘
```

---

## Request Flow (All Methods)

```
┌─────────────────────────────────────────────────────────┐
│        ANY PROTECTED ENDPOINT (e.g., setRole())         │
└─────────────────────────────────────────────────────────┘

 User Code                    ApiService                 Backend
   │                              │                          │
   │    setRole('customer')       │                          │
   ├─────────────────────────────>│                          │
   │                              │                          │
   │                    _authOptions()                       │
   │                    └─ getToken()                        │
   │                       ├─ Check memory                   │
   │                       ├─ Check storage                  │
   │                       └─ Return 'abc123...'             │
   │                              │                          │
   │                         POST /api/auth/set-role         │
   │                         Headers:                        │
   │                         Authorization: Bearer abc123... │
   │                         Body: {role: 'customer'}        │
   │                    ├────────────────────────────────────>│
   │                              │    ┌── Validate token   │
   │                              │    ├─ Check user uid    │
   │                              │    └─ Update DB         │
   │                              │<────────────────────────┤
   │                    200 OK                               │
   │                    {success: true, data: {...}}        │
   │<─────────────────────────────┤                         │
   │                              │
   Role set ✓
   
Duration: ~300-500ms (backend dependent)
Success: User role updated on server
Error: 401 → Redirect to login (token invalid)
```

---

## Session Restore Sequence (Cold Start)

```
APP START
  │
  ├─ [1] Firebase.initializeApp()
  │
  ├─ [2] AuthProvider()
  │   └─ _initializeAsync() [ASYNC - fires immediately, runs in background]
  │       │
  │       ├─ [3] _api.initializeToken()
  │       │   └─ SharedPrefs.getString('backend_auth_token')
  │       │       Result: 'eyJ...' or null
  │       │
  │       ├─ [4] restoreSession()
  │       │   └─ _api.getCurrentToken()
  │       │       └─ Returns stored token
  │       │
  │       ├─ [5] _api.getMe() [Network call]
  │       │   ├─ GET /api/auth/me
  │       │   └─ Headers: Authorization: Bearer eyJ...
  │       │
  │       ├─ [6] Parse response
  │       │   ├─ Success? → Load user → status = authenticated
  │       │   └─ Failed? → Clear token → status = unauthenticated
  │       │
  │       └─ [7] notifyListeners() [State updated]
  │
  ├─ [8] SplashScreen created & displayed
  │   └─ Start 2.5 sec animation
  │
  ├─ [9] After 2.5 sec: _navigate()
  │   └─ Check auth.status
  │       ├─ authenticated + has role → Navigate to home
  │       ├─ authenticated + no role → Navigate to role selection
  │       └─ unauthenticated → Navigate to login
  │
  └─ Done!

TIMELINE:
T=0ms    │ App starts
T=0ms    │ Firebase init
T=0ms    │ AuthProvider created, async restoration starts
T=1-2ms  │ Token loaded from storage
T=10-20ms│ Network request to /api/auth/me starts
T=100-200ms  │ Network response received, user loaded
T=200ms  │ SplashScreen displayed
T=2500ms │ Animation done, navigation logic runs
T=2500ms │ User sees home screen (or login/role selection)

Result: Seamless, fast, transparent to user ✨
```

---

## Error Handling

```
┌──────────────────────────────────────────────────┐
│          ERROR SCENARIOS & RESOLUTION            │
└──────────────────────────────────────────────────┘

SCENARIO 1: Token Expired / Invalid
  │
  ├─ API request with stored token
  ├─ Backend returns: 401 Unauthorized
  ├─ _handleError() catches exception
  │
  ├─ Clear invalid token
  │  └─ _api.clearToken()
  │     └─ SharedPrefs.remove('backend_auth_token')
  │
  └─ User redirected to login
     └─ Next _api call will fail gracefully


SCENARIO 2: Network Down During SessionRestore
  │
  ├─ restoreSession()
  ├─ _api.getMe() → Network timeout
  ├─ Exception caught
  │
  ├─ _status = unauthenticated
  └─ User sees login screen


SCENARIO 3: Storage Corrupted
  │
  ├─ initializeToken()
  ├─ SharedPrefs.getString() → throws
  ├─ Exception caught, logged
  │
  ├─ _backendToken = null
  └─ Fallback to Firebase token ✓


SCENARIO 4: User Deleted on Backend
  │
  ├─ restoreSession()
  ├─ _api.getMe() → 404 Not Found
  ├─ resp['success'] = false
  │
  ├─ Clear token
  │ └─ await _api.clearToken()
  │
  └─ User sees login screen


All errors handled gracefully, no white screen/crash!
```

---

## State Diagram

```
┌─────────────────────────────────────────────────────────┐
│              AUTHPROVIDER STATE TRANSITIONS             │
└─────────────────────────────────────────────────────────┘

                              ┌─────────────────┐
                              │      START      │
                              └────────┬────────┘
                                       │
                              ┌────────▼─────────┐
                              │ unknown          │
                              │ (Initializing)   │
                              └────────┬─────────┘
                    ┌──────────────────┼──────────────────┐
                    │                  │                  │
         ┌──────────▼──────────┐  ┌────▼─────────┐  ┌───▼──────────┐
         │ authenticated       │  │unauthenticated   │ guest        │
         │ (Session restored)  │  │(Fresh install)   │ (Test mode) │
         └──────────┬──────────┘  └────┬──────────┘  └───┬──────────┘
                    │                  │                  │
                    │                  │                  │
         ┌──────────┴──────┐           │                  │
         │                 │           │                  │
         │         ┌───────▼──────┐    │                  │
         │         │ [LOGIN]      │    │                  │
         │         │ Sign in/up   │    │                  │
         │         └───────┬──────┘    │                  │
         │                 │           │                  │
         │         ┌───────▼──────────┐│                  │
         │         │ authenticated    ││                  │
         │         │ (role = null)    ││                  │
         │         └───────┬──────────┘│                  │
         │                 │           │                  │
         │         ┌───────▼────────────┐               │
         │         │ [ROLE SELECTION]  │               │
         │         │ Select role       │               │
         │         └───────┬───────────┘               │
         │                 │                            │
         └─────────────────┤                            │
                           │                            │
                    ┌──────▼──────────┐                 │
                    │ authenticated   │                 │
                    │ (role set)      │──────┐          │
                    └─────────────────┘      │          │
                                             │          │
                              ┌──────────────┴──────────┘
                              │
          ┌───────────────────▼──────────────────┐
          │ [HOME SCREEN(S)]                     │
          │ ├─ CustomerHomeScreen               │
          │ └─ ProfessionalHomeScreen           │
          └───────────────────┬──────────────────┘
                              │
                         ┌────▼─────┐
                         │ Logout   │
                         └────┬─────┘
                              │
                    ┌─────────▼─────────┐
                    │ unauthenticated   │
                    │ (Logged out)      │
                    └─────────┬─────────┘
                              │
                         [LOOP BACK TO LOGIN]
```

---

## Summary

- **Fast cold start**: 2.5 seconds with background session restore
- **Seamless returning users**: No login screen for users with stored tokens
- **Secure token handling**: Tokens stored locally, used in all requests
- **Graceful error handling**: Invalid tokens cleared, users re-prompted to login
- **Clean logout**: All tokens and user data removed

✨ **Your app authentication is now production-ready!** ✨

