import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:psito_sdk/psito_sdk.dart';

import 'l10n/l10n.dart';

/// 192.168.0.10/24: um IPv4 com o tamanho da rede.
bool isValidIpv4Cidr(String text) {
  final parts = text.split('/');
  if (parts.length != 2 || !isValidIpv4(parts[0])) return false;
  final prefix = int.tryParse(parts[1]);
  return prefix != null && prefix >= 1 && prefix <= 32;
}

bool isValidIpv4(String text) =>
    RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(text) &&
    InternetAddress.tryParse(text)?.type == InternetAddressType.IPv4;

/// Os servidores de DNS de um texto, separados por vírgula ou espaço.
List<String> splitDns(String text) =>
    text.split(RegExp(r'[,\s]+')).where((s) => s.isNotEmpty).toList();

/// A seção Rede: os dispositivos, com os detalhes, e as conexões guardadas.
class NetworkSection extends StatefulWidget {
  final PsitoNetworkState network;
  final PsitoNetworkConnections connections;

  const NetworkSection({
    super.key,
    required this.network,
    required this.connections,
  });

  @override
  State<NetworkSection> createState() => _NetworkSectionState();
}

class _NetworkSectionState extends State<NetworkSection> {
  String? _openDevice;
  String? _openConnection;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final device in widget.network.devices) ...[
          _DeviceTile(
            device,
            open: _openDevice == device.interface,
            onTap: () => setState(() {
              _openDevice = _openDevice == device.interface
                  ? null
                  : device.interface;
            }),
          ),
          if (_openDevice == device.interface) _DeviceDetails(device),
        ],
        ValueListenableBuilder(
          valueListenable: widget.connections.connections,
          builder: (context, connections, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (connections.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 4),
                  child: Text(
                    l.savedNetworks,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              for (final connection in connections) ...[
                ListTile(
                  key: ValueKey('connection-${connection.uuid}'),
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_kindIcon(connection.kind)),
                  title: Text(connection.name),
                  subtitle: Text(
                    connection.autoconnect
                        ? l.connectionAuto
                        : l.connectionManual,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.palette.textTertiary,
                    ),
                  ),
                  trailing: Icon(
                    _openConnection == connection.uuid
                        ? Icons.expand_less
                        : Icons.expand_more,
                  ),
                  onTap: () => setState(() {
                    _openConnection = _openConnection == connection.uuid
                        ? null
                        : connection.uuid;
                  }),
                ),
                if (_openConnection == connection.uuid)
                  _EditConnection(
                    // Pelo uuid: gravar muda a conexão, e o aviso de que deu
                    // certo fica no formulário
                    key: ValueKey(connection.uuid),
                    connections: widget.connections,
                    connection: connection,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

IconData _kindIcon(PsitoNetworkKind kind) => switch (kind) {
  PsitoNetworkKind.ethernet => Icons.lan,
  PsitoNetworkKind.wifi => Icons.wifi,
  PsitoNetworkKind.other => Icons.settings_ethernet,
};

class _DeviceTile extends StatelessWidget {
  final PsitoNetworkDevice device;
  final bool open;
  final VoidCallback onTap;

  const _DeviceTile(this.device, {required this.open, required this.onTap});

  static String stateLabel(PsitoDeviceState state, SettingsLocalizations l) =>
      switch (state) {
        PsitoDeviceState.connected => l.deviceConnected,
        PsitoDeviceState.connecting => l.deviceConnecting,
        PsitoDeviceState.disconnected => l.deviceDisconnected,
        PsitoDeviceState.unavailable => l.deviceUnavailable,
        PsitoDeviceState.other => l.deviceUnmanaged,
      };

  @override
  Widget build(BuildContext context) {
    final details = [
      stateLabel(device.state, context.l10n),
      ?device.connection,
      ?device.ipv4,
    ].join(' · ');
    return ListTile(
      key: ValueKey('device-${device.interface}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(_kindIcon(device.kind)),
      title: Text(device.interface),
      subtitle: Text(
        details,
        style: TextStyle(fontSize: 12, color: context.palette.textTertiary),
      ),
      trailing: Icon(open ? Icons.expand_less : Icons.expand_more),
      onTap: onTap,
    );
  }
}

class _DeviceDetails extends StatelessWidget {
  final PsitoNetworkDevice device;

  const _DeviceDetails(this.device);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Wrap(
        spacing: 12,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: context.palette.textQuiet),
            ),
          ),
          SelectableText(
            value,
            style: TextStyle(fontSize: 13, color: context.palette.text),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (device.ipv4 case final ipv4?) row(l.detailIpv4, ipv4),
          if (device.ipv6 case final ipv6?) row(l.detailIpv6, ipv6),
          if (device.gateway case final gateway?) row(l.detailGateway, gateway),
          if (device.dns.isNotEmpty) row(l.detailDns, device.dns.join(', ')),
          if (device.mac case final mac?) row(l.detailMac, mac),
        ],
      ),
    );
  }
}

class _EditConnection extends StatefulWidget {
  final PsitoNetworkConnections connections;
  final PsitoSavedConnection connection;

  const _EditConnection({
    super.key,
    required this.connections,
    required this.connection,
  });

  @override
  State<_EditConnection> createState() => _EditConnectionState();
}

class _EditConnectionState extends State<_EditConnection> {
  late bool _autoconnect = widget.connection.autoconnect;
  late PsitoMetered _metered = widget.connection.metered;
  late PsitoIpMethod _method = widget.connection.ipv4Method;
  late final _priority = TextEditingController(
    text: '${widget.connection.priority}',
  );
  late final _address = TextEditingController(text: widget.connection.address);
  late final _gateway = TextEditingController(text: widget.connection.gateway);
  late final _dns = TextEditingController(
    text: widget.connection.dns.join(', '),
  );
  String? _status;
  bool _error = false;
  bool _confirmForget = false;

