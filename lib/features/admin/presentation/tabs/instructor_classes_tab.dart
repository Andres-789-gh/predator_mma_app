import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../schedule/data/schedule_repository.dart';
import '../../../schedule/domain/models/class_type_model.dart';
import '../../../../core/constants/enums.dart';

class InstructorClassesTab extends StatelessWidget {
  final String coachId;

  const InstructorClassesTab({super.key, required this.coachId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ClassTypeModel>>(
      future: context.read<ScheduleRepository>().getCoachClassTypes(coachId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Error cargando clases:\n${snapshot.error}",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final classes = snapshot.data ?? [];

        if (classes.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sports_mma_outlined, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "Este instructor no tiene\nclases asignadas.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: classes.length,
          itemBuilder: (context, index) {
            final classType = classes[index];

            IconData categoryIcon = Icons.fitness_center;
            Color iconColor = Colors.blueGrey;

            switch (classType.category) {
              case ClassCategory.combat:
                categoryIcon = Icons.sports_mma;
                iconColor = Colors.red;
                break;
              case ClassCategory.conditioning:
                categoryIcon = Icons.fitness_center;
                iconColor = Colors.orange;
                break;
              case ClassCategory.kids:
                categoryIcon = Icons.person;
                iconColor = Colors.green;
                break;
              case ClassCategory.personalized:
                categoryIcon = Icons.person;
                iconColor = Colors.blueGrey;
                break;
              case ClassCategory.virtual:
                categoryIcon = Icons.laptop_chromebook;
                iconColor = Colors.blue;
                break;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  backgroundColor: iconColor.withValues(alpha: 0.1),
                  child: Icon(categoryIcon, color: iconColor),
                ),
                title: Text(
                  classType.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    classType.description.isNotEmpty
                        ? classType.description
                        : "Sin descripción",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                trailing: Text(
                  classType.category.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
