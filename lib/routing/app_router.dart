import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rounds/features/bills/bill_detail_screen.dart';
import 'package:rounds/features/bills/bill_form_screen.dart';
import 'package:rounds/features/bills/bills_screen.dart';
import 'package:rounds/features/history/history_screen.dart';
import 'package:rounds/features/home/home_screen.dart';
import 'package:rounds/features/settings/settings_screen.dart';

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
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) =>
            shell.goBranch(index, initialLocation: index == shell.currentIndex),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Bills',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
