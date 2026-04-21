import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/auth/login_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/customers/customers_screen.dart';
import '../../features/products/products_screen.dart';
import '../../features/newbill/new_bill_screen.dart';
import '../../features/bills/bill_pdf_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authListen = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, __) => authListen.value++);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: authListen,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loggingIn = state.matchedLocation == '/login';
      if (!auth.authenticated) return loggingIn ? null : '/login';
      if (auth.authenticated && loggingIn) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/bills/:id/pdf',
        builder: (_, s) => BillPdfScreen(billId: int.parse(s.pathParameters['id']!)),
      ),
      ShellRoute(
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/customers', builder: (_, __) => const CustomersScreen()),
          GoRoute(path: '/products', builder: (_, __) => const ProductsScreen()),
          GoRoute(path: '/bills/new', builder: (_, __) => const NewBillScreen()),
        ],
      ),
    ],
  );
});
