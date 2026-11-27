import 'package:flutter/material.dart';

import '../../datos/admin/controlador_admin.dart';

/// Bandeja de los avisos encolados para el encargado autenticado.
class AvisosEncargado extends StatefulWidget {
  const AvisosEncargado({super.key, required this.controlador});
  final ControladorAdmin controlador;

  @override
  State<AvisosEncargado> createState() => _AvisosEncargadoState();
}

class _AvisosEncargadoState extends State<AvisosEncargado> {
  late Future<List<Map<String, dynamic>>> avisos;

  @override
  void initState() {
    super.initState();
    avisos = widget.controlador.avisosZona();
  }

  Future<void> _actualizar() async {
    setState(() => avisos = widget.controlador.avisosZona());
    try { await avisos; } catch (_) { /* FutureBuilder muestra el error. */ }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Avisos de mi zona')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: avisos,
      builder: (context, estado) {
        if (!estado.hasData && !estado.hasError) {
          return const Center(child: CircularProgressIndicator());
        }
        if (estado.hasError) {
          return Center(child: TextButton(
            onPressed: _actualizar, child: const Text('No se pudieron cargar. Reintentar')));
        }
        final lista = estado.data!;
        return RefreshIndicator(onRefresh: _actualizar, child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (lista.isEmpty) const Padding(padding: EdgeInsets.all(24),
              child: Text('Todavía no hay avisos de tu zona.')),
            for (final a in lista) Card(child: ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: Text(a['plantilla'] == 'zanky_apoyo_confirmado'
                ? 'Una persona voluntaria va a ayudar' : 'Nuevo aviso de la zona'),
              subtitle: Text('${(a['datos'] as Map?)?['zona'] ?? ''} · '
                '${(a['datos'] as Map?)?['tipo'] ?? ''} · '
                '${(a['datos'] as Map?)?['prioridad'] ?? ''}'),
            )),
          ],
        ));
      },
    ),
  );
}
