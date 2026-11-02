// packages/psito_services/lib/storage_service.dart
//
// O uso dos discos, medido pelo shell: o `df` diz o espaço, e o `du`, num
// processo à parte e com prioridade baixa, as maiores pastas. As Configurações
// leem pelo StorageClient.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:psito_sdk/psito_sdk.dart';

import 'disks_service.dart';

typedef RunProcess = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

/// Quantas pastas a seção mostra.
const largestFoldersLimit = 8;

/// O tamanho e o livre, da saída de `df -B1 --output=size,avail`.
(int, int)? parseDf(String output) {
  final lines = const LineSplitter().convert(output);
  if (lines.length < 2) return null;
  final fields = lines[1].trim().split(RegExp(r'\s+'));
  if (fields.length < 2) return null;
  final total = int.tryParse(fields[0]);
  final free = int.tryParse(fields[1]);
  return total == null || free == null ? null : (total, free);
}

/// As maiores pastas, da saída de `du -0 --max-depth=1`, sem a própria [root]:
/// o `du` termina com ela.
List<PsitoFolderSize> parseDu(String output, String root) {
  final found = <PsitoFolderSize>[];
  for (final record in output.split('\u0000')) {
    final tab = record.indexOf('\t');
    if (tab <= 0) continue;
    final size = int.tryParse(record.substring(0, tab));
    final path = record.substring(tab + 1);
    if (size != null && path != root) found.add(PsitoFolderSize(path, size));
  }
  found.sort((a, b) => b.size.compareTo(a.size));
  return found.take(largestFoldersLimit).toList();
}

Future<ProcessResult> _run(String executable, List<String> arguments) =>
    // Um nome de arquivo pode não ser UTF-8
    Process.run(
      executable,
      arguments,
      stdoutEncoding: const Utf8Codec(allowMalformed: true),
    );

class LocalStorage implements PsitoStorage {
  final DisksService _service;
  final String home;
  final Future<List<String>> Function() trashDirs;
  final VoidCallback onEmptyTrash;
  final Future<void> Function(String path) onOpen;
  final void Function(String id) onOpenFormat;
  final RunProcess run;

  /// Quem formata. Sem ele, o serviço dos discos.
  final Future<PsitoDiskResult> Function(
    String id,
    PsitoDiskFormat type,
    String label,
  )?
  formatter;
  final _disks = ValueNotifier<List<PsitoDiskUsage>>(const []);

  LocalStorage({
    required DisksService disks,
    required this.home,
    required this.trashDirs,
    required this.onEmptyTrash,
    required this.onOpen,
    required this.onOpenFormat,
    this.run = _run,
    this.formatter,
  }) : _service = disks {
    disks.volumes.addListener(_volumesChanged);
  }

  void _volumesChanged() => unawaited(refresh());

  void dispose() {
    _service.volumes.removeListener(_volumesChanged);
    _disks.dispose();
  }

  @override
  ValueListenable<List<PsitoDiskUsage>> get disks => _disks;

  /// Sem medir: para os testes do que vem depois.
  @visibleForTesting
  void seed(List<PsitoDiskUsage> disks) => _disks.value = disks;

  Future<(int, int)?> _measure(String path) async {
    try {
      final result = await run('df', ['-B1', '--output=size,avail', path]);
      return result.exitCode == 0 ? parseDf(result.stdout as String) : null;
    } on ProcessException catch (e) {
      debugPrint('🦜 Sem o df: $e');
      return null;
    }
  }

  @override
  Future<void> refresh() async {
    final next = <PsitoDiskUsage>[];
    if (await _measure(home) case (final total, final free)) {
      next.add(PsitoDiskUsage(path: home, total: total, free: free));
    }
    for (final volume in _service.volumes.value) {
      final mount = volume.mountPoint;
      final measured = mount == null ? null : await _measure(mount);
      next.add(
        PsitoDiskUsage(
          id: volume.id,
          name: volume.label,
          path: mount,
          total: measured?.$1 ?? volume.size,
          free: measured?.$2,
        ),
      );
    }
    if (!listEquals(next, _disks.value)) _disks.value = next;
  }

  @override
  Future<List<PsitoFolderSize>> largestFolders(String path) async {
    try {
      final result = await run('nice', [
        '-n',
        '10',
        'du',
        '-x',
        '-0',
        '-B1',
        '--max-depth=1',
        path,
      ]);
      // Sem permissão numa pasta, ele sai com erro, mas mede o resto
      return parseDu(result.stdout as String, path);
    } on ProcessException catch (e) {
      debugPrint('🦜 Sem o du: $e');
      return const [];
    }
  }

  @override
  Future<int> trashSize() async {
    final dirs = await trashDirs();
    final existing = [
      for (final dir in dirs)
        if (Directory(dir).existsSync()) dir,
    ];
    if (existing.isEmpty) return 0;
    try {
      final result = await run('du', ['-s', '-c', '-B1', ...existing]);
      final lines = const LineSplitter().convert(result.stdout as String);
      if (lines.isEmpty) return 0;
      return int.tryParse(lines.last.split(RegExp(r'\s+')).first) ?? 0;
    } on ProcessException catch (e) {
      debugPrint('🦜 Sem o du: $e');
      return 0;
    }
  }

  @override
  Future<void> emptyTrash() async => onEmptyTrash();

  @override
  Future<void> openFolder(String path) => onOpen(path);

  @override
  Future<void> openFormat(String id) async => onOpenFormat(id);

  @override
  Future<PsitoDiskResult> format(
    String id,
    PsitoDiskFormat type,
    String label,
  ) => (formatter ?? _service.format)(id, type, label);
}

/// O laboratório e os testes: nunca os discos de verdade do host.
class FakeStorage implements PsitoStorage {
  static const pendrive = PsitoDiskUsage(
    id: '/fake/pendrive',
    name: 'PENDRIVE',
    path: '/media/ana/PENDRIVE',
    total: 16000000000,
    free: 4000000000,
  );

  final ValueNotifier<List<PsitoDiskUsage>> usage;
  final folders = <PsitoFolderSize>[
    const PsitoFolderSize('/home/ana/Videos', 40000000000),
    const PsitoFolderSize('/home/ana/.cache', 3000000000),
  ];
  int trash = 1500000000;
  PsitoDiskResult answer = PsitoDiskResult.ok;
  final formatted = <(String, PsitoDiskFormat, String)>[];
  final opened = <String>[];
  int asksToEmpty = 0;

  FakeStorage([List<PsitoDiskUsage>? disks])
    : usage = ValueNotifier(
        disks ??
            const [
              PsitoDiskUsage(
                path: '/home/ana',
                total: 256000000000,
                free: 120000000000,
              ),
              pendrive,
            ],
      );

  @override
  ValueListenable<List<PsitoDiskUsage>> get disks => usage;

  @override
  Future<void> refresh() async {}

  @override
  Future<List<PsitoFolderSize>> largestFolders(String path) async => folders;

  @override
  Future<int> trashSize() async => trash;

  @override
  Future<void> emptyTrash() async => asksToEmpty++;

  @override
  Future<void> openFolder(String path) async => opened.add(path);

  @override
  Future<void> openFormat(String id) async => opened.add('format:$id');

  @override
  Future<PsitoDiskResult> format(
    String id,
    PsitoDiskFormat type,
    String label,
  ) async {
    formatted.add((id, type, label));
    return answer;
  }
}
