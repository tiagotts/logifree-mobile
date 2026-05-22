import 'package:flutter/material.dart';

import '../../domain/package_status.dart';

/// Chip colorido que representa o [PackageStatus] de um pacote.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.compact = false});

  final PackageStatus status;

  /// Versão menor, para uso dentro de cards de lista.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = status.color;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: compact ? 11.5 : 13,
        ),
      ),
    );
  }
}
