// packages/psito_fs/lib/src/operations.dart
//
// O que muda os arquivos: copiar, mover e duplicar (um FileJob num Isolate,
// com progresso, cancelamento e os conflitos perguntados a quem chamou),
// renomear, criar pasta e jogar na lixeira. Cada operação devolve o seu
// desfazer, para o Ctrl+Z do Files.
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'names.dart';
import 'trash.dart';

/// O desfazer de uma operação.
class FsUndo {
  /// "Copiar", "Mover", "Renomear"… (o menu mostra "Desfazer <label>").
  final String label;
  final Future<void> Function() run;

  const FsUndo(this.label, this.run);
}

/// Um erro que o Files mostra como está.
class FsError implements Exception {
  final String message;

  const FsError(this.message);

  @override
  String toString() => message;
}

FileSystemEntityType _type(String path) =>
    FileSystemEntity.typeSync(path, followLinks: false);

bool _exists(String path) => _type(path) != FileSystemEntityType.notFound;

/// Apaga [path] de vez, com o que tiver dentro, sem seguir links.
Future<void> deleteEntity(String path) async {
  switch (_type(path)) {
    case FileSystemEntityType.directory:
      await Directory(path).delete(recursive: true);
    case FileSystemEntityType.notFound:
      return;
    case FileSystemEntityType.link:
      await Link(path).delete();
    default:
      await File(path).delete();
  }
}

const _crossDevice = 18; // EXDEV

/// Move [from] para [to] (que não pode existir): o `rename` e, entre
/// sistemas de arquivos, copiar e apagar.
Future<void> moveEntity(String from, String to) async {
  try {
    await _rename(from, to);
  } on FileSystemException catch (e) {
    if (e.osError?.errorCode != _crossDevice) rethrow;
    await _copyTree(from, to, null);
    await deleteEntity(from);
  }
}

Future<void> _rename(String from, String to) async {
  switch (_type(from)) {
    case FileSystemEntityType.directory:
      await Directory(from).rename(to);
    case FileSystemEntityType.link:
      await Link(from).rename(to);
    case FileSystemEntityType.notFound:
      throw FileSystemException('não existe', from);
    default:
      await File(from).rename(to);
  }
}

/// Renomeia o item. O desfazer volta o nome.
Future<(String, FsUndo)> renameEntry(String path, String newName) async {
  if (invalidName(newName) case final reason?) throw FsError(reason);
  final target = joinPath(dirName(path), newName);
  if (target == path) return (path, FsUndo('Renomear', () async {}));
  // Só a caixa mudou ("foto" para "Foto"): o rename resolve
  if (_exists(target) && target.toLowerCase() != path.toLowerCase()) {
    throw FsError('Já existe um item chamado "$newName".');
  }
  await _rename(path, target);
  return (
    target,
    FsUndo('Renomear', () async {
      if (!_exists(path)) await _rename(target, path);
    }),
  );
}

/// Cria uma pasta com o primeiro nome livre ("Nova pasta", "Nova pasta 2").
/// O desfazer apaga a pasta se ela ainda estiver vazia, ou manda para a
/// lixeira.
Future<(String, FsUndo)> createFolder(
  String dir, {
  String name = 'Nova pasta',
  Trash? trash,
}) async {
  if (invalidName(name) case final reason?) throw FsError(reason);
  final path = joinPath(dir, uniqueName(dir, name, isDirectory: true));
  await Directory(path).create();
  return (
    path,
    FsUndo('Nova pasta', () async {
      final folder = Directory(path);
      if (!await folder.exists()) return;
      if (await folder.list().isEmpty) {
        await folder.delete();
      } else {
        await trash?.trash(path);
      }
    }),
  );
}

/// Joga os itens na lixeira. O desfazer põe de volta.
Future<(List<TrashItem>, FsUndo)> trashEntries(
  Trash trash,
  List<String> paths,
) async {
  final items = <TrashItem>[];
  for (final path in paths) {
    items.add(await trash.trash(path));
  }
  return (
    items,
    FsUndo('Mover para a lixeira', () async {
      for (final item in items.reversed) {
        if (_exists(item.path)) await trash.restore(item);
      }
    }),
  );
}

// Copiar, mover e duplicar

enum JobKind {
  copy('Copiar'),
  move('Mover'),
  duplicate('Duplicar');

  final String label;

  const JobKind(this.label);
}

/// Se [paths] estão todos no mesmo disco que [dir]. Sem como saber, não: quem
/// pergunta copia, o que não perde nada.
Future<bool> sameDevice(List<String> paths, String dir) async {
  try {
    final result = await Process.run('stat', [
      '-L',
      '-c',
      '%d',
      '--',
      dir,
      ...paths,
    ]).timeout(const Duration(seconds: 2));
    if (result.exitCode != 0) return false;
    return '${result.stdout}'.trim().split('\n').toSet().length == 1;
  } on Exception {
    return false;
  }
}

