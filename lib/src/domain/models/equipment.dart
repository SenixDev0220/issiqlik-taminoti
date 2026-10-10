import 'package:flutter/material.dart';

import '../../core/l10n.dart';

enum EquipmentStatus { operating, standby, maintenance, decommissioned }

enum EquipmentType { boiler, pump, heatExchanger, burner, expansionTank, other }

extension EquipmentStatusX on EquipmentStatus {
  String label(AppL10n l) {
    switch (this) {
      case EquipmentStatus.operating:
        return l.eqStatusOperating;
      case EquipmentStatus.standby:
        return l.eqStatusStandby;
      case EquipmentStatus.maintenance:
        return l.eqStatusMaintenance;
      case EquipmentStatus.decommissioned:
        return l.eqStatusDecommissioned;
    }
  }

  Color get color {
    switch (this) {
      case EquipmentStatus.operating:
        return const Color(0xFF4CAF50);
      case EquipmentStatus.standby:
        return const Color(0xFF2196F3);
      case EquipmentStatus.maintenance:
        return const Color(0xFFFFC107);
      case EquipmentStatus.decommissioned:
        return const Color(0xFF9E9E9E);
    }
  }
}

extension EquipmentTypeX on EquipmentType {
  String label(AppL10n l) {
    switch (this) {
      case EquipmentType.boiler:
        return l.eqTypeBoiler;
      case EquipmentType.pump:
        return l.eqTypePump;
      case EquipmentType.heatExchanger:
        return l.eqTypeHeatExchanger;
      case EquipmentType.burner:
        return l.eqTypeBurner;
      case EquipmentType.expansionTank:
        return l.eqTypeExpansionTank;
      case EquipmentType.other:
        return l.eqTypeOther;
    }
  }
}

class Equipment {
  final String id;
  final String boilerHouseId;
  final EquipmentType type;
  final String name;
  final String model;
  final String manufacturer;
  final String serialNumber;
  final String inventoryNumber;
  final DateTime productionDate;
  final DateTime installedDate;
  final EquipmentStatus status;
  final DateTime lastServiceDate;
  final DateTime nextServiceDate;
  final String responsiblePersonId;
  final Map<String, dynamic> technicalParameters;
  final List<String> photoPaths;
  final String notes;

  const Equipment({
    required this.id,
    required this.boilerHouseId,
    required this.type,
    required this.name,
    required this.model,
    required this.manufacturer,
    required this.serialNumber,
    required this.inventoryNumber,
    required this.productionDate,
    required this.installedDate,
    required this.status,
    required this.lastServiceDate,
    required this.nextServiceDate,
    required this.responsiblePersonId,
    this.technicalParameters = const {},
    this.photoPaths = const [],
    this.notes = '',
  });
}
