import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../schedule/domain/models/class_model.dart';
import '../../../../core/constants/enums.dart';

class AdminClassCard extends StatelessWidget {
  final ClassModel classModel;
  final VoidCallback onTap;

  const AdminClassCard({
    super.key,
    required this.classModel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeFormat = DateFormat('h:mm a');
    final startTime = timeFormat.format(classModel.startTime);
    final endTime = timeFormat.format(classModel.endTime);

    final isCancelled = classModel.isCancelled;
    final isExpired = classModel.hasFinished;
    final enrolledCount = classModel.attendees.length;
    final maxCap = classModel.maxCapacity;
    final isFull = enrolledCount >= maxCap;
    
    final occupationColor = isFull ? Colors.red : (enrolledCount > 0 ? Colors.green : Colors.grey);
    
    final cardColor = isCancelled 
        ? Colors.red.withValues(alpha: 0.05)
        : (isExpired ? Colors.grey.withValues(alpha: 0.1) : (isDark ? const Color(0xFF1E1E1E) : Colors.white));
        
    final textColor = isCancelled || isExpired ? Colors.grey : (isDark ? Colors.white : Colors.black87);
    final decoration = isCancelled ? TextDecoration.lineThrough : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Columna Hora
                  Column(
                    children: [
                      Text(
                        startTime, 
                        style: TextStyle(
                          fontSize: 16, 
                          fontWeight: FontWeight.bold, 
                          color: textColor,
                          decoration: decoration,
                        )
                      ),
                      Text(
                        endTime, 
                        style: TextStyle(
                          fontSize: 12, 
                          color: isDark ? Colors.grey : Colors.grey[600],
                          decoration: decoration,
                        )
                      ),
                      if (isCancelled)
                        const Text("CANCELADA", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(width: 16),
                  
                  Container(height: 40, width: 2, color: occupationColor.withValues(alpha: 0.3)),
                  const SizedBox(width: 16),
                  
                  // Detalles clase
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              classModel.classType.toUpperCase(),
                              style: TextStyle(
                                fontSize: 16, 
                                fontWeight: FontWeight.w900, 
                                fontStyle: FontStyle.italic, 
                                color: textColor,
                                decoration: decoration,
                              )
                            ),
                            const SizedBox(width: 8),
                            // Categoría
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isCancelled ? Colors.red.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isCancelled ? Colors.red.withValues(alpha: 0.3) : Colors.blue.withValues(alpha: 0.3)
                                ),
                              ),
                              child: Text(
                                classModel.category.label.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9, 
                                  fontWeight: FontWeight.bold,
                                  color: isCancelled ? Colors.red : Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.person, size: 14, color: isDark ? Colors.grey : Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              classModel.coachName, 
                              style: TextStyle(fontSize: 13, color: isDark ? Colors.grey : Colors.grey[700])
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: occupationColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: occupationColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '$enrolledCount / $maxCap INSCRITOS',
                            style: TextStyle(
                              fontSize: 10, 
                              color: occupationColor,
                              fontWeight: FontWeight.bold
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  Icon(Icons.edit, color: Colors.grey[400], size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}