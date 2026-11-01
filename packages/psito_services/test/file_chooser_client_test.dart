import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_services/file_chooser_client.dart';

void main() {
  test('o caminho vem da uri, e cancelar não tem caminho', () {
    final results = {
      'uris': DBusArray.string(['file:///home/ana/minha%20vpn.conf']),
    };
    expect(pickedPath(0, results), '/home/ana/minha vpn.conf');
    expect(pickedPath(1, results), isNull);
    expect(pickedPath(0, const {}), isNull);
  });
}
