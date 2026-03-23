import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rounds/features/bills/bill_detail_screen.dart';
import 'package:rounds/features/bills/bill_form_screen.dart';
import 'package:rounds/features/bills/bills_screen.dart';
import 'package:rounds/features/history/history_screen.dart';
import 'package:rounds/features/home/home_screen.dart';
import 'package:rounds/features/settings/settings_screen.dart';
import 'package:rounds/l10n/app_localizations.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _ScaffoldWithNav(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/bills-tab',
              builder: (context, state) => const BillsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/history',
              builder: (context, state) => const HistoryScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/bills/new',
      builder: (context, state) => const BillFormScreen(),
    ),
    GoRoute(
      path: '/bills/:billId/edit',
      builder: (context, state) {
        final billId = int.parse(state.pathParameters['billId']!);
        return BillFormScreen(billId: billId);
      },
    ),
    GoRoute(
      path: '/bills/:billId',
      builder: (context, state) {
        final billId = int.parse(state.pathParameters['billId']!);
        return BillDetailScreen(billId: billId);
      },
    ),
  ],
);

class _ScaffoldWithNav extends StatelessWidget {
  const _ScaffoldWithNav({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: _BottomNavBar(
        currentIndex: shell.currentIndex,
        onTap: (index) =>
            shell.goBranch(index, initialLocation: index == shell.currentIndex),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom bottom nav — indicator covers both icon and label
// ---------------------------------------------------------------------------

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _icons = [
    (Icons.home_outlined, Icons.home),
    (Icons.receipt_long_outlined, Icons.receipt_long),
    (Icons.history_outlined, Icons.history),
    (Icons.settings_outlined, Icons.settings),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = [l10n.navHome, l10n.navBills, l10n.navHistory, l10n.navSettings];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final bg = isDark ? const Color(0xFF0A1322) : Colors.white;
    final indicatorColor =
        isDark ? const Color(0xFF1A3A55) : const Color(0xFFD0E8F8);
    final selectedColor = cs.primary;
    final unselectedColor = cs.onSurface.withValues(alpha: 0.4);
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      color: bg,
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: SizedBox(
        height: 72,
        child: Row(
          children: [
            for (int i = 0; i < _icons.length; i++)
              Expanded(
                child: _NavItem(
                  outlinedIcon: _icons[i].$1,
                  filledIcon: _icons[i].$2,
                  label: labels[i],
                  isSelected: currentIndex == i,
                  indicatorColor: indicatorColor,
                  selectedColor: selectedColor,
                  unselectedColor: unselectedColor,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.outlinedIcon,
    required this.filledIcon,
    required this.label,
    required this.isSelected,
    required this.indicatorColor,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  final IconData outlinedIcon;
  final IconData filledIcon;
  final String label;
  final bool isSelected;
  final Color indicatorColor;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: isSelected
              ? BoxDecoration(
                  color: indicatorColor,
                  borderRadius: BorderRadius.circular(14),
                )
              : const BoxDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? filledIcon : outlinedIcon,
                size: 22,
                color: isSelected ? selectedColor : unselectedColor,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.6,
                  color: isSelected ? selectedColor : unselectedColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
