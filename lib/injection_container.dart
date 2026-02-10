import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/schedule/data/schedule_repository.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/inventory/data/repositories/inventory_repository_impl.dart';
import 'features/inventory/domain/repositories/inventory_repository.dart';
import 'features/inventory/domain/usecases/get_inventory_usecase.dart';
import 'features/inventory/domain/usecases/manage_product_usecase.dart';
import 'features/inventory/presentation/cubit/inventory_cubit.dart';
import 'features/inventory/presentation/cubit/product_form_cubit.dart';
import 'features/sales/data/repositories/sales_repository_impl.dart';
import 'features/sales/data/repositories/sales_repository.dart';
import 'features/sales/domain/usecases/register_sale_usecase.dart';
import 'features/sales/presentation/cubit/sales_cubit.dart';

final sl = GetIt.instance;

Future<void> init() async {
  sl.registerLazySingleton(() => FirebaseAuth.instance);
  sl.registerLazySingleton(() => FirebaseFirestore.instance);

  // auth
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepository(auth: sl(), firestore: sl()),
  );
  sl.registerLazySingleton<ScheduleRepository>(
    () => ScheduleRepository(firestore: sl()),
  );

  // inventario
  sl.registerLazySingleton<InventoryRepository>(
    () => InventoryRepositoryImpl(firestore: sl()),
  );
  sl.registerLazySingleton(() => ManageProductUseCase(sl()));
  sl.registerLazySingleton(() => GetInventoryUseCase(sl()));
  sl.registerFactory(() => InventoryCubit(sl()));
  sl.registerFactory(() => ProductFormCubit(sl()));

  // Presentacion
  sl.registerFactory(() => AuthCubit(sl()));

  // ventas
  sl.registerLazySingleton<SalesRepository>(
    () => SalesRepositoryImpl(firestore: sl()),
  );
  sl.registerLazySingleton(() => RegisterSaleUseCase(sl()));
  sl.registerFactory(() => SalesCubit(sl(), sl()));
}
