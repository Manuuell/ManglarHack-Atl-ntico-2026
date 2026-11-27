import 'package:flutter/material.dart';

import '../../nucleo/tema.dart';
import 'pantalla_avisos_zona.dart';

/// Entrada autónoma para Inicio o Guardián; no modifica su navegación actual.
class EntradaVoluntario extends StatelessWidget {
  const EntradaVoluntario({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Card(
          color: Zc.hojaClara,
          child: ListTile(
            leading: const Icon(Icons.volunteer_activism_outlined, color: Zc.raiz),
            title: const Text('Sé voluntario de tu zona'),
            subtitle: const Text('Recibe avisos cerca de ti y ayuda al manglar'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const PantallaAvisosZona(),
            )),
          ),
        ),
      );
}
