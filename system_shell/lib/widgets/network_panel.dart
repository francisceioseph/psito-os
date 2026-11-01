// system_shell/lib/widgets/network_panel.dart
//
// Painel do ícone de rede: a conexão atual, os interruptores e as redes Wi-Fi,
// com a senha no próprio painel.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/network_service.dart';
import 'package:system_shell/l10n/l10n.dart';

import 'network_indicator.dart';
import 'top_bar.dart';

class NetworkPanel extends StatefulWidget {
  final NetworkService service;
  final VoidCallback onClose;
  final VoidCallback? onOpenSettings;

  /// Abre a página de login de uma rede com portal.
  final VoidCallback? onOpenPortal;

  const NetworkPanel({
    super.key,
    required this.service,
    required this.onClose,
    this.onOpenSettings,
    this.onOpenPortal,
  });

  static String connectivityLabel(SystemLocalizations l, PsitoConnectivity c) =>
      switch (c) {
        PsitoConnectivity.full => l.connectivityFull,
        PsitoConnectivity.limited ||
        PsitoConnectivity.none => l.connectivityNone,
        PsitoConnectivity.portal => l.connectivityPortal,
        PsitoConnectivity.unknown => l.connectivityUnknown,
      };

  static String kindLabel(SystemLocalizations l, PsitoNetworkKind kind) =>
      switch (kind) {
        PsitoNetworkKind.ethernet => l.kindEthernet,
        PsitoNetworkKind.wifi => l.kindWifi,
        PsitoNetworkKind.other => l.network,
      };

  /// Procura de novo enquanto o painel está aberto, e mostra "procurando" até
  /// a primeira busca responder.
  static const rescanEvery = Duration(seconds: 20);
  static const searchingFor = Duration(seconds: 4);

  @override
  State<NetworkPanel> createState() => _NetworkPanelState();
}

/// O formulário aberto: o de uma rede da lista ou, com [ssid] null, o da rede
/// oculta.
class _Form {
  final String? ssid;
  const _Form(this.ssid);
}

class _NetworkPanelState extends State<NetworkPanel> {
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _passwordFocus = FocusNode();
  final _nameFocus = FocusNode();
  Timer? _rescan;
  Timer? _searchDone;
  bool _searching = true;
  bool _obscure = true;
  _Form? _form;

  /// A rede em que está conectando.
  String? _connecting;
  PsitoWifiResult? _failure;

  /// A rede da falha, ou null quando foi no formulário da oculta.
  String? _failedSsid;

  @override
  void initState() {
    super.initState();
    unawaited(widget.service.scanWifi());
    _rescan = Timer.periodic(
      NetworkPanel.rescanEvery,
      (_) => unawaited(widget.service.scanWifi()),
    );
    _searchDone = Timer(NetworkPanel.searchingFor, () {
      if (mounted) setState(() => _searching = false);
    });
  }

