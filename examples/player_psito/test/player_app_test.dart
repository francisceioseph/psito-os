import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:player_psito/player_app.dart';

void main() {
  test('o nome no menu segue o idioma', () {
    const app = PlayerApp();
    expect(app.localizedName(const Locale('en')), 'Music Player');
    expect(app.localizedName(const Locale('pt')), 'Player de música');
  });
}
