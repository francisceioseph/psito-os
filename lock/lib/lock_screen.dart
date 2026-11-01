// lock/lib/lock_screen.dart
//
// O papel de parede, o relógio, o nome e o campo de senha.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/session_service.dart';

import 'l10n/lock_localizations.dart';

/// Quanto esperar depois de [failures] erros seguidos. O PAM já demora um
/// pouco em cada um, e isto segura quem tenta muitas.
Duration lockDelay(int failures) => switch (failures) {
  < 3 => Duration.zero,
  3 => const Duration(seconds: 5),
  4 => const Duration(seconds: 15),
  5 => const Duration(seconds: 30),
  _ => const Duration(minutes: 1),
};

class LockScreen extends StatefulWidget {
  final PsitoSettings settings;
  final String userName;
  final SessionService session;

  /// Confere a senha. Certa, o runner desbloqueia e encerra o processo.
  final Future<bool> Function(String password) authenticate;

  const LockScreen({
    super.key,
    required this.settings,
    required this.userName,
    required this.session,
    required this.authenticate,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _password = TextEditingController();
  final _focus = FocusNode();
  late final Timer _ticker;

  // O processo nasce a cada bloqueio, então o fuso do DateTime.now() é o de
  // agora (o problema dele é só em quem roda por muito tempo)
  DateTime _now = DateTime.now();
  bool _checking = false;
  bool _wrong = false;
  int _failures = 0;
  DateTime? _waitUntil;

  int get _waitSeconds {
    final until = _waitUntil;
    return until == null ? 0 : until.difference(_now).inSeconds + 1;
  }

  bool get _waiting {
    final until = _waitUntil;
    return until != null && _now.isBefore(until);
  }

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    _password.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _password.text;
    if (password.isEmpty || _checking || _waiting) return;
    setState(() => _checking = true);
    final ok = await widget.authenticate(password);
    if (!mounted || ok) return;
    _password.clear();
    final delay = lockDelay(++_failures);
    setState(() {
      _checking = false;
      _wrong = true;
      _now = DateTime.now();
      _waitUntil = delay == Duration.zero ? null : _now.add(delay);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = LockLocalizations.of(context);
    final palette = context.palette;
    final locale = Localizations.localeOf(context).toString();
    final colors = wallpaperById(widget.settings.wallpaperId).colors;
    final time =
        (widget.settings.use24h
                ? DateFormat.Hm(locale)
                : DateFormat('h:mm a', locale))
            .format(_now);
    final message = _waiting
        ? l.waitSeconds(_waitSeconds)
        : _wrong
        ? l.wrongPassword
        : null;
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _focus.requestFocus,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.first,
            gradient: colors.length > 1
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  )
                : null,
          ),
          child: Stack(
            children: [
              Center(
                child: SizedBox(
                  width: 320,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.w300,
                          color: palette.text,
                        ),
                      ),
                      Text(
                        DateFormat.yMMMMEEEEd(locale).format(_now),
                        style: TextStyle(color: palette.textSecondary),
                      ),
                      const SizedBox(height: 48),
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: palette.panel,
                        child: Icon(
                          Icons.person,
                          size: 40,
                          color: palette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.userName,
                        style: TextStyle(fontSize: 18, color: palette.text),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const ValueKey('lock-password'),
                        controller: _password,
                        focusNode: _focus,
                        autofocus: true,
                        obscureText: true,
                        // Não é enabled: desabilitado, o campo perde o foco, e
                        // a senha seguinte não teria onde entrar
                        readOnly: _checking || _waiting,
                        onSubmitted: (_) => unawaited(_submit()),
                        // Sem isto, o Enter tira o foco do campo
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
                            tooltip: l.unlock,
                            icon: const Icon(Icons.arrow_forward),
                            onPressed: _checking || _waiting
                                ? null
                                : () => unawaited(_submit()),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 20,
                        child: message == null
                            ? null
                            : Text(
                                message,
                                style: TextStyle(color: palette.danger),
                              ),
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
      ),
    );
  }
}
