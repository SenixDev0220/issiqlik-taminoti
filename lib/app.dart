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

/// Smooth fade + slide transition for all routes.
CustomTransitionPage<T> _slideFade<T>({required Widget child, required GoRouterState state}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curve),
          child: child,
        ),
      );
    },
  );
}

class App extends ConsumerWidget {
  const App({super.key});

  static final _router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', pageBuilder: (c, s) => _slideFade(state: s, child: const SplashScreen())),
      GoRoute(path: '/login', pageBuilder: (c, s) => _slideFade(state: s, child: const LoginScreen())),
      GoRoute(path: '/register', pageBuilder: (c, s) => _slideFade(state: s, child: const RegisterScreen())),
      GoRoute(path: '/forgot-password', pageBuilder: (c, s) => _slideFade(state: s, child: const ForgotPasswordScreen())),
      GoRoute(path: '/home', pageBuilder: (c, s) => _slideFade(state: s, child: const HomeScreen())),
      GoRoute(path: '/boilerhouses', pageBuilder: (c, s) => _slideFade(state: s, child: const BoilerHouseListScreen())),
      GoRoute(
        path: '/boilerhouses/:id',
        pageBuilder: (c, s) => _slideFade(
          state: s,
          child: BoilerHouseDetailScreen(boilerHouseId: s.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(path: '/journal', pageBuilder: (c, s) => _slideFade(state: s, child: const JournalScreen())),
      GoRoute(path: '/instructions', pageBuilder: (c, s) => _slideFade(state: s, child: const InstructionsScreen())),
      GoRoute(path: '/drawings', pageBuilder: (c, s) => _slideFade(state: s, child: const DrawingsScreen())),
      GoRoute(path: '/notifications', pageBuilder: (c, s) => _slideFade(state: s, child: const NotificationsScreen())),
      GoRoute(path: '/profile', pageBuilder: (c, s) => _slideFade(state: s, child: const ProfileScreen())),
      GoRoute(path: '/workers', pageBuilder: (c, s) => _slideFade(state: s, child: const WorkersScreen())),
      GoRoute(path: '/shifts', pageBuilder: (c, s) => _slideFade(state: s, child: const ShiftsScreen())),
      GoRoute(path: '/analytics', pageBuilder: (c, s) => _slideFade(state: s, child: const AnalyticsScreen())),
      GoRoute(path: '/admin', pageBuilder: (c, s) => _slideFade(state: s, child: const AdminPanelScreen())),
      GoRoute(path: '/about', pageBuilder: (c, s) => _slideFade(state: s, child: const AboutScreen())),
    ],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appStateInitProvider);
    final lang = ref.watch(selectedLanguageProvider);

    // Kick the user out live if an admin deletes or blocks them while the
    // app is open (currentUserSyncProvider mirrors the Firestore user doc).
    ref.listen(currentUserSyncProvider, (prev, next) {
      final hadUser = prev?.valueOrNull != null;
      final user = next.valueOrNull;
      if (hadUser && (user == null || user.status == UserStatus.blocked)) {
        ref.read(currentUserProvider.notifier).state = null;
        _router.go('/login');
      }
    });

    return SessionTimeoutManager(
      onTimeout: () => _router.go('/login'),
      child: MaterialApp.router(
        key: ValueKey(lang),
        title: AppConstants.appName,
        theme: AppTheme.lightTheme,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
