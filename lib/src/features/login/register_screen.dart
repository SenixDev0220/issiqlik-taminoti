import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/glass.dart';
import '../../core/validators.dart';
import '../auth/auth_providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _loginCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _loginCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final l = ref.read(l10nProvider);
    final error = await registerUser(
      ref,
      login: Validators.sanitize(_loginCtrl.text),
      password: _passCtrl.text.trim(),
      firstName: Validators.sanitize(_firstNameCtrl.text),
      lastName: Validators.sanitize(_lastNameCtrl.text),
      phone: Validators.sanitize(_phoneCtrl.text),
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: AppTheme.error));
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: AppTheme.success, size: 48),
        title: Text(l.registerTitle),
        content: Text(l.registerSuccess),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/login');
            },
            child: Text(l.loginButton),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    return GlassScaffold(
      title: l.registerTitle,
      leading: BackButton(onPressed: () => context.go('/login')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.registerSubtitle, style: const TextStyle(fontSize: 14, color: AppTheme.inkSoft)),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameCtrl,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(labelText: l.firstNameLabel, hintText: l.firstNameHint, prefixIcon: const Icon(Icons.person_outline)),
                      validator: Validators.validateName,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameCtrl,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(labelText: l.lastNameLabel, hintText: l.lastNameHint),
                      validator: Validators.validateName,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _loginCtrl,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l.loginLabel, hintText: l.loginHint, prefixIcon: const Icon(Icons.alternate_email)),
                validator: Validators.validateLogin,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _phoneCtrl,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: l.phoneLabel, hintText: l.phoneHint, prefixIcon: const Icon(Icons.phone_outlined)),
                validator: Validators.validatePhone,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _passCtrl,
                obscureText: _obscurePass,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l.passwordLabel,
                  hintText: l.passwordHint,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _obscurePass = !_obscurePass),
                  ),
                ),
                validator: Validators.validatePassword,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _confirmPassCtrl,
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: l.confirmPasswordLabel,
                  hintText: l.confirmPasswordHint,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return l.fieldRequired;
                  if (v.trim() != _passCtrl.text.trim()) return l.passwordMismatch;
                  return null;
                },
              ),
              const SizedBox(height: 28),

              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(l.registerButton),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l.alreadyHaveAccount, style: const TextStyle(color: AppTheme.inkSoft)),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => context.go('/login'),
                    child: Text(l.loginLink, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
