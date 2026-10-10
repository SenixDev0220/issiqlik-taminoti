import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/glass.dart';
import '../../domain/models/app_user.dart';
import '../../services/firebase_service.dart';
import '../auth/auth_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final lang = ref.watch(selectedLanguageProvider);
    final l = ref.watch(l10nProvider);

    return GlassScaffold(
      title: l.profileTitle,
      leading: BackButton(onPressed: () => context.go('/home')),
      tab: AppTab.profile,
      body: user == null
          ? Center(child: Text(l.profileNotFound))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, kBottomNavSpace),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: GestureDetector(
                      onTap: () => _pickProfilePhoto(context, ref, user),
                      child: Stack(
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.45),
                              border: Border.all(color: AppTheme.glassBorder, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withValues(alpha: 0.18),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.primary.withValues(alpha: 0.12),
                                image: user.photoUrl.isNotEmpty
                                    ? DecorationImage(
                                        image: ResizeImage(
                                          NetworkImage(user.photoUrl),
                                          width: (90 * MediaQuery.devicePixelRatioOf(context)).round(),
                                          height: (90 * MediaQuery.devicePixelRatioOf(context)).round(),
                                        ),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: user.photoUrl.isEmpty
                                  ? Center(
                                      child: Text(
                                        user.initials,
                                        style: const TextStyle(
                                          fontSize: 30,
                                          color: AppTheme.primary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: const Icon(Icons.camera_alt, size: 13, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    user.fullName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (user.position.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      user.position,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.inkSoft),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Center(child: StatusChip(label: _roleLabel(user.role, l), color: _roleColor(user.role))),
                  const SizedBox(height: 24),

                  Text(l.profileInfo, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _InfoTile(icon: Icons.alternate_email, label: l.profileLogin, value: user.login),
                        const Divider(indent: 16, endIndent: 16),
                        _InfoTile(icon: Icons.phone_outlined, label: l.profilePhone, value: user.phone),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const GlassIconTile(icon: Icons.translate, size: 40),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(l.profileLanguage, style: Theme.of(context).textTheme.titleMedium),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<String>(
                          segments: [
                            ButtonSegment(value: 'uz_cyrl', label: Text(l.profileLangCyrl)),
                            ButtonSegment(value: 'uz_latin', label: Text(l.profileLangLatin)),
                          ],
                          selected: {lang},
                          onSelectionChanged: (s) {
                            ref.read(selectedLanguageProvider.notifier).state = s.first;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l.profileLangChanged), duration: const Duration(seconds: 1)),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  GlassCard(
                    onTap: () => _showChangePassword(context, ref, l),
                    child: Row(
                      children: [
                        const GlassIconTile(icon: Icons.lock_outline, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(l.profileChangePassword, style: Theme.of(context).textTheme.titleMedium),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: AppTheme.inkFaint),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  GlassCard(
                    tint: AppTheme.error,
                    onTap: () async {
                      await signOut(ref);
                      if (context.mounted) context.go('/login');
                    },
                    child: Row(
                      children: [
                        const GlassIconTile(icon: Icons.exit_to_app, size: 40, color: AppTheme.error),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l.profileLogout,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: AppTheme.error),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: AppTheme.error),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  GlassCard(
                    tint: AppTheme.error,
                    onTap: () => _confirmDeleteAccount(context, ref),
                    child: Row(
                      children: [
                        const GlassIconTile(icon: Icons.delete_forever_outlined, size: 40, color: AppTheme.error),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l.deleteAccount,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: AppTheme.error),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: AppTheme.error),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _showChangePassword(BuildContext context, WidgetRef ref, dynamic l) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _ChangePasswordSheet(),
    );
  }

  Future<void> _pickProfilePhoto(BuildContext context, WidgetRef ref, AppUser user) async {
    final l = ref.read(l10nProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.photoUploadUnavailable), duration: const Duration(seconds: 2)),
    );
  }

  void _confirmDeleteAccount(BuildContext context, WidgetRef ref) {
    final l = ref.read(l10nProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 48),
        title: Text(l.deleteAccount),
        content: Text(l.deleteAccountConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final error = await FirebaseService.instance.deleteAccount(ref.read(currentUserProvider)!.id);
              if (error != null) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error), backgroundColor: AppTheme.error),
                  );
                }
                return;
              }
              await signOut(ref);
              if (context.mounted) context.go('/login');
            },
            child: Text(l.journalDelete),
          ),
        ],
      ),
    );
  }

  Color _roleColor(UserRole r) {
    switch (r) {
      case UserRole.admin: return AppTheme.primary;
      case UserRole.coAdmin: return AppTheme.accent;
      case UserRole.member: return AppTheme.inkFaint;
    }
  }

  String _roleLabel(UserRole r, dynamic l) {
    switch (r) {
      case UserRole.admin: return l.roleAdmin;
      case UserRole.coAdmin: return l.roleCoAdmin;
      case UserRole.member: return l.roleMember;
    }
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          GlassIconTile(icon: icon, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: AppTheme.inkFaint, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Change password sheet ─────────────────────────────────────────
class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet();

  @override
  ConsumerState<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    final l = ref.read(l10nProvider);

    final error = await changePassword(
      currentPassword: _currentCtrl.text.trim(),
      newPassword: _newCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      setState(() => _error = error);
      return;
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.passwordChanged), backgroundColor: AppTheme.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 12, 24, bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.inkFaint.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l.profileChangePassword,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.ink),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _currentCtrl,
                obscureText: _obscureCurrent,
                decoration: InputDecoration(
                  labelText: l.passwordCurrent,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty) ? l.fieldRequired : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _newCtrl,
                obscureText: _obscureNew,
                decoration: InputDecoration(
                  labelText: l.passwordNew,
                  prefixIcon: const Icon(Icons.lock_open_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return l.fieldRequired;
                  if (v.length < 6) return l.passwordMinLength;
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _confirmCtrl,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: l.confirmPasswordLabel,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return l.fieldRequired;
                  if (v != _newCtrl.text) return l.passwordMismatch;
                  return null;
                },
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.error.withValues(alpha: 0.25)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 13))),
                  ]),
                ),
              ],
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(l.save),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
