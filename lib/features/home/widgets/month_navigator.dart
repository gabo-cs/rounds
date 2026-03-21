import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rounds/features/home/providers/home_providers.dart';
import 'package:rounds/core/extensions/date_extensions.dart';

class MonthNavigator extends ConsumerWidget {
  const MonthNavigator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedMonthProvider);
    final now = DateTime.now();
    final selectedDt = DateTime(selected.year, selected.month);
    final isCurrentMonth =
        selectedDt.isSameMonth(now);

    final label = DateFormat.yMMMM().format(selectedDt);

    return Row(
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
        GestureDetector(
          onTap: isCurrentMonth
              ? null
              : () {
                  ref.read(selectedMonthProvider.notifier).state =
                      SelectedMonth(year: now.year, month: now.month);
                },
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isCurrentMonth
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
            child: Text(label),
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
    );
  }
}
