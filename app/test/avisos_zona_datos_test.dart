import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanky/datos/avisos_zona/repositorio.dart';
import 'package:zanky/datos/servidor.dart';

void main() {
  test('sin consentimiento no se registra ni siquiera en demostración', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = RepositorioAvisosZona(servidor: Servidor(base: '', anon: ''));
    const alta = AltaVoluntario(nombre: 'Ana', telefono: '+573001234567',
      zona: 'mallorquin', lat: 11.02, lon: -74.85, radioKm: 2,
      canales: ['app'], tipos: ['basuras'], consentimiento: false);
    await expectLater(repo.inscribir(alta), throwsStateError);
    expect(await repo.inscrito(), isFalse);
  });

  test('demostración limpia la participación al dar de baja', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = RepositorioAvisosZona(servidor: Servidor(base: '', anon: ''));
    const alta = AltaVoluntario(nombre: 'Ana', telefono: '+573001234567',
      zona: 'mallorquin', lat: 11.02, lon: -74.85, radioKm: 2,
      canales: ['app'], tipos: ['basuras'], consentimiento: true);
    await repo.inscribir(alta);
    expect(await repo.inscrito(), isTrue);
    await repo.ayudar('demo-1');
    expect((await repo.listar()).single.apoye, isTrue);
    await repo.baja();
    expect(await repo.inscrito(), isFalse);
    await repo.inscribir(alta);
    expect((await repo.listar()).single.apoye, isFalse);
  });
}
