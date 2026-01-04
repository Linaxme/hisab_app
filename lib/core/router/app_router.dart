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
import '../../widgets/main_shell.dart';

/// Auth state notifier for GoRouter refresh
class AuthStateNotifier extends ChangeNotifier {
  AuthStateNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
    _ref.listen(currentUserProvider, (_, __) => notifyListeners());
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
    debugLogDiagnostics: true,
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final currentUser = ref.read(currentUserProvider);
      
      final firebaseUser = authState.valueOrNull;
      final isLoggedIn = firebaseUser != null;
      final user = currentUser.valueOrNull;
      
      final currentPath = state.matchedLocation;
      final isAuthRoute = currentPath == '/login' || 
                          currentPath == '/register' ||
                          currentPath == '/create-shop' ||
                          currentPath == '/join-shop';

      debugPrint('🔐 Router redirect: path=$currentPath, isLoggedIn=$isLoggedIn, hasUser=${user != null}, shopId=${user?.shopId}');

      // Still loading auth state
      if (authState.isLoading) {
        debugPrint('⏳ Auth state loading...');
        return null;
      }

      // Not logged in - must be on auth pages
      if (!isLoggedIn) {
        debugPrint('❌ Not logged in, redirecting to login');
        if (currentPath == '/login' || currentPath == '/register') return null;
        return '/login';
      }

      // Logged in but user data still loading
      if (currentUser.isLoading) {
        debugPrint('⏳ User data loading...');
        return null;
      }

      // Logged in but no user document (shouldn't happen normally)
      if (user == null) {
        debugPrint('⚠️ User logged in but no user document');
        if (isAuthRoute) return null;
        return '/login';
      }

      // User has no shop yet - redirect to create/join shop
      if (user.shopId == null) {
        debugPrint('🏪 User has no shop, redirecting to create/join');
        if (currentPath == '/create-shop' || currentPath == '/join-shop') return null;
        return user.isOwner ? '/create-shop' : '/join-shop';
      }

      // User has shop - redirect away from auth pages to dashboard
      if (isAuthRoute) {
        debugPrint('✅ User has shop, redirecting to dashboard');
        return '/dashboard';
      }

      // Staff access restrictions
      if (user.isStaff) {
        final restrictedRoutes = ['/settings', '/monthly-summary'];
        if (restrictedRoutes.contains(currentPath)) {
          return '/dashboard';
        }
        
        // Inactive staff - sign out
        if (!user.active) {
          ref.read(authRepositoryProvider).signOut();
          return '/login';
        }
      }

      debugPrint('✅ No redirect needed');
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
      
      // Main App Routes with Shell (Bottom Navigation)
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
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
        ],
      ),
      
      // Non-shell routes
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/deposits',
        builder: (context, state) => const DepositsScreen(),
      ),
      GoRoute(
        path: '/returns',
        builder: (context, state) => const ReturnsScreen(),
      ),
      GoRoute(
        path: '/monthly-summary',
        builder: (context, state) => const MonthlySummaryScreen(),
      ),
      GoRoute(
        path: '/products-settings',
        builder: (context, state) => const ProductsSettingsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.matchedLocation}'),
      ),
    ),
  );
});
