import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api/api_client.dart';
import 'auth/auth_storage.dart';
import '../data/repositories/auth_repo.dart';
import '../data/repositories/bill_repo.dart';
import '../data/repositories/customer_repo.dart';
import '../data/repositories/product_repo.dart';

final authStorageProvider = Provider<AuthStorage>((ref) => AuthStorage());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(authStorageProvider));
});

final authRepoProvider = Provider<AuthRepo>((ref) => AuthRepo(ref.watch(apiClientProvider)));
final customerRepoProvider = Provider<CustomerRepo>((ref) => CustomerRepo(ref.watch(apiClientProvider)));
final productRepoProvider = Provider<ProductRepo>((ref) => ProductRepo(ref.watch(apiClientProvider)));
final billRepoProvider = Provider<BillRepo>((ref) => BillRepo(ref.watch(apiClientProvider)));
