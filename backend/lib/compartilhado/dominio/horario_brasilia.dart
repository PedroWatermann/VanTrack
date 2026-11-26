/// Formata a hora do evento em Brasília, mesmo com servidor em UTC.
/// RF-011, UC-I02; preserva a hora do embarque offline (RNF-006).
class HorarioBrasilia {
  HorarioBrasilia._();

  static String formatarHoraMinuto(DateTime dataHora) {
    final horario = dataHora.toUtc().subtract(const Duration(hours: 3));
    return '${horario.hour.toString().padLeft(2, '0')}:${horario.minute.toString().padLeft(2, '0')}';
  }

  /// ISO 8601 com o fuso de Brasília, como o contrato da API pede
  /// (ex.: `2026-11-16T06:30:00-03:00`). Usado nas respostas JSON (task A-08).
  static String formatarIso8601(DateTime dataHora) {
    final h = dataHora.toUtc().subtract(const Duration(hours: 3));
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${h.year.toString().padLeft(4, '0')}-${dois(h.month)}-${dois(h.day)}'
        'T${dois(h.hour)}:${dois(h.minute)}:${dois(h.second)}-03:00';
  }
}
