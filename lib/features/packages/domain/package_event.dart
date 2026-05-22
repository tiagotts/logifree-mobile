import 'package:flutter/material.dart';

/// Tipo de evento na linha do tempo de um pacote.
enum PackageEventType {
  received('Pacote recebido', Icons.inventory_2_outlined),
  identified('Destinatário identificado', Icons.person_search_outlined),
  delivered('Entregue ao morador', Icons.check_circle_outline),
  returned('Devolvido à transportadora', Icons.undo_outlined);

  const PackageEventType(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Um evento datado no histórico de um pacote.
class PackageEvent {
  const PackageEvent({
    required this.type,
    required this.timestamp,
    this.actor,
    this.note,
  });

  final PackageEventType type;
  final DateTime timestamp;

  /// Quem realizou a ação (porteiro, morador, etc.).
  final String? actor;

  /// Observação livre associada ao evento.
  final String? note;
}
