# Arpa Shop Accounting

A complete shop accounting Flutter app for Android and Web with Firebase backend.

## Features

- **Authentication**: Email/Password login with role-based access (Owner/Staff)
- **Dashboard**: KPIs, Live Cash, Quick Actions
- **Sales Management**: Track daily sales with cash/non-cash payment types
- **Expenses**: Track expenses by categories/subcategories
- **Credit Management**: Credit sales and collections
- **Deposits & Returns**: Track cash flow
- **Monthly Summary**: (Owner only) Monthly business reports
- **Settings**: (Owner only) Manage staff, categories, invite codes
- **Offline Support**: Works offline with Firestore persistence

## Tech Stack

- Flutter 3.x (Material 3)
- Riverpod (State Management)
- Firebase Auth + Cloud Firestore
- GoRouter (Navigation)
- Shimmer (Skeleton Loaders)

## Getting Started

### Prerequisites

- Flutter SDK (3.10+)
- Firebase CLI
- FlutterFire CLI

### Setup Firebase

1. **Install Firebase CLI**:
```bash
npm install -g firebase-tools
firebase login
```

2. **Install FlutterFire CLI**:
```bash
dart pub global activate flutterfire_cli
```

3. **Configure Firebase**:
```bash
flutterfire configure
```
This will:
- Create a new Firebase project (or use existing)
- Register Android and Web apps
- Generate `firebase_options.dart`

4. **Enable Firebase Services**:
   - Go to [Firebase Console](https://console.firebase.google.com)
   - Enable **Authentication** > Email/Password
   - Enable **Cloud Firestore**
   - Set Firestore Rules (copy from `firestore.rules`)

5. **Update main.dart** to use generated options:
```dart
import 'firebase_options.dart';

// In main():
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

### Run the App

```bash
# Get dependencies
flutter pub get

# Run on Android
flutter run

# Run on Web
flutter run -d chrome

# Run on Windows
flutter run -d windows
```

### Build for Production

**Android APK**:
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

**Android App Bundle**:
```bash
flutter build appbundle --release
```

**Web**:
```bash
flutter build web --release
```
Output: `build/web/`

### Deploy Web to Firebase Hosting

1. **Initialize Firebase Hosting**:
```bash
firebase init hosting
```
- Select your Firebase project
- Set public directory to `build/web`
- Configure as single-page app: Yes
- Don't overwrite index.html

2. **Build and Deploy**:
```bash
flutter build web --release
firebase deploy --only hosting
```

## Firestore Security Rules

Copy the contents of `firestore.rules` to your Firebase Console:
- Go to Firestore Database > Rules
- Paste the rules
- Publish

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── core/
│   ├── constants/           # App constants
│   ├── providers/           # Riverpod providers
│   ├── router/              # GoRouter configuration
│   ├── theme/               # App theme
│   └── utils/               # Utilities (date, currency formatters)
├── data/
│   └── models/              # Data models
├── features/
│   ├── auth/                # Authentication screens
│   ├── dashboard/           # Dashboard
│   ├── sales/               # Sales CRUD
│   ├── expenses/            # Expenses CRUD
│   ├── credit/              # Credit sales/collections
│   ├── deposits/            # Deposits
│   ├── returns/             # Returns
│   ├── monthly/             # Monthly summary (Owner)
│   ├── settings/            # Settings (Owner)
│   └── profile/             # User profile
└── widgets/                 # Reusable widgets
```

## User Roles

### Owner
- Full access to all features
- Can create shop and generate invite codes
- Can manage staff (enable/disable)
- Can manage expense categories
- Can toggle profit visibility
- Can view monthly summary

### Staff
- Limited access (entry-related only)
- Must join shop using invite code
- Can add sales, expenses, credit, deposits, returns
- Cannot access settings or monthly summary
- Can be disabled by owner

## Development Phases

- [x] **Phase 1**: Auth + Shop + Role Guards + Profile
- [x] **Phase 2**: CRUD modules (Sales/Expenses/Credit/Deposit/Return)
- [x] **Phase 3**: Dashboard + Live Cash + Sync Indicator + Skeleton Loaders
- [x] **Phase 4**: Settings (Categories, Staff Management, Profit Toggle)
- [x] **Phase 5**: Monthly Summary

## Live Cash Formula

```
LiveCash = OpeningCash + CashSales + CreditCollections - ManualDeposits - CashExpenses - Returns
```

Note: 
- **Non-cash sales (bKash/Bank payments) automatically create deposits** but these are excluded from Live Cash calculation.
- Only manual deposits affect Live Cash (money physically taken from the shop).
- Credit collections are added on the date they are collected, not the credit sale date.

## Default Expense Categories

When a new shop is created, the following categories are automatically added:
- **Shop Expense** (with subcategories: Breakfast, Bag, Rent, Electricity, Generator, Other Bills, Staff Bill)
- **Home Expense**
- **Purchase**
- **Transport**
- **Installment**
- **Savings**
- **Personal**
- **Other**

## Firestore Indexes

For better query performance, create these composite indexes:

```
Collection: shops/{shopId}/sales
Fields: date (Ascending), createdAt (Descending)

Collection: shops/{shopId}/expenses
Fields: date (Ascending), createdAt (Descending)

Collection: shops/{shopId}/creditSales
Fields: status (Ascending), createdAt (Descending)
```

## License

This project is for private use only.
