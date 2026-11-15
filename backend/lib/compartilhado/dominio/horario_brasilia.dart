/// Formata a hora do evento em Brasília, mesmo com servidor em UTC.
/// RF-011, UC-I02; preserva a hora do embarque offline (RNF-006).
class HorarioBrasilia {
  HorarioBrasilia._();

  static String formatarHoraMinuto(DateTime dataHora) {
    final horario = dataHora.toUtc().subtract(const Duration(hours: 3));
    return '${horario.hour.toString().padLeft(2, '0')}:${horario.minute.toString().padLeft(2, '0')}';
  }
}
