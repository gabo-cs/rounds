import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:rounds/data/database/app_database.dart';
import 'package:rounds/data/repositories/bill_instances_repository.dart';

const _backupVersion = 1;

class BackupService {
  BackupService(this._repo);

  final BillInstancesRepository _repo;

  Future<void> exportAndShare() async {
    final bills = await _repo.getAllBills();
    final instances = await _repo.getAllInstances();

    final payload = {
      'version': _backupVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'bills': bills.map(_billToJson).toList(),
      'billInstances': instances.map(_instanceToJson).toList(),
    };

    final json = const JsonEncoder.withIndent('  ').convert(payload);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/rounds_backup_${_timestamp()}.json');
    await file.writeAsString(json);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'Rounds backup',
    );
  }

  /// Returns null on success, or an error message string.
  Future<String?> importFromFile(String filePath) async {
    try {
      final content = await File(filePath).readAsString();
      final dynamic decoded = jsonDecode(content);

      if (decoded is! Map<String, dynamic>) {
        return 'Invalid backup file format.';
      }

      final version = decoded['version'] as int?;
      if (version == null || version > _backupVersion) {
        return 'Unsupported backup version.';
      }

      final rawBills = decoded['bills'] as List<dynamic>?;
      final rawInstances = decoded['billInstances'] as List<dynamic>?;

      if (rawBills == null || rawInstances == null) {
        return 'Backup file is missing required data.';
      }

      final bills = rawBills
          .cast<Map<String, dynamic>>()
          .map(_billFromJson)
          .toList();
      final instances = rawInstances
          .cast<Map<String, dynamic>>()
          .map(_instanceFromJson)
          .toList();

      await _repo.replaceAllData(bills: bills, instances: instances);
      return null;
    } on FormatException {
      return 'Could not parse backup file — invalid JSON.';
    } on FileSystemException catch (e) {
      return 'Could not read file: ${e.message}';
    } catch (e) {
      return 'Import failed: $e';
    }
  }

  // --- Serialization ---

  Map<String, dynamic> _billToJson(Bill b) => {
        'id': b.id,
        'name': b.name,
        'amount': b.amount,
        'dueDayOfMonth': b.dueDayOfMonth,
        'category': b.category,
        'notes': b.notes,
        'isArchived': b.isArchived,
        'createdAt': b.createdAt.toUtc().toIso8601String(),
        'updatedAt': b.updatedAt.toUtc().toIso8601String(),
      };

  BillsCompanion _billFromJson(Map<String, dynamic> m) => BillsCompanion(
        id: Value(m['id'] as int),
        name: Value(m['name'] as String),
        amount: Value((m['amount'] as num).toDouble()),
        dueDayOfMonth: Value(m['dueDayOfMonth'] as int),
        category: Value(m['category'] as String?),
        notes: Value(m['notes'] as String?),
        isArchived: Value(m['isArchived'] as bool? ?? false),
        createdAt: Value(DateTime.parse(m['createdAt'] as String)),
        updatedAt: Value(DateTime.parse(m['updatedAt'] as String)),
      );

  Map<String, dynamic> _instanceToJson(BillInstance i) => {
        'id': i.id,
        'billId': i.billId,
        'year': i.year,
        'month': i.month,
        'isPaid': i.isPaid,
        'paidAt': i.paidAt?.toUtc().toIso8601String(),
        'paymentMethod': i.paymentMethod,
        'referenceNote': i.referenceNote,
        'createdAt': i.createdAt.toUtc().toIso8601String(),
        'updatedAt': i.updatedAt.toUtc().toIso8601String(),
      };

  BillInstancesCompanion _instanceFromJson(Map<String, dynamic> m) =>
      BillInstancesCompanion(
        id: Value(m['id'] as int),
        billId: Value(m['billId'] as int),
        year: Value(m['year'] as int),
        month: Value(m['month'] as int),
        isPaid: Value(m['isPaid'] as bool? ?? false),
        paidAt: Value(
          m['paidAt'] != null ? DateTime.parse(m['paidAt'] as String) : null,
        ),
        paymentMethod: Value(m['paymentMethod'] as String?),
        referenceNote: Value(m['referenceNote'] as String?),
        createdAt: Value(DateTime.parse(m['createdAt'] as String)),
        updatedAt: Value(DateTime.parse(m['updatedAt'] as String)),
      );

  String _timestamp() {
    final now = DateTime.now();
    return '${now.year}${_pad(now.month)}${_pad(now.day)}_'
        '${_pad(now.hour)}${_pad(now.minute)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
