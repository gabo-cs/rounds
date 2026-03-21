import 'package:drift/drift.dart';

class Bills extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  RealColumn get amount => real()();
  IntColumn get dueDayOfMonth => integer()();
  TextColumn get category => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isArchived =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
