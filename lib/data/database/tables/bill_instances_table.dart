import 'package:drift/drift.dart';

import 'bills_table.dart';

class BillInstances extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get billId =>
      integer().references(Bills, #id, onDelete: KeyAction.restrict)();
  IntColumn get year => integer()();
  IntColumn get month => integer()();
  BoolColumn get isPaid =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get paidAt => dateTime().nullable()();
  TextColumn get paymentMethod => text().nullable()();
  TextColumn get referenceNote => text().nullable()();
  RealColumn get amountPaid => real().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {billId, year, month},
      ];
}
