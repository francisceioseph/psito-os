import 'dart:async';

import 'package:flutter/material.dart';
import 'package:psito_sdk/psito_sdk.dart';

import 'l10n/l10n.dart';
import 'settings_ui.dart';

/// O que o `useradd` aceita sem reclamar.
bool isValidLogin(String login) =>
    RegExp(r'^[a-z_][a-z0-9_-]{0,31}$').hasMatch(login);

/// A seção Usuários: o nome, a senha, criar e apagar. O que precisa de
/// administrador pede a senha no diálogo do shell, e cancelar vira um erro aqui.
class UsersSection extends StatefulWidget {
  final PsitoAccounts accounts;

  const UsersSection({super.key, required this.accounts});

  @override
  State<UsersSection> createState() => _UsersSectionState();
}

class _UsersSectionState extends State<UsersSection> {
  int? _open;
  bool _adding = false;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: widget.accounts.users,
    builder: (context, users, _) {
      if (users.isEmpty) return Text(context.l10n.usersUnavailable);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsGroup(
            children: [
              for (final user in users) ...[
                ListTile(
                  key: ValueKey('user-${user.login}'),
                  leading: const Icon(Icons.person_outline),
                  title: Text(user.name.isEmpty ? user.login : user.name),
                  subtitle: Text(_role(context, user)),
                  trailing: Icon(
                    _open == user.uid ? Icons.expand_less : Icons.expand_more,
                  ),
                  onTap: () => setState(() {
                    _open = _open == user.uid ? null : user.uid;
                  }),
                ),
                if (_open == user.uid)
                  SettingsPad(
                    child: _EditUser(
                      key: ValueKey(user.uid),
                      accounts: widget.accounts,
                      user: user,
                    ),
                  ),
              ],
            ],
          ),
          if (_adding)
            _AddUser(
              accounts: widget.accounts,
              onDone: () => setState(() => _adding = false),
            )
          else
            OutlinedButton.icon(
              icon: const Icon(Icons.person_add_outlined),
              label: Text(context.l10n.userAdd),
              onPressed: () => setState(() => _adding = true),
            ),
        ],
      );
    },
  );

  String _role(BuildContext context, PsitoUserAccount user) {
    final l = context.l10n;
    final role = user.isAdmin ? l.userAdmin : l.userStandard;
    return user.isCurrent
        ? l.userYou(user.login, role)
        : '${user.login} · $role';
  }
}

/// A linha de aviso depois de uma ação.
class _Status extends StatelessWidget {
  final String? text;
  final bool error;

  const _Status(this.text, {this.error = false});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 24,
    child: text == null
        ? null
        : Text(
            text!,
            style: TextStyle(
              color: error
                  ? context.palette.danger
                  : context.palette.textSecondary,
            ),
          ),
  );
}

/// Dois campos de senha iguais, e devolve qual problema há.
String? passwordProblem(BuildContext context, String first, String second) {
  if (first.isEmpty) return context.l10n.userPasswordEmpty;
  if (first != second) return context.l10n.userPasswordMismatch;
  return null;
}

class _EditUser extends StatefulWidget {
  final PsitoAccounts accounts;
  final PsitoUserAccount user;

  const _EditUser({super.key, required this.accounts, required this.user});

  @override
  State<_EditUser> createState() => _EditUserState();
}

class _EditUserState extends State<_EditUser> {
  late final _name = TextEditingController(text: widget.user.name);
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _status;
  bool _error = false;
  bool _confirmDelete = false;

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _show(bool ok) {
    if (!mounted) return;
    setState(() {
      _status = ok ? context.l10n.userSaved : context.l10n.userFailed;
      _error = !ok;
    });
  }

  Future<void> _saveName() async =>
      _show(await widget.accounts.setName(widget.user.uid, _name.text.trim()));

  Future<void> _savePassword() async {
    final problem = passwordProblem(context, _password.text, _confirm.text);
    if (problem != null) {
      setState(() {
        _status = problem;
        _error = true;
      });
      return;
    }
    final password = _password.text;
    _password.clear();
    _confirm.clear();
    _show(await widget.accounts.setPassword(widget.user.uid, password));
  }

  Future<void> _delete() async {
    final ok = await widget.accounts.delete(widget.user.uid);
    if (!ok) _show(false);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const ValueKey('user-name'),
            controller: _name,
            decoration: InputDecoration(labelText: l.userName),
          ),
          TextButton(
            onPressed: () => unawaited(_saveName()),
            child: Text(l.userSaveName),
          ),
          TextField(
            key: const ValueKey('user-password'),
            controller: _password,
            obscureText: true,
            decoration: InputDecoration(labelText: l.userNewPassword),
          ),
          TextField(
            key: const ValueKey('user-confirm'),
            controller: _confirm,
            obscureText: true,
            decoration: InputDecoration(labelText: l.userConfirmPassword),
          ),
          TextButton(
            onPressed: () => unawaited(_savePassword()),
            child: Text(l.userChangePassword),
          ),
          _Status(_status, error: _error),
          // A própria conta não sai: quem apagaria a sessão de quem está nela?
          if (!widget.user.isCurrent)
            if (_confirmDelete)
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(l.userDeleteConfirm(widget.user.login)),
                  TextButton(
                    onPressed: () => setState(() => _confirmDelete = false),
                    child: Text(l.cancel),
                  ),
                  FilledButton(
                    onPressed: () => unawaited(_delete()),
                    child: Text(l.userDelete),
                  ),
                ],
              )
            else
              TextButton(
                onPressed: () => setState(() => _confirmDelete = true),
                child: Text(l.userDelete),
              ),
        ],
      ),
    );
  }
}

class _AddUser extends StatefulWidget {
  final PsitoAccounts accounts;
  final VoidCallback onDone;

  const _AddUser({required this.accounts, required this.onDone});

  @override
  State<_AddUser> createState() => _AddUserState();
}

class _AddUserState extends State<_AddUser> {
  final _name = TextEditingController();
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _admin = false;
  String? _problem;

  @override
  void dispose() {
    _name.dispose();
    _login.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final l = context.l10n;
    final login = _login.text.trim();
    final problem = !isValidLogin(login)
        ? l.userLoginInvalid
        : passwordProblem(context, _password.text, _confirm.text);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    final name = _name.text.trim();
    final ok = await widget.accounts.create(
      login: login,
      name: name.isEmpty ? login : name,
      admin: _admin,
      password: _password.text,
    );
    if (ok) {
      widget.onDone();
    } else if (mounted) {
      setState(() => _problem = l.userFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey('new-name'),
          controller: _name,
          decoration: InputDecoration(labelText: l.userName),
        ),
        TextField(
          key: const ValueKey('new-login'),
          controller: _login,
          decoration: InputDecoration(labelText: l.userLogin),
        ),
        TextField(
          key: const ValueKey('new-password'),
          controller: _password,
          obscureText: true,
          decoration: InputDecoration(labelText: l.userNewPassword),
        ),
        TextField(
          key: const ValueKey('new-confirm'),
          controller: _confirm,
          obscureText: true,
          decoration: InputDecoration(labelText: l.userConfirmPassword),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.userAdminChoice),
          value: _admin,
          onChanged: (value) => setState(() => _admin = value),
        ),
        _Status(_problem, error: true),
        Wrap(
          spacing: 8,
          children: [
            TextButton(onPressed: widget.onDone, child: Text(l.cancel)),
            FilledButton(
              onPressed: () => unawaited(_create()),
              child: Text(l.userCreate),
            ),
          ],
        ),
      ],
    );
  }
}
