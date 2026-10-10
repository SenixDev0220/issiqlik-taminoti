import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/glass.dart';
import '../../core/validators.dart';
import '../../services/firebase_service.dart';
import '../auth/auth_providers.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _loginCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _loginCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final err = Validators.validateLogin(_loginCtrl.text);
    if (err != null) { setState(() => _error = err); return; }

    setState(() { _loading = true; _error = null; });
    final result = await FirebaseService.instance.requestPasswordReset(_loginCtrl.text.trim());
    if (!mounted) return;
    setState(() { _loading = false; });

    if (result == null) {
      setState(() => _sent = true);
    } else {
      setState(() => _error = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    return GlassScaffold(
      title: l.forgotPassword,
      leading: BackButton(onPressed: () => context.go('/login')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: _sent ? _buildSuccess(l) : _buildForm(l),
      ),
    );
  }

  Widget _buildSuccess(dynamic l) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const GlassIconTile(icon: Icons.check_circle_outline, color: AppTheme.success, size: 72),
        const SizedBox(height: 16),
        Text(
          l.requestSent,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.ink),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(onPressed: () => context.go('/login'), child: Text(l.loginButton)),
        ),
      ],
    );
  }

  Widget _buildForm(dynamic l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.forgotPasswordHint,
          style: const TextStyle(fontSize: 14, color: AppTheme.inkSoft),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _loginCtrl,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(labelText: l.loginLabel, prefixIcon: const Icon(Icons.person_outline)),
        ),
        if (_error != null) Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 13)),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(l.resetButton),
        ),
      ],
    );
  }
}
