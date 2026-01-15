import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/admin_cubit.dart';
import '../cubit/admin_state.dart';

class AdminTypesTab extends StatefulWidget {
  final AdminLoadedData data;
  const AdminTypesTab({super.key, required this.data});

  @override
  State<AdminTypesTab> createState() => _AdminTypesTabState();
}

class _AdminTypesTabState extends State<AdminTypesTab> {
  final _typeNameController = TextEditingController();
  final _typeDescController = TextEditingController();

  @override
  void dispose() {
    _typeNameController.dispose();
    _typeDescController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AdminCubit, AdminState>(
      listener: (context, state) {
        if (state is AdminOperationSuccess) {
          _typeNameController.clear();
          _typeDescController.clear();
        }
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Area de formulario fija
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text("Crear Nueva Clase", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  
                  TextField(
                    controller: _typeNameController, 
                    decoration: const InputDecoration(labelText: "Nombre (Ej: Combate)", border: OutlineInputBorder())
                  ),
                  
                  const SizedBox(height: 15),
                  
                  TextField(
                    controller: _typeDescController, 
                    maxLines: 2, 
                    decoration: const InputDecoration(labelText: "Descripción (Opcional)", border: OutlineInputBorder())
                  ),
                  
                  const SizedBox(height: 20),
                  
                  ElevatedButton(
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      if (_typeNameController.text.isEmpty) return;
                      context.read<AdminCubit>().createClassType(_typeNameController.text.trim(), _typeDescController.text.trim());
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                    child: const Text("GUARDAR"),
                  ),
                ],
              ),
            ),

            const Divider(height: 3, thickness: 1),

            const Padding(
              padding: EdgeInsets.all(20),
              child: Text("Catálogo de Clases", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),

            Expanded(
              child: _buildClassList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassList() {
    final types = widget.data.classTypes;

    // Estado vacio
    if (types.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.class_outlined, size: 50, color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 10),
            Text(
              "No hay clases registradas",
              style: TextStyle(color: Colors.grey.withValues(alpha: 0.8), fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 80), 
      itemCount: types.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final type = types[index];
        final hasDesc = type.description.isNotEmpty;

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: Colors.red.withValues(alpha: 0.1),
            child: Text(
              type.name.isNotEmpty ? type.name[0].toUpperCase() : "?", 
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)
            ),
          ),
          title: Text(type.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Padding(
            padding: const EdgeInsets.only(right: 40.0), 
            child: Text(
              hasDesc ? type.description.replaceAll('\n', ' ') : "Sin descripción",
              maxLines: 1, 
              overflow: TextOverflow.ellipsis, 
              style: TextStyle(
                fontStyle: hasDesc ? FontStyle.normal : FontStyle.italic,
                color: hasDesc ? null : Colors.grey,
              ),
            ),
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') _showEditTypeDialog(context, type);
              if (value == 'delete') _confirmDeleteType(context, type.id);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 10), Text("Editar")])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 10), Text("Eliminar", style: TextStyle(color: Colors.red))])),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteType(BuildContext context, String id) {
    FocusScope.of(context).unfocus();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Eliminar del catálogo?"),
        content: const Text("Esto no borrará las clases ya agendadas, pero no podrás agendar nuevas con este nombre."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AdminCubit>().deleteClassType(id);
            }, 
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );
  }

  void _showEditTypeDialog(BuildContext context, dynamic type) {
    FocusScope.of(context).unfocus();

    final nameCtrl = TextEditingController(text: type.name);
    final descCtrl = TextEditingController(text: type.description);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Editar Clase", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Nombre
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: "Nombre",
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
            const SizedBox(height: 12),
            // Descripción
            TextField(
              controller: descCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: "Descripción",
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AdminCubit>().updateClassType(type.copyWith(
                name: nameCtrl.text.trim(),
                description: descCtrl.text.trim(),
              ));
            }, 
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }
}