// apps/files/lib/src/controller.dart
//
// A janela do Files: as abas, a área de transferência de arquivos (copiar,
// recortar e colar), os trabalhos em andamento (copiar e mover, com o
// progresso), o desfazer e o que abre cada arquivo. A UI chama daqui, e as
// perguntas (os conflitos, os erros) voltam para ela pelos callbacks.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:psito_fs/psito_fs.dart';
import 'package:psito_runtime/psito_runtime.dart';
import 'package:psito_sdk/psito_sdk.dart';

import 'env.dart';
import 'tab.dart';

/// Um copiar ou mover em andamento, para a barra de progresso.
class RunningJob {
  final FileJob job;
  final String label;
  JobProgress progress = const JobProgress();

  RunningJob(this.job, this.label);
}

class FilesController extends ChangeNotifier {
  final PsitoAppContext ctx;
  final FilesEnv env;
  final FilesConfig config;

  final tabs = <FilesTab>[];
  int _active = 0;

  /// A área de transferência de arquivos, a mesma de todo o sistema.
  final PsitoClipboard fileClipboard;

  /// O que está copiado ou recortado, aqui ou em outro app.
  List<String> get clipboard => fileClipboard.current.value?.paths ?? const [];
  bool get clipboardCut => fileClipboard.current.value?.cut ?? false;

  final _undo = <FsUndo>[];
  final jobs = <RunningJob>[];

  /// Pergunta o que fazer quando o nome já existe (o diálogo).
  ConflictHandler? onConflict;

  /// Mostra um erro (a barra embaixo).
  void Function(String message)? onError;

  /// Pede confirmação antes do que não se desfaz: a pergunta, o detalhe e o
  /// botão.
  Future<bool> Function(String question, String detail, String action)?
  onConfirm;

  StreamSubscription<List<String>>? _requests;

  /// O último clique que caiu num item: o fundo da vista, que também recebe
  /// o clique, não limpa a seleção.
  int? claimedPointer;

  /// O clique num item já selecionado: ao soltar (sem arrastar), só ele fica
  /// selecionado.
  String? pendingCollapse;

  /// O arrastar saiu da janela e virou o arrastar do sistema (o Wayland): o
  /// ícone que segue o ponteiro passa a ser o do sistema.
  final outsideDrag = ValueNotifier(false);

  FilesController({
    required this.ctx,
    required this.env,
    required this.config,
    List<String> opened = const [],
    PsitoClipboard? clipboard,
  }) : fileClipboard = clipboard ?? PsitoClipboard.instance {
    fileClipboard.current.addListener(notifyListeners);
    unawaited(fileClipboard.read());
    if (opened.isEmpty) {
      tabs.add(FilesTab(env, config, FolderLocation(env.home)));
    } else {
      for (final path in opened) {
        tabs.add(_tabFor(path));
      }
    }
    for (final tab in tabs) {
      tab.addListener(_tabChanged);
    }
    _requests = ctx.openRequests.listen(openPaths);
    _updateTitle();
  }

  FilesTab get tab => tabs[_active];
  int get activeIndex => _active;

  /// A pasta da lixeira (o que a dock manda) abre a Lixeira.
  FilesTab _tabFor(String path) {
    if (path.startsWith(psitoQuickLookPrefix)) {
      return _quickLookTab(path.substring(psitoQuickLookPrefix.length));
    }
    String bare(String p) =>
        p.endsWith('/') && p.length > 1 ? p.substring(0, p.length - 1) : p;
    if (bare(path) == bare(env.trash.filesDir)) {
      return FilesTab(env, config, const TrashLocation());
    }
    final entry = FsEntry.stat(path, env.mime);
    if (entry != null && !entry.isDirectory) {
      return FilesTab(env, config, FolderLocation(dirName(path)))
        ..selection.add(path)
        ..cursor = path;
    }
    return FilesTab(env, config, FolderLocation(path));
  }

  /// A pasta de [path] com ele selecionado, e o Quick Look a abrir
  /// ([takeQuickLook]).
  FilesTab _quickLookTab(String path) {
    _quickLook = true;
    return FilesTab(env, config, FolderLocation(dirName(path)))
      ..selection.add(path)
      ..cursor = path;
  }

  /// Espaço de novo na mesa, na mesma pasta: não abre outra aba.
  bool _reuseForQuickLook(String marked) {
    if (!marked.startsWith(psitoQuickLookPrefix)) return false;
    final path = marked.substring(psitoQuickLookPrefix.length);
    final index = tabs.indexWhere((tab) => tab.folder == dirName(path));
    if (index < 0) return false;
    _active = index;
    tabs[index]
      ..selection.clear()
      ..selection.add(path)
      ..cursor = path;
    _quickLook = true;
    _updateTitle();
    notifyListeners();
    return true;
  }

  bool _quickLook = false;

