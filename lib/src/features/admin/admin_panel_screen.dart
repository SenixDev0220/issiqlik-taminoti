import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/app_theme.dart';
import '../../core/glass.dart';
import '../../core/l10n.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/audit_entry.dart';
import '../../domain/models/boiler_house.dart';
import '../../domain/models/drawing.dart';
import '../../domain/models/instruction.dart';
import '../../services/firebase_service.dart';
import '../auth/auth_providers.dart';
import '../boilerhouse/boilerhouse_providers.dart';
import '../drawings/drawings_providers.dart';
import '../instructions/instructions_providers.dart';

part 'admin_users_tab.dart';
part 'admin_entities_tab.dart';
part 'admin_activity_tab.dart';
part 'admin_form_support.dart';
part 'admin_boiler_form.dart';
part 'admin_document_forms.dart';

final _fb = FirebaseService.instance;

bool _isAdmin(AppUser? user) => user?.status == UserStatus.active && user?.role == UserRole.admin;
bool _canManage(AppUser? user) => user?.status == UserStatus.active &&
    (user?.role == UserRole.admin || user?.role == UserRole.coAdmin);

class AdminPanelScreen extends ConsumerStatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this)..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final l = ref.watch(l10nProvider);
    if (!_canManage(user)) {
      return GlassScaffold(
        title: l.adminTitle,
        leading: BackButton(onPressed: () => context.go('/home')),
        body: Center(child: Text(l.adminAccessDenied)),
      );
    }
    return GlassScaffold(
      appBar: AppBar(
        title: Text(l.adminTitle),
        leading: BackButton(onPressed: () => context.go('/home')),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: l.adminPendingUsers),
            Tab(text: l.adminUsersList),
            Tab(text: l.navBoilerhouses),
            Tab(text: l.navInstructions),
            Tab(text: l.navDrawings),
            Tab(text: l.auditLogTab),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _PendingTab(),
          _UsersTab(),
          _BoilerhousesTab(),
          _InstructionsTab(),
          _DrawingsTab(),
          _AuditLogTab(),
        ],
      ),
      floatingActionButton: _buildFab(l),
    );
  }

  Widget? _buildFab(AppL10n l) {
    final (String label, Widget sheet)? action = switch (_tabs.index) {
      2 => (l.navBoilerhouses, const _BoilerForm()),
      3 => (l.navInstructions, const _InstructionForm()),
      4 => (l.navDrawings, const _DrawingForm()),
      _ => null,
    };
    if (action == null) return null;
    return FloatingActionButton.extended(
      heroTag: 'admin-add-${_tabs.index}',
      shape: const StadiumBorder(),
      onPressed: () => _showAdminSheet(context, action.$2),
      icon: const Icon(Icons.add),
      label: Text(action.$1),
    );
  }
}

Future<void> _showAdminSheet(BuildContext context, Widget form) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => form,
);
