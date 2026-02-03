import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/admin_cubit.dart';
import '../cubit/admin_state.dart';
import '../../../../core/constants/enums.dart';
import '../../../schedule/domain/models/class_type_model.dart';

class AdminTypesTab extends StatefulWidget {
  final AdminLoadedData data;
  const AdminTypesTab({super.key, required this.data});

  @override
  State<AdminTypesTab> createState() => _AdminTypesTabState();
}

class _AdminTypesTabState extends State<AdminTypesTab> {
  final _typeNameController = TextEditingController();
  final _typeDescController = TextEditingController();
  ClassCategory? _selectedCategory;
  final _formKey = GlobalKey<FormState>();

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
          setState(() => _selectedCategory = null);
        }
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(
            bottom: 50,
          ), 
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        "Crear Nueva Clase",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _typeNameController,
                        decoration: const InputDecoration(
                          labelText: "Nombre (Ej: Combate)",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: _typeDescController,
                        decoration: const InputDecoration(
                          labelText: "Descripción (Opcional)",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 15),
                      DropdownButtonFormField<ClassCategory>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: "Categoría",
                          border: OutlineInputBorder(),
                        ),
                        hint: const Text("Seleccione una categoría"),
                        items: ClassCategory.values.map((cat) {
                          return DropdownMenuItem(
                            value: cat,
                            child: Text(cat.label.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedCategory = val);
                        },
                        validator: (val) =>
                            val == null ? 'Selecciona una opción' : null,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          if (!_formKey.currentState!.validate()) return;
                          if (_typeNameController.text.isEmpty) return;

                          context.read<AdminCubit>().createClassType(
                            _typeNameController.text.trim(),
                            _typeDescController.text.trim(),
                            _selectedCategory!,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: const Text("GUARDAR"),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 3, thickness: 1),

                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    "Catálogo de Clases",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),

                _buildClassList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClassList() {
    final types = widget.data.classTypes;

    if (types.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.class_outlined,
                size: 50,
                color: Colors.grey.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 10),
              Text(
                "No hay clases registradas",
                style: TextStyle(
                  color: Colors.grey.withValues(alpha: 0.8),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
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
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Row(
            children: [
              Text(
                type.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  type.category.label.toUpperCase(),
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(right: 40.0),
            child: Text(
              hasDesc
                  ? type.description.replaceAll('\n', ' ')
                  : "Sin descripción",
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
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20),
                    SizedBox(width: 10),
                    Text("Editar"),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red, size: 20),
                    SizedBox(width: 10),
                    Text("Eliminar", style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteType(BuildContext context, String id) {
    FocusScope.of(context).requestFocus(FocusNode());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Eliminar del catálogo?"),
        content: const Text(
          "Esto no borrará las clases ya agendadas, pero no podrás agendar nuevas con este nombre.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
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

  void _showEditTypeDialog(BuildContext context, ClassTypeModel type) {
    FocusScope.of(context).requestFocus(FocusNode());

    final nameCtrl = TextEditingController(text: type.name);
    final descCtrl = TextEditingController(text: type.description);
    ClassCategory selectedCat = type.category;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                "Editar Clase",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: "Nombre:"),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: "Descripción:",
                    ),
                  ),
                  const SizedBox(height: 15),

                  // dropdown de edicion
                  DropdownButtonFormField<ClassCategory>(
                    value: selectedCat,
                    decoration: const InputDecoration(
                      labelText: "Categoría",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                    ),
                    items: ClassCategory.values.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text(cat.label.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedCat = val);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancelar"),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.read<AdminCubit>().updateClassType(
                      type.copyWith(
                        name: nameCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        category: selectedCat,
                      ),
                    );
                  },
                  child: const Text("Guardar"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