  /// Um pedido de Quick Look que chegou de fora (o Espaço na mesa).
  bool takeQuickLook() {
    final pending = _quickLook;
    _quickLook = false;
    return pending;
  }

  /// O que o shell mandou com o Files já aberto: cada caminho numa aba nova
  /// (um arquivo abre a pasta dele, com ele selecionado).
  void openPaths(List<String> paths) {
    for (final path in paths) {
      if (_reuseForQuickLook(path)) continue;
      final tab = _tabFor(path)..addListener(_tabChanged);
      tabs.add(tab);
      _active = tabs.length - 1;
    }
    _updateTitle();
    notifyListeners();
  }

  void _tabChanged() {
    _updateTitle();
    notifyListeners();
  }

  String _title = '';

  void _updateTitle() {
    final title = tab.title;
    if (title == _title) return;
    _title = title;
    // Depois do quadro: o Files nasce e muda de aba no meio de um build, e no
    // laboratório o título avisa a moldura
    scheduleMicrotask(() => ctx.setTitle(title));
  }

  // Abas

  void newTab([FilesLocation? location]) {
    final next = FilesTab(
      env,
      config,
      location ??
          (tab.folder != null
              ? FolderLocation(tab.folder!)
              : FolderLocation(env.home)),
    )..addListener(_tabChanged);
    tabs.insert(_active + 1, next);
    _active++;
    _updateTitle();
    notifyListeners();
  }

  /// Fechar a última aba fecha a janela.
  void closeTab([int? index]) {
    final i = index ?? _active;
    if (tabs.length == 1) {
      ctx.close();
      return;
    }
    tabs.removeAt(i).dispose();
    if (_active >= tabs.length || _active > i) _active--;
    _active = _active.clamp(0, tabs.length - 1);
    _updateTitle();
    notifyListeners();
  }

  void selectTab(int index) {
    if (index < 0 || index >= tabs.length) return;
    _active = index;
    _updateTitle();
    notifyListeners();
  }

  void nextTab(int delta) => selectTab((_active + delta) % tabs.length);

  // Abrir

  /// Abrir os selecionados: as pastas aqui (com [newTab], numa aba nova), e
  /// os arquivos no app padrão pelo shell. Na lixeira nada abre.
  Future<void> open(List<FsEntry> entries, {bool newTab = false}) async {
    if (tab.location is TrashLocation) {
      onError?.call('Para abrir, ponha o item de volta primeiro.');
      return;
    }
    final folders = [
      for (final e in entries)
        if (e.isDirectory) e,
    ];
    final files = [
      for (final e in entries)
        if (!e.isDirectory) e,
    ];
    if (folders.length == 1 && !newTab) {
      tab.go(FolderLocation(folders.single.path));
    } else {
      for (final folder in folders) {
        this.newTab(FolderLocation(folder.path));
      }
    }
    if (files.isEmpty) return;
    try {
      await ctx.open([for (final f in files) f.path]);
    } on PsitoOpenException catch (e) {
      onError?.call(e.message);
    }
  }

  Future<void> openWith(List<FsEntry> entries, String appId) async {
    try {
      await ctx.open([for (final e in entries) e.path], withApp: appId);
    } on PsitoOpenException catch (e) {
      onError?.call(e.message);
    }
  }

  /// "Mostrar na pasta": a pasta do item, com ele selecionado.
  void reveal(String path) =>
      tab.go(FolderLocation(dirName(path)), select: path);

  // Desfazer

  bool get canUndo => _undo.isNotEmpty;
  String? get undoLabel => _undo.lastOrNull?.label;

  void _pushUndo(FsUndo undo) {
    _undo.add(undo);
    if (_undo.length > 50) _undo.removeAt(0);
    notifyListeners();
  }

  Future<void> undo() async {
    if (_undo.isEmpty) return;
    final undo = _undo.removeLast();
    notifyListeners();
    await _guard(undo.run);
  }

