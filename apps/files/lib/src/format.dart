// apps/files/lib/src/format.dart
//
// Tamanhos, datas e permissões como o Finder mostra, no idioma de quem usa.
import 'package:intl/intl.dart';

import 'package:psito_files/l10n/files_localizations.dart';

/// Em potências de 1000, como o Finder: "512 bytes", "1,2 KB", "3,4 MB".
String formatSize(FilesLocalizations l, int bytes) {
  if (bytes < 1000) return l.sizeBytes(bytes);
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1000;
  var unit = 0;
  while (value >= 1000 && unit < units.length - 1) {
    value /= 1000;
    unit++;
  }
  final number = NumberFormat(value < 10 ? '0.0' : '0', l.localeName);
  return '${number.format(value)} ${units[unit]}';
}

/// Um instante (em UTC) na hora local de [now] (o `ctx.now()`, que tem o
/// fuso certo): "Hoje, 14:05", "Ontem, 09:10", "31 de out. de 2026, 14:05".
String formatDate(FilesLocalizations l, DateTime utc, DateTime now) =>
    formatLocalDate(l, utc.toUtc().add(now.timeZoneOffset), now);

/// Uma hora local já nos campos de um DateTime (a `DeletionDate` da
/// lixeira).
String formatLocalDate(FilesLocalizations l, DateTime local, DateTime now) {
  final time = DateFormat.Hm(l.localeName).format(local);
  final day = DateTime.utc(local.year, local.month, local.day);
  final today = DateTime.utc(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return l.dateToday(time);
  if (diff == 1) return l.dateYesterday(time);
  return l.dateFull(DateFormat.yMMMd(l.localeName).format(local), time);
}

/// `rwxr-xr-x`.
String formatMode(int mode) {
  const letters = 'rwx';
  final out = StringBuffer();
  for (var i = 8; i >= 0; i--) {
    out.write(mode & (1 << i) != 0 ? letters[(8 - i) % 3] : '-');
  }
  return out.toString();
}
