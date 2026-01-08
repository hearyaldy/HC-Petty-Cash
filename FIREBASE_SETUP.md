# Firebase Setup Guide

## Current Status

✅ **Completed:**
- Firebase dependencies added to pubspec.yaml
- All models updated for Firestore (User, PettyCashReport, Transaction)
- Firebase services created (Auth, Firestore, Storage)
- Security rules created (firestore.rules, storage.rules)
- Query indexes defined (firestore.indexes.json)
- Old Hive services removed
- AuthProvider updated for Firebase Authentication

⏳ **Remaining:**
- Run `flutterfire configure` to connect to your Firebase project
- Update ReportProvider and TransactionProvider
- Update main.dart to initialize Firebase
- Deploy security rules
- Create initial test users

---

## Step 1: Connect to Firebase Project

### Run FlutterFire CLI Configuration

```bash
flutterfire configure
```

This will:
1. Show you a list of your Firebase projects
2. Let you select your project
3. Generate `lib/firebase_options.dart` automatically
4. Configure platform-specific files

**Select your Firebase project** from the list when prompted.

---

## Step 2: Deploy Security Rules

### Deploy Firestore Rules

```bash
firebase deploy --only firestore:rules
```

### Deploy Firestore Indexes

```bash
firebase deploy --only firestore:indexes
```

### Deploy Storage Rules

```bash
firebase deploy --only storage
```

---

## Step 3: Enable Firebase Services

1. **Go to Firebase Console**: https://console.firebase.google.com
2. **Select your project**
3. **Enable Authentication**:
   - Go to Authentication → Sign-in method
   - Enable "Email/Password"
   - (Optional) Enable email verification

4. **Create Firestore Database**:
   - Go to Firestore Database
   - Click "Create database"
   - Start in **production mode** (rules are already configured)
   - Choose your region

5. **Enable Firebase Storage**:
   - Go to Storage
   - Click "Get started"
   - Use production mode (rules are already configured)

---

## Step 4: Create Initial Users

Since Firebase Authentication is now managing passwords, you need to create users through Firebase:

### Option A: Firebase Console (Recommended for first admin)

1. Go to Firebase Console → Authentication → Users
2. Click "Add user"
3. Enter email and password
4. Copy the UID
5. Go to Firestore Database
6. Add a document to `users` collection:
   - Document ID: (paste the UID)
   - Fields:
     ```
     id: <UID>
     email: "admin@company.com"
     name: "Admin User"
     role: "admin"
     department: "IT"
     createdAt: <Timestamp> (use "Add field" → timestamp → current time)
     updatedAt: null
     ```

### Option B: Use App Registration

Once you have one admin user created via Console:
1. Login as admin
2. Use the admin panel to create other users
3. App will automatically create both Firebase Auth account and Firestore document

---

## Step 5: Test User Credentials

**Default roles:**
- `admin` - Can manage users, approve transactions, full access
- `manager` - Can approve transactions, view all reports
- `finance` - Can approve transactions
- `requester` - Can create reports and transactions

**Example test users to create:**

| Email | Role | Department |
|-------|------|------------|
| admin@company.com | admin | IT |
| manager@company.com | manager | Operations |
| finance@company.com | finance | Finance |
| user@company.com | requester | General |

---

## Step 6: Update Remaining Code (To Do)

The following files still need to be updated:

### 1. Update `lib/providers/report_provider.dart`
- Already uses async methods (should work)
- May need to add error handling for Firebase exceptions

### 2. Update `lib/providers/transaction_provider.dart`
- Update to use FirestoreService
- Update to use FirebaseStorageService for file uploads
- Handle file uploads before transaction creation