  Future<T?> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FsError catch (e) {
      onError?.call(e.message);
    } on Exception catch (e) {
      onError?.call('$e');
    }
    return null;
  }

  // Operações

  Future<void> newFolder() async {
    final dir = tab.folder;
    if (dir == null || tab.location is! FolderLocation) return;
    final created = await _guard(() => createFolder(dir, trash: env.trash));
    if (created == null) return;
    final (path, undo) = created;
    _pushUndo(undo);
    await tab.refresh();
    // A pasta nova já entra com o nome em edição, como no Finder
    tab.startRename(path);
  }

  /// Renomeia; devolve false (e avisa) se o nome não serve.
  Future<bool> rename(String path, String newName) async {
    tab.stopRename();
    if (baseName(path) == newName) return true;
    final result = await _guard(() => renameEntry(path, newName));
    if (result == null) return false;
    final (target, undo) = result;
    _pushUndo(undo);
    await tab.refresh();
    tab.tap(target);
    return true;
  }

  Future<void> moveToTrash(List<String> paths) async {
    if (paths.isEmpty) return;
    final result = await _guard(() => trashEntries(env.trash, paths));
    if (result == null) return;
    _pushUndo(result.$2);
    await tab.refresh();
  }

  /// "Pôr de volta" na lixeira.
  Future<void> restore(List<String> paths) async {
    for (final path in paths) {
      final item = tab.trashItems[path];
      if (item != null) await _guard(() => env.trash.restore(item));
    }
    await tab.refresh();
  }

  /// "Apagar imediatamente", na lixeira (a UI confirma antes).
  Future<void> deleteForever(List<String> paths) async {
    for (final path in paths) {
      final item = tab.trashItems[path];
      if (item != null) await _guard(() => env.trash.delete(item));
    }
    await tab.refresh();
  }

  /// "Apagar imediatamente", depois de confirmar.
  Future<void> deleteForeverAsked(List<String> paths) async {
    if (paths.isEmpty) return;
    final name = paths.length == 1
        ? '"${tab.trashItems[paths.single]?.name ?? baseName(paths.single)}"'
        : '${paths.length} itens';
    final ok = await onConfirm?.call(
      'Apagar $name para sempre?',
      'Não dá para desfazer.',
      'Apagar',
    );
    if (ok ?? false) await deleteForever(paths);
  }

  /// "Esvaziar a lixeira", depois de confirmar.
  Future<void> emptyTrashAsked() async {
    final ok = await onConfirm?.call(
      'Apagar tudo o que está na lixeira?',
      'Não dá para desfazer.',
      'Esvaziar',
    );
    if (ok ?? false) await emptyTrash();
  }

  Future<void> emptyTrash() async {
    await _guard(env.trash.empty);
    await tab.refresh();
  }

  void copy(List<String> paths, {bool cut = false}) {
    if (paths.isEmpty) return;
    unawaited(fileClipboard.copy(List.of(paths), cut: cut));
  }

  Future<void> paste() async {
    final dir = tab.folder;
    if (dir == null || tab.location is! FolderLocation) return;
    final clip = await fileClipboard.read();
    if (clip == null) return;
    if (clip.cut) await fileClipboard.clear();
    await transfer(clip.paths, dir, move: clip.cut);
  }

  Future<void> duplicate(List<String> paths) async {
    if (paths.isEmpty) return;
    await _run(FileJob.start(JobKind.duplicate, paths), 'Duplicando');
  }

  /// Copiar ou mover para [destination] (colar e arrastar).
  Future<void> transfer(
    List<String> paths,
    String destination, {
    required bool move,
  }) async {
    final sources = [
      for (final p in paths)
        if (!(move && dirName(p) == destination)) p,
    ];
    if (sources.isEmpty) return;
    await _run(
      FileJob.start(
        move ? JobKind.move : JobKind.copy,
        sources,
        destination: destination,
        onConflict: onConflict,
      ),
      move ? 'Movendo' : 'Copiando',
    );
  }

  Future<void> _run(FileJob job, String label) async {
    final running = RunningJob(job, label);
    jobs.add(running);
    notifyListeners();
    final sub = job.progress.listen((p) {
      running.progress = p;
      notifyListeners();
    });
    final result = await job.result;
    await sub.cancel();
    jobs.remove(running);
    if (result.errors.isNotEmpty) onError?.call(result.errors.join('\n'));
    if (result.done.isNotEmpty) {
      _pushUndo(FileJob.undoFor(job.kind, result, env.trash));
    }
    notifyListeners();
    await tab.refresh();
    // O que chegou fica selecionado
    final arrived = [
      for (final (_, target) in result.done)
        if (dirName(target) == tab.folder) target,
    ];
    if (arrived.isNotEmpty) tab.selectPaths(arrived);
  }

  // Abrir com

  final _appsCache = <String, Future<List<PsitoAppChoice>>>{};

  /// Os apps de um tipo, guardados enquanto a janela existir (o menu de
  /// contexto pede a cada vez).
  Future<List<PsitoAppChoice>> appsFor(String mimeType) =>
      _appsCache.putIfAbsent(mimeType, () => ctx.appsFor(mimeType));

  Future<void> setDefaultApp(String mimeType, String appId) async {
    _appsCache.clear();
    try {
      await ctx.setDefaultApp(mimeType, appId);
    } on Exception catch (e) {
      onError?.call('Não foi possível mudar o app padrão ($e)');
    }
  }

  @override
  void dispose() {
    fileClipboard.current.removeListener(notifyListeners);
    unawaited(_requests?.cancel());
    for (final job in jobs) {
      job.job.cancel();
    }
    for (final tab in tabs) {
      tab.dispose();
    }
    super.dispose();
  }
}
