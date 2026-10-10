import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/glass.dart';
import '../../core/validators.dart';
import '../auth/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  String? _error;
  bool _isPending = false;
  bool _loading = false;
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;

  @override
  void dispose() {
    _loginCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  bool get _isLockedOut =>
      _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);

  Future<void> _submit() async {
    if (_isLockedOut) {
      final remaining = _lockoutUntil!.difference(DateTime.now()).inSeconds;
      setState(() => _error = ref.read(l10nProvider).lockoutMessage(remaining));
      return;
    }
    setState(() { _error = null; _isPending = false; });
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    final l = ref.read(l10nProvider);
    final login = Validators.sanitize(_loginCtrl.text);
    final error = await attemptLogin(ref, login, _passCtrl.text.trim());
    if (!mounted) return;
    setState(() => _loading = false);

    if (error == null) {
      _failedAttempts = 0;
      context.go('/home');
    } else {
      _failedAttempts++;
      if (_failedAttempts >= 5) {
        final seconds = (30 * (_failedAttempts ~/ 5)).clamp(30, 300);
        _lockoutUntil = DateTime.now().add(Duration(seconds: seconds));
      }
      setState(() {
        _error = error;
        _isPending = error == l.loginPendingError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final statusColor = _isPending ? AppTheme.warning : AppTheme.error;
    return GlassScaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Container(
                    width: 92,
                    height: 92,
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
                  const SizedBox(height: 20),
                  Text(
                    l.loginTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.loginSubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: AppTheme.inkSoft),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _loginCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(labelText: l.loginLabel, hintText: l.loginHint, prefixIcon: const Icon(Icons.person_outline)),
                    validator: (v) => (v == null || v.trim().isEmpty) ? l.loginEmptyError : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: l.passwordLabel,
                      hintText: l.passwordHint,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? l.passwordEmptyError : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: statusColor.withValues(alpha: 0.30)),
                      ),
                      child: Row(children: [
                        Icon(_isPending ? Icons.hourglass_top : Icons.error_outline,
                            color: statusColor, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: TextStyle(color: statusColor, fontSize: 13.5))),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(l.loginButton),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => context.push('/forgot-password'),
                    child: Text(l.forgotPassword, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      Text(l.noAccount, style: const TextStyle(color: AppTheme.inkSoft)),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => context.push('/register'),
                        child: Text(l.registerLink, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
