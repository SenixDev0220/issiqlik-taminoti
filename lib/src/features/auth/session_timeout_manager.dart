import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';

/// Wraps the app to detect user inactivity and auto-logout.
class SessionTimeoutManager extends ConsumerStatefulWidget {
  final Widget child;
  final VoidCallback onTimeout;
  final Duration timeout;

  const SessionTimeoutManager({
    super.key,
    required this.child,
    required this.onTimeout,
    this.timeout = const Duration(minutes: 15),
  });

  @override
  ConsumerState<SessionTimeoutManager> createState() => _SessionTimeoutManagerState();
}

class _SessionTimeoutManagerState extends ConsumerState<SessionTimeoutManager>
    with WidgetsBindingObserver {
  Timer? _timer;
  DateTime _lastReset = DateTime.now();
  DateTime? _backgroundedAt;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resetTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final backgroundedAt = _backgroundedAt;
      _backgroundedAt = null;
      if (backgroundedAt != null &&
          DateTime.now().difference(backgroundedAt) >=
              const Duration(minutes: 5)) {
        _onTimeout();
      } else {
        _resetTimer(force: true);
      }
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _backgroundedAt ??= DateTime.now();
      _timer?.cancel();
      _timer = null;
    }
  }

  void _resetTimer({bool force = false}) {
    final now = DateTime.now();
    if (!force && now.difference(_lastReset).inSeconds < 2) return;
    _lastReset = now;
    _timer?.cancel();
    final user = ref.read(currentUserProvider);
    if (user != null && !_signingOut) {
      _timer = Timer(widget.timeout, _onTimeout);
    }
  }

  void _onUserChanged() {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      _timer?.cancel();
      _timer = null;
      _signingOut = false;
    } else {
      _resetTimer(force: true);
    }
  }

  void _onTimeout() {
    final user = ref.read(currentUserProvider);
    if (user == null || _signingOut) return;
    _signingOut = true;
    _timer?.cancel();
    _timer = null;
    unawaited(signOut(ref));
    if (mounted) widget.onTimeout();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentUserProvider, (_, _) => _onUserChanged());
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetTimer(),
      onPointerMove: (_) => _resetTimer(),
      child: widget.child,
    );
  }
}
