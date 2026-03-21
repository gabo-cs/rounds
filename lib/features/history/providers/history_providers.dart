import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rounds/data/repositories/bill_instances_repository.dart';
import 'package:rounds/features/home/providers/home_providers.dart';

final historyMonthsProvider = StreamProvider<List<MonthSummary>>((ref) {
  return ref.watch(billInstancesRepositoryProvider).watchAllMonthSummaries();
});
