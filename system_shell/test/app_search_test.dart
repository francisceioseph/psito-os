import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:system_shell/shell/app_search.dart';

class _FakeApp extends PsitoApp {
  @override
  final String id;
  @override
  final String name;

  const _FakeApp(this.id, this.name);

  @override
  IconData get icon => const IconData(0);
  @override
  Color get color => const Color(0xFFFFFFFF);
  @override
  Widget build(PsitoAppContext context) => const SizedBox();
}

const _apps = [
  _FakeApp('calculator', 'Calculator'),
  _FakeApp('notepad', 'Notepad'),
  _FakeApp('config', 'Configurações'),
  _FakeApp('files', 'Arquivos'),
];

List<String> _ids(String query) =>
    searchApps(_apps, query).map((a) => a.id).toList();

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
