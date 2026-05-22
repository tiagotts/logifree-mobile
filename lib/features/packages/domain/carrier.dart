import 'package:flutter/material.dart';

/// Transportadoras reconhecidas pelo app.
///
/// No protótipo o ícone é um placeholder do Material; na versão final cada
/// transportadora terá seu logo.
enum Carrier {
  correios('Correios', Icons.local_post_office_outlined),
  mercadoLivre('Mercado Livre', Icons.shopping_bag_outlined),
  amazon('Amazon', Icons.shopping_cart_outlined),
  shopee('Shopee', Icons.storefront_outlined),
  other('Outra', Icons.inventory_2_outlined);

  const Carrier(this.label, this.icon);

  /// Nome exibido na UI (pt-BR).
  final String label;

  /// Ícone representativo enquanto não há logo oficial.
  final IconData icon;
}
