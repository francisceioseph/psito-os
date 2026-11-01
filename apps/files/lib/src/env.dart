// apps/files/lib/src/env.dart
//
// O que o Files lê do sistema uma vez (o home, os tipos MIME, a lixeira e as
// pastas do usuário) e a configuração dele, em ~/.config/psito/files.json:
// os favoritos da barra lateral, o modo de ver de cada pasta, a ordem e os
// ocultos.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:psito_files_ui/psito_files_ui.dart';
import 'package:psito_fs/psito_fs.dart';
import 'package:psito_sdk/psito_sdk.dart';

import 'package:psito_files/l10n/files_localizations.dart';

class FilesEnv implements FileIconEnv {
  final String home;
  @override
  final MimeDatabase mime;
  final Trash trash;
  final Map<UserDir, String> userDirs;

  /// O `LANG`, para a descrição dos tipos.
  final String? locale;

  /// O idioma em uso.
  final Locale Function() currentLocale;

  /// Onde a configuração fica. Null: só na memória (os testes).
  final File? configFile;

  const FilesEnv({
    required this.home,
    required this.mime,
    required this.trash,
    this.userDirs = const {},
    this.locale,
    this.currentLocale = _systemLocale,
    this.configFile,
  });

  factory FilesEnv.fromPlatform({
    required DateTime Function() now,
    Locale Function() currentLocale = _systemLocale,
  }) {
    final env = Platform.environment;
    final home = env['HOME'] ?? '/';
    final config = env['XDG_CONFIG_HOME'] ?? '$home/.config';
    return FilesEnv(
      home: home,
      mime: MimeDatabase.load(MimeDatabase.dirsFor(env)),
      trash: Trash.forEnv(env, now: now),
      userDirs: loadUserDirs(env),
      locale: env['LANG'],
      currentLocale: currentLocale,
      configFile: File('$config/psito/files.json'),
    );
  }

  @override
  String? folderIcon(String path) => knownFolder(path)?.$1;

  /// O ícone e o nome de uma pasta conhecida (o home e as do usuário).
  (String, String)? knownFolder(String path) {
    if (path == home) return ('user-home', l10n.placeHome);
    if (path == '/') return ('drive-harddisk', l10n.placeComputer);
    for (final MapEntry(key: dir, value: dirPath) in userDirs.entries) {
      if (dirPath == path) return (dir.icon, baseName(path));
    }
    return null;
  }

  /// A descrição do tipo, como a coluna "Tipo" mostra.
  String describe(String mimeType) => mimeType == directoryType
      ? l10n.kindFolder
      : mime.description(mimeType, locale: _mimeLocale);

  FilesLocalizations get l10n => lookupFilesLocalizations(currentLocale());

  /// O `LANG` diz a variante (`pt_BR`), se o idioma em uso for o dele.
  String get _mimeLocale {
    final code = currentLocale().languageCode;
    return locale?.startsWith(code) ?? false ? locale! : code;
  }
}

Locale _systemLocale() => resolvePsitoLocale('');

enum ViewMode { icons, list, columns }

class FilesConfig extends ChangeNotifier {
  final File? file;

  /// As pastas da barra lateral, na ordem.
  List<String> favorites;

  /// O modo de cada pasta; as outras ficam com [defaultMode].
  final Map<String, ViewMode> viewModes;
  ViewMode defaultMode;
  FsSort sort;
  bool showHidden;

  /// O lado do ícone no modo ícones.
  double iconSize;

  FilesConfig({
    this.file,
    required this.favorites,
    Map<String, ViewMode>? viewModes,
    this.defaultMode = ViewMode.icons,
    this.sort = const FsSort(),
    this.showHidden = false,
    this.iconSize = 64,
  }) : viewModes = viewModes ?? {};

  static const minIconSize = 32.0;
  static const maxIconSize = 128.0;

  /// Os favoritos de quem nunca mexeu: o home e as pastas do usuário.
  static List<String> defaultFavorites(FilesEnv env) => [
    env.home,
    for (final dir in [
      UserDir.desktop,
      UserDir.documents,
      UserDir.download,
      UserDir.pictures,
      UserDir.music,
      UserDir.videos,
    ])
      ?env.userDirs[dir],
  ];

  static FilesConfig load(FilesEnv env) {
    final file = env.configFile;
    Map<String, Object?> json = const {};
    try {
      if (file != null && file.existsSync()) {
        final value = jsonDecode(file.readAsStringSync());
        if (value is Map<String, Object?>) json = value;
      }
    } on FormatException catch (e) {
      debugPrint('🦜 files: files.json inválido ($e)');
    } on FileSystemException catch (e) {
      debugPrint('🦜 files: sem o files.json ($e)');
    }
    ViewMode? mode(Object? name) =>
        ViewMode.values.where((m) => m.name == name).firstOrNull;
    final favorites = json['favorites'];
    final modes = json['viewModes'];
    return FilesConfig(
      file: file,
      favorites: favorites is List
          ? favorites.whereType<String>().toList()
          : defaultFavorites(env),
      viewModes: {
        if (modes is Map)
          for (final MapEntry(:key, :value) in modes.entries)
            if (key is String && mode(value) != null) key: mode(value)!,
      },
      defaultMode: mode(json['defaultMode']) ?? ViewMode.icons,
      sort: FsSort.fromJson(json['sort']),
      showHidden: json['showHidden'] == true,
      iconSize: switch (json['iconSize']) {
        final num n => n.toDouble().clamp(minIconSize, maxIconSize),
        _ => 64,
      },
    );
  }

  Map<String, Object?> toJson() => {
    'favorites': favorites,
    'viewModes': {
      for (final MapEntry(:key, :value) in viewModes.entries) key: value.name,
    },
    'defaultMode': defaultMode.name,
    'sort': sort.toJson(),
    'showHidden': showHidden,
    'iconSize': iconSize,
  };

  ViewMode modeFor(String path) => viewModes[path] ?? defaultMode;

  void setMode(String path, ViewMode mode) {
    viewModes[path] = mode;
    // A próxima pasta nova abre no último modo escolhido, como no Finder
    defaultMode = mode;
    _changed();
  }

  void setSort(FsSort value) {
    sort = value;
    _changed();
  }

  void setShowHidden(bool value) {
    showHidden = value;
    _changed();
  }

  void setIconSize(double value) {
    iconSize = value.clamp(minIconSize, maxIconSize);
    _changed();
  }

  void addFavorite(String path, {int? at}) {
    favorites.remove(path);
    favorites.insert((at ?? favorites.length).clamp(0, favorites.length), path);
    _changed();
  }

  void removeFavorite(String path) {
    if (favorites.remove(path)) _changed();
  }

  void moveFavorite(int from, int to) {
    final path = favorites.removeAt(from);
    favorites.insert(to.clamp(0, favorites.length), path);
    _changed();
  }

  Timer? _saveTimer;

  void _changed() {
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), save);
  }

  void save() {
    _saveTimer?.cancel();
    final file = this.file;
    if (file == null) return;
    try {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(toJson()),
      );
    } on FileSystemException catch (e) {
      debugPrint('🦜 files: não gravei o files.json ($e)');
    }
  }

  @override
  void dispose() {
    if (_saveTimer?.isActive ?? false) save();
    super.dispose();
  }
}
