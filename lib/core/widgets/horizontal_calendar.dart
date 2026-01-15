import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HorizontalCalendar extends StatelessWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;
  final int daysCount;

  const HorizontalCalendar({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.daysCount = 8,
  });

  @override
  Widget build(BuildContext context) {
    // control de tema oscuro
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedColor = Colors.red;
    final unselectedTextColor = isDark ? Colors.white70 : Colors.black54;
    final monthFormat = DateFormat('MMMM yyyy', 'es');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // nombre del mes
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: Text(
            toBeginningOfSentenceCase(monthFormat.format(selectedDate)) ?? '',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87
            ),
          ),
        ),
        const SizedBox(height: 10),
        
        // tira de fechas
        SizedBox(
          height: 85,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: daysCount,
            itemBuilder: (context, index) {
              final date = DateTime.now().add(Duration(days: index));
              
              final isSelected = date.day == selectedDate.day && 
                                 date.month == selectedDate.month &&
                                 date.year == selectedDate.year;
              
              final dayName = DateFormat('E', 'es').format(date).toUpperCase().replaceAll('.', '');
              final dayNumber = date.day.toString();

              return GestureDetector(
                onTap: () => onDateSelected(date),
                child: Container(
                  width: 60,
                  margin: EdgeInsets.only(
                    left: index == 0 ? 20 : 5,
                    right: index == daysCount - 1 ? 20 : 5, 
                    top: 5, bottom: 5
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? selectedColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: isSelected ? null : Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dayName,
                        style: TextStyle(
                          color: isSelected ? Colors.white : unselectedTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        dayNumber,
                        style: TextStyle(
                          color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (index == 0 && !isSelected) ...[
                          const SizedBox(height: 4),
                          CircleAvatar(radius: 2, backgroundColor: selectedColor),
                      ]
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}