  @override
  void dispose() {
    _priority.dispose();
    _address.dispose();
    _gateway.dispose();
    _dns.dispose();
    super.dispose();
  }

  /// O que está errado no formulário, para não mandar ao NetworkManager.
  String? _problem() {
    final l = context.l10n;
    if (int.tryParse(_priority.text.trim()) == null) {
      return l.connectionBadPriority;
    }
    if (_method == PsitoIpMethod.manual) {
      if (!isValidIpv4Cidr(_address.text.trim())) return l.connectionBadAddress;
      final gateway = _gateway.text.trim();
      if (gateway.isNotEmpty && !isValidIpv4(gateway)) {
        return l.connectionBadGateway;
      }
    }
    if (!splitDns(_dns.text).every(isValidIpv4)) return l.connectionBadDns;
    return null;
  }

  void _show(String text, {required bool error}) {
    if (!mounted) return;
    setState(() {
      _status = text;
      _error = error;
    });
  }

  Future<void> _save() async {
    final l = context.l10n;
    final problem = _problem();
    if (problem != null) return _show(problem, error: true);
    final manual = _method == PsitoIpMethod.manual;
    final ok = await widget.connections.update(
      widget.connection.copyWith(
        autoconnect: _autoconnect,
        priority: int.parse(_priority.text.trim()),
        metered: _metered,
        ipv4Method: _method,
        address: manual ? _address.text.trim() : '',
        gateway: manual ? _gateway.text.trim() : '',
        dns: splitDns(_dns.text),
      ),
    );
    _show(ok ? l.userSaved : l.userFailed, error: !ok);
  }

  Future<void> _forget() async {
    final l = context.l10n;
    final ok = await widget.connections.forget(widget.connection.uuid);
    if (!ok) _show(l.userFailed, error: true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final connection = widget.connection;
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            key: const ValueKey('connection-autoconnect'),
            contentPadding: EdgeInsets.zero,
            title: Text(l.connectionAutoconnect),
            value: _autoconnect,
            onChanged: (value) => setState(() => _autoconnect = value),
          ),
          TextField(
            key: const ValueKey('connection-priority'),
            controller: _priority,
            decoration: InputDecoration(
              labelText: l.connectionPriority,
              helperText: l.connectionPriorityHint,
              helperMaxLines: 3,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<PsitoMetered>(
            key: const ValueKey('connection-metered'),
            initialValue: _metered,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.connectionMetered),
            items: [
              DropdownMenuItem(
                value: PsitoMetered.auto,
                child: Text(l.connectionMeteredAuto),
              ),
              DropdownMenuItem(
                value: PsitoMetered.yes,
                child: Text(l.connectionMeteredYes),
              ),
              DropdownMenuItem(
                value: PsitoMetered.no,
                child: Text(l.connectionMeteredNo),
              ),
            ],
            onChanged: (value) => setState(() => _metered = value!),
          ),
          const SizedBox(height: 8),
          if (connection.ipv4Method != PsitoIpMethod.other) ...[
            DropdownButtonFormField<PsitoIpMethod>(
              key: const ValueKey('connection-method'),
              initialValue: _method,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.connectionIpv4),
              items: [
                DropdownMenuItem(
                  value: PsitoIpMethod.auto,
                  child: Text(l.connectionIpv4Auto),
                ),
                DropdownMenuItem(
                  value: PsitoIpMethod.manual,
                  child: Text(l.connectionIpv4Manual),
                ),
              ],
              onChanged: (value) => setState(() => _method = value!),
            ),
            if (_method == PsitoIpMethod.manual) ...[
              TextField(
                key: const ValueKey('connection-address'),
                controller: _address,
                decoration: InputDecoration(
                  labelText: l.connectionAddress,
                  hintText: '192.168.0.10/24',
                ),
              ),
              TextField(
                key: const ValueKey('connection-gateway'),
                controller: _gateway,
                decoration: InputDecoration(labelText: l.detailGateway),
              ),
            ],
            TextField(
              key: const ValueKey('connection-dns'),
              controller: _dns,
              decoration: InputDecoration(
                labelText: l.detailDns,
                helperText: l.connectionDnsHint,
                helperMaxLines: 3,
              ),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            height: 24,
            child: _status == null
                ? null
                : Text(
                    _status!,
                    style: TextStyle(
                      color: _error
                          ? context.palette.danger
                          : context.palette.textSecondary,
                    ),
                  ),
          ),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton(
                key: const ValueKey('connection-save'),
                onPressed: () => unawaited(_save()),
                child: Text(l.connectionSave),
              ),
              // O cabo não sai: sem a conexão dele, o NetworkManager não cria
              // outra sozinho, e a rede só volta pelo terminal
              if (connection.kind != PsitoNetworkKind.ethernet)
                if (_confirmForget) ...[
                  Text(l.connectionForgetConfirm(connection.name)),
                  TextButton(
                    onPressed: () => setState(() => _confirmForget = false),
                    child: Text(l.cancel),
                  ),
                  FilledButton(
                    key: const ValueKey('connection-forget-yes'),
                    onPressed: () => unawaited(_forget()),
                    child: Text(l.connectionForget),
                  ),
                ] else
                  TextButton(
                    key: const ValueKey('connection-forget'),
                    onPressed: () => setState(() => _confirmForget = true),
                    child: Text(l.connectionForget),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}
