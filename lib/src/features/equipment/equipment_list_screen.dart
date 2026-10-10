import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/glass.dart';
import '../../domain/models/equipment.dart';
import '../auth/auth_providers.dart';
import 'equipment_providers.dart';

Color _statusColor(EquipmentStatus status) {
  switch (status) {
    case EquipmentStatus.operating:
      return AppTheme.success;
    case EquipmentStatus.standby:
      return AppTheme.accent;
    case EquipmentStatus.maintenance:
      return AppTheme.warning;
    case EquipmentStatus.decommissioned:
      return AppTheme.inkFaint;
  }
}

class EquipmentListScreen extends ConsumerWidget {
  const EquipmentListScreen({super.key, required this.boilerHouseId});

  final String boilerHouseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final equipment = ref.watch(equipmentListProvider(boilerHouseId));
    final l = ref.watch(l10nProvider);

    return GlassScaffold(
      title: l.equipmentTitle,
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: equipment.length,
        addAutomaticKeepAlives: false,
        itemBuilder: (context, index) {
          final eq = equipment[index];
          final statusColor = _statusColor(eq.status);
          return RepaintBoundary(
            child: GlassCard(
              margin: const EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.zero,
              child: ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                backgroundColor: Colors.transparent,
                collapsedBackgroundColor: Colors.transparent,
                iconColor: AppTheme.primary,
                collapsedIconColor: AppTheme.inkFaint,
                tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                leading: GlassIconTile(icon: _iconForType(eq.type), color: statusColor, size: 44),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        eq.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusChip(label: eq.status.label(l), color: statusColor),
                  ],
                ),
                subtitle: Text(eq.type.label(l), style: const TextStyle(fontSize: 12, color: AppTheme.inkSoft)),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Row(label: l.fieldModel, value: eq.model),
                        _Row(label: l.fieldManufacturer, value: eq.manufacturer),
                        _Row(label: l.fieldSerial, value: eq.serialNumber),
                        _Row(label: l.fieldInventory, value: eq.inventoryNumber),
                        _Row(label: l.fieldProductionDate, value: _fmt(eq.productionDate)),
                        _Row(label: l.fieldInstalledDate, value: _fmt(eq.installedDate)),
                        _Row(label: l.fieldResponsible, value: eq.responsiblePersonId),
                        _Row(label: l.fieldLastService, value: _fmt(eq.lastServiceDate)),
                        _Row(label: l.fieldNextService, value: _fmt(eq.nextServiceDate)),
                        if (eq.notes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(eq.notes, style: const TextStyle(color: AppTheme.inkSoft)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _fmt(DateTime d) => '${d.day}.${d.month}.${d.year}';

  IconData _iconForType(EquipmentType type) {
    switch (type) {
      case EquipmentType.boiler:
        return Icons.fireplace;
      case EquipmentType.pump:
        return Icons.water;
      case EquipmentType.heatExchanger:
        return Icons.hub;
      case EquipmentType.burner:
        return Icons.local_fire_department;
      case EquipmentType.expansionTank:
        return Icons.storage;
      case EquipmentType.other:
        return Icons.miscellaneous_services;
    }
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500, color: AppTheme.inkSoft, fontSize: 13)),
          ),
          Expanded(
            flex: 3,
            child: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppTheme.ink)),
          ),
        ],
      ),
    );
  }
}
