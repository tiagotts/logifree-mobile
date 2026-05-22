import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Necessário para formatar datas em pt-BR (DateFormat com locale).
  await initializeDateFormatting('pt_BR');
  runApp(const ProviderScope(child: LogiFreeApp()));
}
