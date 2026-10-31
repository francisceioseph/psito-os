// shell/lib/bridge/wayfire.dart
//
// A ponte para o Wayfire, pelo IPC (plugin ipc): os atalhos e as cores vão
// por wayfire/set-config-options, sem mexer no wayfire.ini. As opções valem
// até o Wayfire sair, e o shell aplica de novo a cada vez que sobe.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:system_shell/shell/shortcuts.dart';

import 'bindings.dart';
import 'colors.dart';

/// A opção do Wayfire de cada ação que o compositor faz.
String? _wayfireOption(ShellAction action) => switch (action) {
  ShellAction.closeWindow => 'core/close_top_view',
  ShellAction.maximize => 'grid/slot_c',
  ShellAction.snapLeft => 'grid/slot_l',
  ShellAction.snapRight => 'grid/slot_r',
  ShellAction.minimize => 'wm-actions/minimize',
  _ => null,
};

/// As opções que a ponte muda. Um activator aceita várias combinações
/// separadas por `|`; as ações do shell viram entradas do plugin command
/// (`repeatable_bindings` para as que repetem com a tecla segurada).
Map<String, Object> wayfireOptions(
  List<CompositorBinding> bindings,
  Color accent,
) {
  final activators = <String, List<String>>{};
  final commands = <String, Map<String, List<String>>>{};
  for (final b in bindings) {
    if (shellHandles(b.action)) {
      final list = b.repeats
          ? 'command/repeatable_bindings'
          : 'command/bindings';
      (commands
              .putIfAbsent(list, () => {})
              .putIfAbsent('psito_${b.action.name}', () => []))
          .add(wayfireKey(b));
    } else {
      activators
          .putIfAbsent(_wayfireOption(b.action)!, () => [])
          .add(wayfireKey(b));
    }
  }
  return {
    for (final MapEntry(:key, :value) in activators.entries)
      key: value.join(' | '),
    for (final list in ['command/bindings', 'command/repeatable_bindings'])
      list: {
        for (final MapEntry(:key, :value) in (commands[list] ?? {}).entries)
          key: {
            'command': shellCommand(
              ShellAction.values.byName(key.substring(6)),
            ),
            'binding': value.join(' | '),
          },
      },
    'decoration/active_color': wayfireColor(accent),
    'decoration/inactive_color': wayfireColor(psitoBackground),
  };
}

/// Uma mensagem do IPC: 4 bytes de tamanho (little-endian) e o JSON.
Uint8List encodeMessage(String method, Map<String, Object?> data) {
  final body = utf8.encode(jsonEncode({'method': method, 'data': data}));
  return (BytesBuilder()
        ..add(
          (ByteData(
            4,
          )..setUint32(0, body.length, Endian.little)).buffer.asUint8List(),
        )
        ..add(body))
      .toBytes();
}

/// Junta os pedaços do socket e devolve as mensagens completas.
class MessageDecoder {
  final _buffer = BytesBuilder();

  List<Map<String, Object?>> add(List<int> chunk) {
    _buffer.add(chunk);
    final messages = <Map<String, Object?>>[];
    var bytes = _buffer.takeBytes();
    while (bytes.length >= 4) {
      final length = ByteData.sublistView(
        bytes,
        0,
        4,
      ).getUint32(0, Endian.little);
      if (bytes.length < 4 + length) break;
      messages.add(
        jsonDecode(utf8.decode(bytes.sublist(4, 4 + length)))
            as Map<String, Object?>,
      );
      bytes = bytes.sublist(4 + length);
    }
    _buffer.add(bytes);
    return messages;
  }
}

/// Uma chamada ao IPC, num socket próprio.
Future<Map<String, Object?>> wayfireCall(
  String socketPath,
  String method,
  Map<String, Object?> data,
) async {
  final socket = await Socket.connect(
    InternetAddress(socketPath, type: InternetAddressType.unix),
    0,
  );
  try {
    socket.add(encodeMessage(method, data));
    final decoder = MessageDecoder();
    await for (final chunk in socket.timeout(const Duration(seconds: 3))) {
      final messages = decoder.add(chunk);
      if (messages.isNotEmpty) return messages.first;
    }
    throw const SocketException('o Wayfire fechou o IPC sem responder');
  } finally {
    socket.destroy();
  }
}

Future<void> applyWayfire(String socketPath, Color accent) async {
  final reply = await wayfireCall(
    socketPath,
    'wayfire/set-config-options',
    wayfireOptions(compositorBindings(), accent),
  );
  if (reply['result'] != 'ok') {
    throw StateError('Wayfire recusou as opções: ${reply['error']}');
  }
}
