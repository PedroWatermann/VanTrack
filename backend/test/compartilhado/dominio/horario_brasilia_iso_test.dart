import 'package:test/test.dart';
import 'package:vantrack_backend/compartilhado/dominio/horario_brasilia.dart';

/// `HorarioBrasilia.formatarIso8601` (task A-08): ISO 8601 com o fuso -03:00,
/// mesmo com o servidor em UTC.
void main() {
  test('converte um instante UTC para o horário de Brasília', () {
    expect(
      HorarioBrasilia.formatarIso8601(DateTime.utc(2026, 11, 16, 9, 30)),
      '2026-11-16T06:30:00-03:00',
    );
  });

  test('perto da meia-noite UTC, a data é a do dia anterior em Brasília', () {
    expect(
      HorarioBrasilia.formatarIso8601(DateTime.utc(2026, 11, 17, 1, 5, 9)),
      '2026-11-16T22:05:09-03:00',
    );
  });
}
