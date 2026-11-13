import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/create_shop_screen.dart';
import '../../features/auth/screens/join_shop_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/sales/screens/sales_screen.dart';
import '../../features/expenses/screens/expenses_screen.dart';
import '../../features/credit/screens/credit_screen.dart';
import '../../features/deposits/screens/deposits_screen.dart';
import '../../features/returns/screens/returns_screen.dart';
import '../../features/monthly/screens/monthly_summary_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/settings/screens/products_settings_screen.dart';
import '../../features/more/screens/more_screen.dart';
import '../../features/legal/privacy_policy_screen.dart';
import '../../features/premium/screens/admin_screen.dart';
import '../../features/premium/screens/premium_screen.dart';
import '../../features/stock/screens/stock_screen.dart';
import '../../widgets/main_shell.dart';

/// Auth state notifier for GoRouter refresh
class AuthStateNotifier extends ChangeNotifier {
  AuthStateNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
    _ref.listen(
      currentUserProvider.select((u) => (
            u.isLoading,
            u.valueOrNull == null,
            u.valueOrNull?.shopId,
            u.valueOrNull?.isOwner,
            u.valueOrNull?.active,
          )),
      (_, __) => notifyListeners(),
    );
  }

  final Ref _ref;
}

final authStateNotifierProvider = Provider<AuthStateNotifier>((ref) {
  return AuthStateNotifier(ref);
});

/// Router provider
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(authStateNotifierProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final currentUser = ref.read(currentUserProvider);
      
      final firebaseUser = authState.valueOrNull;
      final isLoggedIn = firebaseUser != null;
      final user = currentUser.valueOrNull;
      
      final currentPath = state.matchedLocation;
      if (currentPath == '/privacy') return null;

      final isAuthRoute = currentPath == '/login' || 
                          currentPath == '/register' ||
                          currentPath == '/create-shop' ||
                          currentPath == '/join-shop';


      // Still loading auth state
      if (authState.isLoading) {
        return null;
      }

      // Not logged in - must be on auth pages
      if (!isLoggedIn) {
        if (currentPath == '/login' || currentPath == '/register') return null;
        return '/login';
      }

      // Logged in but user data still loading
      if (currentUser.isLoading) {
        return null;
      }

      // Logged in but no user document (shouldn't happen normally)
      if (user == null) {
        if (isAuthRoute) return null;
        return '/login';
      }

      // User has no shop yet - redirect to create/join shop
      if (user.shopId == null) {
        if (currentPath == '/create-shop' || currentPath == '/join-shop') return null;
        return user.isOwner ? '/create-shop' : '/join-shop';
      }

      // User has shop - redirect away from auth pages to dashboard
      if (isAuthRoute) {
        return '/dashboard';
      }

      // Staff access restrictions
      if (user.isStaff) {
        final restrictedRoutes = ['/settings', '/monthly-summary', '/products-settings'];
        if (restrictedRoutes.contains(currentPath)) {
          return '/dashboard';
        }
        
        // Inactive staff - sign out
        if (!user.active) {
          ref.read(authRepositoryProvider).signOut();
          return '/login';
        }
      }

      return null;
    },
    routes: [
      // Auth Routes (no shell)
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/create-shop',
        builder: (context, state) => const CreateShopScreen(),
      ),
      GoRoute(
        path: '/join-shop',
        builder: (context, state) => const JoinShopScreen(),
      ),
      GoRoute(
        path: '/privacy',
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      
      // Main app routes share the shell (bottom bar on phones, sidebar on wide screens)
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => const NoTransitionPage(child: ProfileScreen()),
          ),
          GoRoute(
            path: '/deposits',
            pageBuilder: (context, state) => const NoTransitionPage(child: DepositsScreen()),
          ),
          GoRoute(
            path: '/returns',
            pageBuilder: (context, state) => const NoTransitionPage(child: ReturnsScreen()),
          ),
          GoRoute(
            path: '/monthly-summary',
            pageBuilder: (context, state) => const NoTransitionPage(child: MonthlySummaryScreen()),
          ),
          GoRoute(
            path: '/products-settings',
            pageBuilder: (context, state) => const NoTransitionPage(child: ProductsSettingsScreen()),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => const NoTransitionPage(child: SettingsScreen()),
          ),
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) => const NoTransitionPage(child: DashboardScreen()),
          ),
          GoRoute(
            path: '/sales',
            pageBuilder: (context, state) => const NoTransitionPage(child: SalesScreen()),
          ),
          GoRoute(
            path: '/expenses',
            pageBuilder: (context, state) => const NoTransitionPage(child: ExpensesScreen()),
          ),
          GoRoute(
            path: '/credit',
            pageBuilder: (context, state) => const NoTransitionPage(child: CreditScreen()),
          ),
          GoRoute(
            path: '/more',
            pageBuilder: (context, state) => const NoTransitionPage(child: MoreScreen()),
          ),
          GoRoute(
            path: '/stock',
            pageBuilder: (context, state) => const NoTransitionPage(child: StockScreen()),
          ),
          GoRoute(
            path: '/premium',
            pageBuilder: (context, state) => const NoTransitionPage(child: PremiumScreen()),
          ),
          GoRoute(
            path: '/admin',
            pageBuilder: (context, state) => const NoTransitionPage(child: AdminScreen()),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.matchedLocation}'),
      ),
    ),
  );
});
