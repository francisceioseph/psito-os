import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/session_service.dart';

import 'greetd_client.dart';
import 'l10n/greeter_localizations.dart';

class GreeterScreen extends StatefulWidget {
  final LoginFlow flow;
  final List<LoginUser> users;
  final SessionService session;
  final DateTime Function() now;

  const GreeterScreen({
    super.key,
    required this.flow,
    required this.users,
    required this.session,
    required this.now,
  });

  @override
  State<GreeterScreen> createState() => _GreeterScreenState();
}

class _GreeterScreenState extends State<GreeterScreen> {
  final _password = TextEditingController();
  final _focus = FocusNode();
  late final Timer _ticker;

  LoginUser? get _selected {
    final login = widget.flow.user;
    for (final user in widget.users) {
      if (user.login == login) return user;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {});
    });
    if (widget.users.length == 1) {
      unawaited(widget.flow.select(widget.users.single.login));
    }
  }

  @override
  void dispose() {
    _ticker.cancel();
    _password.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _pick(LoginUser user) {
    unawaited(widget.flow.select(user.login));
    _focus.requestFocus();
  }

  void _submit() {
    if (_password.text.isEmpty) return;
    unawaited(widget.flow.answer(_password.text));
    _password.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l = GreeterLocalizations.of(context);
    final palette = context.palette;
    final locale = Localizations.localeOf(context).toString();
    final now = widget.now();
    return Scaffold(
      body: PsitoWallpaperView(
        wallpaper: wallpaperById(PsitoSettings.defaults.wallpaperId),
        child: Stack(
          children: [
            Center(
              child: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat.Hm(locale).format(now),
                      style: TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.w300,
                        color: palette.text,
                      ),
                    ),
                    Text(
                      DateFormat.yMMMMEEEEd(locale).format(now),
                      style: TextStyle(color: palette.textSecondary),
                    ),
                    const SizedBox(height: 48),
                    ListenableBuilder(
                      listenable: widget.flow,
                      builder: (context, _) => _selected == null
                          ? _userList(l)
                          : _passwordForm(l, _selected!),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: ValueListenableBuilder(
                valueListenable: widget.session.capabilities,
                builder: (context, can, _) => Row(
                  children: [
                    if (can.canSuspend)
                      IconButton(
                        tooltip: l.suspend,
                        icon: const Icon(Icons.bedtime_outlined),
                        onPressed: () => unawaited(widget.session.suspend()),
                      ),
                    if (can.canReboot)
                      IconButton(
                        tooltip: l.reboot,
                        icon: const Icon(Icons.restart_alt),
                        onPressed: () => unawaited(widget.session.reboot()),
                      ),
                    if (can.canPowerOff)
                      IconButton(
                        tooltip: l.powerOff,
                        icon: const Icon(Icons.power_settings_new),
                        onPressed: () => unawaited(widget.session.powerOff()),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar() => CircleAvatar(
    radius: 36,
    backgroundColor: context.palette.panel,
    child: Icon(Icons.person, size: 40, color: context.palette.textSecondary),
  );

  Widget _userList(GreeterLocalizations l) {
    if (widget.users.isEmpty) {
      return Text(l.noUsers, style: TextStyle(color: context.palette.danger));
    }
    return Material(
      color: context.palette.panel,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final user in widget.users)
            ListTile(
              key: ValueKey('user-${user.login}'),
              leading: Icon(Icons.person, color: context.palette.textSecondary),
              title: Text(user.name),
              onTap: () => _pick(user),
            ),
        ],
      ),
    );
  }

  Widget _passwordForm(GreeterLocalizations l, LoginUser user) {
    final flow = widget.flow;
    final palette = context.palette;
    final checking = flow.state == LoginState.checking;
    final message = switch (flow.state) {
      LoginState.wrong => l.wrongPassword,
      LoginState.failed => l.signInFailed(flow.detail ?? ''),
      _ => flow.detail,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _avatar(),
        const SizedBox(height: 12),
        Text(user.name, style: TextStyle(fontSize: 18, color: palette.text)),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('greeter-password'),
          controller: _password,
          focusNode: _focus,
          autofocus: true,
          obscureText: flow.secret,
          // Como no bloqueio: desabilitado ou com o Enter padrão, o campo perde
          // o foco, e a próxima tentativa não teria onde entrar
          readOnly: checking,
          onSubmitted: (_) => _submit(),
          onEditingComplete: () {},
          decoration: InputDecoration(
            hintText: l.passwordHint,
            filled: true,
            fillColor: palette.panel,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            suffixIcon: IconButton(
              tooltip: l.signIn,
              icon: const Icon(Icons.arrow_forward),
              onPressed: checking ? null : _submit,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 20,
          child: message == null || message.isEmpty
              ? null
              : Text(message, style: TextStyle(color: palette.danger)),
        ),
        if (widget.users.length > 1)
          TextButton(
            onPressed: () => unawaited(_back()),
            child: Text(l.otherUser),
          ),
      ],
    );
  }

  Future<void> _back() async {
    await widget.flow.cancel();
    _password.clear();
  }
}
