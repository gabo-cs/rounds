import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rounds/core/extensions/date_extensions.dart';
import 'package:rounds/features/home/providers/home_providers.dart';

class MonthNavigator extends ConsumerWidget {
  const MonthNavigator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedMonthProvider);
    final now = DateTime.now();
    final selectedDt = DateTime(selected.year, selected.month);
    final isCurrentMonth =
        selected.year == now.year && selected.month == now.month;

    final label = DateFormat.yMMMM().format(selectedDt);

    void goToCurrent() {
      ref.read(selectedMonthProvider.notifier).state =
          SelectedMonth(year: now.year, month: now.month);
    }

    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Centered nav row — always centered regardless of the Today button
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous month',
                onPressed: () {
                  final prev = selectedDt.previousMonth;
                  ref.read(selectedMonthProvider.notifier).state =
                      SelectedMonth(year: prev.year, month: prev.month);
                },
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next month',
                onPressed: () {
                  final next = selectedDt.nextMonth;
                  ref.read(selectedMonthProvider.notifier).state =
                      SelectedMonth(year: next.year, month: next.month);
                },
              ),
            ],
          ),

          // "Today" link — floated to the right, invisible when already on current month
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isCurrentMonth ? 0 : 1,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton(
                  onPressed: isCurrentMonth ? null : goToCurrent,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: Theme.of(context).textTheme.labelSmall,
                  ),
                  child: const Text('Today'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
