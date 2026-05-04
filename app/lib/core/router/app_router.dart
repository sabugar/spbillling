// GoRouter configuration for the whole application.
//
// Two concerns live here:
//   1. Auth gating — a redirect callback sends logged-out users to
//      `/login` and bounces logged-in users away from `/login` to
//      `/dashboard`. The router re-runs redirect whenever the auth
//      state changes via refreshListenable.
//   2. Route tree — top-level routes (login, PDF previews) sit outside
//      the ShellRoute, while the main navigation lives inside the
//      shell so the sidebar and top bar stay mounted across screens.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/auth/login_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/customers/customers_screen.dart';
import '../../features/products/products_screen.dart';
import '../../features/outlets/outlets_screen.dart';
import '../../features/newbill/new_bill_screen.dart';
import '../../features/bills/bill_pdf_screen.dart';
import '../../features/bills/bills_batch_pdf_screen.dart';
import '../../features/bills/bills_screen.dart';
import '../../features/registers/daily_register_screen.dart';
import '../../features/registers/do_register_screen.dart';

/// Builds the app's [GoRouter], re-evaluating auth redirects on state change.
final routerProvider = Provider<GoRouter>((ref) {
  // A lightweight notifier that bumps whenever the auth controller emits.
  // GoRouter treats this as a signal to re-run [redirect].
  final authListen = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, __) => authListen.value++);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: authListen,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loggingIn = state.matchedLocation == '/login';
      // Not logged in → force login (unless already there).
      if (!auth.authenticated) return loggingIn ? null : '/login';
      // Logged in but on the login page → send to dashboard.
      if (auth.authenticated && loggingIn) return '/dashboard';
      return null;
    },
    routes: [
      // Standalone routes — no shell chrome.
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/bills/:id/pdf',
        builder: (_, s) => BillPdfScreen(billId: int.parse(s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/bills/batch-print',
        builder: (_, s) {
          final qp = s.uri.queryParameters;
          final from = DateTime.parse(qp['from']!);
          final to = DateTime.parse(qp['to']!);
          final format = qp['format'] ?? '9up';
          final doId = int.tryParse(qp['do_id'] ?? '');
          final city = qp['city'];
          final bnFrom = qp['bill_number_from'];
          final bnTo = qp['bill_number_to'];
          return BillsBatchPdfScreen(
            fromDate: from,
            toDate: to,
            format: format,
            doId: doId,
            city: (city == null || city.isEmpty) ? null : city,
            billNumberFrom: (bnFrom == null || bnFrom.isEmpty) ? null : bnFrom,
            billNumberTo: (bnTo == null || bnTo.isEmpty) ? null : bnTo,
          );
        },
      ),
      // Main app shell — sidebar + top bar wrap every child page.
      ShellRoute(
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/customers', builder: (_, __) => const CustomersScreen()),
          GoRoute(path: '/outlets', builder: (_, __) => const OutletsScreen()),
          GoRoute(path: '/products', builder: (_, __) => const ProductsScreen()),
          GoRoute(path: '/bills', builder: (_, __) => const BillsScreen()),
          GoRoute(path: '/bills/new', builder: (_, __) => const NewBillScreen()),
          GoRoute(
              path: '/register/daily',
              builder: (_, __) => const DailyRegisterScreen()),
          GoRoute(
              path: '/register/do',
              builder: (_, __) => const DoRegisterScreen()),
        ],
      ),
    ],
  );
});
