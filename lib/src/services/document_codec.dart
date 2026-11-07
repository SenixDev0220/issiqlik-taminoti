import 'package:cloud_firestore/cloud_firestore.dart';

/// Boundary validation for untrusted Firestore values. Invalid records are
/// reported and omitted individually; identity/permission values never default.
class DocumentFields {
  DocumentFields(this.data);
  final Map<String, dynamic> data;

  String string(String key, {String fallback = '', bool required = false, int max = 100000}) {
    final value = data[key];
    if (value == null && !required) return fallback;
    if (value is! String || value.length > max || (required && value.trim().isEmpty)) {
      throw const FormatException('Invalid document text');
    }
    return value;
  }

  num number(String key, {num fallback = 0, bool integer = false}) {
    final value = data[key];
    if (value == null) return fallback;
    if (value is! num || !value.isFinite || (integer && value != value.roundToDouble())) {
      throw const FormatException('Invalid document number');
    }
    return integer ? value.toInt() : value;
  }

  bool boolean(String key, {bool fallback = false}) {
    final value = data[key];
    if (value == null) return fallback;
    if (value is! bool) throw const FormatException('Invalid document boolean');
    return value;
  }

  Timestamp date(String key, {Timestamp? fallback}) {
    final value = data[key];
    if (value == null && fallback != null) return fallback;
    if (value is! Timestamp) throw const FormatException('Invalid document timestamp');
    return value;
  }

  List<String> strings(String key, {int max = 100, bool required = false}) {
    final value = data[key];
    if (value == null && !required) return const [];
    if (value is! List || value.length > max || value.any((element) => element is! String)) {
      throw const FormatException('Invalid document list');
    }
    return List<String>.unmodifiable(value.cast<String>());
  }

  String choice(String key, List<String> choices, {String? fallback}) {
    final value = string(key, required: fallback == null, fallback: fallback ?? '');
    if (!choices.contains(value)) throw const FormatException('Invalid document enum');
    return value;
  }
}

class BusinessDocumentCodec {
  static const _roles = ['admin', 'coAdmin', 'member'];
  static const _statuses = ['active', 'pending', 'blocked'];

  static Map<String, dynamic> read(String collection, String id, Map<String, dynamic>? data) {
    if (data == null || id.isEmpty) throw const FormatException('Missing document');
    final f = DocumentFields(data);
    final out = <String, dynamic>{};
    void text(String name, {bool required = false, String fallback = ''}) =>
        out[name] = f.string(name, required: required, fallback: fallback);
    void date(String name, {Timestamp? fallback}) => out[name] = f.date(name, fallback: fallback);
    void house() => text('boilerHouseId', required: true);
    switch (collection) {
      case 'users':
      case 'employeeDirectory':
      case 'userProfiles':
        for (final key in ['login', 'firstName', 'lastName', 'phone', 'position']) { text(key); }
        out['photoUrl'] = '';
        out['role'] = f.choice('role', _roles);
        out['status'] = f.choice('status', _statuses);
        out['boilerhouseIds'] = f.strings('boilerhouseIds', max: 30);
      case 'journal':
        house();
        out['equipmentId'] = data['equipmentId'] == null ? null : f.string('equipmentId', max: 128);
        date('eventDateTime');
        date('createdAt');
        date('updatedAt', fallback: out['createdAt'] as Timestamp);
        for (final key in ['category', 'title', 'description', 'authorId', 'authorName']) {
          text(key, required: key == 'title' || key == 'authorId');
        }
        out['importance'] = f.choice('importance', ['normal', 'important', 'critical'], fallback: 'normal');
        out['status'] = f.choice('status', ['open', 'inProgress', 'closed'], fallback: 'open');
      case 'notifications':
        text('recipientId', required: true);
        text('title', required: true);
        text('message');
        out['type'] = f.choice('type', ['emergency', 'important', 'informational', 'system'], fallback: 'informational');
        out['isRead'] = f.boolean('isRead');
        date('createdAt');
        date('sentAt', fallback: out['createdAt'] as Timestamp);
      case 'boilerhouses':
        text('name', required: true);
        for (final key in ['district', 'address', 'consumers', 'dispatchPhone', 'defects', 'locationUrl']) { text(key); }
        for (final key in ['yearBuilt', 'modernizationYear', 'workersCount', 'operatorsCount']) {
          out[key] = f.number(key, integer: true);
        }
        for (final key in ['totalArea', 'installedCapacity', 'connectedLoad', 'pipelineLength', 'annualElectricity', 'annualWater', 'annualGas', 'annualHeatProduction', 'aboveGroundPipeline', 'belowGroundPipeline']) {
          out[key] = f.number(key);
        }
        out['status'] = f.choice('status', ['operating', 'maintenance', 'emergencyShutdown', 'mothballed'], fallback: 'operating');
      case 'equipment':
        house(); text('name', required: true);
        for (final key in ['model', 'manufacturer', 'serialNumber', 'inventoryNumber', 'responsiblePersonId', 'notes']) { text(key); }
        for (final key in ['productionDate', 'installedDate', 'lastServiceDate', 'nextServiceDate']) { date(key); }
        out['type'] = f.choice('type', ['boiler', 'pump', 'heatExchanger', 'burner', 'expansionTank', 'other'], fallback: 'other');
        out['status'] = f.choice('status', ['operating', 'standby', 'maintenance', 'decommissioned'], fallback: 'operating');
      case 'instructions':
        text('title', required: true);
        for (final key in ['category', 'body', 'authorId']) { text(key); }
        text('version', fallback: '1.0');
        date('createdAt'); date('updatedAt', fallback: out['createdAt'] as Timestamp);
        out['urgency'] = f.choice('urgency', ['normal', 'mandatory'], fallback: 'normal');
      case 'drawings':
        house(); text('title', required: true);
        for (final key in ['number', 'category', 'description', 'filePath', 'authorId']) { text(key); }
        date('addedAt');
      case 'changeLogs':
        house(); text('title', required: true);
        for (final key in ['text', 'authorId', 'authorName']) { text(key); }
        out['photoUrls'] = f.strings('photoUrls', max: 20);
        date('createdAt');
      case 'reactions':
        for (final key in ['changeLogId', 'text', 'authorId', 'authorName']) { text(key); }
        date('createdAt');
      case 'shifts':
        house();
        for (final key in ['boilerHouseName', 'operatorId', 'operatorName', 'note', 'createdBy']) { text(key); }
        date('date'); date('createdAt');
        out['type'] = f.choice('type', ['day', 'night']);
      case 'audit_log':
        for (final key in ['userId', 'userName', 'targetType', 'targetId', 'targetName']) { text(key); }
        out['action'] = f.choice('action', ['add', 'edit', 'delete', 'ban', 'unban', 'approve', 'decline', 'changeRole']);
        date('createdAt');
      default:
        throw const FormatException('Unsupported document collection');
    }
    return out;
  }
}
