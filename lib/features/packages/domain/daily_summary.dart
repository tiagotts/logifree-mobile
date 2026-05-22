/// Resumo operacional do dia exibido na Home.
class DailySummary {
  const DailySummary({
    required this.receivedToday,
    required this.awaitingPickup,
    required this.deliveredToday,
  });

  /// Pacotes recebidos hoje.
  final int receivedToday;

  /// Pacotes em qualquer dia ainda aguardando retirada.
  final int awaitingPickup;

  /// Pacotes entregues hoje.
  final int deliveredToday;
}
