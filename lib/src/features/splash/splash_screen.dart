import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_constants.dart';
import '../../core/app_theme.dart';
import '../../core/glass.dart';
import '../../services/firebase_service.dart';
import '../../services/push_service.dart';
import '../auth/auth_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  bool _restoring = true;
  bool _restoreFailed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);

    _restoreSession();
  }

  Future<void> _restoreSession() async {
    setState(() {
      _restoring = true;
      _restoreFailed = false;
    });
    try {
      final user = await restoreSession().timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (user != null) {
        ref.read(currentUserProvider.notifier).state = user;
        FirebaseService.instance.waitForPendingWrites();
        FirebaseService.instance.seedIfEmpty().catchError((_) {});
        PushService.instance.init();
        PushService.instance.registerToken(user.id);
      }
      context.go(user != null ? '/home' : '/login');
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _restoring = false;
        _restoreFailed = true;
      });
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('Session restore failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _restoring = false;
        _restoreFailed = true;
      });
    } catch (error, stackTrace) {
      debugPrint('Session restore failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _restoring = false;
        _restoreFailed = true;
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    return GlassScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.glassFill,
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(color: AppTheme.glassBorder),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x141B5E55),
                                blurRadius: 24,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          AppConstants.companyName,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l.employeeApp,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: AppTheme.inkSoft),
                        ),
                        const SizedBox(height: 24),
                        if (_restoring)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else if (_restoreFailed) ...[
                          Text(
                            l.startupError,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.inkSoft,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _restoreSession,
                            child: Text(l.retryButton),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                '${l.aboutVersion} 1.0.0',
                style: const TextStyle(fontSize: 12, color: AppTheme.inkFaint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