enum ConflictChoice { replace, keepBoth, skip }

/// Já existe um item com o nome do que chega.
class FsConflict {
  final String source;
  final String target;
  final bool sourceIsDirectory;
  final bool targetIsDirectory;

  const FsConflict({
    required this.source,
    required this.target,
    required this.sourceIsDirectory,
    required this.targetIsDirectory,
  });
}

class ConflictAnswer {
  final ConflictChoice choice;

  /// Vale para os próximos conflitos deste trabalho.
  final bool applyToAll;

  const ConflictAnswer(this.choice, {this.applyToAll = false});
}

typedef ConflictHandler = Future<ConflictAnswer> Function(FsConflict);

class JobProgress {
  final int doneBytes;
  final int totalBytes;
  final int doneItems;
  final int totalItems;

  /// O nome do item que está indo agora.
  final String? current;

  const JobProgress({
    this.doneBytes = 0,
    this.totalBytes = 0,
    this.doneItems = 0,
    this.totalItems = 0,
    this.current,
  });

  /// De 0 a 1, pelos bytes ou, sem bytes (um rename), pelos itens.
  double get fraction {
    if (totalBytes > 0) return (doneBytes / totalBytes).clamp(0, 1);
    if (totalItems > 0) return (doneItems / totalItems).clamp(0, 1);
    return 0;
  }
}

class JobResult {
  /// Cada item que foi, com onde ficou.
  final List<(String, String)> done;
  final bool cancelled;
  final List<String> errors;

  const JobResult({
    this.done = const [],
    this.cancelled = false,
    this.errors = const [],
  });
}

/// Copiar, mover ou duplicar, num Isolate. Os conflitos voltam para
/// [onConflict]; sem ele, o item que chega fica com um nome livre ("manter
/// os dois").
class FileJob {
  final JobKind kind;
  final List<String> sources;

  /// A pasta para onde vão (na duplicata, a pasta de cada um).
  final String? destination;
  final ConflictHandler? onConflict;

  final _progress = StreamController<JobProgress>.broadcast();
  final _result = Completer<JobResult>();
  SendPort? _control;
  bool _cancelRequested = false;
  JobProgress _last = const JobProgress();

  FileJob._(this.kind, this.sources, this.destination, this.onConflict);

  static FileJob start(
    JobKind kind,
    List<String> sources, {
    String? destination,
    ConflictHandler? onConflict,
  }) {
    if (kind != JobKind.duplicate && destination == null) {
      throw ArgumentError('falta a pasta de destino');
    }
    final job = FileJob._(kind, sources, destination, onConflict);
    unawaited(job._run());
    return job;
  }

  Stream<JobProgress> get progress => _progress.stream;
  JobProgress get lastProgress => _last;
  Future<JobResult> get result => _result.future;

  void cancel() {
    _cancelRequested = true;
    _control?.send(const ['cancel']);
  }

  Future<void> _run() async {
    final port = ReceivePort();
    final exit = ReceivePort();
    try {
      await Isolate.spawn(
        _jobMain,
        _JobStart(port.sendPort, kind.index, sources, destination),
        onExit: exit.sendPort,
      );
    } on Object catch (e) {
      port.close();
      exit.close();
      _finish(JobResult(errors: ['$e']));
      return;
    }
    exit.listen((_) {
      // O Isolate saiu sem o "done" (um erro fora dos try)
      if (!_result.isCompleted) _finish(const JobResult(errors: ['falhou']));
      port.close();
      exit.close();
    });
    await for (final message in port) {
      final list = message as List;
      switch (list[0]) {
        case 'control':
          _control = list[1] as SendPort;
          if (_cancelRequested) _control!.send(const ['cancel']);
        case 'progress':
          _last = JobProgress(
            doneBytes: list[1] as int,
            totalBytes: list[2] as int,
            doneItems: list[3] as int,
            totalItems: list[4] as int,
            current: list[5] as String?,
          );
          _progress.add(_last);
        case 'conflict':
          final conflict = FsConflict(
            source: list[2] as String,
            target: list[3] as String,
            sourceIsDirectory: list[4] as bool,
            targetIsDirectory: list[5] as bool,
          );
          final handler = onConflict;
          final answer = handler == null
              ? const ConflictAnswer(ConflictChoice.keepBoth)
              : await handler(conflict);
          _control?.send([
            'answer',
            list[1],
            answer.choice.index,
            answer.applyToAll,
          ]);
        case 'done':
          _finish(
            JobResult(
              done: [
                for (final pair in list[1] as List)
                  ((pair as List)[0] as String, pair[1] as String),
              ],
              cancelled: list[2] as bool,
              errors: (list[3] as List).cast<String>(),
            ),
          );
          port.close();
      }
    }
  }

