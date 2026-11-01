import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_runtime/psito_runtime.dart';

const _channel = MethodChannel('psito_test/clipboard');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('os formatos', () {
    const clip = FileClip(['/a b/c.txt', '/d'], cut: true);

    test('oferece os três, como o Nautilus', () {
      expect(clip.gnome, 'cut\nfile:///a%20b/c.txt\nfile:///d');
      expect(clip.uris, 'file:///a%20b/c.txt\r\nfile:///d\r\n');
      expect(clip.text, '/a b/c.txt\n/d');
      expect(const FileClip(['/d']).gnome, 'copy\nfile:///d');
    });

    test('lê o que ele mesmo oferece', () {
      expect(FileClip.parseGnome(clip.gnome), clip);
      expect(
        FileClip.parseUris(clip.uris),
        const FileClip(['/a b/c.txt', '/d']),
      );
    });

    test('um texto qualquer não é um arquivo', () {
      expect(FileClip.parseGnome('oi'), isNull);
      expect(FileClip.parseGnome('copy\nhttps://psito.org'), isNull);
      expect(FileClip.parseUris('https://psito.org\r\n'), isNull);
      expect(
        FileClip.parseUris('# comentário\r\nfile:///a\r\n'),
        const FileClip(['/a']),
      );
    });
  });

  group('o canal', () {
    late Map<String, String?> offered;
    late List<MethodCall> calls;

    setUp(() {
      offered = {};
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            calls.add(call);
            if (call.method != 'read') return null;
            final text = offered[call.arguments as String];
            return text == null ? null : utf8.encode(text);
          });
    });

    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null),
    );

    test('prefere o formato com a ação, e cai no das URIs', () async {
      final clipboard = PsitoClipboard(_channel);
      offered = {
        'x-special/gnome-copied-files': 'cut\nfile:///a',
        'text/uri-list': 'file:///a\r\n',
      };
      expect(await clipboard.read(), const FileClip(['/a'], cut: true));
      offered = {'text/uri-list': 'file:///b\r\n'};
      expect(await clipboard.read(), const FileClip(['/b']));
      offered = {};
      expect(await clipboard.read(), isNull);
      expect(clipboard.current.value, isNull);
    });

    test('copiar manda os três formatos', () async {
      final clipboard = PsitoClipboard(_channel);
      await clipboard.copy(['/a']);
      expect(calls.single.method, 'set');
      expect(calls.single.arguments, {
        'gnome': 'copy\nfile:///a',
        'uris': 'file:///a\r\n',
        'text': '/a',
      });
      expect(clipboard.current.value, const FileClip(['/a']));
    });

    test('outro app copiou: o "changed" relê', () async {
      final clipboard = PsitoClipboard(_channel);
      offered = {'text/uri-list': 'file:///c\r\n'};
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            _channel.name,
            _channel.codec.encodeMethodCall(const MethodCall('changed')),
            (_) {},
          );
      await pumpEventQueue();
      expect(clipboard.current.value, const FileClip(['/c']));
    });

    test('sem o plugin, fica no processo', () async {
      final clipboard = PsitoClipboard(
        const MethodChannel('psito_test/sem_plugin'),
      );
      await clipboard.copy(['/a'], cut: true);
      expect(await clipboard.read(), const FileClip(['/a'], cut: true));
      await clipboard.clear();
      expect(await clipboard.read(), isNull);
    });
  });
}