  @override
  void dispose() {
    _rescan?.cancel();
    _searchDone?.cancel();
    _password.dispose();
    _name.dispose();
    _passwordFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _openForm(String? ssid) {
    _password.clear();
    _name.clear();
    setState(() {
      _form = _Form(ssid);
      _obscure = true;
      _failure = null;
      _failedSsid = null;
    });
    // O autofocus não serve: o painel já tem o foco quando o campo nasce
    final field = ssid == null ? _nameFocus : _passwordFocus;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) field.requestFocus();
    });
  }

  void _closeForm() => setState(() {
    _form = null;
    _failure = null;
    _failedSsid = null;
  });

  Future<void> _tap(PsitoWifiNetwork network) async {
    if (network.active || _connecting != null) return;
    if (network.security == PsitoWifiSecurity.personal && !network.saved) {
      _openForm(network.ssid);
      return;
    }
    await _connect(network.ssid);
  }

  Future<void> _submit() async {
    final form = _form;
    if (form == null || _connecting != null) return;
    final hidden = form.ssid == null;
    final ssid = hidden ? _name.text.trim() : form.ssid!;
    if (ssid.isEmpty) return;
    final password = _password.text;
    await _connect(
      ssid,
      password: password.isEmpty ? null : password,
      hidden: hidden,
    );
  }

  Future<void> _connect(
    String ssid, {
    String? password,
    bool hidden = false,
  }) async {
    setState(() {
      _connecting = ssid;
      _failure = null;
      _failedSsid = null;
    });
    final result = await widget.service.connectWifi(
      ssid,
      password: password,
      hidden: hidden,
    );
    if (!mounted) return;
    if (result == PsitoWifiResult.needsPassword ||
        result == PsitoWifiResult.wrongPassword) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _passwordFocus.requestFocus();
      });
    }
    setState(() {
      _connecting = null;
      switch (result) {
        case PsitoWifiResult.connected:
          _form = null;
        case PsitoWifiResult.needsPassword:
          _form = _Form(ssid);
        case PsitoWifiResult.wrongPassword:
          _form = hidden ? const _Form(null) : _Form(ssid);
          _failure = result;
          _failedSsid = hidden ? null : ssid;
        // O que foi digitado continua no campo, para corrigir
        case PsitoWifiResult.notFound || PsitoWifiResult.failed:
          _failure = result;
          _failedSsid = hidden ? null : ssid;
      }
    });
  }

  String? _failureText(SystemLocalizations l) => switch (_failure) {
    PsitoWifiResult.wrongPassword => l.wifiWrongPassword,
    PsitoWifiResult.notFound => l.wifiNotFound,
    PsitoWifiResult.failed => l.wifiFailed,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
      },
      child: Focus(
        autofocus: true,
        child: Stack(
          children: [
            // Clicar fora fecha. A top bar fica de fora: clicar em outro
            // ícone dela troca de painel em vez de só fechar este
            Positioned.fill(
              top: TopBar.height,
              child: GestureDetector(
                onTap: widget.onClose,
                behavior: HitTestBehavior.opaque,
              ),
            ),
            Positioned(
              top: 48,
              right: 12,
              width: 300,
              child: ValueListenableBuilder(
                valueListenable: widget.service.state,
                builder: (context, s, _) => _buildPanel(context, s),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanel(BuildContext context, PsitoNetworkState s) {
    final primary = s.primary;
    final palette = context.palette;
    final (icon, _, color) =
        NetworkIndicator.describe(context.l10n, s, palette: palette) ??
        (Icons.link_off, '', null);
    final wifi = s.wifi;
    return Material(
      color: palette.panel,
      borderRadius: BorderRadius.circular(18),
      elevation: 12,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 28, color: color ?? palette.text),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        primary?.connection ??
                            (s.enabled
                                ? context.l10n.networkDisconnected
                                : context.l10n.networkOff),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (primary != null)
                        Text(
                          '${NetworkPanel.kindLabel(context.l10n, primary.kind)} · '
                          '${NetworkPanel.connectivityLabel(context.l10n, s.connectivity)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.textTertiary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (primary?.ipv4 case final ip?) ...[
              const SizedBox(height: 12),
              Text(
                'IPv4  $ip',
                style: TextStyle(fontSize: 12, color: palette.textSecondary),
              ),
            ],
            if (s.connectivity == PsitoConnectivity.portal &&
                s.checkUrl.isNotEmpty)
              if (widget.onOpenPortal case final open?)
                TextButton(
                  key: const ValueKey('network-portal'),
                  onPressed: open,
                  child: Text(context.l10n.networkPortalLogin),
                ),
            Divider(height: 24, color: palette.lineSoft),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(context.l10n.network),
              value: s.enabled,
              onChanged: widget.service.setEnabled,
            ),
            if (wifi != null && s.enabled) ...[
              SwitchListTile(
                key: const ValueKey('wifi-switch'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(context.l10n.wifi),
                value: wifi.enabled,
                onChanged: widget.service.setWifiEnabled,
              ),
              if (wifi.enabled) ..._wifiList(context, wifi),
            ],
            if (widget.onOpenSettings case final open?) ...[
              Divider(height: 16, color: palette.lineSoft),
              TextButton(
                key: const ValueKey('network-settings'),
                onPressed: open,
                child: Text(context.l10n.networkSettings),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _wifiList(BuildContext context, PsitoWifiState wifi) {
    final l = context.l10n;
    final palette = context.palette;
    final hiddenForm = _form != null && _form!.ssid == null;
    return [
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (wifi.networks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _searching ? l.wifiSearching : l.wifiNoNetworks,
                    style: TextStyle(fontSize: 12, color: palette.textTertiary),
                  ),
                ),
              for (final network in wifi.networks) ...[
                _row(context, network),
                if (_form?.ssid == network.ssid)
                  _passwordForm(context)
                else if (_failedSsid == network.ssid)
                  _failureLine(context),
              ],
              if (hiddenForm)
                _passwordForm(context, askName: true)
              else
                InkWell(
                  key: const ValueKey('wifi-other'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: _connecting == null ? () => _openForm(null) : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      l.wifiOtherNetwork,
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _row(BuildContext context, PsitoWifiNetwork network) {
    final l = context.l10n;
    final palette = context.palette;
    final unsupported = network.security == PsitoWifiSecurity.unsupported;
    final color = unsupported ? palette.textDisabled : palette.text;
    final row = InkWell(
      key: ValueKey('wifi-${network.ssid}'),
      borderRadius: BorderRadius.circular(8),
      onTap: unsupported ? null : () => unawaited(_tap(network)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              NetworkIndicator.wifiIcon(network.strength),
              size: 16,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                network.ssid,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: network.active ? FontWeight.w600 : null,
                ),
              ),
            ),
            if (network.security != PsitoWifiSecurity.open)
              Icon(Icons.lock_outline, size: 14, color: palette.textTertiary),
            if (_connecting == network.ssid) ...[
              const SizedBox(width: 8),
              const SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
            if (network.active) ...[
              const SizedBox(width: 8),
              Icon(Icons.check, size: 16, color: palette.textSecondary),
              IconButton(
                key: const ValueKey('wifi-disconnect'),
                tooltip: l.wifiDisconnect,
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                icon: const Icon(Icons.link_off),
                onPressed: () => unawaited(widget.service.disconnectWifi()),
              ),
            ],
          ],
        ),
      ),
    );
    return unsupported ? Tooltip(message: l.wifiUnsupported, child: row) : row;
  }

  Widget _failureLine(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 26, bottom: 6),
    child: Text(
      _failureText(context.l10n) ?? '',
      style: TextStyle(fontSize: 12, color: context.palette.danger),
    ),
  );

  Widget _passwordForm(BuildContext context, {bool askName = false}) {
    final l = context.l10n;
    final busy = _connecting != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (askName) ...[
            TextField(
              key: const ValueKey('wifi-name'),
              controller: _name,
              focusNode: _nameFocus,
              readOnly: busy,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                labelText: l.wifiNetworkName,
                labelStyle: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            key: const ValueKey('wifi-password'),
            controller: _password,
            focusNode: _passwordFocus,
            obscureText: _obscure,
            // Não é enabled: desabilitado, o campo perde o foco
            readOnly: busy,
            style: const TextStyle(fontSize: 13),
            onSubmitted: (_) => unawaited(_submit()),
            // Sem isto, o Enter tira o foco do campo
            onEditingComplete: () {},
            decoration: InputDecoration(
              isDense: true,
              labelText: l.wifiPassword,
              labelStyle: const TextStyle(fontSize: 13),
              suffixIcon: IconButton(
                tooltip: _obscure ? l.wifiShowPassword : l.wifiHidePassword,
                iconSize: 16,
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          if (_failureText(l) != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _failureText(l)!,
                key: const ValueKey('wifi-failure'),
                style: TextStyle(fontSize: 12, color: context.palette.danger),
              ),
            ),
          const SizedBox(height: 6),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            children: [
              if (busy && askName)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              TextButton(
                onPressed: busy ? null : _closeForm,
                child: Text(l.wifiCancel),
              ),
              TextButton(
                key: const ValueKey('wifi-connect'),
                onPressed: busy ? null : () => unawaited(_submit()),
                child: Text(l.wifiConnect),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
