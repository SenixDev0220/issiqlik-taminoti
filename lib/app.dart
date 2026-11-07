import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'src/core/app_constants.dart';
import 'src/core/app_state.dart';
import 'src/core/app_theme.dart';
import 'src/domain/models/app_user.dart';
import 'src/features/about/about_screen.dart';
import 'src/features/admin/admin_panel_screen.dart';
import 'src/features/analytics/analytics_screen.dart';
import 'src/features/auth/session_timeout_manager.dart';
import 'src/features/auth/auth_providers.dart' as auth;
import 'src/features/boilerhouse/boilerhouse_detail_screen.dart';
import 'src/features/boilerhouse/boilerhouse_list_screen.dart';
import 'src/features/drawings/drawings_screen.dart';
import 'src/features/home/home_screen.dart';
import 'src/features/instructions/instructions_screen.dart';
import 'src/features/journal/journal_screen.dart';
import 'src/features/login/forgot_password_screen.dart';
import 'src/features/login/login_screen.dart';
import 'src/features/login/register_screen.dart';
import 'src/features/notifications/notifications_screen.dart';
import 'src/features/profile/profile_screen.dart';
import 'src/features/shifts/shifts_screen.dart';
import 'src/features/splash/splash_screen.dart';
import 'src/features/workers/workers_screen.dart';

/// Lightweight slide transition with the destination isolated for repainting.
CustomTransitionPage<T> _slideFade<T>({
  required Widget child,
  required GoRouterState state,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 340),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.disableAnimationsOf(context) ||
          MediaQuery.accessibleNavigationOf(context)) {
        return child;
      }
      final curve = animation.drive(CurveTween(curve: Curves.easeOutBack));
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.018),
          end: Offset.zero,
        ).animate(curve),
        child: RepaintBoundary(
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1).animate(curve),
            child: child,
          ),
        ),
      );
    },
  );
}

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final _router = GoRouter(
    navigatorKey: _navigatorKey,
    redirect: (context, state) {
      final user = ref.read(currentUserProvider);
      final public = const {'/', '/login', '/register', '/forgot-password'}
          .contains(state.uri.path);
      if (user == null || user.status != UserStatus.active) {
        return public ? null : '/login';
      }
      if (state.uri.path == '/admin' && user.role != UserRole.admin && user.role != UserRole.coAdmin) return '/home';
      return null;
    },
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (c, s) =>
            _slideFade(state: s, child: const SplashScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (c, s) => _slideFade(state: s, child: const LoginScreen()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (c, s) =>
            _slideFade(state: s, child: const RegisterScreen()),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (c, s) =>
            _slideFade(state: s, child: const ForgotPasswordScreen()),
      ),
      GoRoute(
        path: '/home',
        pageBuilder: (c, s) => _slideFade(state: s, child: const HomeScreen()),
      ),
      GoRoute(
        path: '/boilerhouses',
        pageBuilder: (c, s) =>
            _slideFade(state: s, child: const BoilerHouseListScreen()),
      ),
      GoRoute(
        path: '/boilerhouses/:id',
        pageBuilder: (c, s) => _slideFade(
          state: s,
          child: BoilerHouseDetailScreen(
            boilerHouseId: s.pathParameters['id'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/journal',
        pageBuilder: (c, s) =>
            _slideFade(state: s, child: const JournalScreen()),
      ),
      GoRoute(
        path: '/instructions',
        pageBuilder: (c, s) =>
            _slideFade(state: s, child: const InstructionsScreen()),
      ),
      GoRoute(
        path: '/drawings',
        pageBuilder: (c, s) =>
            _slideFade(state: s, child: const DrawingsScreen()),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (c, s) =>
            _slideFade(state: s, child: const NotificationsScreen()),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (c, s) =>
            _slideFade(state: s, child: const ProfileScreen()),
      ),
      GoRoute(
        path: '/workers',
        pageBuilder: (c, s) =>
            _slideFade(state: s, child: const WorkersScreen()),
      ),
      GoRoute(
        path: '/shifts',
        pageBuilder: (c, s) =>
            _slideFade(state: s, child: const ShiftsScreen()),
      ),
      GoRoute(
        path: '/analytics',
        pageBuilder: (c, s) =>
            _slideFade(state: s, child: const AnalyticsScreen()),
      ),
      GoRoute(
        path: '/admin',
        pageBuilder: (c, s) =>
            _slideFade(state: s, child: const AdminPanelScreen()),
      ),
      GoRoute(
        path: '/about',
        pageBuilder: (c, s) => _slideFade(state: s, child: const AboutScreen()),
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  void _clearProtectedRoutes() {
    // Dialogs and imperatively pushed media/detail routes must disappear too.
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    _router.go('/login');
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appStateInitProvider);
    final lang = ref.watch(selectedLanguageProvider);

    ref.listen(currentUserProvider, (previous, user) {
      if (user == null || user.status != UserStatus.active) {
        if (previous != null) _clearProtectedRoutes();
      } else {
        if (previous != null && (previous.role != user.role ||
            previous.boilerhouseIds.join('|') != user.boilerhouseIds.join('|'))) {
          _navigatorKey.currentState?.popUntil((route) => route.isFirst);
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
          _router.go('/home');
        }
        _router.refresh();
      }
    });
    // Server access validation is owned by the service/provider, not inferred
    // from a locally restored role or an old profile snapshot.
    ref.listen(currentUserSyncProvider, (previous, next) {
      if (next.isLoading) return;
      final user = next.valueOrNull;
      if ((next.hasError || user == null || user.status != UserStatus.active) &&
          ref.read(currentUserProvider) != null) {
        _clearProtectedRoutes();
        auth.signOut(ref).catchError((_) {});
      }
    });

    return SessionTimeoutManager(
      onTimeout: () => _router.go('/login'),
      child: MaterialApp.router(
        key: ValueKey(lang),
        title: AppConstants.appName,
        theme: AppTheme.lightTheme,
        scrollBehavior: MaterialScrollBehavior().copyWith(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
        ),
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