  void _finish(JobResult result) {
    if (_result.isCompleted) return;
    _result.complete(result);
    unawaited(_progress.close());
  }

  /// O desfazer do que o trabalho fez: a cópia e a duplicata vão para a
  /// lixeira, e o que foi movido volta (se o lugar de antes estiver livre).
  static FsUndo undoFor(JobKind kind, JobResult result, Trash trash) =>
      FsUndo(kind.label, () async {
        for (final (source, target) in result.done.reversed) {
          if (!_exists(target)) continue;
          if (kind == JobKind.move) {
            if (!_exists(source)) {
              await Directory(dirName(source)).create(recursive: true);
              await moveEntity(target, source);
            }
          } else {
            await trash.trash(target);
          }
        }
      });
}

class _JobStart {
  final SendPort port;
  final int kind;
  final List<String> sources;
  final String? destination;

  const _JobStart(this.port, this.kind, this.sources, this.destination);
}

class _Cancelled implements Exception {}

/// O estado do trabalho dentro do Isolate.
class _Job {
  final SendPort port;
  bool cancelled = false;
  int doneBytes = 0, totalBytes = 0, doneItems = 0, totalItems = 0;
  String? current;
  final Stopwatch _sinceReport = Stopwatch()..start();
  final _answers = <int, Completer<ConflictAnswer>>{};
  int _nextConflict = 0;
  ConflictChoice? forAll;

  _Job(this.port);

  void checkCancel() {
    if (cancelled) throw _Cancelled();
  }

  void addBytes(int n) {
    doneBytes += n;
    report();
  }

  void addItem() {
    doneItems++;
    report();
  }

  /// No máximo a cada 100 ms, e sempre com [force].
  void report({bool force = false}) {
    if (!force && _sinceReport.elapsedMilliseconds < 100) return;
    _sinceReport.reset();
    port.send([
      'progress',
      doneBytes,
      totalBytes,
      doneItems,
      totalItems,
      current,
    ]);
  }

  Future<ConflictChoice> ask(String source, String target) async {
    if (forAll case final choice?) return choice;
    final id = _nextConflict++;
    final completer = _answers[id] = Completer<ConflictAnswer>();
    port.send([
      'conflict',
      id,
      source,
      target,
      _type(source) == FileSystemEntityType.directory,
      _type(target) == FileSystemEntityType.directory,
    ]);
    final answer = await completer.future;
    if (answer.applyToAll) forAll = answer.choice;
    return answer.choice;
  }

  void answer(int id, ConflictAnswer answer) =>
      _answers.remove(id)?.complete(answer);
}

Future<void> _jobMain(_JobStart start) async {
  final control = ReceivePort();
  final job = _Job(start.port);
  control.listen((message) {
    final list = message as List;
    switch (list[0]) {
      case 'cancel':
        job.cancelled = true;
        // Um conflito esperando resposta também para
        for (final c in job._answers.values) {
          c.complete(const ConflictAnswer(ConflictChoice.skip));
        }
        job._answers.clear();
      case 'answer':
        job.answer(
          list[1] as int,
          ConflictAnswer(
            ConflictChoice.values[list[2] as int],
            applyToAll: list[3] as bool,
          ),
        );
    }
  });
  start.port.send(['control', control.sendPort]);
  final kind = JobKind.values[start.kind];
  final done = <List<String>>[];
  final errors = <String>[];
  try {
    // A soma do que vai, para o progresso. Mover no mesmo disco não copia
    // bytes: aí vale a contagem dos itens
    for (final source in start.sources) {
      if (kind == JobKind.move) {
        job.totalItems++;
      } else {
        final (bytes, items) = _measure(source);
        job.totalBytes += bytes;
        job.totalItems += items;
      }
    }
    job.report(force: true);
    for (final source in start.sources) {
      job.checkCancel();
      try {
        final target = await _transfer(kind, source, start.destination, job);
        if (target != null) done.add([source, target]);
      } on FileSystemException catch (e) {
        errors.add('${baseName(source)}: ${e.osError?.message ?? e.message}');
      } on FsError catch (e) {
        errors.add(e.message);
      }
    }
  } on _Cancelled {
    start.port.send(['done', done, true, errors]);
    control.close();
    return;
  }
  job.report(force: true);
  start.port.send(['done', done, false, errors]);
  control.close();
}

