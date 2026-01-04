You are a senior Flutter architect + Firebase engineer. Build a complete, production-ready Flutter app (Android + Web) for a shop accounting system. The app must be fully runnable with zero TODOs and must compile.

========================
APP OVERVIEW
========================
App name: Arpa Shop Accounting
Platforms: Android + Web
Backend: Firebase (Auth + Firestore)
Goal: Shop owner and staff manage daily sales/expenses/credit etc. Staff can do entries but cannot access settings or monthly summary.

IMPORTANT: No shop logo needed.
Must include user profile and logout for both owner and staff.

========================
TECH STACK
========================
- Flutter (Material 3)
- Riverpod for state management
- Firebase Auth (Email/Password)
- Cloud Firestore (data)
- Firebase Hosting for web deployment guidance
- Offline-first behavior:
  - Android/iOS: Firestore persistence enabled
  - Web: enablePersistence with try/catch (IndexedDB)
- Good UX:
  - Skeleton loaders/shimmer for perceived speed
  - Empty states for lists
  - Pagination for list pages (limit + load more)

========================
ROLES & PERMISSIONS (CRITICAL)
========================
Roles: owner, staff

Owner can:
- Access all features: Dashboard, Sales, Expenses, Credit, Deposits, Returns, Monthly Summary, Settings, Staff management, Category management, Profile, Logout

Staff can:
- ONLY access entry-related features: Sales, Expenses, Credit (sale/collection), Deposits, Returns, Profile, Logout
- Staff MUST NOT access:
  - Settings
  - Monthly Summary
  - any admin-only controls
- Even if staff tries to open restricted route directly, route guard must block.
- Enforce permissions in Firestore Rules too (not only UI hiding).

========================
AUTH & SHOP MEMBERSHIP
========================
- Owner creates a shop (shopId).
- Staff must join an existing shop (NOT create a new shop).
Implement a simple “Invite Code / Join Shop” flow:
- shop has inviteCode (store hash or plain for simplicity)
- Owner can regenerate invite code
- Staff signs up -> goes to Join Shop screen -> enters invite code -> gets linked to shopId with role=staff

User profile stored in Firestore:
- users/{uid} doc:
  - uid
  - role: owner|staff
  - shopId
  - name
  - email
  - active (bool)
  - createdAt

Shop doc:
- shops/{shopId} doc:
  - name
  - inviteCode
  - ownerUid
  - createdAt

========================
MODULES / FEATURES (MUST IMPLEMENT)
========================

1) DASHBOARD
Show only top KPIs (clean, not cluttered):
- Opening Cash (today)
- Live Cash
- Today Sales total
- Today Expenses total
- Total Profit (toggle show/hide from Settings)
Quick actions:
- Add Sale
- Add Expense
- Add Credit Sale
- Add Credit Collection
For staff: show limited dashboard (no profit if owner toggled off OR always hidden for staff).

Live Cash computation:
LiveCash = OpeningCash + CashSales + Deposits - CashExpenses - Returns
(Non-cash sales/expenses do not affect LiveCash)

2) SALES (Daily Sales Entry)
Fields:
- productName (string)
- sellPrice (double)
- profit (double)
- paymentType: cash | noncash
- date (YYYY-MM-DD)
CRUD:
- Add/Edit/Delete
- List by selected date
- Totals at top: todaySales, todayProfit (profit visibility controlled by settings + role)
Offline-first:
- create locally and sync when online

3) OPENING CASH (Daily)
- One opening cash per day per shop
- Only owner can set/edit
- Staff can view if allowed
Fields: amount, date, createdBy, createdAt

4) EXPENSES (Cash & Non-cash)
Fields:
- amount (double)
- categoryId (string)
- subCategoryId (string, optional)
- note (string optional)
- paymentType: cash | noncash
- date
Behavior:
- cash expense reduces live cash; noncash does not
CRUD + list by date + totals

5) EXPENSE CATEGORY & SUBCATEGORY MANAGEMENT (Owner Only) [NEW FEATURE]
From Settings:
- Manage categories per shop: create/update/delete
- Manage subcategories under each category: create/update/delete
- Expense entry screen must use dropdown selection for category and subcategory.
- Must support unlimited categories/subcategories and future staff growth.

