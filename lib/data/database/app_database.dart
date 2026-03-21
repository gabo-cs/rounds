import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/bills_table.dart';
import 'tables/bill_instances_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Bills, BillInstances])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(billInstances, billInstances.amountPaid);
          }
          if (from < 3) {
            // Remove NOT NULL constraint on bills.amount by recreating the table.
            // SQLite does not support ALTER COLUMN, so we use the rename trick.
            await customStatement('''
              CREATE TABLE bills_new (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                amount REAL,
                due_day_of_month INTEGER NOT NULL,
                category TEXT,
                notes TEXT,
                is_archived INTEGER NOT NULL DEFAULT 0,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
              )
            ''');
            await customStatement(
                'INSERT INTO bills_new SELECT * FROM bills');
            await customStatement('DROP TABLE bills');
            await customStatement(
                'ALTER TABLE bills_new RENAME TO bills');
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'rounds_db');
  }
}