/// Os bytes e os itens de um caminho, sem seguir links.
(int, int) _measure(String path) {
  switch (_type(path)) {
    case FileSystemEntityType.directory:
      var bytes = 0, items = 1;
      try {
        for (final e in Directory(
          path,
        ).listSync(recursive: true, followLinks: false)) {
          items++;
          if (e is File) bytes += e.lengthSync();
        }
      } on FileSystemException {
        // O que não deu para ler aparece como erro na cópia
      }
      return (bytes, items);
    case FileSystemEntityType.file:
      return (File(path).lengthSync(), 1);
    default:
      return (0, 1);
  }
}

/// Um item de um trabalho. Devolve onde ele ficou, ou null se foi pulado.
Future<String?> _transfer(
  JobKind kind,
  String source,
  String? destination,
  _Job job,
) async {
  final sourceType = _type(source);
  if (sourceType == FileSystemEntityType.notFound) {
    throw FileSystemException('não existe', source);
  }
  final isDir = sourceType == FileSystemEntityType.directory;
  final name = baseName(source);
  job.current = name;
  final String dir;
  var targetName = name;
  if (kind == JobKind.duplicate) {
    dir = dirName(source);
    targetName = copyName(dir, name, isDirectory: isDir);
  } else {
    dir = destination!;
    if (isDir && isWithin(source, dir)) {
      throw FsError('"$name" não pode ir para dentro dela mesma.');
    }
  }
  var target = joinPath(dir, targetName);
  if (kind == JobKind.move && target == source) {
    job.addItem();
    return null;
  }
  if (_exists(target)) {
    // Copiar para a mesma pasta é duplicar, sem perguntar
    final choice = target == source
        ? ConflictChoice.keepBoth
        : await job.ask(source, target);
    job.checkCancel();
    switch (choice) {
      case ConflictChoice.skip:
        final (bytes, items) = kind == JobKind.move ? (0, 1) : _measure(source);
        job.doneBytes += bytes;
        job.doneItems += items;
        job.report();
        return null;
      case ConflictChoice.keepBoth:
        target = joinPath(
          dir,
          target == source
              ? copyName(dir, name, isDirectory: isDir)
              : uniqueName(dir, name, isDirectory: isDir),
        );
      case ConflictChoice.replace:
        if (isWithin(target, source)) {
          throw FsError('"$name" não pode substituir a pasta em que está.');
        }
        await deleteEntity(target);
    }
  }
  if (kind == JobKind.move) {
    try {
      await _rename(source, target);
      job.addItem();
      return target;
    } on FileSystemException catch (e) {
      if (e.osError?.errorCode != _crossDevice) rethrow;
    }
    // Outro disco: copia com progresso e apaga
    final (bytes, items) = _measure(source);
    job.totalBytes += bytes;
    job.totalItems += items - 1;
    await _copyTopLevel(source, target, job);
    await deleteEntity(source);
    return target;
  }
  await _copyTopLevel(source, target, job);
  return target;
}

/// Copia um item inteiro; se cancelar no meio, o pedaço copiado sai.
Future<void> _copyTopLevel(String from, String to, _Job job) async {
  try {
    await _copyTree(from, to, job);
  } on _Cancelled {
    await deleteEntity(to);
    rethrow;
  }
}

Future<void> _copyTree(String from, String to, _Job? job) async {
  job?.checkCancel();
  switch (_type(from)) {
    case FileSystemEntityType.link:
      await Link(to).create(await Link(from).target());
    case FileSystemEntityType.directory:
      await Directory(to).create();
      final children = Directory(from).listSync(followLinks: false)
        ..sort((a, b) => a.path.compareTo(b.path));
      job?.addItem();
      for (final child in children) {
        await _copyTree(child.path, joinPath(to, baseName(child.path)), job);
      }
      await _copyTimes(from, to);
      return;
    case FileSystemEntityType.file:
      await _copyFile(from, to, job);
    default:
      throw FileSystemException('tipo de arquivo que não dá para copiar', from);
  }
  job?.addItem();
}

const _chunk = 1 << 20;

Future<void> _copyFile(String from, String to, _Job? job) async {
  final input = await File(from).open();
  final output = await File(to).open(mode: FileMode.writeOnly);
  try {
    while (true) {
      job?.checkCancel();
      final chunk = await input.read(_chunk);
      if (chunk.isEmpty) break;
      await output.writeFrom(chunk);
      job?.addBytes(chunk.length);
    }
  } finally {
    await input.close();
    await output.close();
  }
  final stat = await FileStat.stat(from);
  // O Dart não tem chmod: só o bit de execução importa (scripts e binários)
  if (stat.mode & 0x49 != 0) {
    await Process.run('chmod', ['--reference=$from', to]);
  }
  await _copyTimes(from, to);
}

Future<void> _copyTimes(String from, String to) async {
  try {
    final stat = await FileStat.stat(from);
    if (_type(to) == FileSystemEntityType.file) {
      await File(to).setLastModified(stat.modified);
    }
  } on FileSystemException {
    // A data não é essencial
  }
}
