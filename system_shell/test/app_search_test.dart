import 'package:flutter_test/flutter_test.dart';
import 'package:system_shell/shell/app_entry.dart';
import 'package:system_shell/shell/app_search.dart';

import 'helpers.dart';

const _apps = [
  FakeApp('calculator', name: 'Calculator'),
  FakeApp('notepad', name: 'Notepad'),
  FakeApp('config', name: 'Configurações'),
  FakeApp('files', name: 'Arquivos'),
];

List<String> _ids(String query) => searchApps([
  for (final app in _apps) AppEntry.fromPsitoApp(app),
], query).map((a) => a.id).toList();

void main() {
  test('foldForSearch tira acentos e maiúsculas', () {
    expect(foldForSearch('ConfiguRAÇÕES Básicas'), 'configuracoes basicas');
  });

  test('busca vazia devolve todos na ordem do registry', () {
    expect(_ids(''), ['calculator', 'notepad', 'config', 'files']);
    expect(_ids('   '), hasLength(4));
  });

  test('ignora maiúsculas e acentos dos dois lados', () {
    expect(_ids('CALC'), ['calculator']);
    expect(_ids('cálc'), ['calculator']);
    expect(_ids('configuracoes'), ['config']);
    expect(_ids('CONFIGURAÇÕES'), ['config']);
  });

  test('acha pelo id', () {
    expect(_ids('files'), ['files']);
  });

  test('prefixo vem antes de trecho no meio', () {
    // Só Arquivos começa com "a"; os outros só contêm
    expect(_ids('a'), ['files', 'calculator', 'notepad', 'config']);
  });

  test('sem resultado', () {
    expect(_ids('xyz'), isEmpty);
  });
}
