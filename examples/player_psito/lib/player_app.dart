// examples/player_psito/lib/player_app.dart
//
// O player como app do Psito: a janela, o tema e os seletores vêm do runtime, e o
// resto é o próprio player.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:psito_player/l10n/player_localizations.dart';
import 'package:psito_player/player_app.dart';
import 'package:psito_sdk/psito_sdk.dart';

class PlayerApp extends PsitoApp {
  const PlayerApp();

  @override
  String get id => 'player';

  @override
  String get name => 'Music Player';

  @override
  String localizedName(Locale locale) =>
      lookupPlayerLocalizations(locale).appName;

  @override
  List<LocalizationsDelegate<dynamic>> get localizationsDelegates => const [
    PlayerLocalizations.delegate,
  ];

  @override
  IconData get icon => Icons.music_note_rounded;

  @override
  Color get color => const Color(0xFFFE8363);

  @override
  Size get defaultSize => const Size(1280, 800);

  // Abrir outro arquivo entrega ao player já aberto (openRequests)
  @override
  bool get singleInstance => true;

  @override
  Widget build(PsitoAppContext context) => PlayerView(
    createEngine: MediaKitEngine.new,
    openLibrary: openLibraryServices,
    initialPaths: context.openedPaths,
    openRequests: context.openRequests,
    connectBus: sessionBus,
    openFolder: (path) => context.open([path]),
    musicDir: userMusicDir(Platform.environment),
    pickFolder: (title) => context.pickFolder(title: title),
    pickPlaylistFile: (title) =>
        context.pickFile(title: title, patterns: const ['*.m3u', '*.m3u8']),
    pickSaveFile: (title, name) =>
        context.pickSaveFile(title: title, suggestedName: name),
  );
}
