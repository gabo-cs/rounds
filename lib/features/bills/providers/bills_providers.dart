import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rounds/data/database/app_database.dart';
import 'package:rounds/data/repositories/bill_instances_repository.dart';
import 'package:rounds/features/home/providers/home_providers.dart';

final billDetailProvider =
    StreamProvider.family<Bill?, int>((ref, billId) {
  return ref.watch(billsRepositoryProvider).watchBillById(billId);
});

final billInstancesForBillProvider =
    StreamProvider.family<List<BillInstanceWithBill>, int>((ref, billId) {
  return ref
      .watch(billInstancesRepositoryProvider)
      .watchInstancesForBill(billId);
});
