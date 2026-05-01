// Top-level Riverpod providers for cross-cutting dependencies.
//
// This file wires AuthStorage → ApiClient → repositories. Any widget or
// controller that needs to talk to the backend should `ref.watch` one of
// the repo providers here instead of constructing its own client.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api/api_client.dart';
import 'auth/auth_storage.dart';
import '../data/repositories/auth_repo.dart';
import '../data/repositories/bill_repo.dart';
import '../data/repositories/customer_repo.dart';
import '../data/repositories/do_repo.dart';
import '../data/repositories/product_repo.dart';

/// Provides persistent auth storage (JWT token, role, user id).
final authStorageProvider = Provider<AuthStorage>((ref) => AuthStorage());

/// Dio-based HTTP client wired to [AuthStorage] so every request carries
/// the current bearer token automatically.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(authStorageProvider));
});

// Repositories — thin wrappers around [ApiClient] exposing domain methods.
final authRepoProvider = Provider<AuthRepo>((ref) => AuthRepo(ref.watch(apiClientProvider)));
final customerRepoProvider = Provider<CustomerRepo>((ref) => CustomerRepo(ref.watch(apiClientProvider)));
final productRepoProvider = Provider<ProductRepo>((ref) => ProductRepo(ref.watch(apiClientProvider)));
final billRepoProvider = Provider<BillRepo>((ref) => BillRepo(ref.watch(apiClientProvider)));
final doRepoProvider = Provider<DORepo>((ref) => DORepo(ref.watch(apiClientProvider)));

/// Bumped by Products screen on any product/variant save/delete; watched by
/// NewBill screen to know when to reload its cached variants list.
final productCatalogVersionProvider = StateProvider<int>((ref) => 0);
