import 'package:flutter/material.dart';

import '../../core/l10n.dart';

enum BoilerHouseStatus { operating, maintenance, emergencyShutdown, mothballed }

class BoilerHouse {
  final String id;
  final String name;
  final String district;
  final String address;
  final int yearBuilt;
  final int modernizationYear;
  final double totalArea;
  final int workersCount;
  final int operatorsCount;
  final double installedCapacity;
  final double connectedLoad;
  final String consumers;
  final double pipelineLength;
  final String dispatchPhone;
  final double annualElectricity;
  final double annualWater;
  final double annualGas;
  final double annualHeatProduction;
  final double aboveGroundPipeline;
  final double belowGroundPipeline;
  final String defects;
  final String locationUrl;
  final BoilerHouseStatus status;

  const BoilerHouse({
    required this.id,
    required this.name,
    this.district = '',
    required this.address,
    this.yearBuilt = 0,
    this.modernizationYear = 0,
    this.totalArea = 0,
    this.workersCount = 0,
    this.operatorsCount = 0,
    this.installedCapacity = 0,
    this.connectedLoad = 0,
    this.consumers = '',
    this.pipelineLength = 0,
    this.dispatchPhone = '',
    this.annualElectricity = 0,
    this.annualWater = 0,
    this.annualGas = 0,
    this.annualHeatProduction = 0,
    this.aboveGroundPipeline = 0,
    this.belowGroundPipeline = 0,
    this.defects = '',
    this.locationUrl = '',
    this.status = BoilerHouseStatus.operating,
  });
}

extension BoilerHouseStatusX on BoilerHouseStatus {
  String label(AppL10n l) {
    switch (this) {
      case BoilerHouseStatus.operating:
        return l.statusOperating;
      case BoilerHouseStatus.maintenance:
        return l.statusMaintenance;
      case BoilerHouseStatus.emergencyShutdown:
        return l.statusEmergency;
      case BoilerHouseStatus.mothballed:
        return l.statusMothballed;
    }
  }

  Color get color {
    switch (this) {
      case BoilerHouseStatus.operating:
        return const Color(0xFF2E7D32);
      case BoilerHouseStatus.maintenance:
        return const Color(0xFFF9A825);
      case BoilerHouseStatus.emergencyShutdown:
        return const Color(0xFFC62828);
      case BoilerHouseStatus.mothballed:
        return const Color(0xFF757575);
    }
  }
}
