import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/schedule/data/schedule_repository.dart';
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
import 'features/plans/data/plan_repository.dart';
import 'features/plans/domain/usecases/assign_plan_and_record_sale_usecase.dart';
import 'features/plans/presentation/cubit/plan_cubit.dart';
import 'features/notifications/data/repositories/notification_repository.dart';
import 'features/notifications/domain/usecases/resolve_plan_request_usecase.dart';
import 'features/notifications/domain/usecases/request_plan_usecase.dart';
import 'features/notifications/presentation/cubit/admin_notification_cubit.dart';
import 'features/notifications/presentation/cubit/client_notification_cubit.dart';
import 'features/reports/data/repositories/reports_repository.dart';
import 'features/reports/domain/usecases/generate_excel_report_usecase.dart';
import 'features/reports/presentation/cubit/report_cubit.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // External
  sl.registerLazySingleton(() => FirebaseAuth.instance);
  sl.registerLazySingleton(() => FirebaseFirestore.instance);

  // Auth
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepository(auth: sl(), firestore: sl()),
  );
  sl.registerFactory(() => AuthCubit(sl()));

  // Schedule
  sl.registerLazySingleton<ScheduleRepository>(
    () => ScheduleRepository(firestore: sl()),
  );

  // Inventario
  sl.registerLazySingleton<InventoryRepository>(
    () => InventoryRepositoryImpl(firestore: sl()),
  );
  sl.registerLazySingleton(() => ManageProductUseCase(sl()));
  sl.registerLazySingleton(() => GetInventoryUseCase(sl()));
  sl.registerFactory(() => InventoryCubit(sl()));
  sl.registerFactory(() => ProductFormCubit(sl()));

  // Ventas
  sl.registerLazySingleton<SalesRepository>(
    () => SalesRepositoryImpl(firestore: sl()),
  );
  sl.registerLazySingleton(() => RegisterSaleUseCase(sl()));
  sl.registerFactory(() => SalesCubit(sl(), sl()));

  // Planes
  sl.registerLazySingleton<PlanRepository>(
    () => PlanRepository(firestore: sl()),
  );
  sl.registerFactory(() => PlanCubit(sl()));

  // Caso de uso compartido (Venta de Servicios/Planes)
  sl.registerLazySingleton(
    () =>
        AssignPlanAndRecordSaleUseCase(salesRepository: sl(), firestore: sl()),
  );

  // NOTIFICACIONES:

  // Repositorio
  sl.registerLazySingleton<NotificationRepository>(
    () => NotificationRepositoryImpl(firestore: sl()),
  );

  // Casos de Uso
  sl.registerLazySingleton(
    () => ResolvePlanRequestUseCase(
      notificationRepository: sl(),
      assignPlanUseCase: sl(),
      authRepository: sl(),
      planRepository: sl(),
    ),
  );

  sl.registerLazySingleton(() => RequestPlanUseCase(sl()));

  // Cubit (Admin Notificaciones)
  sl.registerFactory(
    () => AdminNotificationCubit(
      notificationRepository: sl(),
      resolveUseCase: sl(),
    ),
  );

  // Cubit (Cliente Notificaciones)
  sl.registerFactoryParam<ClientNotificationCubit, String, void>(
    (userId, _) => ClientNotificationCubit(repository: sl(), userId: userId),
  );

  // REPORTES:
  // cubit
  sl.registerFactory(() => ReportCubit(sl()));

  // use cases
  sl.registerLazySingleton(() => GenerateExcelReportUseCase(sl()));

  // repositories
  sl.registerLazySingleton(() => ReportsRepository(firestore: sl()));
}
