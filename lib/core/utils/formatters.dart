import 'package:intl/intl.dart';

/// Formatação de datas e durações em pt-BR para a UI.

final DateFormat _dayMonth = DateFormat("d 'de' MMM", 'pt_BR');
final DateFormat _dayMonthYear = DateFormat("d 'de' MMMM 'de' y", 'pt_BR');
final DateFormat _time = DateFormat('HH:mm', 'pt_BR');
final DateFormat _weekday = DateFormat("EEEE, d 'de' MMMM", 'pt_BR');

/// Ex.: `22 de mai`.
String formatDay(DateTime date) => _dayMonth.format(date);

/// Ex.: `quinta-feira, 22 de maio`.
String formatWeekday(DateTime date) => _weekday.format(date);

/// Ex.: `22 de maio de 2026 às 14:30`.
String formatFullDateTime(DateTime date) =>
    '${_dayMonthYear.format(date)} às ${_time.format(date)}';

/// Ex.: `14:30`.
String formatTime(DateTime date) => _time.format(date);

/// Tempo decorrido em linguagem natural: `há 2 dias`, `há 3 h`, `agora`.
String formatRelative(DateTime from, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(from);

  if (diff.inMinutes < 1) return 'agora';
  if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'há ${diff.inHours} h';
  if (diff.inDays == 1) return 'há 1 dia';
  return 'há ${diff.inDays} dias';
}
