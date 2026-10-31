// system_shell/lib/shell/app_search.dart
import 'app_entry.dart';

const _accents = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', //
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', //
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', //
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', //
  'ç': 'c', 'ñ': 'n',
};

/// Minúsculas e sem acentos, para comparar buscas.
String foldForSearch(String s) {
  final lower = s.toLowerCase();
  final out = StringBuffer();
  for (final char in lower.split('')) {
    out.write(_accents[char] ?? char);
  }
  return out.toString();
}

/// Apps cujo nome ou id contém [query]. Os que começam com o termo vêm
/// primeiro; fora isso, vale a ordem de [apps].
List<AppEntry> searchApps(List<AppEntry> apps, String query) {
  final term = foldForSearch(query.trim());
  if (term.isEmpty) return List.of(apps);

  final prefix = <AppEntry>[];
  final inside = <AppEntry>[];
  for (final app in apps) {
    final name = foldForSearch(app.name);
    final id = foldForSearch(app.id);
    if (name.startsWith(term) || id.startsWith(term)) {
      prefix.add(app);
    } else if (name.contains(term) || id.contains(term)) {
      inside.add(app);
    }
  }
  return [...prefix, ...inside];
}
