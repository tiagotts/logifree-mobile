import 'package:flutter/material.dart';

/// Ciclo de vida de um pacote na portaria.
enum PackageStatus {
  pendingIdentification('Pendente identificação', Color(0xFFB26A00)),
  awaitingPickup('Aguardando retirada', Color(0xFF1565C0)),
  delivered('Entregue', Color(0xFF2E7D32)),
  returned('Devolvido', Color(0xFF6A1B9A)),
  canceled('Cancelado', Color(0xFF757575));

  const PackageStatus(this.label, this.color);

  /// Texto exibido na UI (pt-BR).
  final String label;

  /// Cor base do chip de status.
  final Color color;
}