Provide default categories at first shop creation:
- Shop Expense (Breakfast, Bag, Rent, Electricity, Generator, Other Bills, Staff Bill)
- Home Expense
- Purchase (inventory)
- Transport
- Installment
- Savings
- Personal
- Other

6) DEPOSITS
Fields: amount, note, date, createdBy, createdAt
Effect: increases live cash

7) RETURNS
Fields: amount, note, date
Effect: reduces live cash

8) CREDIT MODULE
Credit Sale:
- customerName (optional)
- customerPhone (optional)
- amount
- date
Credit Collection:
- creditSaleId (link)
- amount
- date
Credit summary (screen):
- total credit
- collected
- remaining
CRUD for credit sale + collections

9) MONTHLY SUMMARY (Owner Only)
Per month:
- total sales
- total profit
- total expenses + breakdown by category
- average daily sales
- total purchase amount (from expense category "Purchase")
- staff payouts total (if using staff bill category)
- credit totals
- net cashflow overview
Optimize queries (use indexes if required and show guidance in README).

10) SETTINGS (Owner Only)
- Toggle profit visibility across app (show/hide)
- Manage expense categories/subcategories (feature 5)
- Staff management:
  - list staff
  - disable/enable staff
  - regenerate invite code
- App info

11) USER PROFILE (Owner + Staff)
Profile screen shows:
- name (editable)
- email
- role
- shop name
- createdAt
Logout button:
- FirebaseAuth.signOut()
- clear local providers/state
- redirect to login

========================
DATA MODEL (REQUIRED STRUCTURE)
========================
Use shop-scoped collections:

- shops/{shopId} (shop doc: name, inviteCode, ownerUid, createdAt)
- shops/{shopId}/openingCash/{yyyy-mm-dd}
- shops/{shopId}/sales/{saleId}
- shops/{shopId}/expenses/{expenseId}
- shops/{shopId}/deposits/{depositId}
- shops/{shopId}/returns/{returnId}
- shops/{shopId}/creditSales/{creditSaleId}
- shops/{shopId}/creditCollections/{collectionId}
- shops/{shopId}/expenseCategories/{categoryId}
- shops/{shopId}/expenseCategories/{categoryId}/subcategories/{subId}

User doc:
- users/{uid} (global users collection: role, shopId, name, email, active, createdAt)

All documents include:
- createdAt (serverTimestamp)
- createdBy (uid)
- updatedAt (optional)

========================
SECURITY RULES (MUST PROVIDE)
========================
- Only authenticated users
- A user can only access documents inside their shopId
- Staff cannot access:
  - shops/{shopId}/settings (if used)
  - shops/{shopId}/monthly (if used)
  - category management writes
  - invite code regeneration writes
- Staff can read categories (for dropdown) but cannot write them
- Users can read/update only their own users/{uid} profile doc
Provide a firestore.rules file content as part of deliverables.

========================
UI/UX REQUIREMENTS
========================
- Professional accounting UI
- Consistent FAB for add actions across modules
- Skeleton loaders for list pages and dashboard
- Empty states for all lists
- Currency formatting: ৳ with thousand separators
- Responsive layout for web and mobile
- Consistent spacing, typography hierarchy

========================
FOLDER STRUCTURE (REQUIRED)
========================
lib/
  app/
  core/
  auth/
  data/
  domain/
  features/
    dashboard/
    sales/
    expenses/
    credit/
    deposits/
    returns/
    monthly/
    settings/
    profile/
  widgets/

========================
DELIVERABLES
========================
1) Complete runnable Flutter project code (no TODOs)
2) README.md:
   - how to run android/web
   - how to connect firebase via flutterfire configure
   - how to deploy web to Firebase Hosting
   - how to build release APK
3) firestore.rules content for production
4) Make changes incrementally:
   Phase 1: Auth + shop create/join + role guards + profile/logout
   Phase 2: CRUD modules (sales/expenses/credit/deposit/return)
   Phase 3: Dashboard cash engine + offline + sync indicator + skeleton loaders
   Phase 4: Settings (profit toggle, category manager, staff manager)
   Phase 5: Monthly summary

IMPORTANT CONSTRAINTS
- Do not remove any core feature above.
- Ensure all code compiles and runs.
- Keep business logic correct for live cash and totals.
- Use best practices; avoid unnecessary complexity.
