import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/admin_cubit.dart';
import '../cubit/admin_state.dart';
import '../tabs/admin_calendar_tab.dart';
import '../tabs/admin_generator_tab.dart';
import '../tabs/admin_types_tab.dart';
import '../../../../injection_container.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AdminCubit>()..loadFormData(checkSchedule: true),
      child: const _AdminView(),
    );
  }
}

class _AdminView extends StatefulWidget {
  const _AdminView();

  @override
  State<_AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<_AdminView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  AdminLoadedData? _lastLoadedData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestión de Horarios"),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.red,
          labelColor: Colors.red,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.calendar_month), text: "Calendario"),
            Tab(icon: Icon(Icons.edit_calendar), text: "Horarios"),
            Tab(icon: Icon(Icons.sports_mma_outlined), text: "Clases"),
          ],
        ),
      ),
      body: BlocConsumer<AdminCubit, AdminState>(
        listener: (context, state) {
          if (state is AdminOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
            context.read<AdminCubit>().loadFormData(silent: true);
          }
          if (state is AdminError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is AdminLoadedData) {
            _lastLoadedData = state;
          } else if (state is AdminConflictDetected) {
            _lastLoadedData = state.originalData;
          }

          if (_lastLoadedData == null) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.red),
            );
          }

          return Stack(
            children: [
              TabBarView(
                controller: _tabController,
                children: [
                  const AdminCalendarTab(),
                  AdminGeneratorTab(data: _lastLoadedData!),
                  AdminTypesTab(data: _lastLoadedData!),
                ],
              ),
              if (state is AdminLoading)
                Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.red),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
