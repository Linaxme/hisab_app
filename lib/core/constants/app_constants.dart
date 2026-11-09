/// App-wide constants
class AppConstants {
  AppConstants._();

  static const String appName = 'আমার দোকান';
  static const String currency = '৳';

  // Shown in the privacy policy; empty values are hidden
  static const String developerName = '';
  static const String supportEmail = '';
  static const String supportPhone = '';
  static const String supportAddress = '';
  static const String privacyPolicyUpdated = '১০ নভেম্বর ২০২৬';
  
  // Roles
  static const String roleOwner = 'owner';
  static const String roleStaff = 'staff';
  
  // Payment Types
  static const String paymentCash = 'cash';
  static const String paymentNonCash = 'noncash';
  
  // Collection names
  static const String usersCollection = 'users';
  static const String shopsCollection = 'shops';
  static const String salesCollection = 'sales';
  static const String expensesCollection = 'expenses';
  static const String depositsCollection = 'deposits';
  static const String returnsCollection = 'returns';
  static const String creditSalesCollection = 'creditSales';
  static const String creditCollectionsCollection = 'creditCollections';
  static const String openingCashCollection = 'openingCash';
  static const String expenseCategoriesCollection = 'expenseCategories';
  static const String subcategoriesCollection = 'subcategories';
  
  // Pagination
  static const int pageSize = 20;
}
