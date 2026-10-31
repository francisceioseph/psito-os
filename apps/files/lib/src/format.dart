// apps/files/lib/src/format.dart
//
// Tamanhos, datas e permissões como o Finder mostra, em português.

/// Em potências de 1000, como o Finder: "512 bytes", "1,2 KB", "3,4 MB".
String formatSize(int bytes) {
  if (bytes == 1) return '1 byte';
  if (bytes < 1000) return '$bytes bytes';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1000;
  var unit = 0;
  while (value >= 1000 && unit < units.length - 1) {
    value /= 1000;
    unit++;
  }
  final digits = value < 10 ? 1 : 0;
  return '${value.toStringAsFixed(digits).replaceAll('.', ',')} ${units[unit]}';
}

const _months = [
  'jan.',
  'fev.',
  'mar.',
  'abr.',
  'mai.',
  'jun.',
  'jul.',
  'ago.',
  'set.',
  'out.',
  'nov.',
  'dez.',
];

/// Um instante (em UTC) na hora local de [now] (o `ctx.now()`, que tem o
/// fuso certo): "Hoje, 14:05", "Ontem, 09:10", "31 de out. de 2026, 14:05".
String formatDate(DateTime utc, DateTime now) =>
    formatLocalDate(utc.toUtc().add(now.timeZoneOffset), now);

/// Uma hora local já nos campos de um DateTime (a `DeletionDate` da
/// lixeira).
String formatLocalDate(DateTime local, DateTime now) {
  String two(int n) => n.toString().padLeft(2, '0');
  final time = '${two(local.hour)}:${two(local.minute)}';
  final day = DateTime.utc(local.year, local.month, local.day);
  final today = DateTime.utc(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Hoje, $time';
  if (diff == 1) return 'Ontem, $time';
  return '${local.day} de ${_months[local.month - 1]} de ${local.year}, $time';
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

/// "3 itens", "1 item".
String formatCount(int n, String one, String many) =>
    '$n ${n == 1 ? one : many}';
