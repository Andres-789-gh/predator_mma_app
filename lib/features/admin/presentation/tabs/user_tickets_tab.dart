import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../auth/domain/models/access_exception_model.dart';

class UserTicketsTab extends StatelessWidget {
  final List<AccessExceptionModel> tickets;
  final VoidCallback onAddTicket;
  final Function(AccessExceptionModel) onTicketTap;
  final Function(int) onRemoveTicket;

  const UserTicketsTab({
    super.key,
    required this.tickets,
    required this.onAddTicket,
    required this.onTicketTap,
    required this.onRemoveTicket,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Colors.red[800],
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.confirmation_number),
            label: const Text("AGREGAR INGRESO EXTRA"),
            onPressed: onAddTicket,
          ),
          const SizedBox(height: 20),

          // Lista de tickets
          if (tickets.isEmpty)
            const Center(
              child: Text(
                "No hay ingresos extra asignados.",
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...tickets.asMap().entries.map((entry) {
              final index = entry.key;
              final ticket = entry.value;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  onTap: () => onTicketTap(ticket),

                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.withValues(alpha: 0.2),
                    child: Text(
                      "${ticket.quantity}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                  ),
                  title: Text(
                    ticket.originalPlanName.isEmpty
                        ? "Ingreso Extra"
                        : ticket.originalPlanName,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (ticket.reason != null && ticket.reason!.isNotEmpty)
                        Text(
                          "Motivo: ${ticket.reason}",
                          style: const TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      Text(
                        "Vence: ${ticket.validUntil != null ? DateFormat('dd/MM/yyyy').format(ticket.validUntil!) : 'Indefinido'}",
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () async {
                      final confirmDelete = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text("¿Eliminar Ingreso Extra?"),
                          content: Text(
                            ticket.quantity > 1
                                ? "Esta acción removerá los ${ticket.quantity} ingresos extra del plan base \"${ticket.originalPlanName}\" de la lista. Recuerda guardar los cambios."
                                : "Esta acción removerá el ingreso extra del plan base \"${ticket.originalPlanName}\" de la lista. Recuerda guardar los cambios.",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text("Cancelar"),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text("Eliminar"),
                            ),
                          ],
                        ),
                      );

                      if (confirmDelete == true) {
                        onRemoveTicket(index);
                      }
                    },
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