### 3. Update `lib/main.dart`
Add Firebase initialization:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enable offline persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(const MyApp());
}
```

And update AuthProvider initialization:
```dart
ChangeNotifierProvider(
  create: (_) => AuthProvider()..initialize(),
),
```

### 4. Update Admin Screen User Registration

Update the user registration dialog to use the new `registerUser` method:

```dart
await authProvider.registerUser(
  email: email,
  password: password,
  name: name,
  role: selectedRole,
  department: department,
);
```

---

## Step 7: Testing

### Test Authentication
- ✓ Login with valid credentials
- ✓ Login fails with invalid credentials
- ✓ Password reset email
- ✓ Session persistence on app restart
- ✓ Logout

### Test CRUD Operations
- ✓ Create/read/update/delete reports
- ✓ Create/read/update/delete transactions
- ✓ Upload attachments to Firebase Storage
- ✓ Download/view attachments
- ✓ Cascade delete (report → transactions)

### Test Security Rules
- ✓ Role-based access control enforced
- ✓ Non-admins cannot delete
- ✓ Users cannot edit other users' drafts
- ✓ Approvers can modify approval fields

### Test Offline Support
- ✓ App works offline with cached data
- ✓ Changes sync when online
- ✓ Error messages for network failures

---

## Troubleshooting

### Issue: "Firebase project not found"
**Solution**: Run `flutterfire configure` and select the correct project from the list

### Issue: "Permission denied" errors
**Solution**: Check that security rules are deployed and user is authenticated

### Issue: "Missing index" errors
**Solution**: Deploy indexes with `firebase deploy --only firestore:indexes`
Or click the link in the Firebase console error to auto-create the index

### Issue: "Authentication errors"
**Solution**: Check that Email/Password is enabled in Firebase Console

### Issue: "Storage upload fails"
**Solution**: Check storage.rules are deployed and file size is under 10MB

---

## Important Notes

### Enum Serialization Change
- **Old (Hive)**: Stored as indices (0, 1, 2...)
- **New (Firestore)**: Stored as strings ('draft', 'approved', 'closed')
- **Why**: Better readability, easier debugging, no index conflicts

### Password Management
- **Old**: Passwords stored in User model
- **New**: Managed by Firebase Auth separately
- **User Creation**: Two-step process (Firebase Auth + Firestore doc)

### File Attachments
- **Old**: Local file paths in `attachments` field
- **New**: Firebase Storage URLs in `attachmentUrls` field
- **Upload**: Files uploaded to Storage before transaction creation

### Offline Behavior
- Firestore has built-in offline persistence
- Data cached locally automatically
- Syncs when back online
- Configure in main.dart with `persistenceEnabled: true`

---

## Security Best Practices

1. **Never commit sensitive data**:
   - Add `firebase_options.dart` to .gitignore if it contains secrets
   - Use environment variables for sensitive configuration

2. **Review security rules**:
   - Test rules using Firebase Console Rules Playground
   - Start restrictive, relax as needed

3. **Enable email verification**:
   - Go to Firebase Console → Authentication → Templates
   - Customize email verification template

4. **Monitor usage**:
   - Set up budget alerts in Firebase Console
   - Monitor daily operations count
   - Implement pagination for large datasets

---

## Next Steps After Setup

1. Test the app thoroughly
2. Update UI screens if needed (error handling)
3. Add loading states for async operations
4. Implement proper error messages
5. Add email verification if required
6. Set up Firebase Analytics (optional)
7. Configure Firebase Performance Monitoring (optional)

---

## Support & Resources

- **Firebase Documentation**: https://firebase.google.com/docs
- **FlutterFire Documentation**: https://firebase.flutter.dev/
- **Firebase Console**: https://console.firebase.google.com
- **Security Rules Reference**: https://firebase.google.com/docs/firestore/security/get-started

---

## File Structure Summary

```
lib/
├── models/
│   ├── user.dart (✅ Updated)
│   ├── petty_cash_report.dart (✅ Updated)
│   └── transaction.dart (✅ Updated)
├── services/
│   ├── firebase_auth_service.dart (✅ Created)
│   ├── firestore_service.dart (✅ Created)
│   ├── firebase_storage_service.dart (✅ Created)
│   └── report_service.dart (✅ Updated)
├── providers/
│   ├── auth_provider.dart (✅ Updated)
│   ├── report_provider.dart (⏳ Needs update)
│   └── transaction_provider.dart (⏳ Needs update)
└── main.dart (⏳ Needs Firebase initialization)

Root files:
├── firestore.rules (✅ Created)
├── firestore.indexes.json (✅ Created)
├── storage.rules (✅ Created)
└── firebase_options.dart (⏳ To be generated)
```
